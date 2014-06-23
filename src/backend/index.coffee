_ = require 'underscore'
h5bp = require 'h5bp'
path = require 'path'
logger = require "#{__dirname}/logger"
config = require "#{__dirname}/config.json"
phrases = require "#{__dirname}/phrases.json"
Twit = require 'twit'

Handlebars = require 'handlebars'
require './templates/index'
require './templates/error'

twitter = new Twit config.twit

# Note that the directory tree is relative to the 'BACKEND_LIBDIR' Makefile
# variable (`lib` by default) directory
app = h5bp.createServer
  root: path.join(__dirname, "..", "public")
  www: false     # Redirect www.example.tld -> example.tld
  compress: true # gzip responses from the server

#if process.env.NODE_ENV is 'development'
  # Put development environment only routes + code here

# Pull out all the possible tracks
tracks = _.chain(phrases).reduce( ((memo, phrase) ->
  memo.concat phrase.track
), []).uniq().value()

_(phrases).each (phrase) ->
  # Convert the phrase regex's to RegExp objects
  phrase.regex = new RegExp(phrase.regex, 'i') if phrase.regex

  # Convert the replies to handlebars templates
  if _(phrase.reply).isArray()
    _(phrase.reply).each (reply, index, list) -> list[index] = Handlebars.compile reply
  else
    phrase.reply = Handlebars.compile phrase.reply


userStream = twitter.stream 'user',
  with: 'user'  # Restrict to just the authenticated user's tweets/retweets
  track: tracks # Filter to contain these phrases
  stringify_friend_ids: true # ids in string, to avoid overflowing 32-bit ints

userStream.on 'tweet', (tweet) ->

  original = tweet.retweeted_status

  # We're only interested in retweets of our posts
  return if not original? or original.user.id_str isnt config.twitter.user_id

  matchedPhrase = _(phrases).find (phrase) -> original.text.match phrase.regex
  return if not matchedPhrase

  amount = original.text.match(matchedPhrase.regex)[1]
  return if not amount

  user = tweet.user.screen_name
  id = tweet.user.id_str

  # If we have a selection of replies, pick one randomly
  # Otherwise, use it as-is
  replyTemplate = if _(matchedPhrase.reply).isArray()
    _(matchedPhrase.reply).sample()
  else
    matchedPhrase.reply

  twitter.post 'statuses/update', {
    status: replyTemplate
      amount: amount
      user: user
      id: id
  }, (err, data, response) ->
    console.log(err) if err
    # console.log response
    console.log data

  console.log "[TWEET]", amount, matchedPhrase.currency

userStream.on 'connected', (req) ->
  console.log "[CONNECTED]"

userStream.on 'disconnect', (req) ->
  console.log "[DISCONNECT]"


twitter.post 'statuses/update', { status: 'Lets see if this works! Retweet and get 43 Doge' }, (err, data, response) ->
  console.log(err) if err
  # console.log response
  console.log data

# app.get '/', (req, res) ->

#   res.send 200, Handlebars.templates['index']({})


# onError = (res, code, message, url, extra) ->

#   error =
#     error:
#       code: code
#       url: url

#   error.error.extra = extra if extra?

#   logger.error message, error

#   res.send code, Handlebars.templates['error']
#     code: code
#     message: message


# # The 404 Route
# app.use (req, res, next) ->

#   onError res, 404, "Page Not Found", req.url


# # The error Route (ALWAYS Keep this as the last route)
# app.use (err, req, res, next) ->

#   onError res, 500, "There was an error", req.url,
#     message: err.message
#     stack: err.stack


# app.listen 3000
logger.info "STARTUP: Listening on http://localhost:3000"

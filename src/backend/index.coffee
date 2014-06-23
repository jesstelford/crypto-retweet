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


getTweetPhraseMatch = (tweet) ->

  # We're only interested in tweets of our posts
  return null if not tweet.user?
  return null if tweet.user.id_str isnt config.twitter.user_id
  return null if not tweet.text?

  matchedPhrase = _(phrases).find (phrase) -> tweet.text.match phrase.regex

  if not matchedPhrase?
    logger.info "Unmatched phrase",
      tweet: tweet.text
      id: tweet.id_str
      phrases: phrases
    return null

  amount = tweet.text.match(matchedPhrase.regex)[1]

  if not amount
    logger.info "Amount not determined",
      tweet: tweet.text
      id: tweet.id_str
      phrases: phrases
    return null

  result =
    phrase: matchedPhrase
    amount: amount


getReplyAndPhraseMatch = (tweet) ->

  result = getTweetPhraseMatch tweet
  return null if not result?

  # If we have a selection of replies, pick one randomly
  # Otherwise, use it as-is
  result.reply = if _(result.phrase.reply).isArray()
    _(result.phrase.reply).sample()
  else
    result.phrase.reply

  return result


generateReplyText = (phrase, user, id) ->
  return phrase.reply
    amount: phrase.amount
    user: user
    id: id


postReplyTweet = (phrase, user, id) ->

  text = generateReplyText phrase, user, id

  twitter.post 'statuses/update', { status: text }, (err, data, response) ->

    if err?
      logger.error "Unable to post tweet",
        phrase: phrase
        tweet:
          text: text
        user:
          screen_name: user
          id: id
      return

    logger.info "Posted tweet",
      phrase: phrase
      tweet:
        text: text
        id: data.id_str
      user:
        screen_name: user
        id: id

processRetweet = (tweet) ->

  original = tweet.retweeted_status

  matchedPhrase = getReplyAndPhraseMatch original

  return if not matchedPhrase?

  user = tweet.user.screen_name
  id = tweet.user.id_str

  postReplyTweet matchedPhrase, user, id

processTweet = (tweet) ->

  # TODO: Log the tweet to the DB if it matches, in preparation for retweets
  phrase = getTweetPhraseMatch tweet
  return if not phrase?

  console.log "[TWEET]", phrase.amount, phrase.phrase.currency

userStream = twitter.stream 'user',
  with: 'user'  # Restrict to just the authenticated user's tweets/retweets
  track: tracks # Filter to contain these phrases
  stringify_friend_ids: true # ids in string, to avoid overflowing 32-bit ints

userStream.on 'tweet', (tweet) ->

  if tweet.retweeted_status?
    processRetweet tweet
  else
    processTweet tweet

userStream.on 'connected', (req) ->
  logger.info "Connected"

userStream.on 'disconnect', (req) ->
  logger.info "Disconnected"


twitter.post 'statuses/update', { status: 'Refactor test 8! Retweet and get 25 Doge' }, (err, data, response) ->
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

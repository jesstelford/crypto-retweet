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

userStream = twitter.stream 'user',
  with: 'user'  # Restrict to just the authenticated user's tweets/retweets
  track: tracks # Filter to contain these phrases
  stringify_friend_ids: true # ids in string, to avoid overflowing 32-bit ints

userStream.on 'tweet', (tweet) ->

  original = tweet.retweeted_status

  # We're only interested in retweets of our posts
  return if not original? or original.user.id_str isnt config.twitter.user_id


  console.log "[TWEET]", tweet

userStream.on 'connected', (req) ->
  console.log "[CONNECTED]"

userStream.on 'disconnect', (req) ->
  console.log "[DISCONNECT]"


twitter.post 'statuses/update', { status: 'Hurray! Retweet and get 101 Doge' }, (err, data, response) ->
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

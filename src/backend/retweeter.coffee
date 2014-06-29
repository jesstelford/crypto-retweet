_ = require 'underscore'
logger = require "#{__dirname}/logger"
config = require "#{__dirname}/config.json"
phrases = require "#{__dirname}/phrases.json"
Handlebars = require 'handlebars'

# Pull out all the possible tracks
tracks = _.chain(phrases).reduce( ((memo, phrase) ->
  memo.concat phrase.track
), []).uniq().value()

compiledPhrases = []
_(phrases).each (originalPhrase, phraseIndex) ->

  phrase = _({}).extend originalPhrase

  phrase.id = phraseIndex

  # Convert the phrase regex's to RegExp objects
  phrase.regex = new RegExp(phrase.regex, 'i') if phrase.regex

  # Convert the replies to handlebars templates
  if _(phrase.reply).isArray()
    # First, ensure we're using a copy, not the original array
    phrase.reply = phrase.reply.slice()
    _(phrase.reply).each (reply, index) -> phrase.reply[index] = Handlebars.compile reply
  else
    phrase.reply = Handlebars.compile phrase.reply

  compiledPhrases.push phrase

getTweetPhraseMatch = (tweet) ->

  # We're only interested in tweets of our posts
  return null if not tweet.user?
  return null if tweet.user.id_str isnt config.twitter.user_id
  return null if not tweet.text?

  matchedPhrase = _(compiledPhrases).find (phrase) -> tweet.text.match phrase.regex

  if not matchedPhrase?
    logger.debug "Unmatched phrase",
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
    cacheBust: Date.now()
    id: id


postReplyTweet = (tweet, phrase, user, id, postStatus) ->

  text = generateReplyText phrase, user, id

  updateOptions =
    status: generateReplyText phrase, user, id

  if config.options.reply_to_original
    updateOptions.in_reply_to_status_id = tweet.id_str

  postStatus updateOptions, (err, data, response) ->

    logInfo =
      phrase: phrases[phrase.phrase.id]
      tweet:
        text: text
      user:
        screen_name: user
        id: id
      original:
        text: tweet.text
        id: tweet.id_str

    if err?
      logInfo.error = err
      logger.error "Unable to post tweet", logInfo
      return

    logInfo.tweet.id = data.id_str
    logger.info "Posted tweet", logInfo

processRetweet = (tweet, postStatus) ->

  original = tweet.retweeted_status

  matchedPhrase = getReplyAndPhraseMatch original

  return if not matchedPhrase?

  user = tweet.user.screen_name
  id = tweet.user.id_str

  postReplyTweet original, matchedPhrase, user, id, postStatus

processTweet = (tweet) ->

  # TODO: Log the tweet to the DB if it matches, in preparation for retweets
  phrase = getTweetPhraseMatch tweet
  return if not phrase?

  # console.log "[TWEET]", phrase.amount, phrase.phrase.currency

module.exports =
  tracks: tracks
  processTweet: processTweet
  processRetweet: processRetweet

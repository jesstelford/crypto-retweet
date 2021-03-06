_ = require 'underscore'
logger = require "#{__dirname}/logger"
config = require "#{__dirname}/config.json"
phrases = require "#{__dirname}/phrases.json"
TweetModel = require "#{__dirname}/models/tweet"
PayoutModel = require "#{__dirname}/models/payout"
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


postReplyTweet = (tweet, phrase, user, userId, retweetId, postStatus) ->

  text = generateReplyText phrase, user, userId

  updateOptions =
    status: generateReplyText phrase, user, userId

  if config.options.reply_to_original
    updateOptions.in_reply_to_status_id = tweet.id_str

  postStatus updateOptions, (err, replyTweet, response) ->

    logInfo =
      phrase: phrases[phrase.phrase.id]
      tweet:
        text: text
      user:
        screen_name: user
        id: userId
      original:
        text: tweet.text
        id: tweet.id_str

    if err?
      logInfo.error = err
      logger.error "Unable to post tweet", logInfo
      return

    logInfo.tweet.id = replyTweet.id_str
    logger.info "Posted tweet", logInfo

    saveTweetDocument replyTweet, false

    payout = new PayoutModel
      tweet_id: tweet.id_str
      retweet_id: retweetId
      payout_tweet_id: replyTweet.id_str
      user_id: userId
      currency: phrases[phrase.phrase.id].currency
      amount: phrase.amount
      timestamp: replyTweet.timestamp

    saveDocument payout, "Payout"


saveTweetDocument = (tweet, isRetweet) ->

  tweetDocument = new TweetModel
    original: tweet
    id: tweet.id_str
    text: tweet.text
    user_id: tweet.user.id_str
    timestamp: tweet.timestamp
    is_retweet: isRetweet

  saveDocument tweetDocument, "Tweet"

saveDocument = (document, type) ->
  document.save (err, doc) ->
    return unless err?
    logger.error "Unable to save #{type} to database",
      error: err
      values: doc.toObject()

processRetweet = (tweet, postStatus) ->

  original = tweet.retweeted_status

  matchedPhrase = getReplyAndPhraseMatch original

  return if not matchedPhrase?

  saveTweetDocument tweet, true

  user = tweet.user.screen_name
  userId = tweet.user.id_str

  # We want to make sure someone isn't gaming the system before we do another
  # payout
  PayoutModel.findExisting original.id_str, userId, (err, payouts) ->

    if err?
      logger.error "Unable to check for existing payouts",
        error: err
        tweet_id: original.id_str
        user_id: userId

    # Looks like we've already paid out to this user for retweeting this tweet
    if payouts.length > 0
      payouts[0].attempts = payouts[0].attempts + 1
      saveDocument payouts[0], 'Payout'

    else
      postReplyTweet original, matchedPhrase, user, userId, tweet.id_str, postStatus

processTweet = (tweet) ->

  phrase = getTweetPhraseMatch tweet
  return if not phrase?

  saveTweetDocument tweet, false

module.exports =
  tracks: tracks
  processTweet: processTweet
  processRetweet: processRetweet

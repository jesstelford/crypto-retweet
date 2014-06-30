mongoose = require 'mongoose'

MODEL_NAME = 'Payout'

schema = mongoose.Schema
  tweet_id: String # a Tweet model, the original tweet
  retweet_id: String # a Tweet model, the retweet by the user
  payout_tweet_id: String # a Tweet model, they payout reply tweet
  user_id: String # twitter user_id of retweeter
  currency: String
  amount: Number
  timestamp: {type: Date, default: Date.now}
  attempts: {type: Number, default: 1}
  confirmed: Date

schema.statics.findExisting = (tweetId, userId, cb) ->
  return this.model(MODEL_NAME).find {tweet_id: tweetId, user_id: userId}, cb

module.exports = mongoose.model MODEL_NAME, schema

mongoose = require 'mongoose'

schema = mongoose.Schema
  original: mongoose.Schema.Types.Mixed
  id: String
  text: String
  user_id: String
  is_retweet: Boolean
  timestamp: {type: Date, default: Date.now}

module.exports = mongoose.model 'Tweet', schema

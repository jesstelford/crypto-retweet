# Crypto Retweet

Paid retweets using Cryptocurrencies such as Dogecoin.

## Quickstart

Install [nodejs](http://nodejs.org/download/).
Install [mongodb](http://www.mongodb.org/downloads).

Run the following commands

```bash
$ git clone https://github.com/jesstelford/crypto-retweet.git && cd crypto-retweet
$ npm install # Install all the npm dependancies
$ cp src/backend/config.json-example src/backend/config.json
```

Edit the contents of `src/backend/config.json` to have the correct twitter
credentials and ids.

```bash
$ mongo & # Fire up MongoDB
$ make    # Build the project, and fire up a minimal server
```

Visit twitter.com as the user in `config.twitter.user_id`, and make a post
matching a phrase's regex in `src/backend/phrases.json`.

Have a third party retweet this status update.

A tweet reply will be automatically generated and posted to the twitter account.

## Powered By

 * [Coffee-boilerplate](https://github.com/jesstelford/coffee-boilerplate)
 * [mongoose](http://mongoosejs.com/)
 * [twit](https://github.com/ttezel/twit)

## Donations

<img src="http://dogecoin.com/imgs/dogecoin-300.png" width=100 height=100 align=right />
Like what I've created? *So do I!* I develop this project in my spare time, free for the community.

If you'd like to say thanks, buy me a beer by **tipping with Dogecoin**: *DGLSofSqjVYGMw5F59uVG4EqZiFrA9*

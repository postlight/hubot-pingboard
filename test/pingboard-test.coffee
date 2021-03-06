require('es6-promise').polyfill()
chai = require 'chai'
Replay = require('replay')
fetch = require 'isomorphic-fetch'

MockDate = require('mockdate')
MockDate.set('5/5/2016')

expect = chai.expect

# Used to trigger HTTP mocks
process.env.HUBOT_PINGBOARD_CLIENT_ID = 'test'
process.env.HUBOT_PINGBOARD_CLIENT_SECRET = 'test'
process.env.HUBOT_PINGBOARD_SUBDOMAIN = 'test'
process.env.HUBOT_PINGBOARD_FLOWDOCK_FLOW_TOKEN = 'test'
process.env.HUBOT_PINGBOARD_IGNORED_GROUPS = 'Ignored Project'
process.env.EXPRESS_PORT = 8080
process.env.HUBOT_PINGBOARD_USERS_MAP =
  'test1:test1,test2:test2,test3:test3,test4:test4'
process.env.TZ = 'America/New_York'

Helper = require('hubot-test-helper')
helper = new Helper('../src/pingboard.coffee')

# Wait long enough for the fixtures to work
# TODO make this not a abitrary number and instead based on a promise.
ASYNC_WAIT = 70

describe 'pingboard', ->
  beforeEach ->
    @room = helper.createRoom()

  afterEach ->
    @room.destroy()

  it "responds to who's out?", ->
    new Promise (resolve, reject) =>
      @room.user.say 'alice', "@hubot who's out?"
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            "@hubot who's out?"
          ],
          [
            'hubot'
            '\n**Vacation**\n\n- Test Person (Mon 4/11 - Fri 4/22), Hawaii'
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to 'list projects'", ->
    new Promise (resolve, reject) =>
      @room.user.say 'alice', "@hubot list projects"
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            '@hubot list projects'
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '- **[Group with No Users](https://test.pingboard.com/groups/4)**\n- **[Project 1](https://test.pingboard.com/groups/1)**: [Test Person 3](https://test.pingboard.com/users/3)\n- **[Project 2](https://test.pingboard.com/groups/2)**: [Test Person](https://test.pingboard.com/users/1), [Test Person 2](https://test.pingboard.com/users/2), [Test Person 3](https://test.pingboard.com/users/3)'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to 'who's on 2?'", ->
    new Promise (resolve, reject) =>
      @room.user.say 'alice', "@hubot who's on 2?"
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            "@hubot who's on 2?"
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '**[Project 2](https://test.pingboard.com/groups/2)**: [Test Person](https://test.pingboard.com/users/1), [Test Person 2](https://test.pingboard.com/users/2), [Test Person 3](https://test.pingboard.com/users/3)'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to 'who's on project 1?'", ->
    new Promise (resolve, reject) =>
      @room.user.say 'alice', "@hubot who's on project 1?"
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            "@hubot who's on project 1?"
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '**[Project 1](https://test.pingboard.com/groups/1)**: [Test Person 3](https://test.pingboard.com/users/3)'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to 'what's test person 1 working on?'", ->
    new Promise (resolve, reject) =>
      @room.user.say 'alice', "@hubot what's test person 1 working on?"
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            "@hubot what's test person 1 working on?"
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '**[Test Person](https://test.pingboard.com/users/1)** is working on [Project 1](https://test.pingboard.com/groups/1), [Project 2](https://test.pingboard.com/groups/2)'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to 'who's on project 1?'", ->
    checkStatus = (response) ->
      if response.status >= 200 && response.status < 300
        response
      else
        error = new Error(response.statusText)
        error.response = response
        throw error

    new Promise (resolve, reject) ->
      setTimeout(->
        fetch('http://localhost:8080/hubot/pingboard-update',
          headers: 'Content-Type': 'application/json'
          method: 'POST'
        )
          .then(checkStatus)
          .then((response) -> response.text())
          .then((text) ->
            expect(text).to.equal('OK')
            resolve()
          )
          .catch((error) ->
            console.log('Error', error)
            error.response.text().then((text) ->
              console.error('Error', text)
              reject(error)
            )
            .catch(reject)
          )
      , ASYNC_WAIT)

  it 'responds to @mentions of users on vacation', ->
    new Promise (resolve, reject) =>
      message = '@test1 quick question'
      @room.user.say 'alice', message
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            message
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '@alice [Test Person 1](https://test.pingboard.com/users/1) is Out of Office (Running Errand) until Friday, April 22nd'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it 'responds to @mentions of users on vacation with two users', ->
    new Promise (resolve, reject) =>
      message = '@test1, @test2 quick question'
      @room.user.say 'alice', message
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            message
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '@alice [Test Person 1](https://test.pingboard.com/users/1) is Out of Office (Running Errand) until Friday, April 22nd'
            # coffeelint: enable=max_line_length
          ]
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '@alice [Test Person 2](https://test.pingboard.com/users/2) is on Vacation (Hawaii) until Friday, April 22nd'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it 'does not respond to @mention user with no status', ->
    new Promise (resolve, reject) =>
      message = '@test3 quick question'
      @room.user.say 'alice', message
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            message
          ]
        ])
        resolve()
      , ASYNC_WAIT)

  it "responds to @mention of user who's out right now with timestamp", ->
    new Promise (resolve, reject) =>
      message = '@test4 quick question'
      @room.user.say 'alice', message
      setTimeout(=>
        expect(@room.messages).to.deep.equal([
          [
            'alice'
            message
          ],
          [
            'hubot'
            # coffeelint: disable=max_line_length
            '@alice [Test Person 4](https://test.pingboard.com/users/4) is Out of Office (Doctor) until 11:00am EDT'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Replay = require('replay')

expect = chai.expect

Helper = require('hubot-test-helper')
helper = new Helper('../src/pingboard.coffee')

# Used to trigger HTTP mocks
process.env.HUBOT_PINGBOARD_USERNAME = 'test'
process.env.HUBOT_PINGBOARD_PASSWORD = 'test'
process.env.HUBOT_PINGBOARD_SUBDOMAIN = 'test'

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

  it "responds to 'list projects?'", ->
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
            '[Project 1](https://test.pingboard.com/group/1), [Project 2](https://test.pingboard.com/group/1)'
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
            '[Project 2](https://test.pingboard.com/group/1): [Test Person](https://test.pingboard.com/users/1), [Test Person 2](https://test.pingboard.com/users/2), [Test Person 3](https://test.pingboard.com/users/3)'
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
            '[Project 1](https://test.pingboard.com/group/1): [Test Person 3](https://test.pingboard.com/users/3)'
            # coffeelint: enable=max_line_length
          ]
        ])
        resolve()
      , ASYNC_WAIT)

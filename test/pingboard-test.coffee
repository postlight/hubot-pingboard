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


# Description
#   A hubot script for interacting with Pingboard.com
#
# Configuration:
#   HUBOT_PINGBOARD_USERNAME
#   HUBOT_PINGBOARD_PASSWORD
#
# Commands:
#   hubot who's out - Lists who's working today.
#
# Notes:
#   Requires HUBOT_PINGBOARD_PASSWORD to be set.
#
# Author:
#   Jeremy Mack <jeremy.mack@postlight.com>

Promise = require 'bluebird'
moment = require 'moment-timezone'
_ = require 'lodash'
marked = require 'marked'

BASE_APP_URL = 'https://app.pingboard.com'
AUTH_URL = [BASE_APP_URL, 'oauth/token'].join('/')
STATUSES_URL = [BASE_APP_URL, 'api/v2/statuses'].join('/')
MULTI_DAY_FORMAT = 'ddd M/D'

moment.tz.setDefault(process.env.TZ) if process.env.TZ

module.exports = (robot) ->
  fetchAccessToken = ->
    username = process.env.HUBOT_PINGBOARD_USERNAME
    password = process.env.HUBOT_PINGBOARD_PASSWORD

    if !username or !password
      return Promise.reject('Missing username or password for hubot-pingboard')

    new Promise (resolve, reject) ->
      robot.http(AUTH_URL)
        .header('Content-Type', 'application/json')
        .query(username: username, password: password, grant_type: 'password')
        .post() (error, res, body) ->
          return reject("Encountered an error :( #{error}") if error

          try
            json = JSON.parse(body)
          catch error
            return reject('Ran into an error parsing JSON for hubot-pingboard')

          resolve(json.access_token)

  fetchStatuses = (accessToken) ->
    new Promise (resolve, reject) ->
      robot.http(STATUSES_URL)
        .header('Content-Type', 'application/json')
        .query(
          access_token:  accessToken
          include:       'user,status_type'
          page_size:     '2000'
          starts_at:     moment().format('YYYY-MM-DD')
          ends_at:       moment().format('YYYY-MM-DD')
        )
        .get() (error, res, body) ->
          return reject("Encountered an error :( #{error}") if error

          try
            json = JSON.parse(body)
          catch error
            return new Error('Ran into an error parsing JSON for hubot-pingboard')

          resolve(json)

  normalizeStatuses = (data) ->
    { statuses } = data
    users = data.linked.users
    statusTypes = data.linked.status_types
    statuses.map (status) ->
      status.user = _.find(users, id: status.links.user)
      status.statusType = _.find(statusTypes, id: status.links.status_type)
      status

  fetchAndNormalizeStatuses = ->
    fetchAccessToken().then((accessToken) ->
      fetchStatuses(accessToken)
    ).then((data) ->
      allStatuses = normalizeStatuses(data)
      formatStatusMessage(allStatuses)
    )

  formatStatusMessage = (allStatuses) ->
    statusesByType = _.groupBy(allStatuses, 'links.status_type')
    finalMessages = _.map statusesByType, (statuses) ->
      messages = ["\n**#{statuses[0].statusType.name}**\n"]
      statusMessages = statuses.map (status) ->
        name = _.compact([status.user.first_name, status.user.last_name])
          .join(' ')
        startsMoment = moment(status.starts_at)
        endsMoment = moment(status.ends_at)
        isMultiDay =
          status.all_day and !startsMoment.isSame(endsMoment, 'day')
        time = if isMultiDay
          [
            startsMoment.format(MULTI_DAY_FORMAT),
            endsMoment.format(MULTI_DAY_FORMAT)
          ].join(' - ')
        else if status.all_day
          'all day'
        else if status.time_period == 'another_time'
          start = startsMoment.format('h:mma')
          end = endsMoment.format('h:mma')
          "#{start} - #{end}"
        else
          status.time_period.replace('_', ' ')
        [
          '- ' # Bullet
          name,
          " (#{time})",
          ", #{status.message}" if status.message
        ].join('')

      messages.concat(statusMessages)

    finalMessages = _.flatten(finalMessages)
    finalMessages.join('\n')

  robot.router.post '/hubot/pingboard-update', (req, res) ->
    fetchAndNormalizeStatuses().then((message) ->
      now = moment()
      title = "Statuses for #{now.format('MMMM do, YYYY')}"
      htmlMessage = marked(message)
      flowToken = process.env.HUBOT_PINGBOARD_FLOWDOCK_FLOW_TOKEN
      if !flowToken
        console.log 'hubot-pingboard error: Missing Flowdock Flow Token'
        return res.send 'FAILED'

      robot.http('https://api.flowdock.com/messages')
        .header('accept', 'application/json')
        .header('Content-Type', 'application/json')
        .post(JSON.stringify(
          flow_token: flowToken
          event: 'discussion'
          author:
            name: 'Pingboard'
            avatar: 'http://i.imgur.com/gcTuW6T.png'
          title: 'Statuses updated'
          body: htmlMessage
          external_thread_id: now.format('YYYY-MM-DD')
          thread:
            title: title
            body: htmlMessage
        )) (error, postRes, body) ->
          return new Error("Encountered an error :( #{error}") if error

          if postRes.statusCode >= 400
            console.log 'Error from Flowdock', body
            return res.send 'FAILED'

          try
            json = JSON.parse(body)
          catch error
            return reject('Ran into an error parsing JSON for hubot-pingboard')

          res.send 'OK'
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      res.send 'FAILED'
    )

  robot.respond /who.s out??/, (msg) ->
    fetchAndNormalizeStatuses().then((message) ->
      msg.send(message)
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

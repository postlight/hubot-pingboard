# Description
#   A hubot script for interacting with Pingboard.com
#
# Configuration:
#   # TODO REMOVE BASED ON WHICH WE USE
#   HUBOT_PINGBOARD_USERNAME
#   HUBOT_PINGBOARD_PASSWORD
#
#   HUBOT_PINGBOARD_ACCESS_TOKEN
#   HUBOT_PINGBOARD_REFRESH_TOKEN
#
# Commands:
#   hubot who's in - Lists who's not working today.
#   hubot who's out - Lists who's working today.
#   hubot upcoming birthdays
#
# Notes:
#   Requires HUBOT_PINGBOARD_PASSWORD to be set.
#
# Author:
#   Jeremy Mack <jeremy.mack@postlight.com>

Promise = require 'bluebird'
moment = require 'moment'
_ = require 'lodash'

BASE_APP_URL = 'https://app.pingboard.com'
AUTH_URL = [BASE_APP_URL, 'oauth/token'].join('/')
STATUSES_URL = [BASE_APP_URL, 'api/v2/statuses'].join('/')


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
            return reject('Ran into an error parsing JSON for hubot-pingboard')

          resolve(json)

  normalizeStatuses = (data) ->
    { statuses } = data
    users = data.linked.users
    statusTypes = data.linked.status_types
    statuses.map (status) ->
      status.user = _.find(users, id: status.links.user)
      status.statusType = _.find(statusTypes, id: status.links.status_type)
      status

  robot.respond /who.s out??/, (msg) ->
    fetchAccessToken().then((accessToken) ->
      fetchStatuses(accessToken)
    ).then((data) ->
      allStatuses = normalizeStatuses(data)
      statusesByType = _.groupBy(allStatuses, 'links.status_type')
      finalMessages = _.map statusesByType, (statuses) ->
        messages = ["\n## #{statuses[0].statusType.name}\n"]
        statusMessages = statuses.map (status) ->
          name = _.compact([status.user.first_name, status.user.last_name])
            .join(' ')
          time = if status.all_day
            'all day'
          else if status.time_period == 'another_time'
            start = moment(status.starts_at).format('h:mma')
            end = moment(status.ends_at).format('h:mma')
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
      msg.send(finalMessages.join('\n'))
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

# Description
#   A hubot script for interacting with Pingboard.com
#
# Configuration:
#   HUBOT_PINGBOARD_USERNAME
#   HUBOT_PINGBOARD_PASSWORD
#   HUBOT_PINGBOARD_SUBDOMAIN
#
# Commands:
#   hubot who's out - Lists who's working today.
#   hubot who's on <project name> - Lists who's on a given project.
#   hubot list projects - Lists projects at the company.
#
# Author:
#   Jeremy Mack <jeremy.mack@postlight.com>

Promise = require 'bluebird'
moment = require 'moment'
_ = require 'lodash'
marked = require 'marked'
# add score method to string.
require 'string_score'

PINGBOARD_BASE_URL = 'https://app.pingboard.com'
AUTH_URL = "#{PINGBOARD_BASE_URL}/oauth/token"
STATUSES_ENDPOINT = 'api/v2/statuses'
GROUPS_ENDPOINT = 'api/v2/groups'
MULTI_DAY_FORMAT = 'ddd M/D'
SUBDOMAIN = process.env.HUBOT_PINGBOARD_SUBDOMAIN

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

  fetchPingboardEndpoint = ({ endpoint, params }) ->
    new Promise (resolve, reject) ->
      robot.http("#{PINGBOARD_BASE_URL}/#{endpoint}")
        .header('Content-Type', 'application/json')
        .query(params)
        .get() (error, res, body) ->
          return reject("Encountered an error :( #{error}") if error

          try
            json = JSON.parse(body)
          catch error
            return new Error(
              'Ran into an error parsing JSON for hubot-pingboard'
            )

          resolve(json)

  fetchStatuses = (accessToken) ->
    fetchPingboardEndpoint(
      endpoint: STATUSES_ENDPOINT
      params:
        access_token:  accessToken
        include:       'user,status_type'
        page_size:     '2000'
        starts_at:     moment().format('YYYY-MM-DD')
        ends_at:       moment().format('YYYY-MM-DD')
    )

  fetchGroups = (accessToken) ->
    fetchPingboardEndpoint(
      endpoint: GROUPS_ENDPOINT
      params:
        access_token:  accessToken
        include:       'users'
        type:          'group'
        sort:          'name'
        page_size:     '100'
    )

  nameForUser = (user) ->
    _.compact([user.first_name, user.last_name]).join(' ')

  pingboardUrl = (path) ->
    "https://#{SUBDOMAIN}.pingboard.com/#{path}"

  markdownLink = (text, url) ->
    "[#{text}](#{url})"

  normalizeStatuses = (data) ->
    { statuses } = data
    users = data.linked.users
    statusTypes = data.linked.status_types
    statuses.map (status) ->
      status.user = _.find(users, id: status.links.user)
      status.statusType = _.find(statusTypes, id: status.links.status_type)
      status

  normalizeGroups = (data) ->
    { groups } = data
    allusers = data.linked.users
    groups.map (group) ->
      groupUsers = group.links.users
      group.users = groupUsers and groupUsers.map (userId) ->
        _.find(allusers, id: userId)
      group

  fetchAndNormalizeStatuses = ->
    fetchAccessToken().then((accessToken) ->
      fetchStatuses(accessToken)
    ).then((data) ->
      allStatuses = normalizeStatuses(data)
      formatStatusMessage(allStatuses)
    )

  authenticateAndFetchGroups = ->
    fetchAccessToken().then((accessToken) ->
      fetchGroups(accessToken)
    ).then((data) ->
      normalizeGroups(data)
    )

  formatStatusMessage = (allStatuses) ->
    statusesByType = _.groupBy(allStatuses, 'links.status_type')
    finalMessages = _.map statusesByType, (statuses) ->
      messages = ["\n**#{statuses[0].statusType.name}**\n"]
      statusMessages = statuses.map (status) ->
        name = nameForUser(status.user)
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
      title = "Statuses for #{now.format('MMMM Do, YYYY')}"
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

  robot.respond /who.s out(?:\?)/, (msg) ->
    fetchAndNormalizeStatuses().then((message) ->
      msg.send(message)
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

  robot.respond /(list projects|what projects do we have(?:\?))/, (msg) ->
    msg.send('Checking...')
    authenticateAndFetchGroups().then((groups) ->
      groupNames = groups.map((group) -> group.name)
      sortedGroups = _.sortBy(groups, 'name')
      groupsText = sortedGroups.map((group) ->
        '- ' + markdownLink(
          group.name, pingboardUrl("group/#{group.id}")
        )
      ).join('\n')

      msg.send(groupsText)
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

  robot.respond /who(?:'?s| is) on (.+)(?:\?)/, (msg) ->
    msg.send('Checking...')
    projectName = msg.match[1]
    authenticateAndFetchGroups().then((groups) ->
      matchingGroup = _.max(groups, (group) ->
        group.name.score(projectName)
      )
      usersText = _.chain(matchingGroup.users)
        .compact()
        .sortBy('first_name')
        .map((user) ->
          markdownLink(nameForUser(user), pingboardUrl("users/#{user.id}"))
        )
        .value()
        .join(', ')

      msg.send([
        markdownLink(
          matchingGroup.name, pingboardUrl("group/#{matchingGroup.id}")
        )
        ": "
        usersText
      ].join(''))
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

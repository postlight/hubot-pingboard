# Description
#   A hubot script for interacting with Pingboard.com
#
# Configuration:
#   HUBOT_PINGBOARD_CLIENT_ID
#   HUBOT_PINGBOARD_CLIENT_SECRET
#   HUBOT_PINGBOARD_SUBDOMAIN
#   HUBOT_PINGBOARD_FLOWDOCK_FLOW_TOKEN
#   HUBOT_PINGBOARD_IGNORED_GROUPS - Comma list of group names to ignore.
#
# Commands:
#   hubot who's out - Lists who's working today.
#   hubot who's on <project name> - Lists who's on a given project.
#   hubot list projects - Lists projects at the company.
#   hubot what's <person name> working on? - Lists projects user is working on.
#
# Author:
#   Jeremy Mack <jeremy.mack@postlight.com>

moment = require 'moment-timezone'
moment.tz.setDefault(process.env.TZ) if process.env.TZ
_ = require 'lodash'
marked = require 'marked'
# add score method to string.
require 'string_score'

PingboardApi = require '../lib/pingboard-api'

MULTI_DAY_FORMAT = 'ddd M/D'
CLIENT_ID = process.env.HUBOT_PINGBOARD_CLIENT_ID
CLIENT_SECRET = process.env.HUBOT_PINGBOARD_CLIENT_SECRET
SUBDOMAIN = process.env.HUBOT_PINGBOARD_SUBDOMAIN
IGNORED_GROUPS = process.env.HUBOT_PINGBOARD_IGNORED_GROUPS?.split(',')

PINGBOARD_API =
  new PingboardApi(clientId: CLIENT_ID, clientSecret: CLIENT_SECRET)

# TODO Replace with an automated way to gather this info. Perhaps Flowdock's
# API or better, a custom field in Pingboard for chat username.
usersMapString = process.env.HUBOT_PINGBOARD_USERS_MAP
if usersMapString
  USERNAMES_TO_PINGBOARD =
    usersMapString.split(',').map((usernameAndPingboardUserId) ->
      [ username, pingboardUserId ] = usernameAndPingboardUserId.split(':')
      username: username, pingboardUserId: pingboardUserId
    )

  usernamesString = USERNAMES_TO_PINGBOARD.map((u) -> u.username).join('|')
  USERNAMES_REGEX = new RegExp("@(#{usernamesString})", 'ig')

STATUS_TYPE_VERBS =
  'Vacation': 'on Vacation'

module.exports = (robot) ->

  nameForUser = (user) ->
    _.compact([user.first_name, user.last_name]).join(' ')

  pingboardUrl = (path) ->
    "https://#{SUBDOMAIN}.pingboard.com/#{path}"

  markdownLink = (text, url) -> "[#{text}](#{url})"

  markdownBold = (text) -> "**#{text}**"

  humanStatusType = (statusType) ->
    STATUS_TYPE_VERBS[statusType] or statusType

  messageForGroup = (group) ->
    usersText = _.chain(group.users)
      .compact()
      .sortBy('first_name')
      .map((user) ->
        markdownLink(nameForUser(user), pingboardUrl("users/#{user.id}"))
      )
      .value()
      .join(', ')

    [
      markdownBold(markdownLink(
        group.name, pingboardUrl("groups/#{group.id}")
      ))
      ": #{usersText}" if usersText
    ].join('')

  normalizeStatuses = (data) ->
    { statuses } = data
    users = data.linked?.users
    statusTypes = data.linked?.status_types
    statuses.map (status) ->
      status.user = _.find(users, id: status.links.user)
      status.statusType = _.find(statusTypes, id: status.links.status_type)
      status

  normalizeGroups = (data) ->
    { groups } = data
    allUsers = data.linked.users
    groups = _.reject(groups, (group) ->
      _.include(IGNORED_GROUPS, group.name)
    )
    groups.map (group) ->
      groupUsers = group.links.users
      group.users = groupUsers and groupUsers.map (userId) ->
        _.find(allUsers, id: userId)
      group

  normalizeUsers = (data) ->
    { users } = data
    allGroups = data.linked.groups
    users.map (user) ->
      userGroups = user.links.groups
      user.groups = userGroups and userGroups.map (groupId) ->
        _.find(allGroups, id: groupId)
      user.name = _.compact([user.first_name, user.last_name]).join(' ')
      user

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
    PINGBOARD_API.fetchStatuses().then((data) ->
      allStatuses = normalizeStatuses(data)
      message = formatStatusMessage(allStatuses)

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
          if postRes?.statusCode >= 400 or error
            errorMessage = ' '
            if error
              errorMessage = "Encountered an error :( #{error}"
            else
              console.log 'Error from Flowdock', body
              errorMessage = 'Flowdock error: ' + body

            res.status(400).send(errorMessage)

            return

          try
            json = JSON.parse(body)
          catch error
            return res.status(400).send(
              'Ran into an error parsing JSON for hubot-pingboard'
            )

          res.send 'OK'
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      res.send 'hubot-pingboard: Updating statuses'
    )

  robot.respond /who.?s out(?:\?)?/, (msg) ->
    PINGBOARD_API.fetchStatuses().then((data) ->
      allStatuses = normalizeStatuses(data)
      message = formatStatusMessage(allStatuses)
      msg.send(message)
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

  robot.hear(USERNAMES_REGEX, (msg) ->
    return unless msg.match.length > 0

    msg.match.forEach (username) ->
      user = _.find USERNAMES_TO_PINGBOARD, username: username.replace('@','')

      PINGBOARD_API.fetchStatusesForUserId(user.pingboardUserId).then((data) ->
        allStatuses = normalizeStatuses(data)
        unavailableStatuses = _.filter(
          allStatuses, 'statusType.available', false
        )

        return if unavailableStatuses.length == 0

        firstUnavailableStatus = unavailableStatuses[0]
        user = firstUnavailableStatus.user
        startsMoment = moment(firstUnavailableStatus.starts_at)
        endsMoment = moment(firstUnavailableStatus.ends_at)

        isMultiDay = (
          firstUnavailableStatus.all_day and
          !startsMoment.isSame(endsMoment, 'day')
        )

        if isMultiDay
          timeText = endsMoment.format('dddd, MMMM Do')
        else if startsMoment.isBefore(moment()) and endsMoment.isAfter()
          timeText = endsMoment.format('h:mma z')
        else
          # Don't print anything if the moment of being out has past.
          return

        msg.reply([
          markdownLink(nameForUser(user), pingboardUrl("users/#{user.id}"))
          'is'
          humanStatusType(firstUnavailableStatus.statusType.name)
          "(#{firstUnavailableStatus.message})"
          'until'
          timeText
        ].join(' '))
      ).catch((error) ->
        console.log('hubot-pingboard error', error)
        msg.send("Error in hubot-pingboard #{error}")
      )
  ) if USERNAMES_REGEX # Don't apply this with an empty regex

  robot.respond /(list projects|what projects do we have(?:\?)?)/, (msg) ->
    PINGBOARD_API.fetchGroups().then((data) ->
      groups = normalizeGroups(data)
      groupNames = groups.map((group) -> group.name)
      sortedGroups = _.sortBy(groups, 'name')
      groupsText = sortedGroups
        .map((group) -> "- #{messageForGroup(group)}")
        .join('\n')

      msg.send(groupsText)
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

  robot.respond /who(?:.s| is) on (.+?)(?:\?)?/, (msg) ->
    projectName = msg.match[1]

    PINGBOARD_API.fetchGroups().then((data) ->
      groups = normalizeGroups(data)
      matchingGroup = _.max(groups, (group) ->
        group.name.score(projectName)
      )

      msg.send(messageForGroup(matchingGroup))
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

  robot.respond /what(?:.s| is) (.+) working on(?:\?)?/, (msg) ->
    userName = msg.match[1]

    PINGBOARD_API.fetchUsers().then((data) ->
      users = normalizeUsers(data)
      matchingUser = _.max(users, (user) -> user.name.score(userName))
      groupsText = _.chain(matchingUser.groups)
        .compact()
        .sortBy('name')
        .map((group) ->
          markdownLink(
            group.name, pingboardUrl("groups/#{group.id}")
          )
        )
        .value()
        .join(', ')

      msg.send([
        markdownBold(markdownLink(
          matchingUser.name, pingboardUrl("users/#{matchingUser.id}")
        ))
        " is working on "
        groupsText
      ].join(''))
    ).catch((error) ->
      console.log('hubot-pingboard error', error)
      msg.send("Error in hubot-pingboard #{error}")
    )

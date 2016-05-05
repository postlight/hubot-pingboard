require('es6-promise').polyfill()
fetch = require 'isomorphic-fetch'
moment = require 'moment-timezone'
moment.tz.setDefault(process.env.TZ) if process.env.TZ
URI = require 'urijs'

PINGBOARD_BASE_URL = 'https://app.pingboard.com'
AUTH_ENDPOINT = 'oauth/token'
STATUSES_ENDPOINT = 'api/v2/statuses'
GROUPS_ENDPOINT = 'api/v2/groups'
USERS_ENDPOINT = 'api/v2/users'
PINGBOARD_DATE_FORMAT = 'YYYY-MM-DD'


module.exports = class PingboardApi
  constructor: ({ username, password }) ->
    if !username or !password
      throw new Error('username and password required')

    @username = username
    @password = password

  fetchGroups: ->
    @fetchAccessToken().then (accessToken) =>
      @fetchEndpoint(
        endpoint: GROUPS_ENDPOINT
        params:
          access_token:  accessToken
          include:       'users'
          page_size:     '100'
          sort:          'name'
          type:          'group'
      )

  fetchStatuses: ->
    @fetchAccessToken().then (accessToken) =>
      @fetchEndpoint(
        endpoint: STATUSES_ENDPOINT
        params:
          access_token:  accessToken
          include:       'user,status_type'
          page_size:     '2000'
          starts_at:     moment().format(PINGBOARD_DATE_FORMAT)
          ends_at:       moment().format(PINGBOARD_DATE_FORMAT)
      )

  fetchStatuesForUserId: (userId) ->
    @fetchAccessToken().then (accessToken) =>
      @fetchEndpoint(
        endpoint: STATUSES_ENDPOINT
        params:
          access_token:  accessToken
          page_size:     '5'
          include:       'user,status_type'
          starts_at:     moment().format(PINGBOARD_DATE_FORMAT)
          ends_at:       moment().format(PINGBOARD_DATE_FORMAT)
          user_id:       userId
      )

  fetchUsers: ->
    @fetchAccessToken().then (accessToken) =>
      @fetchEndpoint(
        endpoint: USERS_ENDPOINT
        params:
          access_token:  accessToken
          page_size:     '200'
          include:       'groups'
      )

  fetchAccessToken: ->
    @fetchEndpoint(
      endpoint: AUTH_ENDPOINT
      method: 'POST'
      params:
        grant_type: 'password'
        password: @password
        username: @username
    ).then((json) -> json.access_token)

  fetchEndpoint: ({ endpoint, params, method }) ->
    method ?= 'GET'
    uri = new URI("#{PINGBOARD_BASE_URL}/#{endpoint}")
    uri.setQuery(params)
    fetch(uri.toString(),
      headers: 'Content-Type': 'application/json'
      method: method
    )
      .then((response) -> response.json())
      .then((json) -> json)

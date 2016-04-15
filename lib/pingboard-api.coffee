Promise = require 'bluebird'
fetch = require 'isomorphic-fetch'
moment = require 'moment'
URI = require 'urijs'

PINGBOARD_BASE_URL = 'https://app.pingboard.com'
AUTH_ENDPOINT = 'oauth/token'
STATUSES_ENDPOINT = 'api/v2/statuses'
GROUPS_ENDPOINT = 'api/v2/groups'


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
          starts_at:     moment().format('YYYY-MM-DD')
          ends_at:       moment().format('YYYY-MM-DD')
      )

  # fetchUsers: ->

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
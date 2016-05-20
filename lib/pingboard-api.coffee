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

checkStatus = (response) ->
  if response.status >= 200 && response.status < 300
    response
  else
    error = new Error(response.statusText)
    error.response = response
    throw error

module.exports = class PingboardApi
  constructor: ({ clientId, clientSecret }) ->
    if !clientId or !clientSecret
      throw new Error('clientId and clientSecret required')

    @clientId = clientId
    @clientSecret = clientSecret

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

  fetchStatusesForUserId: (userId) ->
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
      headers:
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
      method: 'POST'
      body:
        client_id: @clientId
        client_secret: @clientSecret
        grant_type: 'client_credentials'
    ).then((json) -> json.access_token)

  fetchEndpoint: ({ body, endpoint, headers, params, method }) ->
    method ?= 'GET'
    headers ?= 'Content-Type': 'application/json'

    uri = new URI("#{PINGBOARD_BASE_URL}/#{endpoint}")
    uri.setQuery(params) if params

    if body
      form = for key, value of body
        "#{key}=#{value}"
      form = form.join('&')

    fetch(uri.toString(),
      headers: headers
      method: method
      body: form
    )
      .then(checkStatus)
      .then((response) -> response.json())
      .then((json) -> json)

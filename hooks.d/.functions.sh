#!/bin/bash
set -euo pipefail

function _refresh_authorization() {
  source "$OAUTH_CLIENT_CREDENTIAL"

  REFRESH_TOKEN=$(jq -cer '.refresh_token' < "$AUTHORIZATION")
  FIELDS=(
    -d "client_id=$CLIENT_ID"
    -d "client_secret=$CLIENT_SECRET"
    -d 'grant_type=refresh_token'
    -d "refresh_token=$REFRESH_TOKEN"
  )

  DATA=$(curl -s https://id.twitch.tv/oauth2/token "${FIELDS[@]}")

  if ACCESS_TOKEN=$(jq -cer '.access_token' <<< "$DATA")
  then
    if [[ -n "$ACCESS_TOKEN" ]]
    then
      echo "$DATA" > "$AUTHORIZATION"

      return 0
    fi
  fi

  return 1
}

function _api_request() {
  source "$OAUTH_CLIENT_CREDENTIAL"

  REQUEST_URI="$1"
  shift

  BASE_PATH='https://api.twitch.tv/helix'
  ACCESS_TOKEN=$(jq -cer '.access_token' < "$AUTHORIZATION")
  HEADERS=(
    -H "Authorization: Bearer $ACCESS_TOKEN"
    -H "Client-ID: $CLIENT_ID"
    -H "Content-Type: application/json"
  )

  TEMP=$(mktemp)

  STATUS=$(curl -s -o "$TEMP" -w "%{response_code}" "${HEADERS[@]}" "${BASE_PATH}/${REQUEST_URI#/}" "$@")
  DATA=$(< "$TEMP")

  rm "$TEMP"

  if [ $STATUS -eq 401 ]
  then
    if _refresh_authorization
    then
      _api_request "$REQUEST_URI" "$@"

      return $?
    else
      return 2
    fi
  else
    echo "$DATA"

    if [ $STATUS -ge 200 ] && [ $STATUS -lt 300 ]
    then
      return 0
    elif [ $STATUS -ge 400 ] && [ $STATUS -lt 600 ]
    then
      # HTTP 400-499 = Exit code 50-149
      # HTTP 500-599 = Exit code 150-249
      return $(( $STATUS % 200 + 50 ))
    fi
  fi

  return 1
}

function _get_user_id() {
  export LOGIN=$1

  REQUEST_URI="/users?login=$LOGIN"

  if ! RESPONSE=$(_api_request "$REQUEST_URI")
  then
    echo "An error occurred while attempting to get a user: $RESPONSE" >&2

    return 1
  fi

  jq -cer '.data[0].id' <<< "$RESPONSE"

  return 0
}

#!/bin/bash
set -euo pipefail

###
# @file
# This file processes VOD change events.
#
# When one of these events is encountered, a message will be pinned in chat.
#
# Check the CONFIG section before using this script.
#
# Before initial use, an authorization token must be pre-seeded for each stream:
# - The client credential should be stored at the configured path.
# - The following scopes are required:
#     channel:bot moderator:manage:chat_messages user:bot user:write:chat
# - The raw response from https://id.twitch.tv/oauth2/token should be stored at
#   path configured below.
#
# Run chmod +x on this file to enable.
#
# Consult the Twitch API documentation for more information.
###

STREAM="$1"
FILE="$2"

################################################################################
#                                   CONFIG                                     #
################################################################################

# Configure the path to the OAuth client credential.
#
# This file will be sourced, and should contain the following variables:
# - CLIENT_ID: The client ID to use.
# - CLIENT_SECRET: The client secret to use.
OAUTH_CLIENT_CREDENTIAL="$HOME/.config/twitch/client"

# Configure the path to the authorization and refresh token data.
#
# The response body of the request to https://id.twitch.tv/oauth2/token should
# be stored in this file (which will be automatically refreshed as needed).
AUTHORIZATION="$HOME/.config/twitch/auth/$STREAM.json"

# Configure the date in the pinned message.
#
# Files are expected to be in the format: .../YYYY/MM/DD/[HH:MM:SS] title (ID).*
# This format will be used to extract the original broadcast date and time.
#
# The timezone configured here will be used to convert the resulting UTC date
# into local time, which will then be formatted as configured.
FORMAT='%a, %b %-d, %Y @ %-I:%M %p %Z'

################################################################################
#                                   SCRIPT                                     #
################################################################################

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/.functions.sh

# Get the ID of the broadcaster.
export BROADCASTER_ID=$(_get_user_id "$STREAM")

# Get the message to send.
TITLE=$(echo "$FILE" | cut -d' ' -f 2- | rev | cut -d' ' -f 2- | rev)

DATE=$(echo "$FILE" | rev | cut -d/ -f 1-4 | rev | awk '{print $1}' | rev)
DATE=$(echo "${DATE/\// }" | rev | tr -d '[]' | tr / -)
DATE=$(date -d "$DATE UTC" +"$FORMAT")

export MESSAGE="Now playing: ${TITLE} (originally aired ${DATE})"

# Send a chat message.
DATA=$(jq -cner '{
  "broadcaster_id": env.BROADCASTER_ID,
  "sender_id": env.BROADCASTER_ID,
  "message": env.MESSAGE,
  "pin": true
}')

if RESPONSE=$(_api_request '/chat/messages' -d "$DATA")
then
  MESSAGE_ID=$(jq -cer '.data[0].message_id' <<< "$RESPONSE")

  # Pin the chat message indefinitely.
  _api_request "/chat/pins?broadcaster_id=$BROADCASTER_ID&moderator_id=$BROADCASTER_ID&message_id=$MESSAGE_ID" -X PATCH
fi

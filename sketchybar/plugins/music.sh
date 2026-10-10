#!/usr/bin/env bash

# LINK FOR CODE
# https://accounts.spotify.com/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http%3A%2F%2F127.0.0.1%3A8888%2Fcallback&scope=user-read-currently-playing%20user-read-playback-state

# QUERY ( CODE NEEDED )
# CLIENT_ID is stored in spotify.env
# CLIENT_SECRET is stored in spotify.env
# Authorization codes should never be committed.
#
#   curl -sS -X POST https://accounts.spotify.com/api/token \
#     -u "$CLIENT_ID:$CLIENT_SECRET" \
#     -H 'Content-Type: application/x-www-form-urlencoded' \
#     --data-urlencode grant_type=authorization_code \
#     --data-urlencode code="$CODE" \
#     --data-urlencode redirect_uri='http://127.0.0.1:8888/callback' | jq

# SEPTEMBER 18 REFRESH
# {
#   "access_token": "REDACTED",
#   "token_type": "Bearer",
#   "expires_in": 3600,
#   "refresh_token": "REDACTED",
#   "scope": "user-read-playback-state user-read-currently-playing"
# }


# --- CONFIGURATION ---
SKETCHYBAR_CONFIG_DIR="${CONFIG_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
SECRETS_FILE="$(dirname "$SKETCHYBAR_CONFIG_DIR")/.env"
if [ ! -r "$SECRETS_FILE" ]; then
  echo "Spotify credentials missing: create $SECRETS_FILE from .env.example" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$SECRETS_FILE"
# ---------------------

NAME="music"
MAX_LABEL_LENGTH=45

hide_item() {
  sketchybar --set "$NAME" drawing=off
}

truncate_label() {
  local label="$1"

  if [ "${#label}" -gt "$MAX_LABEL_LENGTH" ]; then
    printf '%s…' "${label:0:$((MAX_LABEL_LENGTH - 1))}"
  else
    printf '%s' "$label"
  fi
}

request() {
  local method="$1"
  local url="$2"
  local body_file="$3"
  local headers_file="$4"
  shift 4

  curl -sS -X "$method" "$url" \
    -D "$headers_file" \
    -o "$body_file" \
    -w "%{http_code}" \
    "$@"
}

AUTH_STR=$(printf '%s' "$CLIENT_ID:$CLIENT_SECRET" | base64 | tr -d '\n')

TOKEN_BODY=$(mktemp)
TOKEN_HEADERS=$(mktemp)
PLAYER_BODY=$(mktemp)
PLAYER_HEADERS=$(mktemp)
trap 'rm -f "$TOKEN_BODY" "$TOKEN_HEADERS" "$PLAYER_BODY" "$PLAYER_HEADERS"' EXIT

TOKEN_STATUS=$(request POST "https://accounts.spotify.com/api/token" \
  "$TOKEN_BODY" "$TOKEN_HEADERS" \
  -H "Authorization: Basic $AUTH_STR" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode grant_type=refresh_token \
  --data-urlencode refresh_token="$REFRESH_TOKEN")

if [ "$TOKEN_STATUS" != "200" ]; then
  echo "spotify token request failed: status=$TOKEN_STATUS body=$(cat "$TOKEN_BODY")" >&2
  hide_item
  exit 1
fi

if ! jq empty <"$TOKEN_BODY" >/dev/null 2>&1; then
  echo "spotify token response was not valid JSON" >&2
  hide_item
  exit 1
fi

ACCESS_TOKEN=$(jq -r '.access_token // empty' <"$TOKEN_BODY")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "spotify token response did not include access_token" >&2
  hide_item
  exit 1
fi

PLAYER_STATUS=$(request GET "https://api.spotify.com/v1/me/player" \
  "$PLAYER_BODY" "$PLAYER_HEADERS" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

case "$PLAYER_STATUS" in
  200)
    ;;
  204)
    hide_item
    exit 0
    ;;
  429)
    RETRY_AFTER=$(awk 'BEGIN{IGNORECASE=1} /^retry-after:/ {gsub("\r", "", $2); print $2}' "$PLAYER_HEADERS")
    echo "spotify player request rate limited: retry_after=${RETRY_AFTER:-unknown}s" >&2
    hide_item
    exit 0
    ;;
  401)
    echo "spotify player request unauthorized" >&2
    hide_item
    exit 1
    ;;
  *)
    echo "spotify player request failed: status=$PLAYER_STATUS body=$(cat "$PLAYER_BODY")" >&2
    hide_item
    exit 1
    ;;
esac

if ! jq empty <"$PLAYER_BODY" >/dev/null 2>&1; then
  echo "spotify player response was not valid JSON" >&2
  hide_item
  exit 1
fi

TRACK=$(jq -r '.item.name // empty' <"$PLAYER_BODY")
ARTIST=$(jq -r '.item.artists[0].name // empty' <"$PLAYER_BODY")
IS_PLAYING=$(jq -r '.is_playing // false' <"$PLAYER_BODY")

if [ -n "$TRACK" ] && [ -n "$ARTIST" ]; then
  if [ "$IS_PLAYING" = "true" ]; then
    LABEL="$(truncate_label "$ARTIST - $TRACK")"
  else
    LABEL="$(truncate_label "Paused: $ARTIST - $TRACK")"
  fi
  sketchybar --set "$NAME" drawing=on label="$LABEL"
else
  hide_item
fi

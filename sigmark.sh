#!/bin/sh
# Usage:
#   sigmark.sh <ip:port> <channel> <message>

REMOTE="$1"
CHANNEL="$2"
MESSAGE="$3"

if [ "$CHANNEL" = "CH1" ]; then
  CH_FLAG="--ch1"
else
  CH_FLAG="--ch2"
fi

curl -sS -X POST "http://$REMOTE/api/log" \
  -H "Content-Type: application/json" \
  -d "{\"msg\":\"$MESSAGE\",\"channel\":\"$CHANNEL\"}"
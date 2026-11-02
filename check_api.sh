#!/usr/bin/env bash

if [ $# -eq 0 ]; then
  echo "Использование: $0 <URL>"
  exit 1
fi

URL="$1"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --retry 3 "$URL")

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "API доступен, код ответа: $HTTP_CODE"
  exit 0
else
  echo "API недоступен, код ответа: $HTTP_CODE"
  exit 1
fi

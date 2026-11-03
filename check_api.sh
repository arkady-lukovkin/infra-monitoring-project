#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
    printf 'Использование: %s URL\n' "$0" >&2
    exit 1
fi

if code=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --connect-timeout 5 --max-time 15 --proto '=http,https' "$1"); then
    if [ "$code" = 200 ]; then
        printf 'API доступен\n'
        exit 0
    fi
fi

printf 'API недоступен, код ответа: %s\n' "${code:-000}"
exit 1


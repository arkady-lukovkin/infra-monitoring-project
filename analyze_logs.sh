#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [ "$#" -gt 1 ]; then
    printf 'Использование: %s [путь к существующему логу]\n' "$0" >&2
    exit 1
fi

log_file=${1:-access.log}
if [ "$#" -eq 0 ]; then
    # Воспроизводимый учебный лог: 300 запросов от четырёх адресов.
    awk 'BEGIN {
        for (i = 1; i <= 300; i++) {
            ip = i <= 120 ? "192.168.1.10" : i <= 210 ? "10.0.0.5" : i <= 270 ? "192.168.1.20" : "203.0.113.10"
            status = i % 10 == 0 ? 500 : i % 10 == 1 ? 401 : i % 10 <= 3 ? 404 : 200
            method = status == 401 ? "POST" : "GET"
            path = status == 401 ? "/api/login" : "/api/users"
            printf "%s - - [03/Nov/2026:10:%02d:%02d] \"%s %s HTTP/1.1\" %d\n", ip, int((i-1)/60), (i-1)%60, method, path, status
        }
    }' > "$log_file"
fi

if [ ! -r "$log_file" ]; then
    printf 'Не удалось прочитать лог: %s\n' "$log_file" >&2
    exit 1
fi

# Регулярное выражение проверяет каждый октет IPv4, а не только наличие точек.
octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
ip_pattern="^${octet}(\.${octet}){3}[[:space:]]"
printf 'Файл: %s\n' "$log_file"
awk 'END { printf "Всего запросов: %d\n", NR }' "$log_file"
printf 'Топ-3 IP (количество, адрес):\n'
# Пустой лог или отсутствие корректных IP — допустимый результат grep.
{ grep -E "$ip_pattern" "$log_file" || [ "$?" -eq 1 ]; } |
    awk '{print $1}' | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR <= 3'
awk '
    $8 ~ /^4[0-9][0-9]$/ { client_errors++ }
    $8 ~ /^5[0-9][0-9]$/ { server_errors++ }
    END {
        printf "Ответы 4xx: %d\nОтветы 5xx: %d\n", client_errors, server_errors
    }
' "$log_file"


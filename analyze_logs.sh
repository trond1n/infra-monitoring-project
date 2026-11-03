#!/usr/bin/env bash

# Массивы с данными
IPS=(192.168.1.10 192.168.1.10 192.168.1.10 192.168.1.20 192.168.1.20 10.0.0.5 172.16.0.1)
METHODS=(GET POST PUT DELETE)
PATHS=("/api/users" "/api/products" "/api/orders" "/api/auth" "/health")
CODES=(200 200 200 201 400 401 403 404 500 502 503)

# Очищаем access.log перед генерацией
> access.log

# Генерируем 350 записей
for ((i=0; i<350; i++)); do
  IP=${IPS[$RANDOM % ${#IPS[@]}]}
  METHOD=${METHODS[$RANDOM % ${#METHODS[@]}]}
  URI=${PATHS[$RANDOM % ${#PATHS[@]}]}
  CODE=${CODES[$RANDOM % ${#CODES[@]}]}
  echo "$IP - - [15/Aug/2026:10:15:32] \"$METHOD $URI HTTP/1.1\" $CODE" >> access.log
done

echo "Общее число запросов: $(wc -l < access.log)"
echo ""
echo "Топ-3 IP:"
grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}' access.log | sort | uniq -c | sort -rn | head -3
echo ""
echo "Количество 4xx: $(awk '$NF ~ /^4/ {count++} END {print count+0}' access.log)"
echo "Количество 5xx: $(awk '$NF ~ /^5/ {count++} END {print count+0}' access.log)"

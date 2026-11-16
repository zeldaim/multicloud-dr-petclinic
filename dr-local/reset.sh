#!/usr/bin/env bash
# 깨끗한 정상 상태로: 전부 내리고(데이터 삭제) 주 사이트 + DR DB 복제까지 올린다. 약 1~2분.
set -u; cd "$(dirname "$0")"
docker compose --profile dr down -v >/dev/null 2>&1
docker compose up -d mysql-primary mysql-dr app-aws front >/dev/null 2>&1
until [ "$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8088/owners?lastName=')" = 200 ]; do sleep 3; done
bash setup_replication.sh >/dev/null; echo "ready"

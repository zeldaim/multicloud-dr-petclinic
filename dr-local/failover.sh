#!/usr/bin/env bash
# 자동 전환: 주 사이트 DB 를 2초마다 확인 → 3번 연속 실패하면 DR DB 승격 → DR 앱 기동 → 진입점이 DR 로 응답할 때까지 대기.
# 각 단계 시각을 failover_times.txt 에 남긴다 (RTO 계산용).   bash failover.sh <out_dir>
OUT=$1; T(){ date +%s.%N | cut -c1-14; }; log(){ printf '[%s] %s\n' "$(date +%T)" "$*"; }
d(){ docker compose exec -T mysql-dr mysql -uroot -prootpw -N -e "$1" 2>/dev/null; }
fails=0
while :; do
  if docker compose exec -T mysql-primary mysqladmin ping -h 127.0.0.1 -uroot -prootpw >/dev/null 2>&1; then fails=0; else fails=$((fails+1)); log "주 사이트 DB 응답 없음 ($fails/3)"; fi
  [ $fails -ge 3 ] && break; sleep 2
done
echo "detected $(T)" >> $OUT/failover_times.txt; log "장애 확정 → DR 전환 시작"
d "STOP REPLICA; RESET REPLICA ALL; SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF;"
echo "promoted $(T)" >> $OUT/failover_times.txt; log "DR DB 승격 (복제 중지, 쓰기 허용)"
docker compose --profile dr up -d app-dr >/dev/null 2>&1; log "DR 앱 기동 (profile azure)"
until curl -fs -o /dev/null "${FRONT:-http://127.0.0.1:8088}/owners?lastName="; do sleep 1; done
echo "serving $(T)" >> $OUT/failover_times.txt; log "진입점이 DR 사이트로 응답 — 서비스 재개"

#!/usr/bin/env bash
# DR 시연 — 정상 운영 → 쓰기 부하 → 주 사이트 장애 → 자동 전환 → RTO/RPO 측정. (reset.sh 로 정상 상태를 만든 뒤 실행)
cd "$(dirname "$0")"; PY=${PY:-python3}; O=run; rm -rf $O; mkdir -p $O
B=$'\e[1;36m'; Y=$'\e[1;33m'; G=$'\e[1;32m'; R=$'\e[1;31m'; N=$'\e[0m'
say(){ printf '\n%s== %s ==%s\n' "$B" "$*" "$N"; }; run(){ printf '%s$ %s%s\n' "$Y" "$*" "$N"; }
FRONT=${FRONT:-http://127.0.0.1:8088}; export FRONT
banner(){ curl -s $FRONT/ | grep -oE "Running on [^<]*" | head -1; }
cnt(){ docker compose exec -T $1 mysql -uroot -prootpw -N -e "SELECT COUNT(*) FROM petclinic.owners" 2>/dev/null; }
say "멀티클라우드 DR 재현 (로컬 Docker) — $(date -u '+%F %T UTC')"
run "docker compose ps"; docker compose ps --format '  {{.Service}}\t{{.Status}}'
say "[1] 정상 운영: 사용자는 진입점(front)으로 접속"
run "curl $FRONT/ | grep Running"; printf '  %s%s%s\n' "$G" "$(banner)" "$N"
run "SHOW REPLICA STATUS  (DR DB 가 주 DB 를 따라가는 중 = DMS CDC 역할)"
docker compose exec -T mysql-dr mysql -uroot -prootpw -e "SHOW REPLICA STATUS\G" 2>/dev/null | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:" | sed 's/^ */  /'
say "[2] 사용자 쓰기 부하 시작: 0.5초마다 보호자 1명 등록 (75초)"
$PY load.py 75 $O & LOAD=$!
sleep 12; run "tail load.log"; tail -n 4 $O/load.log | sed 's/^/  /'
printf '  주 DB %s건 · DR DB %s건 (복제로 따라옴)\n' "$(cnt mysql-primary)" "$(cnt mysql-dr)"
say "[3] 장애 주입: 주 사이트(AWS) DB 와 앱을 동시에 중지"
run "docker compose stop mysql-primary app-aws"
date +%s.%N | cut -c1-14 > $O/t_fail; docker compose stop -t 0 mysql-primary app-aws >/dev/null 2>&1
printf '  %s주 사이트 다운%s\n' "$R" "$N"
say "[4] 자동 전환 (failover.sh): 감지 → DR DB 승격 → DR 앱 기동 → 진입점 재개"
bash failover.sh $O
run "curl $FRONT/ | grep Running"; printf '  %s%s%s\n' "$G" "$(banner)" "$N"
wait $LOAD
say "[5] 결과 — RTO · RPO"
$PY - $O <<'PY'
import sys, subprocess
o = sys.argv[1]; t_fail = float(open(f"{o}/t_fail").read())
ts = dict(l.split() for l in open(f"{o}/failover_times.txt"))
acked = [l.strip() for l in open(f"{o}/acked.txt") if l.strip()]
rows = subprocess.run(["docker", "compose", "exec", "-T", "mysql-dr", "mysql", "-uroot", "-prootpw", "-N", "-e",
                       "SELECT last_name FROM petclinic.owners WHERE last_name LIKE 'Load%'"], capture_output=True, text=True).stdout.split()
lost = [a for a in acked if a not in set(rows)]
log = [l.split() for l in open(f"{o}/load.log")]
fails = [l for l in log if l[2] == "FAIL"]; after = [l for l in log if float(l[0]) > t_fail]
first_ok = next((float(l[0]) for l in after if l[2] == "OK"), None)
print(f"  감지까지          {float(ts['detected']) - t_fail:6.1f}초")
print(f"  DR DB 승격까지    {float(ts['promoted']) - t_fail:6.1f}초")
print(f"  RTO (서비스 재개) {float(ts['serving']) - t_fail:6.1f}초   (장애 주입 → 진입점이 DR 로 응답)")
if first_ok: print(f"  사용자 첫 성공 쓰기  {first_ok - t_fail:6.1f}초 뒤")
print(f"  쓰기 시도 {len(log)}건 · 성공 응답 {len(acked)}건 · 실패 {len(fails)}건 (전환 중)")
print(f"  RPO: 성공 응답을 받았는데 DR DB 에 없는 쓰기 = {len(lost)}건 {lost[:5]}")
open(f"{o}/result.txt", "w").write(f"detected {float(ts['detected'])-t_fail:.1f}\npromoted {float(ts['promoted'])-t_fail:.1f}\nrto {float(ts['serving'])-t_fail:.1f}\nattempts {len(log)}\nacked {len(acked)}\nfailed {len(fails)}\nlost {len(lost)}\n")
PY
printf '  DR DB 보호자 수: %s\n' "$(cnt mysql-dr)"
run "SELECT COUNT(*) … WHERE last_name='Franklin'  (기본 데이터가 DR 기동 때 중복 삽입됐나)"
printf '  %s\n' "$(docker compose exec -T mysql-dr mysql -uroot -prootpw -N -e "SELECT COUNT(*) FROM petclinic.owners WHERE last_name='Franklin'" 2>/dev/null)"
say "끝"

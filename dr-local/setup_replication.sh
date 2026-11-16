#!/usr/bin/env bash
# mysql-dr 를 mysql-primary 의 복제본으로 만든다 — AWS DMS 의 "full load + CDC" 를 MySQL 기본 기능으로:
#   ① full load : 주 DB 를 한 시점(GTID 포함)으로 덤프해 DR DB 에 적재
#   ② CDC      : 그 시점 이후 변경을 GTID 자동 위치 복제로 따라감
set -u
P="docker compose exec -T mysql-primary"; D="docker compose exec -T mysql-dr"
q(){ grep -v "Using a password"; }
$P mysql -uroot -prootpw -e "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpw'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';" 2>&1 | q
$D mysql -uroot -prootpw -e "STOP REPLICA; RESET REPLICA ALL; RESET BINARY LOGS AND GTIDS; DROP DATABASE IF EXISTS petclinic;" 2>&1 | q
$P mysqldump -uroot -prootpw --databases petclinic --single-transaction --set-gtid-purged=ON --routines --triggers 2>/dev/null | $D mysql -uroot -prootpw 2>&1 | q
$D mysql -uroot -prootpw -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysql-primary', SOURCE_USER='repl', SOURCE_PASSWORD='replpw', SOURCE_AUTO_POSITION=1, GET_SOURCE_PUBLIC_KEY=1; START REPLICA;" 2>&1 | q
sleep 3
$D mysql -uroot -prootpw -e "SHOW REPLICA STATUS\G" 2>/dev/null | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_SQL_Error:" | sed 's/^ */  /'

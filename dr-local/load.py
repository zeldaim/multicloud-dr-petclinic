#!/usr/bin/env python3
"""사용자 부하: 진입점(front)으로 보호자(owner)를 0.5초마다 1명씩 등록하고, 성공 응답을 받은 것만 acked.txt 에 적는다.
장애 뒤 DR DB 에 남아 있는지 대조하면 RPO(잃어버린 쓰기)가 나온다.   python3 load.py <초> <out_dir>"""
import os, sys, time, urllib.parse, urllib.request
dur, out = float(sys.argv[1]), sys.argv[2]
open_ = urllib.request.build_opener(urllib.request.ProxyHandler({})).open   # 시스템 프록시 설정을 타지 않게 (로컬 주소)
end, n = time.time() + dur, 0
ack = open(out + "/acked.txt", "w"); log = open(out + "/load.log", "w")
while time.time() < end:
    n += 1; name = f"Load{n:05d}"
    body = urllib.parse.urlencode({"firstName": "DR", "lastName": name, "address": "1 Test St", "city": "Seoul", "telephone": "0101234567"}).encode()
    t = time.time()
    try:
        r = open_(urllib.request.Request(os.environ.get("FRONT", "http://127.0.0.1:8088") + "/owners/new", data=body, method="POST"), timeout=5)
        ok = r.status in (200, 302)
    except urllib.error.HTTPError as e:
        ok = e.code == 302
    except Exception:
        ok = False
    log.write(f"{t:.2f} {name} {'OK' if ok else 'FAIL'}\n"); log.flush()
    if ok: ack.write(name + "\n"); ack.flush()
    time.sleep(0.5)

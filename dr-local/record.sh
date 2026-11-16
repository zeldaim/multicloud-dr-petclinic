#!/usr/bin/env bash
# 실제 화면 녹화: reset.sh 로 정상 상태를 만든 뒤, compose 네트워크 안의 가상 화면 터미널에서 demo.sh 를 실행하며 캡처한다.
#   bash record.sh   → media/dr_demo.mp4 (실시간) · media/dr_demo_2x.mp4
set -u; cd "$(dirname "$0")"; mkdir -p media
WIN="$(pwd -W 2>/dev/null || pwd)"; export MSYS_NO_PATHCONV=1
docker build -q -t dr-rec -f Dockerfile.rec . >/dev/null && bash reset.sh
docker run --rm --network petclinic-dr_default -v /var/run/docker.sock:/var/run/docker.sock -v "$WIN:/dr" -w /dr dr-rec bash -c '
  Xvfb :99 -screen 0 1280x720x24 >/dev/null 2>&1 & sleep 2; export DISPLAY=:99
  ffmpeg -y -loglevel error -f x11grab -draw_mouse 0 -framerate 10 -video_size 1280x720 -i :99 -c:v libx264 -preset veryfast -crf 26 -pix_fmt yuv420p media/dr_demo.mp4 & FF=$!
  sleep 1
  xterm -u8 -fa "DejaVu Sans Mono" -fd "NanumGothicCoding" -fs 12 -geometry 130x34+0+0 -bg "#10121a" -fg "#dde2e8" -b 8 -e bash -c "cd /dr && FRONT=http://front bash demo.sh; sleep 8"
  sleep 1; kill -INT $FF; wait $FF 2>/dev/null
  ffmpeg -y -loglevel error -i media/dr_demo.mp4 -filter:v "setpts=0.5*PTS" -an -c:v libx264 -crf 26 -pix_fmt yuv420p -movflags +faststart media/dr_demo_2x.mp4
  for f in dr_demo dr_demo_2x; do echo "$f.mp4 $(ffprobe -v error -show_entries format=duration -of csv=p=0 media/$f.mp4 | cut -d. -f1)초"; done'

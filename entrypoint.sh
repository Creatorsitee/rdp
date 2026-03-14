#!/bin/bash
service dbus start > /dev/null 2>&1

# Loop biar container gak mati pas kita swap proses
while true; do
  python3 /app/manager.py
  sleep 2
done

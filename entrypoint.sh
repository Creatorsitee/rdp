#!/bin/bash
# Pastikan dbus running biar app desktop lancar
service dbus start > /dev/null 2>&1
python3 /app/manager.py

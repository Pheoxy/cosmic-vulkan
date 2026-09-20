#!/usr/bin/env python3
# Decode cosmic-comp's structured XWayland tracing fields, hidden by default
# journalctl formatting (journalctl -o short-precise drops tracing's structured
# fields entirely; only -o json/-o verbose expose F_ERR, F_WINDOW, F_SERIAL etc).
# Usage: xwayland-decode.py [journalctl args...]
#   e.g. xwayland-decode.py -f                  (live tail, decoded)
#        xwayland-decode.py --since "10 min ago"
import json
import subprocess
import sys
from datetime import datetime

proc = subprocess.Popen(
    ["journalctl", "-o", "json", *sys.argv[1:]],
    stdout=subprocess.PIPE, text=True,
)
for line in proc.stdout:
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        continue
    if "xwm/mod.rs" not in rec.get("CODE_FILE", ""):
        continue
    ts = rec.get("__REALTIME_TIMESTAMP")
    ts_str = datetime.fromtimestamp(int(ts) / 1_000_000).strftime("%H:%M:%S.%f")[:-3] if ts else "?"
    parts = [ts_str, rec.get("MESSAGE", "")]
    for key, label in (("F_ERR", ""), ("F_WINDOW", "window="), ("F_SERIAL", "serial=")):
        if key in rec:
            v = rec[key]
            parts.append(f"{label}{v}" if label else v)
    print("  ".join(parts))

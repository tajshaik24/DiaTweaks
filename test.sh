#!/bin/sh
set -eu
cd "$(dirname "$0")"
support="${DIAPATCH_HOME:-$HOME/Library/Application Support/DiaPatches}"
dia="${DIAPATCH_APP:-/Applications/Dia.app}/Contents/MacOS/Dia"
report="$PWD/build/test-report.json"

# Dia saves which windows auto-hide their tabs in its window state, and only writes that state when it quits normally.
# The test stops Dia abruptly, so each run starts with Auto-Hide Tabs saved off, then on, and the state goes back after.
domain=company.thebrowser.dia
saved_windows=$(defaults read "$domain" persistedWindowData 2>/dev/null || true)
restore_windows() {
    if [ -n "$saved_windows" ]; then defaults write "$domain" persistedWindowData -string "$saved_windows"; fi
}
trap restore_windows EXIT INT TERM

stop_dia() {
    pid=$(pgrep -f "$dia\$" || true)
    [ -z "$pid" ] || kill -TERM $pid
    while [ -n "$pid" ] && kill -0 $pid 2>/dev/null; do sleep 0.5; done
    # Dia skips its quit notification on SIGTERM, so safe mode would count this as a crash at launch.
    plutil -replace launching -bool NO "$support/safe-mode.plist" 2>/dev/null || true
}

# run_dia REPORT [ENV=VALUE]: one test run in a fresh Dia, which writes REPORT when it's done.
run_dia() {
    out=$1
    shift
    stop_dia
    rm -f "$out"
    env DIAPATCH_TEST="$out" "$@" nohup "$dia" >/dev/null 2>&1 &
    test_pid=$!
    # Both tab layouts, every scenario: allow 15 minutes.
    for _ in $(seq 1800); do [ -f "$out" ] && break; kill -0 $test_pid 2>/dev/null || break; sleep 0.5; done
    [ -f "$out" ] || { echo "Dia wrote no report in 15 minutes, or quit before writing one. Is it patched (./install.sh), and was every other Dia closed?" >&2; exit 1; }
}

cp -f build/DiaPatches.dylib "$support/DiaPatches.dylib"
rm -f "$report"
switch_only=${DIAPATCH_TEST_SWITCH_ONLY:+DIAPATCH_TEST_SWITCH_ONLY=1}
# with_auto_hide true|false: the saved window state with every window's Auto-Hide Tabs set that way.
with_auto_hide() {
    printf '%s' "$saved_windows" | python3 -I -c '
import json, sys
state = json.load(sys.stdin)
for window in state.get("windows", []): window["isFocusModeActive"] = sys.argv[1] == "true"
print(json.dumps(state, separators=(",", ":")))' "$1"
}
[ -z "$saved_windows" ] || defaults write "$domain" persistedWindowData -string "$(with_auto_hide false)"
run_dia "$report.shown" ${switch_only:-DIAPATCH_TEST_RUN=shown}
if [ -n "$saved_windows" ]; then
    defaults write "$domain" persistedWindowData -string "$(with_auto_hide true)"
    run_dia "$report.hidden" DIAPATCH_TEST_AUTOHIDE=1 ${switch_only:-DIAPATCH_TEST_RUN=hidden}
fi
restore_windows
stop_dia
# Dia comes back as it was saved, with your settings and layout.
nohup "$dia" >/dev/null 2>&1 &

python3 -I - "$report" "$report.shown" "$report.hidden" <<'MERGE'
import json, os, sys
out, parts = sys.argv[1], [json.load(open(p)) for p in sys.argv[2:] if os.path.exists(p)]
report = dict(parts[0])
report["phases"] = [phase for part in parts for phase in part.get("phases", [])]
report["scenarios"] = [scenario for part in parts for scenario in part["scenarios"]]
report["unavailable"] = sorted({key for part in parts for key in part["unavailable"]})
report["safeMode"] = max(part["safeMode"] for part in parts)
report["switches"] = [line for part in parts for line in part.get("switches", [])]
json.dump(report, open(out, "w"), indent=2, sort_keys=True)
MERGE
rm -f "$report.shown" "$report.hidden"

exec python3 - "$report" <<'EOF'
import json, sys
report = json.load(open(sys.argv[1]))
phases = ", ".join(f"tabs {p}" for p in report.get("phases", [])) or "none"
print(f"Dia {report['dia']}. Ran with: {phases}. Dia reopens as you left it.")
problems = 0
for key in report["unavailable"]:
    print(f"FAIL {key} is unavailable on this Dia version")
    problems += 1
if report["safeMode"]:
    print("FAIL Dia is in safe mode, so no patches loaded")
    problems += 1
for scenario in report["scenarios"]:
    print(("FAIL " if scenario["failures"] else "ok   ") + scenario["name"])
    for key, problem in sorted(scenario["failures"].items()):
        print(f"     {key}: {problem}")
    problems += len(scenario["failures"])
print(f"{len(report['scenarios'])} scenarios, {problems} problems")
sys.exit(1 if problems else 0)
EOF

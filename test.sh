#!/bin/sh
set -eu
cd "$(dirname "$0")"
<<<<<<< HEAD
=======
support="${DIAPATCH_HOME:-$HOME/Library/Application Support/DiaPatches}"
app=${DIAPATCH_APP:-}
if [ -z "$app" ]; then
    app=/Applications/Dia.app
    for candidate in "$(cat "$support/dia-app" 2>/dev/null)" /Applications/Dia.app "$HOME/Applications/Dia.app"; do
        if [ -x "$candidate/Contents/MacOS/Dia" ]; then app=$candidate; break; fi
    done
fi
dia="$app/Contents/MacOS/Dia"
>>>>>>> upstream/main
report="$PWD/build/test-report.json"

# The test runs in a second Dia (scripts/test-dia), never yours: its own app copy, data, settings and DiaTweaks build,
# sandboxed away from your Dia's files. Your Dia stays open and untouched; only the "Dia Test" window comes and goes.
domain=company.thebrowser.dia.diatweaks-test
home="$PWD/build/test-dia/home"
scripts/test-dia setup
trap 'scripts/test-dia stop; plutil -replace launching -bool NO "$home/safe-mode.plist" 2>/dev/null || true' EXIT
trap 'exit 130' INT TERM

# run_dia REPORT [ENV=VALUE]: one test run in a fresh test Dia, which writes REPORT when it's done.
run_dia() {
    out=$1
    shift
    scripts/test-dia stop
    # A Dia that was killed never said it quit, and safe mode would count that as a crash at launch.
    plutil -replace launching -bool NO "$home/safe-mode.plist" 2>/dev/null || true
    rm -f "$out"
    scripts/test-dia run DIAPATCH_TEST="$out" "$@"
    sleep 2
    # Both tab layouts, every scenario: allow 15 minutes.
    for _ in $(seq 1800); do
        [ -f "$out" ] && break
        pgrep -f "^$PWD/build/test-dia/DiaTest.app/Contents/MacOS/Dia" >/dev/null || break
        sleep 0.5
    done
    [ -f "$out" ] || { echo "The test Dia wrote no report in 15 minutes, or quit before writing one; see build/test-dia/run.log." >&2; exit 1; }
}

rm -f "$report"
switch_only=${DIAPATCH_TEST_SWITCH_ONLY:+DIAPATCH_TEST_SWITCH_ONLY=1}
# Each run sets Auto-Hide Tabs itself (DPPrepareWindow), so nothing depends on window state Dia saved.
run_dia "$report.shown" ${switch_only:-DIAPATCH_TEST_RUN=shown}
run_dia "$report.hidden" DIAPATCH_TEST_AUTOHIDE=1 ${switch_only:-DIAPATCH_TEST_RUN=hidden}
scripts/test-dia stop
trap - EXIT

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
print(f"Dia {report['dia']} (the test copy). Ran with: {phases}.")
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

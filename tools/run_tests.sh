#!/usr/bin/env bash
# Local mirror of the CI checks: fresh user data, import, settings round-trip,
# the gameplay smoke suite, then the end-to-end loop. Usage: tools/run_tests.sh [path-to-godot]
set -u
GODOT="${1:-godot}"
USERDIR="$HOME/.local/share/godot/app_userdata/Stock Rogue"
rm -rf "$USERDIR"
fail=0
python3 tools/sweep.py > /tmp/sr_sweep.log 2>&1 || { cat /tmp/sr_sweep.log; fail=1; }
tail -1 /tmp/sr_sweep.log
"$GODOT" --headless --editor --path . --import > /tmp/sr_import.log 2>&1
if grep -E 'SCRIPT ERROR|Parse Error|Failed to load script' /tmp/sr_import.log; then fail=1; fi
timeout 30s "$GODOT" --headless --path . res://tests/settings_test.tscn -- write > /tmp/sr_sw.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:' /tmp/sr_sw.log | grep -v "ALSA\|audio_driver\|init_output_device"; then fail=1; fi
timeout 30s "$GODOT" --headless --path . res://tests/settings_test.tscn -- read > /tmp/sr_sr.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:' /tmp/sr_sr.log | grep -v "ALSA\|audio_driver\|init_output_device"; then fail=1; fi
timeout 180s "$GODOT" --headless --path . res://tests/smoke.tscn > /tmp/sr_smoke.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:' /tmp/sr_smoke.log; then fail=1; fi
grep -q 'TEST SUITE COMPLETE' /tmp/sr_smoke.log || { echo "smoke suite did not complete"; fail=1; }
echo "passes: $(grep -c 'TEST PASS' /tmp/sr_smoke.log)"
# End to end: Home -> crew -> hideout -> heist -> quota -> the Chairman -> ending -> Home.
timeout 180s "$GODOT" --headless --path . res://tests/full_loop.tscn > /tmp/sr_loop.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:' /tmp/sr_loop.log; then fail=1; fi
grep -q 'FULL LOOP COMPLETE' /tmp/sr_loop.log || { echo "full loop did not complete"; fail=1; }
echo "full loop: $(grep -c 'LOOP PASS' /tmp/sr_loop.log) steps"
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit $fail

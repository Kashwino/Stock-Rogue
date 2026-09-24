#!/usr/bin/env bash
# Local mirror of the CI checks: fresh user data, import, settings round-trip,
# then the gameplay smoke suite. Usage: tools/run_tests.sh [path-to-godot]
set -u
GODOT="${1:-godot}"
USERDIR="$HOME/.local/share/godot/app_userdata/Stock Rogue"
rm -rf "$USERDIR"
fail=0
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
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit $fail

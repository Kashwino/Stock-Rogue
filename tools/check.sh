#!/usr/bin/env bash
# Refresh the global class cache (editor import), then compile every script
# as a scene so autoload names resolve. Prints errors with locations.
timeout 200 godot --headless --editor --path . --import > /dev/null 2>&1
timeout 90 godot --headless --path . res://tools/compile_all.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error|COMPILE FAIL|COMPILED|at: .*\.gd" | grep -v "compile_all.gd" | head -40

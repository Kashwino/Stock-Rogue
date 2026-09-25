#!/usr/bin/env python3
"""Static sweep of the project (stdlib only). Exit 1 on any finding.

  * every "res://..." path in scripts, scenes, resources and project.godot exists
  * every input action the code reads is defined in project.godot
  * every `connect(_method)` / `connect(method.bind(...))` target exists
  * change_scene_to_file is always guarded by ResourceLoader.exists
  * tabs-only indentation in GDScript; no Label2D; no method named `bind`;
    no `SomeClass.new` passed as a Callable (exported builds can't resolve it)
  * no bare print() in game scripts (tools/ and tests/ may print; Log gates the rest)

    python3 tools/sweep.py
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
findings = []


def files(*patterns):
    out = []
    for p in patterns:
        out += [f for f in glob.glob(p, recursive=True) if not f.startswith(("build/", ".godot/", "node_modules/"))]
    return sorted(set(out))


GD = files("*.gd", "**/*.gd")
TEXT = GD + files("*.tscn", "**/*.tscn", "*.tres", "**/*.tres") + ["project.godot", "export_presets.cfg"]

# 1. resource paths
for f in TEXT:
    if not os.path.exists(f):
        continue
    src = open(f, encoding="utf-8").read()
    for m in re.finditer(r'"(res://[^"%{}]+?)"', src):
        path = m.group(1)
        if path.endswith("/") or "*" in path:
            continue
        local = path[len("res://"):]
        if not os.path.exists(local):
            line = src[:m.start()].count("\n") + 1
            findings.append("%s:%d missing resource %s" % (f, line, path))

# 2. input actions
project = open("project.godot", encoding="utf-8").read()
inp = project[project.index("[input]"):]
nxt = re.search(r"^\[(?!input)", inp[1:], re.M)
inp = inp[: nxt.start() + 1] if nxt else inp
actions = set(re.findall(r"^(\w+)=\{", inp, re.M))
builtin = lambda a: a.startswith("ui_")
ACTION_CALL = re.compile(r'(?:is_action_pressed|is_action_just_pressed|is_action_just_released|is_action_released|'
                         r'action_press|action_release|get_action_strength|is_action)\(\s*"(\w+)"')
for f in GD:
    src = open(f, encoding="utf-8").read()
    for m in ACTION_CALL.finditer(src):
        if m.group(1) not in actions and not builtin(m.group(1)):
            findings.append("%s:%d unknown input action %s" % (f, src[:m.start()].count("\n") + 1, m.group(1)))
    for m in re.finditer(r'get_vector\(([^)]*)\)', src):
        for a in re.findall(r'"(\w+)"', m.group(1)):
            if a not in actions and not builtin(a):
                findings.append("%s:%d unknown input action %s" % (f, src[:m.start()].count("\n") + 1, a))

# 3. connect targets (methods defined anywhere in the project, or engine methods)
defined = set()
for f in GD:
    defined |= set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)", open(f, encoding="utf-8").read(), re.M))
ENGINE = {"queue_free", "hide", "show", "grab_focus", "emit", "call", "free", "quit", "release_focus",
          "queue_redraw", "set_process", "set_physics_process", "reset_size", "update_minimum_size"}
for f in GD:
    src = open(f, encoding="utf-8").read()
    for m in re.finditer(r"\.connect\(\s*([A-Za-z_]\w*)(?:\.bind\([^)]*\))?\s*[,)]", src):
        name = m.group(1)
        if name in defined or name in ENGINE or name in ("func",):
            continue
        # A Callable held in a parameter or variable.
        if re.search(r"\b%s\s*:\s*Callable\b|\bvar\s+%s\b" % (name, name), src):
            continue
        findings.append("%s:%d connect target %s is not a method" % (f, src[:m.start()].count("\n") + 1, name))

# 4. guarded scene changes, 5. GDScript traps
for f in GD:
    src = open(f, encoding="utf-8").read()
    lines = src.split("\n")
    for i, line in enumerate(lines, 1):
        if re.match(r"^ +\S", line):
            findings.append("%s:%d indented with spaces" % (f, i))
        if "Label2D" in line and not line.lstrip().startswith("#") and "no `Label2D`" not in line:
            findings.append("%s:%d uses Label2D" % (f, i))
        code = line.split("#", 1)[0]
        if re.search(r"\b[A-Z]\w*\.new\b(?!\()", code):
            findings.append("%s:%d constructor used as a Callable (fails in exported builds)" % (f, i))
        if re.match(r"^\s*func bind\(", line):
            findings.append("%s:%d defines a method named bind" % (f, i))
        if "change_scene_to_file(" in line:
            window = "\n".join(lines[max(0, i - 15):i])
            if "ResourceLoader.exists" not in window and "error" not in line.lower() and "err" not in window:
                findings.append("%s:%d unguarded change_scene_to_file" % (f, i))
        if re.match(r"^\s*print\(", line) and not f.startswith(("tools/", "tests/")) and f != "log.gd":
            findings.append("%s:%d bare print() outside Log" % (f, i))

for line in findings:
    print(line)
print("SWEEP: %d files, %d input actions, %d findings" % (len(TEXT), len(actions), len(findings)))
sys.exit(1 if findings else 0)

#!/usr/bin/env bash
set -euo pipefail

# 1) Patch SConstruct to include godot-cpp/gdextension
python3 - <<'PY'
p = "clipper2_ext/SConstruct"
s = open(p,"r",encoding="utf-8").read()
inc = 'os.path.join(godot_cpp_path, "gdextension")'
if inc not in s:
    s = s.replace('env.Append(CPPPATH=[', 'env.Append(CPPPATH=[\n\t'+inc+',')
open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

# 2) Make sure godot-cpp is built (for the exact editor version/tag you use)
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

# 3) Clean & rebuild the extension
( cd clipper2_ext && scons -c >/dev/null 2>&1 || true )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

# 4) Show results
ls -l clipper2_ext/bin || true

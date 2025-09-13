#!/usr/bin/env bash
set -euo pipefail

echo "[1] Ensure Clipper2 is present at expected location"
if [ ! -f clipper2_ext/thirdparty/clipper2/CPP/Clipper2Lib/include/clipper2/clipper.h ]; then
	rm -rf clipper2_ext/thirdparty/clipper2
	git clone --depth 1 https://github.com/AngusJohnson/Clipper2.git clipper2_ext/thirdparty/clipper2
fi

echo "[2] Use correct include directive (lowercase 'clipper2')"
sed -i '' 's|#include <Clipper2/clipper.h>|#include <clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp || true
grep -n '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp

echo "[3] Patch SConstruct include dirs to point at Clipper2Lib/include"
python3 - <<'PY'
p = "clipper2_ext/SConstruct"
s = open(p,"r",encoding="utf-8").read()
# add the canonical include dir if missing
inc = 'os.path.join("thirdparty", "clipper2", "CPP", "Clipper2Lib", "include")'
if inc not in s:
    s = s.replace('env.Append(CPPPATH=[', 'env.Append(CPPPATH=[\n\t'+inc+',')
# keep already-correct godot-cpp libname order; ensure Default(shlib) present
if 'Default(shlib)' not in s:
    s = s.replace(
        'env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)',
        'shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)\nDefault(shlib)'
    )
open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

echo "[4] Build godot-cpp (debug+release)"
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[5] Clean & build the extension (debug+release)"
( cd clipper2_ext && scons -c >/dev/null 2>&1 || true )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[6] Results:"
ls -l clipper2_ext/bin || true

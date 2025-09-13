#!/usr/bin/env bash
set -euo pipefail

# 1) Ensure Clipper2 headers are present where we expect them
test -f clipper2_ext/thirdparty/clipper2/CPP/Clipper2Lib/include/clipper2/clipper.h || {
  echo "[fetch] Clipper2..."
  rm -rf clipper2_ext/thirdparty/clipper2
  git clone --depth 1 https://github.com/AngusJohnson/Clipper2.git clipper2_ext/thirdparty/clipper2
}

# 2) Make sure our include uses the correct path (lowercase)
sed -i '' 's|#include <Clipper2/clipper.h>|#include <clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp || true
grep -n '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp

# 3) Patch SConstruct:
#    - add Clipper2 include dir
#    - link correct godot-cpp lib name
#    - make our SharedLibrary the default target
#    - compile ALL Clipper2 .cpp from CPP/Clipper2Lib/src
python3 - <<'PY'
import os, re, glob
p = "clipper2_ext/SConstruct"
s = open(p,"r",encoding="utf-8").read()

# include paths
if 'Clipper2Lib", "include")' not in s:
    s = s.replace(
        'os.path.join("thirdparty", "clipper2", "CPP"),',
        'os.path.join("thirdparty", "clipper2", "CPP"),\n\tos.path.join("thirdparty", "clipper2", "CPP", "Clipper2Lib", "include"),'
    )

# correct godot-cpp lib name order (libgodot-cpp.<platform>.<target>.<arch>.a)
s = s.replace('libname = "godot-cpp." + platform + "." + arch + "." + target',
              'libname = "godot-cpp." + platform + "." + target + "." + arch')

# add Clipper2 sources
if "clipper_srcs =" not in s:
    insert_after = 'sources = [\n\tos.path.join("src", "clipper2_open.cpp"),\n\tos.path.join("src", "register_types.cpp"),\n]\n'
    clip = 'clipper_srcs = [ os.path.join("thirdparty","clipper2","CPP","Clipper2Lib","src", f) for f in os.listdir(os.path.join("thirdparty","clipper2","CPP","Clipper2Lib","src")) if f.endswith(".cpp") ]\n'
    s = s.replace(insert_after, insert_after + clip + 'sources += clipper_srcs\n')

# default target
if "Default(shlib)" not in s:
    s = s.replace(
        'env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)',
        'shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)\nDefault(shlib)'
    )

open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

# 4) Build godot-cpp (just in case)
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

# 5) Clean & build the extension (debug + release)
( cd clipper2_ext && scons -c >/dev/null 2>&1 || true )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

# 6) Show results
ls -l clipper2_ext/bin || true

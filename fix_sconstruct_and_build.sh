#!/usr/bin/env bash
set -euo pipefail

# 0) Make sure godot-cpp is built for your editor (4.4). If not, build it now.
if [ ! -f godot-cpp/bin/libgodot-cpp.macos.template_debug.arm64.a ]; then
  echo "[build] godot-cpp (debug + release)"
  ( cd godot-cpp && git fetch --all --tags >/dev/null 2>&1 || true )
  ( cd godot-cpp && git checkout godot-4.4-stable )
  ( cd godot-cpp && git submodule update --init --recursive )
  ( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
  ( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )
fi

# 1) Ensure Clipper2 headers are present where we expect them
if [ ! -f clipper2_ext/thirdparty/clipper2/CPP/Clipper2Lib/include/clipper2/clipper.h ]; then
  echo "[fetch] Clipper2 sources"
  rm -rf clipper2_ext/thirdparty/clipper2
  git clone --depth 1 https://github.com/AngusJohnson/Clipper2.git clipper2_ext/thirdparty/clipper2
fi

# 2) Ensure our include uses the current layout (lowercase 'clipper2')
sed -i '' 's|#include <Clipper2/clipper.h>|#include <clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp 2>/dev/null || true
grep -n '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp || true

# 3) Replace clipper2_ext/SConstruct to avoid calling godot-cpp/SConstruct
cat > clipper2_ext/SConstruct <<'SCON'
import os
from SCons.Script import DefaultEnvironment, ARGUMENTS, Default

env = DefaultEnvironment()
target   = ARGUMENTS.get("target", "template_debug")
platform = ARGUMENTS.get("platform", "macos")
arch     = ARGUMENTS.get("arch", "arm64")

godot_cpp_path = os.path.join("..", "godot-cpp")

# Include dirs (godot-cpp + Clipper2)
env.Append(CPPPATH=[
    os.path.join(godot_cpp_path, "include"),
    os.path.join(godot_cpp_path, "gen", "include"),
    os.path.join("thirdparty", "clipper2", "CPP", "Clipper2Lib", "include"),
])

# C++ flags
env.Append(CXXFLAGS=["-std=c++17"])
if target == "template_release":
    env.Append(CXXFLAGS=["-O3"])
else:
    env.Append(CXXFLAGS=["-O2","-g"])

# Link against prebuilt godot-cpp static lib: libgodot-cpp.<platform>.<target>.<arch>.a
libname = "libgodot-cpp.%s.%s.%s.a" % (platform, target, arch)
libfile = os.path.join(godot_cpp_path, "bin", libname)
env.Append(LINKFLAGS=[libfile])

# Our sources + all Clipper2 sources
sources = [
    os.path.join("src", "clipper2_open.cpp"),
    os.path.join("src", "register_types.cpp"),
]

clipper_src_dir = os.path.join("thirdparty","clipper2","CPP","Clipper2Lib","src")
for f in os.listdir(clipper_src_dir):
    if f.endswith(".cpp"):
        sources.append(os.path.join(clipper_src_dir, f))

# Output library
if platform == "windows":
    target_name = "clipper2_ext.windows.%s.%s.dll" % (arch, target)
elif platform == "macos":
    target_name = "libclipper2_ext.macos.%s.%s.dylib" % (arch, target)
else:
    target_name = "libclipper2_ext.linux.%s.%s.so" % (arch, target)

shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)
Default(shlib)
SCON

# 4) Build the extension (debug + release)
echo "[build] clipper2_ext (debug)"
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
echo "[build] clipper2_ext (release)"
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[done] Built:"
ls -l clipper2_ext/bin

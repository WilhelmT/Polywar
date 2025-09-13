#!/usr/bin/env bash
set -euo pipefail

echo "[0] Check tools"
command -v scons >/dev/null || { echo "ERROR: scons not found. brew install scons"; exit 1; }
command -v git   >/dev/null || { echo "ERROR: git not found."; exit 1; }

echo "[1] Ensure folders"
mkdir -p clipper2_ext/src clipper2_ext/thirdparty

echo "[2] Ensure Clipper2 source exists"
if [ ! -f clipper2_ext/thirdparty/clipper2/CPP/Clipper2/clipper.h ]; then
	rm -rf clipper2_ext/thirdparty/clipper2
	git clone --depth 1 https://github.com/AngusJohnson/Clipper2.git clipper2_ext/thirdparty/clipper2
fi
ls -l clipper2_ext/thirdparty/clipper2/CPP/Clipper2/clipper.h

echo "[3] Ensure godot-cpp exists (branch 4.4)"
if [ ! -d godot-cpp ]; then
	git clone --recursive --depth 1 -b 4.4 https://github.com/godotengine/godot-cpp.git
fi

echo "[4] Write/overwrite SConstruct with correct include paths and defaults"
cat > clipper2_ext/SConstruct <<'SCON'
import os
from SCons.Script import DefaultEnvironment, ARGUMENTS, Default

env = DefaultEnvironment()
target   = ARGUMENTS.get("target", "template_debug")
platform = ARGUMENTS.get("platform", "")
arch     = ARGUMENTS.get("arch", "")

godot_cpp_path = os.path.join("..", "godot-cpp")
env.SConscript(os.path.join(godot_cpp_path, "SConstruct"),
               exports={"env": env},
               variant_dir=os.path.join("bin", "godot-cpp"),
               duplicate=0)

# Include dirs (godot-cpp + Clipper2)
env.Append(CPPPATH=[
	os.path.join(godot_cpp_path, "include"),
	os.path.join(godot_cpp_path, "gen", "include"),
	os.path.join("thirdparty", "clipper2", "CPP"),
	os.path.join("thirdparty", "clipper2", "CPP", "Clipper2"),
])

env.Append(CXXFLAGS=["-std=c++17"])
if target == "template_release":
	env.Append(CXXFLAGS=["-O3"])
else:
	env.Append(CXXFLAGS=["-O2", "-g"])

# godot-cpp static lib naming: libgodot-cpp.<platform>.<target>.<arch>.a
libname = "godot-cpp." + platform + "." + target + "." + arch
if platform == "windows":
	libfile = os.path.join("bin", "godot-cpp", "bin", libname + ".lib")
else:
	libfile = os.path.join("bin", "godot-cpp", "bin", "lib" + libname + ".a")
env.Append(LIBPATH=[os.path.dirname(libfile)])
env.Append(LIBS=[os.path.splitext(os.path.basename(libfile))[0]])

sources = [
	os.path.join("src", "clipper2_open.cpp"),
	os.path.join("src", "register_types.cpp"),
]

if platform == "windows":
	target_name = "clipper2_ext.windows." + arch + "." + target + ".dll"
elif platform == "macos":
	target_name = "libclipper2_ext.macos." + arch + "." + target + ".dylib"
else:
	target_name = "libclipper2_ext.linux." + arch + "." + target + ".so"

shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)
Default(shlib)
SCON

echo "[5] Ensure Clipper2 include line matches repo layout"
if grep -q '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp 2>/dev/null; then
	sed -i '' 's|#include <clipper2/clipper.h>|#include <Clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp
fi

echo "[6] Ensure Godot 4.4 entry signature"
cat > clipper2_ext/src/register_types.cpp <<'EOF'
#include "clipper2_open.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
using namespace godot;

void initialize_clipper2_ext_module(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		ClassDB::register_class<Clipper2Open>();
	}
}
void uninitialize_clipper2_ext_module(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
	}
}
extern "C" {
GDExtensionBool GDE_EXPORT clipper2_ext_library_init(
	GDExtensionInterfaceGetProcAddress p_get_proc_address,
	GDExtensionClassLibraryPtr p_library,
	GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_clipper2_ext_module);
	init_obj.register_terminator(uninitialize_clipper2_ext_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
EOF

echo "[7] Build godot-cpp (debug + release)"
cd godot-cpp
scons platform=macos arch=arm64 target=template_debug -j8
scons platform=macos arch=arm64 target=template_release -j8
cd ..

echo "[8] Clean & build extension (debug + release)"
cd clipper2_ext
scons -c >/dev/null 2>&1 || true
scons platform=macos arch=arm64 target=template_debug -j8
scons platform=macos arch=arm64 target=template_release -j8
cd ..

echo "[9] List built files"
ls -l clipper2_ext/bin || true

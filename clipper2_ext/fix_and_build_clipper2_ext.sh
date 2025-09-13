#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Patch Clipper2 include to correct path"
if grep -q '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp 2>/dev/null; then
  sed -i '' 's|#include <clipper2/clipper.h>|#include <Clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp
fi

echo "[2/5] Patch SConstruct (include paths, godot-cpp lib name, set default target)"
python3 - <<'PY'
import io, os, re, sys
p = "clipper2_ext/SConstruct"
s = open(p,"r",encoding="utf-8").read()
s = s.replace(
    'os.path.join("thirdparty", "clipper2", "CPP"),',
    'os.path.join("thirdparty", "clipper2", "CPP"),\n\tos.path.join("thirdparty", "clipper2", "CPP", "Clipper2"),'
)
s = s.replace('libname = "godot-cpp." + platform + "." + arch + "." + target',
              'libname = "godot-cpp." + platform + "." + target + "." + arch')
if "Default(shlib)" not in s:
    s = s.replace(
        'env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)',
        'shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)\nDefault(shlib)'
    )
open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

echo "[3/5] Ensure register_types.cpp uses the 4.4 entry signature"
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
		// nothing
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

echo "[4/5] Build debug + release"
if ! command -v scons >/dev/null 2>&1; then
  echo "ERROR: scons not found. Install with: brew install scons" >&2
  exit 1
fi

# Build godot-cpp
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

# Clean and build the extension
( cd clipper2_ext && scons -c >/dev/null 2>&1 || true )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[5/5] List built files"
ls -l clipper2_ext/bin || true

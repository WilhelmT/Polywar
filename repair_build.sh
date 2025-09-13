#!/usr/bin/env bash
set -euo pipefail

echo "[0] Checking tools"
command -v scons >/dev/null || { echo "ERROR: scons not found. brew install scons"; exit 1; }
command -v git >/dev/null   || { echo "ERROR: git not found."; exit 1; }

echo "[1] Ensure Clipper2 is present (and correct path/case)"
if [ ! -f clipper2_ext/thirdparty/clipper2/CPP/Clipper2/clipper.h ]; then
	echo "  fetching Clipper2..."
	rm -rf clipper2_ext/thirdparty/clipper2
	git clone --depth 1 https://github.com/AngusJohnson/Clipper2.git clipper2_ext/thirdparty/clipper2
fi

echo "[2] Set correct include in C++"
# Use the header as shipped: CPP/Clipper2/clipper.h
if grep -q '#include <clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp 2>/dev/null; then
	sed -i '' 's|#include <clipper2/clipper.h>|#include <Clipper2/clipper.h>|' clipper2_ext/src/clipper2_open.cpp
fi
if ! grep -q '#include <Clipper2/clipper.h>' clipper2_ext/src/clipper2_open.cpp; then
	# Ensure it exists once
	sed -i '' '1s|^|#include <Clipper2/clipper.h>\n|' clipper2_ext/src/clipper2_open.cpp
fi

echo "[3] Patch SConstruct include paths & target defaults"
python3 - <<'PY'
import io, os
p = "clipper2_ext/SConstruct"
s = open(p,"r",encoding="utf-8").read()
# add both CPP and CPP/Clipper2 include dirs
if '("thirdparty", "clipper2", "CPP", "Clipper2")' not in s:
    s = s.replace(
        'os.path.join("thirdparty", "clipper2", "CPP"),',
        'os.path.join("thirdparty", "clipper2", "CPP"),\n\tos.path.join("thirdparty", "clipper2", "CPP", "Clipper2"),'
    )
# correct lib name order for godot-cpp
s = s.replace(
    'libname = "godot-cpp." + platform + "." + arch + "." + target',
    'libname = "godot-cpp." + platform + "." + target + "." + arch'
)
# make our shared library the default target
if "Default(shlib)" not in s:
    s = s.replace(
        'env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)',
        'shlib = env.SharedLibrary(target=os.path.join("bin", target_name), source=sources)\nDefault(shlib)'
    )
open(p,"w",encoding="utf-8").write(s)
print("Patched", p)
PY

echo "[4] Ensure register_types.cpp uses Godot 4.4 entry signature"
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

echo "[5] Build"
# build godot-cpp (debug+release)
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

# clean and build the extension (debug+release)
( cd clipper2_ext && scons -c >/dev/null 2>&1 || true )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[6] Results"
ls -l clipper2_ext/bin || true

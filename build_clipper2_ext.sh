#!/usr/bin/env bash
set -euo pipefail

echo "[check] scons:"
if ! command -v scons >/dev/null 2>&1; then
  echo "  scons not found. Install with: brew install scons"
  exit 1
fi

echo "[check] Xcode CLI tools:"
if ! command -v clang++ >/dev/null 2>&1; then
  echo "  clang++ not found. Installing Xcode Command Line Tools..."
  xcode-select --install || true
fi

echo "[info] uname -m:"
uname -m

echo "[step] Build godot-cpp (debug)"
( cd godot-cpp && scons platform=macos arch=arm64 target=template_debug -j8 )

echo "[step] Build godot-cpp (release)"
( cd godot-cpp && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[step] Build clipper2_ext (debug)"
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_debug -j8 )

echo "[step] Build clipper2_ext (release)"
( cd clipper2_ext && scons platform=macos arch=arm64 target=template_release -j8 )

echo "[done] Built files:"
ls -l clipper2_ext/bin || true
ls -l clipper2_ext/bin/libclipper2_ext.macos.arm64.template_debug.dylib || true
ls -l clipper2_ext/bin/libclipper2_ext.macos.arm64.template_release.dylib || true

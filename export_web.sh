#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${ROOT_DIR}/godot_web_game"
BUILD_DIR="${PROJECT_DIR}/build/web"
EXPORT_PRESET="Web"
GODOT_VERSION="${GODOT_VERSION:-4.6}"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
INSTALL_SCRIPT="${ROOT_DIR}/install_godot_export_templates.sh"

if [[ -x "${INSTALL_SCRIPT}" && "${SKIP_TEMPLATE_INSTALL:-0}" != "1" ]]; then
	echo "Ensuring Godot ${GODOT_VERSION} export templates are installed..."
	"${INSTALL_SCRIPT}" "${GODOT_VERSION}"
elif [[ ! -x "${INSTALL_SCRIPT}" && "${SKIP_TEMPLATE_INSTALL:-0}" != "1" ]]; then
	echo "Warning: install script not found at ${INSTALL_SCRIPT}, continuing without template check." >&2
fi

echo "Cleaning ${BUILD_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "Exporting preset \"${EXPORT_PRESET}\" using ${GODOT_BIN}"
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" --export-release "${EXPORT_PRESET}" "${BUILD_DIR}/index.html"

echo "Copying JavaScript feature files to build directory"
cp -r "${PROJECT_DIR}/js/" "${BUILD_DIR}/"

echo "Web build complete → ${BUILD_DIR}"

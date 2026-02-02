#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${1:-4.6}"
TEMPLATES_DIR="${HOME}/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"

if [[ -d "${TEMPLATES_DIR}" ]]; then
    echo "Export templates for Godot ${GODOT_VERSION} already installed."
    exit 0
fi

echo "Downloading Godot ${GODOT_VERSION} export templates..."
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
TMP_FILE="/tmp/godot_templates_${GODOT_VERSION}.tpz"

curl -L -o "${TMP_FILE}" "${DOWNLOAD_URL}"

echo "Installing templates to ${TEMPLATES_DIR}"
mkdir -p "${TEMPLATES_DIR}"
unzip -o "${TMP_FILE}" -d "/tmp/godot_templates_extract"
mv /tmp/godot_templates_extract/templates/* "${TEMPLATES_DIR}/"

rm -rf "${TMP_FILE}" /tmp/godot_templates_extract
echo "Export templates installed successfully."

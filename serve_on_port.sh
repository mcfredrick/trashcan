#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8080}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/godot_web_game/build/web"

if [[ ! -d "${BUILD_DIR}" ]]; then
    echo "Error: Build directory not found at ${BUILD_DIR}"
    echo "Run ./export_web.sh first to create the web build."
    exit 1
fi

echo "Serving DrumAlong at http://localhost:${PORT}"
echo "Press Ctrl+C to stop"

cd "${BUILD_DIR}"

# Use Python with custom headers for SharedArrayBuffer support
python3 -c "
import http.server
import socketserver

PORT = ${PORT}

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required headers for Godot 4 web export (SharedArrayBuffer)
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def log_message(self, format, *args):
        print(f'[{self.log_date_time_string()}] {format % args}')

with socketserver.TCPServer(('', PORT), CORSRequestHandler) as httpd:
    print(f'Server running at http://localhost:{PORT}')
    print('Required headers enabled: Cross-Origin-Opener-Policy, Cross-Origin-Embedder-Policy')
    httpd.serve_forever()
"

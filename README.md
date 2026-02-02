# DrumAlong

A rhythm game-style drum practice app where users upload audio files, the app transcribes drum hits via client-side onset detection, and users play along on their electronic drum set with accuracy scoring.

## Features

- **Audio Upload**: Support for MP3, M4A, WAV, OGG, FLAC (max 15MB)
- **Client-side Analysis**: Energy-based onset detection with frequency band analysis for drum classification
- **6-Lane Display**: Kick, Snare, Hi-Hat, Tom, Crash, Ride
- **Web MIDI Support**: Connect your electronic drum kit (Chrome required)
- **Keyboard Fallback**: A=kick, S=snare, D=hi-hat, F=tom, J=crash, K=ride
- **Scoring System**: Perfect/Great/Good/Miss timing windows with combo multiplier
- **Persistence**: Songs saved locally via IndexedDB
- **Latency Calibration**: Built-in wizard to compensate for audio/input latency

## Prerequisites

- [Godot Engine 4.6](https://godotengine.org/download)
- Git
- Modern web browser (Chrome recommended for Web MIDI support)

## Development

### Local Development

1. **Open in Godot**
   ```bash
   # Open the project
   godot --path godot_web_game
   ```

2. **Export for Web**
   ```bash
   ./export_web.sh
   ```

3. **Run locally**
   ```bash
   ./serve_on_port.sh 8080
   # Open http://localhost:8080
   ```

### Project Structure

```
drumalong/
├── godot_web_game/
│   ├── project.godot
│   ├── scenes/
│   │   ├── Main.tscn          # Main menu
│   │   ├── song_library.tscn  # Song upload & selection
│   │   ├── gameplay.tscn      # 6-lane rhythm game
│   │   ├── results.tscn       # Score breakdown
│   │   └── calibration.tscn   # Latency wizard
│   ├── scripts/autoload/
│   │   ├── game_state.gd      # Global state
│   │   ├── audio_manager.gd   # Audio playback
│   │   └── midi_input.gd      # MIDI handling
│   └── js/
│       ├── file_upload.js     # HTML5 File API
│       ├── onset_detection.js # Drum hit detection
│       ├── song_db.js         # IndexedDB storage
│       └── midi_bridge.js     # Web MIDI API
├── export_web.sh
├── serve_on_port.sh
└── install_godot_export_templates.sh
```

## Deployment

Push to `main` to automatically deploy to GitHub Pages via GitHub Actions.

## Technical Notes

- **No server-side processing**: All audio analysis runs in the browser
- **Original audio playback**: Users play along to the original song (no drum isolation)
- **General MIDI mapping**: Standard drum note mappings, configurable per device

## License

MIT License

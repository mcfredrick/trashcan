# DrumAlong - Claude Code Instructions

## Quick Context

This is a **Godot 4.6 web game** - a rhythm game for drum practice. Users upload audio files, the app detects drum hits client-side, and users play along with their electronic drum kit.

**Full documentation:** See `docs/AI_ASSISTANT_GUIDE.md` for comprehensive details.

## Project Structure

```
drumalong/
├── godot_web_game/           # Main Godot project
│   ├── scenes/               # .tscn (scenes) and .gd (scripts)
│   ├── scripts/autoload/     # Global singletons
│   ├── js/                   # JavaScript bridges for web APIs
│   └── build/web/            # Exported web build
├── docs/                     # Documentation
├── export_web.sh             # Build script
└── serve_on_port.sh          # Dev server
```

## Key Commands

```bash
# Build web export
./export_web.sh

# Run local server (required for COOP/COEP headers)
./serve_on_port.sh
# Then visit http://localhost:8080
```

## Technology Notes

- **GDScript** for game logic (`.gd` files)
- **JavaScript** for web APIs (audio, MIDI, IndexedDB)
- **Godot scenes** are `.tscn` files (text-based, editable)
- Communication between Godot and JS uses `JavaScriptBridge`

## Common Tasks

| Task | Key Files |
|------|-----------|
| Modify gameplay | `scenes/gameplay.gd`, `scenes/gameplay.tscn` |
| Change audio processing | `js/onset_detection.js`, `js/file_upload.js` |
| Modify MIDI mapping | `scripts/autoload/midi_input.gd`, `js/midi_bridge.js` |
| Change scoring/timing | `scenes/gameplay.gd` (search for TIMING) |
| Modify persistence | `js/song_db.js`, `scenes/song_library.gd` |
| Update audio playback | `scripts/autoload/audio_manager.gd` |

## Important Patterns

### Godot-JavaScript Bridge
```gdscript
# Call JS from GDScript
JavaScriptBridge.eval("window.drumalong.someFunction();")

# Receive callbacks from JS
var _callback = JavaScriptBridge.create_callback(_on_result)
JavaScriptBridge.get_interface("window").my_callback = _callback
```

### Scene Structure
Each scene (`.tscn`) has a corresponding script (`.gd`):
- `Main.tscn` + `Main.gd` - Main menu
- `song_library.tscn` + `song_library.gd` - Upload/manage songs
- `gameplay.tscn` + `gameplay.gd` - Core game loop
- `results.tscn` + `results.gd` - Score display

### Autoloads (Global Singletons)
Defined in `project.godot`, available everywhere:
- `GameState` - Current song, last results
- `AudioManager` - Audio playback abstraction
- `MidiInput` - MIDI drum input handling

## Web Export Requirements

1. **Custom HTML shell** - `custom_shell.html` includes JS files before Godot loads
2. **COOP/COEP headers** - Required for SharedArrayBuffer; `serve_on_port.sh` handles this
3. **Export templates** - Run `./install_godot_export_templates.sh` if missing

## Current Status

MVP complete with these enhancement features:
- Count-in metronome at detected song tempo
- Timeline seeking (clickable progress bar) and restart
- Tempo adjustment (0.25x to 2.0x playback speed)

See `docs/AI_ASSISTANT_GUIDE.md` for full roadmap and technical details.

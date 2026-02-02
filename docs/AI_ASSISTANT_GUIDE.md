# DrumAlong - AI Assistant Implementation Guide

This document provides comprehensive context for AI coding assistants working on this project.

## Project Overview

**DrumAlong** is a rhythm game-style drum practice application where users:
1. Upload audio files (MP3, OGG, WAV, M4A, FLAC)
2. The app automatically detects drum hits via client-side onset detection
3. Users play along on their electronic drum kit with real-time accuracy scoring

**Current Status:** MVP Complete with enhancement features implemented

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Game Engine | Godot 4.6 (web export) | Core application framework |
| Audio Processing | Web Audio API | Decode and play audio in browser |
| Onset Detection | Custom JavaScript | Energy-based drum hit detection |
| Drum Classification | FFT frequency analysis | Classify hits into 6 drum types |
| MIDI Input | Web MIDI API | Electronic drum kit input |
| Persistence | IndexedDB | Store analyzed songs locally |
| UI Framework | Godot Control nodes | Lane-based rhythm game display |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT ONLY (Godot 4 Web)                     │
├─────────────────────────────────────────────────────────────────┤
│  HTML5 File Upload (file_upload.js)                              │
│       │                                                          │
│       ▼                                                          │
│  Audio Decoder (Web Audio API)                                   │
│       │                                                          │
│       ▼                                                          │
│  Onset Detection (onset_detection.js)                            │
│  - Energy-based peak detection                                   │
│  - FFT frequency band analysis for drum classification           │
│  - Tempo estimation from inter-onset intervals                   │
│       │                                                          │
│       ▼                                                          │
│  IndexedDB Storage (song_db.js)                                  │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Gameplay Loop (gameplay.gd)                                 │ │
│  │  - Audio playback (original song via AudioManager)           │ │
│  │  - 6-lane note highway display                               │ │
│  │  - MIDI input from drum kit (midi_bridge.js → MidiInput.gd)  │ │
│  │  - Timing-based scoring engine                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Key Architecture Decision: No Server-Side Processing

**All audio analysis runs client-side in the browser.**

**Trade-off:** We skip drum track isolation for MVP. Users play along to the **original song audio** (not isolated drums). This matches how most people practice and avoids server infrastructure complexity.

## File Structure

```
drumalong/
├── docs/
│   └── AI_ASSISTANT_GUIDE.md          # This file
├── godot_web_game/
│   ├── project.godot                   # Godot project configuration
│   ├── export_presets.cfg              # Web export settings
│   ├── custom_shell.html               # Custom HTML template for web export
│   ├── scenes/
│   │   ├── Main.tscn / Main.gd         # Main menu
│   │   ├── song_library.tscn / .gd     # Song upload and list management
│   │   ├── gameplay.tscn / .gd         # Core rhythm game loop
│   │   ├── results.tscn / .gd          # Score breakdown screen
│   │   └── calibration.tscn / .gd      # Latency calibration wizard
│   ├── scripts/autoload/
│   │   ├── game_state.gd               # Global state (current song, results)
│   │   ├── audio_manager.gd            # Audio playback abstraction
│   │   └── midi_input.gd               # MIDI input handling
│   ├── js/
│   │   ├── file_upload.js              # HTML5 File API wrapper
│   │   ├── onset_detection.js          # Drum hit detection + tempo estimation
│   │   ├── song_db.js                  # IndexedDB operations
│   │   └── midi_bridge.js              # Web MIDI API bridge
│   └── build/web/                      # Exported web build
├── export_web.sh                       # Build script
├── serve_on_port.sh                    # Local dev server with COOP/COEP headers
├── install_godot_export_templates.sh   # Setup script
├── .github/workflows/deploy.yml        # GitHub Pages deployment
└── README.md                           # Project readme
```

## Implemented Features

### Core MVP
- [x] File upload (MP3, WAV, OGG, M4A, FLAC)
- [x] Client-side onset detection with energy-based algorithm
- [x] Full drum kit classification (8 lanes: kick, snare, hi-hat, high tom, mid tom, floor tom, crash, ride)
- [x] Rhythm game lane display with scrolling notes
- [x] Audio playback synced with note display
- [x] Web MIDI input from electronic drums
- [x] Keyboard fallback input (A=kick, S=snare, D=hi-hat, F=high tom, G=mid tom, H=floor tom, J=crash, K=ride)
- [x] Timing-based scoring (Perfect/Great/Good/Miss)
- [x] Combo system with multiplier
- [x] Results screen with accuracy breakdown
- [x] Latency calibration wizard
- [x] IndexedDB persistence for analyzed songs

### Enhancement Features
- [x] **Count-in metronome** - Tempo-synced countdown at detected BPM
- [x] **Timeline seeking** - Click progress bar to seek, restart button
- [x] **Tempo adjustment** - Speed up/slow down playback (0.25x to 2.0x)

## Technical Details

### Onset Detection Algorithm (onset_detection.js)

The algorithm uses energy-based peak detection:

```javascript
// Key parameters
const frameSize = 512;    // ~23ms at 22050Hz sample rate
const hopSize = 256;      // 50% overlap
const minOnsetGap = 50;   // Minimum ms between detected onsets

// Process:
// 1. Compute RMS energy per frame
// 2. Adaptive threshold = 1.5x median of recent 50 frames + 0.01
// 3. Peak detection: energy > threshold AND energy > prevEnergy * 1.2
// 4. Classify drum type using FFT frequency band analysis
```

### Drum Classification Frequency Bands

```javascript
const DRUM_BANDS = {
    kick:      { low: 20,   high: 100 },    // Deep bass
    snare:     { low: 150,  high: 400 },    // Mid frequencies
    hihat:     { low: 6000, high: 12000 },  // Very high frequencies
    high_tom:  { low: 200,  high: 500 },    // Higher tom frequencies
    mid_tom:   { low: 120,  high: 350 },    // Mid tom frequencies
    floor_tom: { low: 80,   high: 250 },    // Lower tom frequencies
    crash:     { low: 3000, high: 8000 },   // High frequencies, wide spread
    ride:      { low: 4000, high: 10000 }   // Sustained high-mid
};
```

### Timing Windows (gameplay.gd)

```gdscript
# Timing accuracy thresholds
Perfect: ±25ms  → 100 points
Great:   ±50ms  → 75 points
Good:    ±100ms → 50 points
Miss:    >150ms → 0 points, breaks combo
```

### MIDI Drum Mapping (midi_input.gd)

Uses General MIDI drum standard (8 lanes):
```gdscript
# Note → Lane mapping
36 (Kick) → Lane 0
38, 40 (Snare) → Lane 1
42, 44, 46 (Hi-Hat) → Lane 2
48, 50 (High Tom) → Lane 3
45, 47 (Mid Tom) → Lane 4
41, 43 (Floor Tom) → Lane 5
49, 52, 55, 57 (Crash) → Lane 6
51, 53, 59 (Ride) → Lane 7
```

### Web Audio Playback (audio_manager.gd)

The AudioManager provides abstraction over web and native audio:
- **Web:** Uses Web Audio API via JavaScriptBridge
- **Native:** Uses Godot's AudioStreamPlayer

Key features:
- Playback position tracking
- Seeking to arbitrary positions
- Playback rate adjustment (0.25x to 2.0x)
- Pause/resume functionality

### Godot-JavaScript Communication

Communication uses JavaScriptBridge:
```gdscript
# Calling JavaScript from GDScript
JavaScriptBridge.eval("window.drumalong.someFunction();")

# JavaScript calling back to Godot
_js_callback = JavaScriptBridge.create_callback(_on_callback)
JavaScriptBridge.get_interface("window").drumalong_godot_callback = _js_callback
```

## Important Decisions Made

### 1. Client-Side Only Processing
**Decision:** No server-side GPU processing for audio analysis.
**Rationale:** Simplifies deployment, avoids infrastructure costs, works offline.
**Trade-off:** No drum track isolation - users hear the full mix.

### 2. Custom HTML Shell Required
**Decision:** Use custom_shell.html instead of default Godot template.
**Rationale:** Need to include JS files before Godot engine loads so `window.drumalong` is available.
**Location:** `godot_web_game/custom_shell.html`

### 3. Cross-Origin Isolation Headers
**Decision:** Serve with COOP/COEP headers for SharedArrayBuffer support.
**Rationale:** Required for Web Audio API threading.
**Implementation:** `serve_on_port.sh` uses Python server with custom headers.

### 4. Energy-Based Detection Over ML
**Decision:** Use simple energy-based onset detection, not ML models.
**Rationale:** Faster, no model loading, works for MVP.
**Upgrade Path:** Can integrate Aubio.js or ML classifier if accuracy insufficient.

### 5. Six-Lane Full Kit
**Decision:** Support full drum kit (6 lanes) rather than simplified 2-3 lane mode.
**Rationale:** More authentic drumming experience.
**Challenge:** Classification accuracy varies; consider fallback to simplified mode.

### 6. Original Audio Playback
**Decision:** Play original song audio, not isolated drum track.
**Rationale:** Drum isolation requires server-side ML processing.
**User Impact:** Acceptable - matches how drummers typically practice.

## Known Limitations

1. **Drum classification accuracy** - FFT-based classification is imperfect; some hits may be misclassified
2. **No audio waveform display** - Progress bar is simple, no visual waveform
3. **Web MIDI browser support** - Primarily Chrome; Firefox/Safari have limited support
4. **Large file handling** - No explicit size limit but very large files may cause issues
5. **Tempo detection** - Works best with consistent tempos; may struggle with tempo changes

## Roadmap / Future Features

### Post-MVP Enhancements
- [ ] Server-side drum isolation (Demucs/Spleeter integration)
- [ ] YouTube URL input (extract and analyze audio)
- [ ] Spotify integration
- [ ] Traditional sheet music notation view
- [ ] User accounts and cloud sync
- [ ] Practice mode with section looping
- [ ] Difficulty levels (filter out quiet hits)
- [ ] Custom drum kit mapping configuration
- [ ] iOS/Android native apps

### Technical Improvements
- [ ] Upgrade to Aubio.js for better onset detection
- [ ] ML-based drum classification model
- [ ] Audio waveform visualization
- [ ] Offline PWA support
- [ ] Better mobile/touch support

## Development Setup

### Prerequisites
- Godot 4.6+ with web export templates
- Modern web browser (Chrome recommended for Web MIDI)

### Build Commands
```bash
# Install export templates (first time only)
./install_godot_export_templates.sh

# Build web export
./export_web.sh

# Run local dev server
./serve_on_port.sh
# Visit http://localhost:8080
```

### Key Files to Modify

| Task | Files |
|------|-------|
| Change onset detection | `js/onset_detection.js` |
| Modify gameplay mechanics | `scenes/gameplay.gd` |
| Add new audio formats | `js/file_upload.js`, `scenes/song_library.gd` |
| Change MIDI mapping | `scripts/autoload/midi_input.gd`, `js/midi_bridge.js` |
| Modify scoring | `scenes/gameplay.gd` (timing windows, points) |
| Add UI elements | Relevant `.tscn` and `.gd` files |
| Change persistence | `js/song_db.js`, `scenes/song_library.gd` |

## Testing

### Manual Testing Checklist
1. Upload various audio formats (MP3, OGG, WAV, M4A)
2. Verify onset detection produces reasonable results
3. Connect MIDI drum kit, verify hits register correctly
4. Test keyboard fallback (A, S, D, F, G, H keys)
5. Verify timing accuracy with metronome test
6. Test seek functionality (click progress bar)
7. Test restart button
8. Test tempo adjustment buttons
9. Verify results screen shows accurate statistics
10. Test song persistence (refresh page, songs should remain)

### Browser Compatibility
- **Chrome:** Full support (recommended)
- **Firefox:** Works but Web MIDI may require flags
- **Safari:** Limited Web MIDI support
- **Edge:** Should work (Chromium-based)

## Deployment

The project uses GitHub Actions for deployment to GitHub Pages:
- Push to `master` branch triggers deployment
- Workflow: `.github/workflows/deploy.yml`
- Deployed to: GitHub Pages (configure in repo settings)

---

*Last updated: February 2026*
*Project repository: github.com/mcfredrick/trashcan*

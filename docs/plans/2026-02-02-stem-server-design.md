# Stem Separation Server Design

**Date:** 2026-02-02
**Status:** Approved

## Overview

A Dockerized server that uses Spleeter to isolate drum stems from uploaded audio, then runs onset detection on the isolated drums for more accurate transcription. Results are cached by audio hash to avoid reprocessing.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Godot Web Client                             │
│  1. User uploads audio file                                      │
│  2. Connect WebSocket for progress                               │
│  3. Receive: drum audio URL, MIDI data, onset JSON               │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTP POST + WebSocket
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Docker Container                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   FastAPI   │  │   Spleeter  │  │  Onset Detection        │  │
│  │  + WebSocket│  │   (2-stem)  │  │  (Python port of JS)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────┐  ┌─────────────────────────────────────────┐   │
│  │   SQLite    │  │  Volume: /data                          │   │
│  │  (metadata) │  │  - /originals/{hash}.{ext}              │   │
│  │             │  │  - /drums/{hash}.wav                    │   │
│  │             │  │  - /midi/{hash}.mid                     │   │
│  └─────────────┘  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Decisions

| Component | Decision | Rationale |
|-----------|----------|-----------|
| Stem separation | Spleeter (2-stem) | Proven, fast, isolates drums well |
| Onset detection | Python port of current JS | Consistency with client-side fallback |
| Database | SQLite | Simple, portable, no extra container |
| API framework | FastAPI | Async, WebSocket support, auto-docs |
| File storage | Docker volume | Simple, persistent, easy to inspect |
| Audio hashing | SHA256 of PCM samples | Same song in different formats matches |
| Progress updates | WebSocket (polling fallback) | Real-time UX without complexity |

## API Endpoints

```
POST /api/v1/process
  - Accepts: multipart/form-data with audio file
  - Returns: { job_id, websocket_url }
  - If cached: { job_id, status: "complete", results: {...} }

GET /api/v1/status/{job_id}
  - Polling fallback
  - Returns: { status, progress_percent, results? }

WebSocket /api/v1/ws/{job_id}
  - Pushes: { stage, progress, message }
  - Stages: "hashing", "separating", "transcribing", "saving", "complete"

GET /api/v1/files/drums/{hash}.wav
  - Serves isolated drum audio

GET /api/v1/files/midi/{hash}.mid
  - Serves MIDI transcription

GET /api/v1/songs
  - Lists all processed songs

DELETE /api/v1/songs/{hash}
  - Removes cached song and files

GET /health
  - Health check for client startup
```

## Database Schema

```sql
CREATE TABLE schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE songs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audio_hash TEXT UNIQUE NOT NULL,
    original_filename TEXT,
    original_format TEXT,
    duration_seconds REAL,
    sample_rate INTEGER,
    bpm REAL,
    onset_count INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_time_seconds REAL
);

CREATE TABLE jobs (
    id TEXT PRIMARY KEY,
    audio_hash TEXT,
    status TEXT DEFAULT 'pending',
    stage TEXT,
    progress INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (audio_hash) REFERENCES songs(audio_hash)
);
```

## File Storage

| Path | Contents |
|------|----------|
| `/data/originals/{hash}.{ext}` | Original uploaded audio |
| `/data/drums/{hash}.wav` | Isolated drum stem |
| `/data/midi/{hash}.mid` | MIDI transcription |
| `/data/onsets/{hash}.json` | Raw onset data (times, lanes, confidence) |

## Lane Structure (8 Lanes)

The game uses 8 lanes to represent a full drum kit with separate toms:

| Lane | Type | Keyboard | MIDI Notes |
|------|------|----------|------------|
| 0 | Kick | A | 36 |
| 1 | Snare | S | 38, 40 |
| 2 | Hi-Hat | D | 42, 44, 46 |
| 3 | High Tom | F | 48, 50 |
| 4 | Mid Tom | G | 45, 47 |
| 5 | Floor Tom | H | 41, 43 |
| 6 | Crash | J | 49, 52, 55, 57 |
| 7 | Ride | K | 51, 53, 59 |

## Onset Data Structure

```json
{
  "time": 1.5,
  "lane": 5,
  "type": "floor_tom",
  "confidence": 0.85
}
```

## Processing Pipeline

```python
async def process_audio(file_path: str, job_id: str, ws_manager):
    # 1. Hash audio samples (0-10%)
    await ws_manager.send(job_id, stage="hashing", progress=0)
    audio_hash = await hash_audio_samples(file_path)

    # 2. Check cache
    existing = db.get_song_by_hash(audio_hash)
    if existing:
        await ws_manager.send(job_id, stage="complete", cached=True)
        return existing

    # 3. Spleeter stem separation (10-70%)
    await ws_manager.send(job_id, stage="separating", progress=10)
    drum_path = await run_spleeter(file_path, audio_hash)

    # 4. Onset detection on drum stem (70-90%)
    await ws_manager.send(job_id, stage="transcribing", progress=70)
    onsets, bpm = await detect_onsets(drum_path)

    # 5. Generate MIDI from onsets (90-95%)
    await ws_manager.send(job_id, stage="saving", progress=90)
    midi_path = generate_midi(onsets, bpm, audio_hash)

    # 6. Save to database (95-100%)
    db.save_song(audio_hash, metadata, onsets)
    await ws_manager.send(job_id, stage="complete", progress=100)
```

## Project Structure

```
server/
├── Dockerfile
├── docker-compose.yml
├── pyproject.toml
├── README.md
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models.py
│   ├── websocket.py
│   └── processing/
│       ├── __init__.py
│       ├── hasher.py
│       ├── separator.py
│       ├── onset_detection.py
│       └── midi_writer.py
├── migrations/
│   ├── __init__.py
│   ├── runner.py
│   └── 001_initial.sql
├── tests/
│   ├── conftest.py
│   ├── test_onset_detection.py
│   ├── test_api.py
│   └── fixtures/
└── scripts/
    └── generate_test_fixtures.py
```

## Schema Migrations

Migrations are versioned SQL files that run automatically on startup.

**Adding a migration:**

1. Create `migrations/NNN_description.sql` (next number in sequence)
2. Write SQL statements
3. End with: `INSERT INTO schema_version (version) VALUES (NNN);`
4. Migrations run automatically on server startup

## Environment Configuration

**Automatic detection:**
- `localhost` / `127.0.0.1` → Uses `http://localhost:8000`
- GitHub Pages → Uses URL from `STEM_SERVER_URL` secret

**Setting up GitHub secrets:**

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `STEM_SERVER_URL`
5. Value: Your server's public URL (e.g., `https://drums.yourserver.com`)
6. Click "Add secret"

The deployment workflow automatically substitutes this value at build time.

## Python Code Standards

**Required tools:**
- `black` - Code formatting
- `isort` - Import sorting
- `pylint` - Linting
- `mypy` - Type checking (strict mode)
- `bandit` - Security scanning
- `pytest` - Testing

**Pydantic required** for all API models and data validation.

## Testing Strategy

**Ground truth testing for onset detection:**

1. Create MIDI file with known drum pattern
2. Render to WAV using FluidSynth + drum soundfont
3. Run onset detection on WAV
4. Verify detected onsets match MIDI within ±25ms tolerance

```python
def test_onset_detection_accuracy():
    expected_onsets = load_ground_truth("fixtures/test_pattern_onsets.json")
    detected = detect_onsets("fixtures/test_pattern.wav")

    tolerance_sec = 0.025
    for expected in expected_onsets:
        match = find_closest(detected, expected["time"])
        assert abs(match["time"] - expected["time"]) < tolerance_sec
        assert match["lane"] == expected["lane"]
```

## Docker Configuration

```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Pre-download Spleeter model
RUN python -c "from spleeter.separator import Separator; Separator('spleeter:2stems')"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
services:
  drumalong-server:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - drumalong-data:/data
      - ./db:/db
    environment:
      - DATA_DIR=/data
      - DB_PATH=/db/drumalong.db

volumes:
  drumalong-data:
```

## Client Integration

The Godot client auto-detects environment and falls back gracefully:

```gdscript
func _ready():
    var config = JavaScriptBridge.eval("window.DRUMALONG_CONFIG")
    print("[StemServer] Environment: ", config.environment)
    print("[StemServer] Server URL: ", config.stemServerUrl)

    if _is_server_configured(config):
        _check_server_health(config.stemServerUrl)
    else:
        print("[StemServer] No server - using client-side detection")
```

If the server is unavailable, the client uses the existing client-side onset detection as a fallback.

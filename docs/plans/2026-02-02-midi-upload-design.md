# MIDI Upload Feature Design

**Date:** 2026-02-02
**Status:** Approved

## Overview

Allow users to upload a MIDI file alongside their audio to get precise onset data instead of energy-based detection.

## User Flow

1. User uploads audio file (existing flow, unchanged)
2. Song appears in library with "Add MIDI" button
3. User clicks "Add MIDI", selects MIDI file
4. MIDI is parsed, drum notes extracted and converted to onsets
5. Song's onsets are replaced with MIDI-derived data
6. UI shows indicator that song has user-provided MIDI

## Data Model

One new field added to song records in IndexedDB:

```javascript
{
  // Existing fields unchanged
  id, name, duration, sampleRate, bpm, onsets, createdAt,

  // New field
  midiSource: "user"  // or null/undefined if using detected onsets
}
```

The `onsets` array format is identical whether from detection or MIDI.

## MIDI Parsing

**Supported extensions:** `.mid`, `.midi`, `.smf`, `.kar`

**Process:**
1. Parse MIDI header - format type, track count, PPQ (ticks per quarter note)
2. Find tempo - Set Tempo meta-events (FF 51 03), default 120 BPM
3. Extract Note On events from all tracks (velocity > 0)
4. Filter to drum notes using existing MIDI note mapping
5. Convert tick timing to seconds

**Drum Note Mapping:**

| MIDI Notes | Lane | Type |
|------------|------|------|
| 36 | 0 | kick |
| 38, 40 | 1 | snare |
| 42, 44, 46 | 2 | hihat |
| 48, 50 | 3 | high_tom |
| 45, 47 | 4 | mid_tom |
| 41, 43 | 5 | floor_tom |
| 49, 52, 55, 57 | 6 | crash |
| 51, 53, 59 | 7 | ride |

**Output format:**
```javascript
{ time: 1.5, lane: 1, type: "snare", energy: 1.0 }
```

## Error Handling

If MIDI file contains no recognizable drum notes:
- Show warning: "No drum notes found in MIDI file"
- Keep existing detected onsets unchanged

## Implementation Touchpoints

**Create:**
- `js/midi_parser.js` - MIDI file parsing and onset extraction

**Modify:**
- `js/file_upload.js` - Add `triggerMidiUpload(songId)` function
- `js/song_db.js` - Add `updateSongOnsets(songId, onsets, midiSource)` function
- `scenes/song_library.gd` - Add MIDI button per song, handle callback
- `custom_shell.html` - Include new JS file

**No changes:**
- `gameplay.gd` - onset format unchanged
- `midi_bridge.js` - only for live MIDI input
- `onset_detection.js` - still used for audio-only uploads

# 8-Lane Tom Expansion Design

**Date:** 2026-02-02
**Status:** Approved, ready for implementation

## Overview

Expand from 6 lanes to 8 lanes by splitting the single "Tom" lane into three separate lanes: High Tom, Mid Tom, and Floor Tom.

## Lane Structure

### Before (6 lanes)
| Lane | Drum | Keyboard |
|------|------|----------|
| 0 | Kick | A |
| 1 | Snare | S |
| 2 | Hi-Hat | D |
| 3 | Tom (all) | F |
| 4 | Crash | G |
| 5 | Ride | H |

### After (8 lanes)
| Lane | Drum | Keyboard | Color |
|------|------|----------|-------|
| 0 | Kick | A | Red |
| 1 | Snare | S | Yellow |
| 2 | Hi-Hat | D | Green |
| 3 | High Tom | F | Blue |
| 4 | Mid Tom | G | Cyan |
| 5 | Floor Tom | H | Indigo |
| 6 | Crash | J | Orange |
| 7 | Ride | K | Purple |

## Files to Modify

### 1. gameplay.gd

Update lane constants:

```gdscript
const LANE_NAMES = ["Kick", "Snare", "Hi-Hat", "High Tom", "Mid Tom", "Floor Tom", "Crash", "Ride"]
const LANE_COLORS = [
    Color(0.8, 0.2, 0.2),  # Kick - Red
    Color(0.9, 0.9, 0.2),  # Snare - Yellow
    Color(0.2, 0.8, 0.2),  # Hi-Hat - Green
    Color(0.2, 0.6, 0.9),  # High Tom - Blue
    Color(0.2, 0.8, 0.8),  # Mid Tom - Cyan
    Color(0.4, 0.4, 0.9),  # Floor Tom - Indigo
    Color(0.9, 0.5, 0.1),  # Crash - Orange
    Color(0.7, 0.3, 0.9),  # Ride - Purple
]
```

Update `_setup_lanes()` loop: `range(6)` → `range(8)`

Update `_check_input()` loop: `range(6)` → `range(8)`

### 2. midi_input.gd

Update MIDI note mapping:

```gdscript
const MIDI_TO_LANE = {
    # Kick
    36: 0,
    # Snare
    38: 1, 40: 1,
    # Hi-Hat
    42: 2, 44: 2, 46: 2,
    # High Tom
    48: 3, 50: 3,
    # Mid Tom
    45: 4, 47: 4,
    # Floor Tom
    41: 5, 43: 5,
    # Crash
    49: 6, 52: 6, 55: 6, 57: 6,
    # Ride
    51: 7, 53: 7, 59: 7
}
```

### 3. js/onset_detection.js

Update frequency bands for drum classification:

```javascript
const DRUM_BANDS = {
    kick:      { low: 20,   high: 100,  lane: 0 },
    snare:     { low: 150,  high: 400,  lane: 1 },
    hihat:     { low: 6000, high: 12000, lane: 2 },
    high_tom:  { low: 200,  high: 500,  lane: 3 },
    mid_tom:   { low: 120,  high: 350,  lane: 4 },
    floor_tom: { low: 80,   high: 250,  lane: 5 },
    crash:     { low: 3000, high: 8000, lane: 6 },
    ride:      { low: 4000, high: 10000, lane: 7 }
};
```

Update `classifyDrumHit()` function to distinguish between tom types based on frequency.

### 4. project.godot

Add new input actions:

```ini
[input]
drum_kick={ ... key: A }
drum_snare={ ... key: S }
drum_hihat={ ... key: D }
drum_hightom={ ... key: F }
drum_midtom={ ... key: G }
drum_floortom={ ... key: H }
drum_crash={ ... key: J }
drum_ride={ ... key: K }
```

### 5. js/midi_bridge.js

No changes needed - passes raw MIDI notes to Godot.

### 6. song_library.gd

Update `_generate_placeholder_onsets()` to use 8 lanes instead of 6.

## Testing Checklist

- [ ] All 8 lanes render correctly in gameplay view
- [ ] Keyboard input works for all 8 keys (A-K)
- [ ] MIDI input correctly maps to all 8 lanes
- [ ] Onset detection classifies toms into correct lanes
- [ ] Demo mode generates notes for all 8 lanes
- [ ] Existing saved songs still work (may show all toms in one lane)
- [ ] Results screen displays correctly

## Migration Notes

Existing songs in IndexedDB have `lane: 3` for all toms. Options:
1. **Accept it** - Old songs show all toms in High Tom lane (lane 3)
2. **Re-analyze** - Prompt user to re-upload for better classification
3. **Auto-migrate** - Not feasible without re-analyzing audio

Recommendation: Accept it for now. When stem server is ready, users can re-process songs for accurate tom classification.

## Implementation Order

1. Update `project.godot` with new input actions
2. Update `gameplay.gd` lane constants and loops
3. Update `midi_input.gd` MIDI mapping
4. Update `onset_detection.js` frequency bands and classification
5. Update `song_library.gd` placeholder generation
6. Test all inputs (keyboard + MIDI)
7. Build and verify web export

# Future Features

This document tracks feature ideas for future development.

## Planned / In Design

### Stem Separation Server
**Status:** Design complete, **implement next**

Server-side drum stem isolation using Spleeter for improved onset detection accuracy. See [design document](plans/2026-02-02-stem-server-design.md).

---

## Feature Ideas

### Gameplay Enhancements

- [ ] **Practice mode with section looping** - Select a section of the song to repeat
- [ ] **Difficulty levels** - Filter out quieter hits for easier modes
- [ ] **Visual drum kit display** - Show which drum is being hit in real-time
- [ ] **Audio waveform visualization** - Display waveform in progress bar

### Input & Configuration

- [ ] **Configurable keyboard mapping** - Let users customize which keys map to which drums
- [ ] **Custom MIDI mapping** - Configure which MIDI notes map to which lanes
- [ ] **Touch/mobile support** - On-screen drum pads for mobile devices

### Audio & Analysis

- [ ] **ML-based drum transcription** - Replace frequency-band classification with a proper ML model (e.g., Magenta's Onsets and Frames, or a custom CNN) running on the stem server. Current FFT-based approach is unreliable for distinguishing kick vs floor tom, etc.
- [ ] **Madmom integration** - ML-based onset detection for better accuracy
- [ ] **YouTube URL input** - Extract and analyze audio from YouTube videos
- [ ] **Spotify integration** - Import songs from Spotify
- [ ] **Multiple difficulty tracks** - Generate easy/medium/hard note charts from same audio

### Social & Cloud

- [ ] **User accounts** - Save progress across devices
- [ ] **Cloud sync** - Sync analyzed songs between devices
- [ ] **Leaderboards** - Compare scores with other players
- [ ] **Share charts** - Export/import onset data for songs

### Platform Expansion

- [ ] **iOS native app** - Native iOS build
- [ ] **Android native app** - Native Android build
- [ ] **Offline PWA support** - Full offline functionality as Progressive Web App

### Notation & Learning

- [ ] **Traditional sheet music view** - Display drum notation instead of lanes
- [ ] **Lesson mode** - Guided tutorials for learning drum patterns
- [ ] **Pattern library** - Common drum patterns to practice

---

## Completed Features

- [x] **8-lane tom expansion** - Separate lanes for High Tom, Mid Tom, and Floor Tom (8 total lanes)
- [x] **Count-in metronome** - Tempo-synced countdown before song starts
- [x] **Timeline seeking** - Click progress bar to seek, restart button
- [x] **Tempo adjustment** - Playback speed from 0.25x to 2.0x
- [x] **Keyboard fallback input** - A=Kick, S=Snare, D=Hi-Hat, F=High Tom, G=Mid Tom, H=Floor Tom, J=Crash, K=Ride
- [x] **IndexedDB persistence** - Songs saved locally for replay without re-upload

---

## How to Add Ideas

Add new feature ideas under the appropriate category with:
- `[ ]` checkbox prefix
- **Bold title**
- Brief description

Move to "Completed Features" with `[x]` when implemented.

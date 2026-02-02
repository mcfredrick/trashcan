/**
 * DrumAlong MIDI File Parser
 * Parses Standard MIDI Files and extracts drum onsets
 */

(function() {
    'use strict';

    // Reuse drum mappings from midi_bridge.js
    const GM_DRUM_MAP = {
        36: 'kick',       // Bass Drum 1
        35: 'kick',       // Acoustic Bass Drum
        38: 'snare',      // Acoustic Snare
        40: 'snare',      // Electric Snare
        37: 'snare',      // Side Stick
        42: 'hihat',      // Closed Hi-Hat
        44: 'hihat',      // Pedal Hi-Hat
        46: 'hihat',      // Open Hi-Hat
        48: 'high_tom',   // Hi-Mid Tom
        50: 'high_tom',   // High Tom
        45: 'mid_tom',    // Low Tom
        47: 'mid_tom',    // Low-Mid Tom
        41: 'floor_tom',  // Low Floor Tom
        43: 'floor_tom',  // High Floor Tom
        49: 'crash',      // Crash Cymbal 1
        57: 'crash',      // Crash Cymbal 2
        55: 'crash',      // Splash Cymbal
        52: 'crash',      // Chinese Cymbal
        51: 'ride',       // Ride Cymbal 1
        59: 'ride',       // Ride Cymbal 2
        53: 'ride',       // Ride Bell
    };

    const LANE_MAP = {
        'kick': 0,
        'snare': 1,
        'hihat': 2,
        'high_tom': 3,
        'mid_tom': 4,
        'floor_tom': 5,
        'crash': 6,
        'ride': 7
    };

    const SUPPORTED_EXTENSIONS = ['.mid', '.midi', '.smf', '.kar'];

    /**
     * Parse a MIDI file and extract drum onsets
     * @param {ArrayBuffer} arrayBuffer - Raw MIDI file data
     * @returns {Object} { onsets: Array, bpm: number, drumNoteCount: number }
     */
    function parseMidiFile(arrayBuffer) {
        const data = new DataView(arrayBuffer);
        let offset = 0;

        // Parse header chunk
        const headerChunk = readChunk(data, offset);
        if (headerChunk.type !== 'MThd') {
            throw new Error('Invalid MIDI file: missing MThd header');
        }
        offset += 8 + headerChunk.length;

        const format = data.getUint16(8, false);
        const numTracks = data.getUint16(10, false);
        const timeDivision = data.getUint16(12, false);

        // Check if time division is ticks per quarter note (not SMPTE)
        if (timeDivision & 0x8000) {
            throw new Error('SMPTE time division not supported');
        }
        const ppq = timeDivision; // Pulses (ticks) per quarter note

        // Collect all events from all tracks
        const allEvents = [];
        let tempo = 500000; // Default: 120 BPM (500000 microseconds per beat)

        for (let i = 0; i < numTracks; i++) {
            const trackChunk = readChunk(data, offset);
            if (trackChunk.type !== 'MTrk') {
                throw new Error('Invalid MIDI file: expected MTrk chunk');
            }

            const trackEnd = offset + 8 + trackChunk.length;
            let trackOffset = offset + 8;
            let absoluteTicks = 0;
            let runningStatus = 0;

            while (trackOffset < trackEnd) {
                // Read delta time (variable length)
                const deltaResult = readVariableLength(data, trackOffset);
                absoluteTicks += deltaResult.value;
                trackOffset = deltaResult.nextOffset;

                // Read event
                let eventByte = data.getUint8(trackOffset);

                // Handle running status
                if (eventByte < 0x80) {
                    eventByte = runningStatus;
                } else {
                    trackOffset++;
                    if (eventByte >= 0x80 && eventByte < 0xF0) {
                        runningStatus = eventByte;
                    }
                }

                const eventType = eventByte & 0xF0;
                const channel = eventByte & 0x0F;

                if (eventByte === 0xFF) {
                    // Meta event
                    const metaType = data.getUint8(trackOffset);
                    trackOffset++;
                    const lengthResult = readVariableLength(data, trackOffset);
                    trackOffset = lengthResult.nextOffset;

                    if (metaType === 0x51 && lengthResult.value === 3) {
                        // Set Tempo
                        tempo = (data.getUint8(trackOffset) << 16) |
                                (data.getUint8(trackOffset + 1) << 8) |
                                data.getUint8(trackOffset + 2);
                    }

                    trackOffset += lengthResult.value;
                } else if (eventByte === 0xF0 || eventByte === 0xF7) {
                    // SysEx event
                    const lengthResult = readVariableLength(data, trackOffset);
                    trackOffset = lengthResult.nextOffset + lengthResult.value;
                } else if (eventType === 0x90) {
                    // Note On
                    const note = data.getUint8(trackOffset);
                    const velocity = data.getUint8(trackOffset + 1);
                    trackOffset += 2;

                    if (velocity > 0) {
                        allEvents.push({
                            ticks: absoluteTicks,
                            note: note,
                            velocity: velocity
                        });
                    }
                } else if (eventType === 0x80) {
                    // Note Off - skip
                    trackOffset += 2;
                } else if (eventType === 0xA0 || eventType === 0xB0 || eventType === 0xE0) {
                    // Aftertouch, Control Change, Pitch Bend - 2 data bytes
                    trackOffset += 2;
                } else if (eventType === 0xC0 || eventType === 0xD0) {
                    // Program Change, Channel Pressure - 1 data byte
                    trackOffset += 1;
                }
            }

            offset = trackEnd;
        }

        // Convert ticks to seconds and filter to drum notes
        const bpm = Math.round(60000000 / tempo);
        const onsets = [];
        let drumNoteCount = 0;

        for (const event of allEvents) {
            const drumType = GM_DRUM_MAP[event.note];
            if (drumType) {
                drumNoteCount++;
                const lane = LANE_MAP[drumType];
                const timeSeconds = (event.ticks / ppq) * (tempo / 1000000);

                onsets.push({
                    time: timeSeconds,
                    lane: lane,
                    type: drumType,
                    energy: 1.0
                });
            }
        }

        // Sort by time
        onsets.sort((a, b) => a.time - b.time);

        return {
            onsets: onsets,
            bpm: bpm,
            drumNoteCount: drumNoteCount
        };
    }

    /**
     * Read a chunk header
     */
    function readChunk(data, offset) {
        const type = String.fromCharCode(
            data.getUint8(offset),
            data.getUint8(offset + 1),
            data.getUint8(offset + 2),
            data.getUint8(offset + 3)
        );
        const length = data.getUint32(offset + 4, false);
        return { type, length };
    }

    /**
     * Read a variable-length quantity
     */
    function readVariableLength(data, offset) {
        let value = 0;
        let byte;

        do {
            byte = data.getUint8(offset);
            offset++;
            value = (value << 7) | (byte & 0x7F);
        } while (byte & 0x80);

        return { value, nextOffset: offset };
    }

    /**
     * Validate MIDI file extension
     */
    function isValidMidiExtension(filename) {
        const ext = '.' + filename.split('.').pop().toLowerCase();
        return SUPPORTED_EXTENSIONS.includes(ext);
    }

    // Expose API
    window.drumalong_midi_parser = {
        parse: parseMidiFile,
        isValidExtension: isValidMidiExtension,
        SUPPORTED_EXTENSIONS: SUPPORTED_EXTENSIONS
    };

    console.log('DrumAlong MIDI parser loaded');
})();

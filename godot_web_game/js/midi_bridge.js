/**
 * DrumAlong MIDI Bridge
 * Web MIDI API integration for electronic drum kit input
 */

(function() {
    'use strict';

    // Standard General MIDI drum note mappings
    // These are common but may vary by manufacturer
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

    // Lane indices matching Godot gameplay
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

    // State
    let midiAccess = null;
    let connectedInputs = [];
    let noteCallback = null;
    let customDrumMap = { ...GM_DRUM_MAP };

    /**
     * Initialize Web MIDI
     * @param {Function} onNote - Callback for note events: (lane, velocity, timestamp)
     * @returns {Promise<boolean>} Success status
     */
    window.drumalong_midi = {
        init: async function(onNoteCallback) {
            noteCallback = onNoteCallback;

            if (!navigator.requestMIDIAccess) {
                console.warn('Web MIDI API not supported in this browser');
                return false;
            }

            try {
                midiAccess = await navigator.requestMIDIAccess();
                console.log('MIDI access granted');

                // Connect to all available inputs
                midiAccess.inputs.forEach(input => {
                    connectInput(input);
                });

                // Listen for new devices
                midiAccess.onstatechange = (e) => {
                    if (e.port.type === 'input') {
                        if (e.port.state === 'connected') {
                            connectInput(e.port);
                        } else {
                            disconnectInput(e.port);
                        }
                    }
                };

                return true;
            } catch (err) {
                console.error('Failed to get MIDI access:', err);
                return false;
            }
        },

        /**
         * Get list of connected MIDI inputs
         */
        getInputs: function() {
            if (!midiAccess) return [];

            const inputs = [];
            midiAccess.inputs.forEach(input => {
                inputs.push({
                    id: input.id,
                    name: input.name,
                    manufacturer: input.manufacturer,
                    state: input.state
                });
            });
            return inputs;
        },

        /**
         * Check if MIDI is supported
         */
        isSupported: function() {
            return !!navigator.requestMIDIAccess;
        },

        /**
         * Check if any MIDI devices are connected
         */
        hasDevices: function() {
            return connectedInputs.length > 0;
        },

        /**
         * Set custom drum mapping
         * @param {Object} mapping - { midiNote: drumType, ... }
         */
        setDrumMap: function(mapping) {
            customDrumMap = { ...GM_DRUM_MAP, ...mapping };
        },

        /**
         * Get current drum mapping
         */
        getDrumMap: function() {
            return { ...customDrumMap };
        },

        /**
         * Learn mode - returns the next MIDI note received
         * @returns {Promise<number>} MIDI note number
         */
        learnNote: function() {
            return new Promise((resolve) => {
                const originalCallback = noteCallback;
                noteCallback = (lane, velocity, timestamp, noteNumber) => {
                    noteCallback = originalCallback;
                    resolve(noteNumber);
                };
            });
        },

        /**
         * Disconnect all MIDI inputs
         */
        disconnect: function() {
            connectedInputs.forEach(input => {
                input.onmidimessage = null;
            });
            connectedInputs = [];
        }
    };

    function connectInput(input) {
        if (connectedInputs.find(i => i.id === input.id)) {
            return; // Already connected
        }

        console.log('Connecting MIDI input:', input.name);
        input.onmidimessage = handleMIDIMessage;
        connectedInputs.push(input);

        // Notify Godot of connection
        if (window.drumalong_godot_midi_callback) {
            window.drumalong_godot_midi_callback('connected', JSON.stringify({
                id: input.id,
                name: input.name
            }));
        }
    }

    function disconnectInput(input) {
        const index = connectedInputs.findIndex(i => i.id === input.id);
        if (index >= 0) {
            console.log('Disconnecting MIDI input:', input.name);
            connectedInputs.splice(index, 1);

            if (window.drumalong_godot_midi_callback) {
                window.drumalong_godot_midi_callback('disconnected', JSON.stringify({
                    id: input.id,
                    name: input.name
                }));
            }
        }
    }

    function handleMIDIMessage(event) {
        const [status, note, velocity] = event.data;
        const command = status & 0xF0;

        // Note On with velocity > 0
        if (command === 0x90 && velocity > 0) {
            const drumType = customDrumMap[note];
            if (drumType) {
                const lane = LANE_MAP[drumType];
                const timestamp = performance.now();

                // Call the registered callback
                if (noteCallback) {
                    noteCallback(lane, velocity, timestamp, note);
                }

                // Also notify Godot directly
                if (window.drumalong_godot_midi_callback) {
                    window.drumalong_godot_midi_callback('note', JSON.stringify({
                        lane: lane,
                        drumType: drumType,
                        velocity: velocity,
                        timestamp: timestamp,
                        midiNote: note
                    }));
                }
            }
        }
    }

    console.log('DrumAlong MIDI bridge loaded');
})();

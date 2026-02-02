/**
 * DrumAlong File Upload Bridge
 * Handles HTML5 File API for audio file uploads and bridges to Godot
 */

(function() {
    'use strict';

    const MAX_FILE_SIZE = 15 * 1024 * 1024; // 15MB
    const SUPPORTED_TYPES = ['audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/flac', 'audio/x-flac', 'audio/mp4', 'audio/x-m4a', 'audio/aac'];
    const SUPPORTED_EXTENSIONS = ['.mp3', '.wav', '.ogg', '.flac', '.m4a', '.aac'];

    // Store for pending file data
    window.drumalong = window.drumalong || {};
    window.drumalong.pendingFile = null;
    window.drumalong.audioContext = null;
    window.drumalong.decodedBuffer = null;

    /**
     * Initialize the audio context (must be called after user interaction)
     */
    window.drumalong.initAudioContext = function() {
        if (!window.drumalong.audioContext) {
            window.drumalong.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        }
        return window.drumalong.audioContext;
    };

    /**
     * Trigger file upload dialog
     * @returns {Promise} Resolves with file info or rejects on cancel/error
     */
    window.drumalong.triggerFileUpload = function() {
        return new Promise((resolve, reject) => {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = SUPPORTED_EXTENSIONS.join(',') + ',audio/*';

            input.onchange = function(e) {
                const file = e.target.files[0];
                if (!file) {
                    reject(new Error('No file selected'));
                    return;
                }

                // Validate file
                const validation = validateFile(file);
                if (!validation.valid) {
                    reject(new Error(validation.error));
                    return;
                }

                window.drumalong.pendingFile = file;
                resolve({
                    name: file.name,
                    size: file.size,
                    type: file.type || 'unknown'
                });
            };

            input.oncancel = function() {
                reject(new Error('File selection cancelled'));
            };

            input.click();
        });
    };

    /**
     * Validate uploaded file
     */
    function validateFile(file) {
        // Check file size
        if (file.size > MAX_FILE_SIZE) {
            return {
                valid: false,
                error: `File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`
            };
        }

        // Check file extension
        const ext = '.' + file.name.split('.').pop().toLowerCase();
        if (!SUPPORTED_EXTENSIONS.includes(ext)) {
            return {
                valid: false,
                error: `Unsupported file type. Supported: ${SUPPORTED_EXTENSIONS.join(', ')}`
            };
        }

        return { valid: true };
    }

    /**
     * Read and decode the pending audio file
     * @returns {Promise} Resolves with decoded audio data
     */
    window.drumalong.decodeAudioFile = function() {
        return new Promise((resolve, reject) => {
            const file = window.drumalong.pendingFile;
            if (!file) {
                reject(new Error('No file pending'));
                return;
            }

            const reader = new FileReader();

            reader.onload = async function(e) {
                try {
                    const arrayBuffer = e.target.result;
                    const audioContext = window.drumalong.initAudioContext();

                    // Decode audio data
                    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
                    window.drumalong.decodedBuffer = audioBuffer;

                    resolve({
                        duration: audioBuffer.duration,
                        sampleRate: audioBuffer.sampleRate,
                        numberOfChannels: audioBuffer.numberOfChannels,
                        length: audioBuffer.length
                    });
                } catch (err) {
                    reject(new Error('Failed to decode audio: ' + err.message));
                }
            };

            reader.onerror = function() {
                reject(new Error('Failed to read file'));
            };

            reader.readAsArrayBuffer(file);
        });
    };

    /**
     * Get audio samples from decoded buffer (mono, downsampled for analysis)
     * @param {number} targetSampleRate - Target sample rate for analysis (default 22050)
     * @returns {Float32Array} Audio samples
     */
    window.drumalong.getAudioSamples = function(targetSampleRate = 22050) {
        const buffer = window.drumalong.decodedBuffer;
        if (!buffer) {
            throw new Error('No decoded audio buffer');
        }

        // Get mono channel (average if stereo)
        let samples;
        if (buffer.numberOfChannels === 1) {
            samples = buffer.getChannelData(0);
        } else {
            const left = buffer.getChannelData(0);
            const right = buffer.getChannelData(1);
            samples = new Float32Array(left.length);
            for (let i = 0; i < left.length; i++) {
                samples[i] = (left[i] + right[i]) / 2;
            }
        }

        // Downsample if needed
        const ratio = buffer.sampleRate / targetSampleRate;
        if (ratio > 1) {
            const newLength = Math.floor(samples.length / ratio);
            const downsampled = new Float32Array(newLength);
            for (let i = 0; i < newLength; i++) {
                downsampled[i] = samples[Math.floor(i * ratio)];
            }
            return downsampled;
        }

        return samples;
    };

    /**
     * Create an audio source for playback
     * @returns {AudioBufferSourceNode}
     */
    window.drumalong.createPlaybackSource = function() {
        const buffer = window.drumalong.decodedBuffer;
        if (!buffer) {
            throw new Error('No decoded audio buffer');
        }

        const audioContext = window.drumalong.initAudioContext();
        const source = audioContext.createBufferSource();
        source.buffer = buffer;
        source.connect(audioContext.destination);
        return source;
    };

    /**
     * Get current audio context time (for synchronization)
     */
    window.drumalong.getAudioTime = function() {
        const ctx = window.drumalong.audioContext;
        return ctx ? ctx.currentTime : 0;
    };

    /**
     * Store audio data as base64 for persistence
     * @returns {Promise<string>} Base64 encoded audio
     */
    window.drumalong.getAudioBase64 = function() {
        return new Promise((resolve, reject) => {
            const file = window.drumalong.pendingFile;
            if (!file) {
                reject(new Error('No file pending'));
                return;
            }

            const reader = new FileReader();
            reader.onload = function(e) {
                // Remove data URL prefix to get just base64
                const base64 = e.target.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = function() {
                reject(new Error('Failed to encode file'));
            };
            reader.readAsDataURL(file);
        });
    };

    /**
     * Clear pending file and decoded buffer
     */
    window.drumalong.clearAudio = function() {
        window.drumalong.pendingFile = null;
        window.drumalong.decodedBuffer = null;
    };

    console.log('DrumAlong file upload bridge loaded');
})();

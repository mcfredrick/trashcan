/**
 * DrumAlong Onset Detection
 * Energy-based onset detection with frequency band analysis for drum classification
 */

(function() {
    'use strict';

    // Frequency bands for drum classification (Hz)
    const DRUM_BANDS = {
        kick:   { low: 20,   high: 100,  name: 'kick' },
        snare:  { low: 150,  high: 400,  name: 'snare' },
        hihat:  { low: 6000, high: 12000, name: 'hihat' },
        tom:    { low: 80,   high: 400,  name: 'tom' },
        crash:  { low: 3000, high: 8000, name: 'crash' },
        ride:   { low: 4000, high: 10000, name: 'ride' }
    };

    // Lane indices matching Godot gameplay
    const LANE_MAP = {
        'kick': 0,
        'snare': 1,
        'hihat': 2,
        'tom': 3,
        'crash': 4,
        'ride': 5
    };

    /**
     * Main onset detection function
     * @param {Float32Array} samples - Audio samples (mono)
     * @param {number} sampleRate - Sample rate of the audio
     * @returns {Array} Array of onset objects with time, lane, and type
     */
    window.drumalong_detectOnsets = function(samples, sampleRate) {
        const frameSize = 512;  // ~23ms at 22050Hz
        const hopSize = 256;    // 50% overlap
        const onsets = [];

        // Energy history for adaptive threshold
        const energyHistory = [];
        const maxHistorySize = 50;
        let prevEnergy = 0;

        // Minimum time between onsets (ms)
        const minOnsetGap = 50;
        let lastOnsetTime = -minOnsetGap;

        // Process audio in frames
        for (let i = 0; i < samples.length - frameSize; i += hopSize) {
            // Extract frame
            const frame = samples.subarray(i, i + frameSize);

            // Compute RMS energy
            let energy = 0;
            for (let j = 0; j < frameSize; j++) {
                energy += frame[j] * frame[j];
            }
            energy = Math.sqrt(energy / frameSize);

            // Update energy history
            energyHistory.push(energy);
            if (energyHistory.length > maxHistorySize) {
                energyHistory.shift();
            }

            // Adaptive threshold: 1.5x median of recent frames
            const threshold = getMedian(energyHistory) * 1.5 + 0.01;

            // Peak detection: energy above threshold and rising
            const isOnset = energy > threshold && energy > prevEnergy * 1.2;

            if (isOnset) {
                const timeMs = (i / sampleRate) * 1000;

                // Avoid double-detections
                if (timeMs - lastOnsetTime >= minOnsetGap) {
                    // Classify drum type using FFT
                    const drumType = classifyDrumHit(frame, sampleRate);

                    onsets.push({
                        time: timeMs / 1000,  // Convert to seconds for Godot
                        lane: LANE_MAP[drumType],
                        type: drumType,
                        energy: energy
                    });

                    lastOnsetTime = timeMs;
                }
            }

            prevEnergy = energy;
        }

        console.log(`Detected ${onsets.length} onsets`);
        return onsets;
    };

    /**
     * Classify drum hit type using frequency analysis
     * @param {Float32Array} frame - Audio frame
     * @param {number} sampleRate - Sample rate
     * @returns {string} Drum type name
     */
    function classifyDrumHit(frame, sampleRate) {
        // Compute FFT
        const fftSize = frame.length;
        const fft = computeFFT(frame);

        // Calculate energy in each frequency band
        const bandEnergies = {};
        for (const [drum, band] of Object.entries(DRUM_BANDS)) {
            bandEnergies[drum] = getBandEnergy(fft, band.low, band.high, sampleRate, fftSize);
        }

        // Normalize energies
        const maxEnergy = Math.max(...Object.values(bandEnergies), 0.0001);
        for (const drum in bandEnergies) {
            bandEnergies[drum] /= maxEnergy;
        }

        // Decision tree for classification
        // Kick: dominant low frequency
        if (bandEnergies.kick > 0.6 && bandEnergies.kick > bandEnergies.snare * 1.5) {
            return 'kick';
        }

        // Hi-hat: very high frequency dominant
        if (bandEnergies.hihat > 0.5 && bandEnergies.hihat > bandEnergies.crash) {
            return 'hihat';
        }

        // Crash: high frequency with wider spread
        if (bandEnergies.crash > 0.4 && bandEnergies.crash > bandEnergies.ride * 1.2) {
            return 'crash';
        }

        // Ride: sustained high-mid
        if (bandEnergies.ride > 0.4 && bandEnergies.ride > bandEnergies.hihat * 0.8) {
            return 'ride';
        }

        // Tom: mid frequencies
        if (bandEnergies.tom > 0.5 && bandEnergies.tom > bandEnergies.snare * 0.9) {
            // Distinguish tom from kick by checking if there's also high frequency content
            if (bandEnergies.kick < bandEnergies.tom * 0.7) {
                return 'tom';
            }
        }

        // Default to snare (most common drum hit)
        return 'snare';
    }

    /**
     * Simple FFT implementation (DFT for small sizes)
     * For production, consider using a proper FFT library
     */
    function computeFFT(samples) {
        const n = samples.length;
        const real = new Float32Array(n);
        const imag = new Float32Array(n);

        // DFT (not the most efficient, but works for small frame sizes)
        for (let k = 0; k < n / 2; k++) {
            let sumReal = 0;
            let sumImag = 0;
            for (let t = 0; t < n; t++) {
                const angle = (2 * Math.PI * k * t) / n;
                sumReal += samples[t] * Math.cos(angle);
                sumImag -= samples[t] * Math.sin(angle);
            }
            real[k] = sumReal;
            imag[k] = sumImag;
        }

        // Return magnitude spectrum
        const magnitude = new Float32Array(n / 2);
        for (let k = 0; k < n / 2; k++) {
            magnitude[k] = Math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
        }

        return magnitude;
    }

    /**
     * Get energy in a frequency band
     */
    function getBandEnergy(fft, lowFreq, highFreq, sampleRate, fftSize) {
        const binWidth = sampleRate / fftSize;
        const lowBin = Math.floor(lowFreq / binWidth);
        const highBin = Math.min(Math.ceil(highFreq / binWidth), fft.length - 1);

        let energy = 0;
        for (let i = lowBin; i <= highBin; i++) {
            energy += fft[i] * fft[i];
        }

        return Math.sqrt(energy / Math.max(1, highBin - lowBin + 1));
    }

    /**
     * Get median of an array
     */
    function getMedian(arr) {
        if (arr.length === 0) return 0;
        const sorted = [...arr].sort((a, b) => a - b);
        const mid = Math.floor(sorted.length / 2);
        return sorted.length % 2 !== 0
            ? sorted[mid]
            : (sorted[mid - 1] + sorted[mid]) / 2;
    }

    /**
     * Advanced onset detection using spectral flux
     * More accurate but computationally heavier
     */
    window.drumalong_detectOnsetsAdvanced = function(samples, sampleRate) {
        const frameSize = 1024;
        const hopSize = 512;
        const onsets = [];

        let prevSpectrum = null;
        const fluxHistory = [];
        const maxHistorySize = 20;
        let lastOnsetTime = -100;

        for (let i = 0; i < samples.length - frameSize; i += hopSize) {
            const frame = samples.subarray(i, i + frameSize);

            // Apply Hann window
            const windowed = applyWindow(frame);

            // Compute spectrum
            const spectrum = computeFFT(windowed);

            if (prevSpectrum) {
                // Compute spectral flux (only positive changes)
                let flux = 0;
                for (let j = 0; j < spectrum.length; j++) {
                    const diff = spectrum[j] - prevSpectrum[j];
                    if (diff > 0) {
                        flux += diff;
                    }
                }

                fluxHistory.push(flux);
                if (fluxHistory.length > maxHistorySize) {
                    fluxHistory.shift();
                }

                // Peak picking with adaptive threshold
                const threshold = getMedian(fluxHistory) * 1.5 + getMean(fluxHistory) * 0.5;

                if (flux > threshold) {
                    const timeMs = (i / sampleRate) * 1000;

                    if (timeMs - lastOnsetTime >= 50) {
                        const drumType = classifyDrumHit(frame, sampleRate);

                        onsets.push({
                            time: timeMs / 1000,
                            lane: LANE_MAP[drumType],
                            type: drumType,
                            energy: flux
                        });

                        lastOnsetTime = timeMs;
                    }
                }
            }

            prevSpectrum = spectrum;
        }

        console.log(`Advanced detection found ${onsets.length} onsets`);
        return onsets;
    };

    /**
     * Apply Hann window to frame
     */
    function applyWindow(frame) {
        const windowed = new Float32Array(frame.length);
        for (let i = 0; i < frame.length; i++) {
            const window = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (frame.length - 1)));
            windowed[i] = frame[i] * window;
        }
        return windowed;
    }

    /**
     * Get mean of an array
     */
    function getMean(arr) {
        if (arr.length === 0) return 0;
        return arr.reduce((a, b) => a + b, 0) / arr.length;
    }

    /**
     * Estimate tempo (BPM) from onset times
     * @param {Array} onsets - Array of onset objects with time property (in seconds)
     * @returns {number} Estimated BPM (or 120 as default)
     */
    window.drumalong_estimateTempo = function(onsets) {
        if (!onsets || onsets.length < 4) {
            return 120; // Default BPM
        }

        // Calculate inter-onset intervals (IOIs)
        const iois = [];
        for (let i = 1; i < onsets.length; i++) {
            const ioi = onsets[i].time - onsets[i-1].time;
            // Only consider reasonable intervals (50ms to 2s, i.e., 30-1200 BPM range)
            if (ioi >= 0.05 && ioi <= 2.0) {
                iois.push(ioi);
            }
        }

        if (iois.length < 3) {
            return 120;
        }

        // Build histogram of IOIs to find common intervals
        // Quantize to 10ms bins
        const histogram = {};
        for (const ioi of iois) {
            const bin = Math.round(ioi * 100) / 100; // Round to 10ms
            histogram[bin] = (histogram[bin] || 0) + 1;
        }

        // Find peaks in histogram (common beat intervals)
        const sortedBins = Object.entries(histogram)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10);

        if (sortedBins.length === 0) {
            return 120;
        }

        // Look for intervals that correspond to reasonable tempos (60-180 BPM)
        // Beat interval = 60 / BPM, so BPM = 60 / interval
        let bestInterval = parseFloat(sortedBins[0][0]);

        // Check if the interval or its multiples/divisions give a reasonable BPM
        const candidateIntervals = [
            bestInterval,
            bestInterval * 2,
            bestInterval / 2,
            bestInterval * 4,
            bestInterval / 4
        ];

        for (const interval of candidateIntervals) {
            const bpm = 60 / interval;
            if (bpm >= 60 && bpm <= 180) {
                console.log(`Estimated tempo: ${Math.round(bpm)} BPM`);
                return Math.round(bpm);
            }
        }

        // Fallback: use median IOI
        iois.sort((a, b) => a - b);
        const medianIoi = iois[Math.floor(iois.length / 2)];
        const bpm = Math.round(60 / medianIoi);

        // Clamp to reasonable range
        const clampedBpm = Math.max(60, Math.min(180, bpm));
        console.log(`Estimated tempo (fallback): ${clampedBpm} BPM`);
        return clampedBpm;
    };

    /**
     * Generate a metronome click sound
     * @param {AudioContext} audioContext
     * @param {number} time - When to play the click (AudioContext time)
     * @param {boolean} accent - Whether this is an accented beat
     */
    window.drumalong_playClick = function(audioContext, time, accent = false) {
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();

        osc.connect(gain);
        gain.connect(audioContext.destination);

        // Higher pitch for accent
        osc.frequency.value = accent ? 1000 : 800;
        osc.type = 'sine';

        // Short click envelope
        const volume = accent ? 0.5 : 0.3;
        gain.gain.setValueAtTime(volume, time);
        gain.gain.exponentialRampToValueAtTime(0.001, time + 0.05);

        osc.start(time);
        osc.stop(time + 0.05);
    };

    /**
     * Play a count-in metronome
     * @param {number} bpm - Beats per minute
     * @param {number} beats - Number of beats to play (default 4)
     * @returns {Promise} Resolves when count-in is complete
     */
    window.drumalong_playCountIn = function(bpm, beats = 4) {
        return new Promise((resolve) => {
            const audioContext = window.drumalong.audioContext || new AudioContext();
            const beatInterval = 60 / bpm;
            const startTime = audioContext.currentTime + 0.1;

            for (let i = 0; i < beats; i++) {
                const isAccent = (i === 0); // Accent first beat
                window.drumalong_playClick(audioContext, startTime + i * beatInterval, isAccent);
            }

            // Resolve after all beats have played
            const totalDuration = beats * beatInterval * 1000;
            setTimeout(resolve, totalDuration + 100);
        });
    };

    console.log('DrumAlong onset detection loaded');
})();

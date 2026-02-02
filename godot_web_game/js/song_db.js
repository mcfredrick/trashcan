/**
 * DrumAlong Song Database
 * IndexedDB storage for persisting analyzed songs
 */

(function() {
    'use strict';

    const DB_NAME = 'drumalong_songs';
    const DB_VERSION = 1;
    const STORE_NAME = 'songs';

    let db = null;

    /**
     * Initialize the database
     * @returns {Promise<IDBDatabase>}
     */
    async function initDB() {
        if (db) return db;

        return new Promise((resolve, reject) => {
            const request = indexedDB.open(DB_NAME, DB_VERSION);

            request.onerror = () => {
                console.error('Failed to open database:', request.error);
                reject(request.error);
            };

            request.onsuccess = () => {
                db = request.result;
                console.log('Database opened successfully');
                resolve(db);
            };

            request.onupgradeneeded = (event) => {
                const database = event.target.result;

                // Create songs object store
                if (!database.objectStoreNames.contains(STORE_NAME)) {
                    const store = database.createObjectStore(STORE_NAME, { keyPath: 'id' });
                    store.createIndex('name', 'name', { unique: false });
                    store.createIndex('createdAt', 'createdAt', { unique: false });
                    console.log('Created songs store');
                }
            };
        });
    }

    /**
     * Save a song to the database
     * @param {Object} songData - Song data including onsets
     * @returns {Promise<string>} Song ID
     */
    async function saveSong(songData) {
        const database = await initDB();

        // Add timestamp if not present
        if (!songData.createdAt) {
            songData.createdAt = Date.now();
        }

        return new Promise((resolve, reject) => {
            const transaction = database.transaction([STORE_NAME], 'readwrite');
            const store = transaction.objectStore(STORE_NAME);

            const request = store.put(songData);

            request.onsuccess = () => {
                console.log('Song saved:', songData.id);
                resolve(songData.id);
            };

            request.onerror = () => {
                console.error('Failed to save song:', request.error);
                reject(request.error);
            };
        });
    }

    /**
     * Get a song by ID
     * @param {string} id - Song ID
     * @returns {Promise<Object|null>}
     */
    async function getSong(id) {
        const database = await initDB();

        return new Promise((resolve, reject) => {
            const transaction = database.transaction([STORE_NAME], 'readonly');
            const store = transaction.objectStore(STORE_NAME);

            const request = store.get(id);

            request.onsuccess = () => {
                resolve(request.result || null);
            };

            request.onerror = () => {
                console.error('Failed to get song:', request.error);
                reject(request.error);
            };
        });
    }

    /**
     * Get all songs
     * @returns {Promise<Array>}
     */
    async function getAllSongs() {
        const database = await initDB();

        return new Promise((resolve, reject) => {
            const transaction = database.transaction([STORE_NAME], 'readonly');
            const store = transaction.objectStore(STORE_NAME);

            const request = store.getAll();

            request.onsuccess = () => {
                const songs = request.result || [];
                // Sort by creation time, newest first
                songs.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
                resolve(songs);
            };

            request.onerror = () => {
                console.error('Failed to get songs:', request.error);
                reject(request.error);
            };
        });
    }

    /**
     * Delete a song by ID
     * @param {string} id - Song ID
     * @returns {Promise<void>}
     */
    async function deleteSong(id) {
        const database = await initDB();

        return new Promise((resolve, reject) => {
            const transaction = database.transaction([STORE_NAME], 'readwrite');
            const store = transaction.objectStore(STORE_NAME);

            const request = store.delete(id);

            request.onsuccess = () => {
                console.log('Song deleted:', id);
                resolve();
            };

            request.onerror = () => {
                console.error('Failed to delete song:', request.error);
                reject(request.error);
            };
        });
    }

    /**
     * Clear all songs
     * @returns {Promise<void>}
     */
    async function clearAllSongs() {
        const database = await initDB();

        return new Promise((resolve, reject) => {
            const transaction = database.transaction([STORE_NAME], 'readwrite');
            const store = transaction.objectStore(STORE_NAME);

            const request = store.clear();

            request.onsuccess = () => {
                console.log('All songs cleared');
                resolve();
            };

            request.onerror = () => {
                console.error('Failed to clear songs:', request.error);
                reject(request.error);
            };
        });
    }

    /**
     * Get database storage estimate
     * @returns {Promise<Object>} Storage info with usage and quota
     */
    async function getStorageInfo() {
        if (navigator.storage && navigator.storage.estimate) {
            const estimate = await navigator.storage.estimate();
            return {
                usage: estimate.usage || 0,
                quota: estimate.quota || 0,
                usagePercent: ((estimate.usage || 0) / (estimate.quota || 1)) * 100
            };
        }
        return { usage: 0, quota: 0, usagePercent: 0 };
    }

    /**
     * Export all songs as JSON
     * @returns {Promise<string>} JSON string of all songs
     */
    async function exportSongs() {
        const songs = await getAllSongs();
        return JSON.stringify(songs, null, 2);
    }

    /**
     * Import songs from JSON
     * @param {string} jsonString - JSON string of songs array
     * @returns {Promise<number>} Number of songs imported
     */
    async function importSongs(jsonString) {
        const songs = JSON.parse(jsonString);
        if (!Array.isArray(songs)) {
            throw new Error('Invalid import data: expected array');
        }

        let imported = 0;
        for (const song of songs) {
            if (song.id && song.name) {
                await saveSong(song);
                imported++;
            }
        }

        return imported;
    }

    // Expose API globally
    window.drumalong_db = {
        init: initDB,
        saveSong,
        getSong,
        getAllSongs,
        deleteSong,
        clearAllSongs,
        getStorageInfo,
        exportSongs,
        importSongs
    };

    // Initialize on load
    initDB().catch(err => {
        console.error('Failed to initialize database:', err);
    });

    console.log('DrumAlong song database loaded');
})();

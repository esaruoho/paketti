const settingsStore = {};

const isStringValue = ['lastUsedAudioConfig', 'defaultAudioConfigText'];

const defaultSettings = {
    lastUsedAudioConfig: '48000m16w',
    defaultAudioConfigText: '48kHz/16BIT MONO',
    restoreLastUsedAudioConfig: true,
    retainSessionState: true,

    spacedChainMode: true,
    updateResampleChainsToList: false,
    exportChainsAsXyPresets: false,

    wavePanelHeight: 128,

    attemptToFindCrossingPoint: false,
    darkModeTheme: null,
    deClick: 0.4,
    ditherExports: false,
    embedCuePoints: true,
    splitOutExistingSlicesOnJoin: true,
    embedOrslData: false,
    exportWithOtFile: false,
    importFileLimit: true,
    normalizeContrast: false,
    reverseEvenSamplesInChains: false,
    pitchModifier: 1,
    playWithPopMarker: 0,
    showTouchModifierKeys: false,
    showWelcomeModalOnLaunchIfListEmpty: true,
    shiftClickForFileDownload: false,
    skipMiniWaveformRender: false,
    treatDualMonoStereoAsMono: true,
    zipDownloads: true
};

const getDefaultSetting = function(prop) {
    switch (prop) {
        case 'supportedSampleRates':
            return getSupportedSampleRates();
        default:
            return defaultSettings[prop];
    }
};

const getSetting = function(prop) {
    const localStore = localStorage.getItem(prop);
    if (localStore !== null) {
        return isStringValue.includes(prop) ?
          localStore :
          JSON.parse(localStore);
    } else {
        return getDefaultSetting(prop);
    }
};

const setSetting = function(prop, value) {
    if (value === undefined || value === null || value === '') {
        delete settingsStore[prop];
        localStorage.removeItem(prop);
        return;
    }
    if (typeof value === 'object') {
        localStorage.setItem(prop, JSON.stringify(value));
        return;
    }
    localStorage.setItem(prop, value);
}

export const settings = new Proxy(settingsStore, {
    get(settingsStore, prop) {
        if (settingsStore[prop] === undefined) {
            settingsStore[prop] = getSetting(prop);
        }
        return settingsStore[prop];
    },

    set(settingsStore, prop, value) {
        settingsStore[prop] = value;
        setSetting(prop, value);
        return true;
    }
});

function getSupportedSampleRates() {
    let supportedSampleRates = [8000, 48000];
    try {
        new AudioContext({sampleRate: 1});
        supportedSampleRates = [1, 96000];
    } catch(e) {
        const matches = e.toString().match(
          /\[(.*?)\]/g
        );
        if (matches?.length) {
            supportedSampleRates = matches[0].split(',').map(
              sr => +sr.replace(/\D+/g, '')
            );
        }
    }
    supportedSampleRates[1] = supportedSampleRates[1] > 96000 ? 96000 : supportedSampleRates[1];
    return supportedSampleRates;
}

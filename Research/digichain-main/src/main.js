import {settings} from './settings.js';
import {
    Resampler,
    audioBufferToWav,
    encodeOt,
    getAifSampleRate,
    joinToMono,
    joinToStereo,
    bufferToFloat32Array,
    detectTempo, dcDialog, showToastMessage, setLoadingText,
    flattenFile, buildXyDrumPatchData
} from './resources.js';
import {
    editor,
    showEditor,
    drawWaveform,
    getNiceFileName,
    setEditorConf,
    getUniqueName,
    getSetOpExportData,
    sanitizeFileName
} from './editor.js';
import './jszip.js';
import './msgpack.min.js';

const uploadInput = document.getElementById('uploadInput');
const listEl = document.getElementById('fileList');
const infoEl = document.getElementById('infoIndicator');
const supportedAudioTypes = ['syx', 'wav', 'flac', 'aif', 'webm', 'm4a', 'pti', 'mp3'];
const DefaultSliceOptions = [0, 4, 8, 16, 32, 64, 128];
const importFileLimitValue = 750;
let db, dbReq;
let masterSR = 48000; /*The working sample rate*/
let targetSR = 48000; /*The target sample rate, what rendered files will output at.*/
let masterBitDepth = 16;
let masterChannels = 1;
let targetContainer = 'w';
let embedSliceData = false;
let secondsPerFile = 0;
let audioCtx;
let files = [];
let unsorted = [];
let importOrder = [];
let metaFiles = [];
let mergeFiles = [];
let chainFileNames = []; //{ name: '', used: false }
let lastSort = '';
let lastSelectedRow;
let lastDragOverRow;
let lastLastSelectedRow;
let lastSliceFileImport = []; // [].enabledTracks = {t[x]: boolean}
let lastOpKit = [];
let sliceGrid = 0;
let sliceOptions = Array.from(DefaultSliceOptions);
let keyboardShortcutsDisabled = false;
let showSamplesList = true;
let processedCount = 0;
let modifierKeys = {
    shiftKey: false,
    ctrlKey: false
};

metaFiles.getByFileName = function(filename) {
    let found = this.find(m => m.name.replace(/\.[^.]*$/, '') ===
      filename.replace(/\.[^.]*$/, ''));
    if (!found && filename.endsWith('.flac')) {
        found = this.find(m => filename.includes(`(${m.name})`));
    }
    if (filename === '---sliceToTransientCached---' && !found) {
        found = {
            uuid: crypto.randomUUID(),
            name: '---sliceToTransientCached---',
            sliceCount: 0,
            slices: []
        };
        metaFiles.push(found);
    }
    return found;
};
metaFiles.getByFile = function(file) {
    if (file.meta.slicedFrom) { return false; }
    const found = this.find(m => m.name.replace(/\.[^.]*$/, '') ===
      file.file.name.replace(/\.[^.]*$/, ''));
    if (found) { return found; }
    if (file.meta.op1Json && file.meta.op1Json.start) {
        let opSlices = file.meta.op1Json.start.map(
          (s, i) => ({
              startPoint: s,
              endPoint: file.meta.op1Json.end[i],
              p: file.meta.op1Json.pan[i],
              pab: file.meta.op1Json.pan_ab[i],
              st: file.meta.op1Json.pitch[i]
          })).reduce((acc, curr) => {
            if (acc?.pos && acc.pos > -1) {
                if (curr.endPoint > acc.pos) {
                    acc.result.push(curr);
                    acc.pos = curr.endPoint;
                }
            } else {
                acc.pos = acc.pos ?? curr.endPoint;
                acc.result.push(curr);
            }
            return acc;
        }, {result: []}).result;
        return {
            uuid: file.meta.uuid,
            name: file.file.name,
            path: file.file.path,
            cssClass: 'is-op-file',
            sliceCount: opSlices.length,
            slices: opSlices
        };
    } else if (file.meta.customSlices) {
        return {
            uuid: file.meta.uuid,
            name: file.file.name,
            path: file.file.path,
            cssClass: 'is-dc-file',
            sliceCount: file.meta.customSlices.sliceCount,
            slices: file.meta.customSlices.slices
        };
    } else if (file.meta.slices) {
        return {
            uuid: file.meta.uuid,
            name: file.file.name,
            path: file.file.path,
            cssClass: 'is-dc-file',
            otLoop: file.meta.otLoop??0,
            otLoopStart: file.meta.otLoopStart??0,
            sliceCount: file.meta.slices.length,
            slices: file.meta.slices.map(
              slice => ({
                  startPoint: slice.s,
                  endPoint: slice.e,
                  loopPoint: slice.l ?? -1,
                  name: slice.n || slice.name || '',
                  p: slice.p ?? 16384,
                  pab: slice.pab ?? false,
                  st: slice.st ?? 0
              })
            )
        };
    }
};
metaFiles.getByFileInDcFormat = function(file) {
    return (
      file === '---sliceToTransientCached---' ?
        metaFiles.getByFileName('---sliceToTransientCached---') :
        metaFiles.getByFile(file) || {slices: []}).slices.map(slice => {
            let _slice = {
                s: slice.startPoint,
                e: slice.endPoint,
                l: slice.loopPoint,
                n: slice.name || ''
            };
            ['p', 'pab', 'st'].forEach(k => {
                if (slice[k]??false) { return ; }
                _slice[k] = slice[k];
            });
            return _slice;
    });
};
metaFiles.removeSelected = function() {
    files.forEach(f => {
        const idx = this.findIndex(i => i === this.getByFileName(f.file.name));
        f.meta.checked && idx !== -1 ? this.splice(idx, 1) : false;
    });
};
metaFiles.removeByName = function(filename) {
    const idx = this.findIndex(i => i === this.getByFileName(filename));
    if (idx !== -1) {
        this.splice(idx, 1);
        unsorted = unsorted.filter(id => id !== idx);

    }
};

function removeMetaFile(id) {
    const file = getFileById(id);
    if (!file) { return; }
    metaFiles.removeByName(file.file.filename);
    if (file.meta.op1Json) {
        delete file.meta.op1Json;
    }
}

function getSlicesFromMetaFile(file) {
    return metaFiles.getByFileInDcFormat(file);
}

function checkAndSetAudioContext() {
    if (!audioCtx || audioCtx.sampleRate !== masterSR || audioCtx.state === 'closed') {
        audioCtx = new AudioContext(
          {sampleRate: masterSR, latencyHint: 'interactive'});
        setEditorConf({
            audioCtx,
            masterSR,
            masterChannels,
            masterBitDepth
        });
    }
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
}

function setAudioOptionsFromCommonConfig(event) {
    const configString = event.target.value;
    if (configString === 'none') {
        return ;
    }
    const defaults = [48000, 'm', 16, 'w', ...DefaultSliceOptions];
    let configValues = configString ? configString.match(/^\d+|[ms]|\d+|[wa]/g) : defaults;
    document.getElementById(`acoContainer${configValues[3]}`).click();
    document.getElementById('settingsSampleRate').value = +configValues[0];
    document.getElementById(`acoChannel${configValues[1]}`).click();
    document.getElementById(`acoBitDepth${configValues[2]}`).click();
    configValues.slice(4).forEach((g, i) => i > 0 ?document.getElementById(`gridSize${+i}`).value = +g : '');
    if (files.length === 0) {
        document.getElementById('settingsWorkingSampleRate').value = +configValues[0];
    }
}

function setSliceOptionsFromArray(sliceOptions = []) {
    sliceOptions.forEach((option, index) => changeSliceOption(
      document.querySelector(`.master-slices .sel-${index}`), option,
      true
    ));

    selectSliceAmount({
        shiftKey: false,
        target: document.querySelector(`.master-slices [class*="sel-"].check:not(.button-outline)`)
    }, sliceOptions[+document.querySelector(`.master-slices [class*="sel-"].check:not(.button-outline)`)?.dataset?.sel??0]);
}

async function changeAudioConfig(configString = '', onloadRestore = false) {
    const settingsPanelEl = document.getElementById('exportSettingsPanel');
    const configOptionsEl = document.getElementById('audioConfigOptions');
    const audioValuesFromCommonSelectEl = document.getElementById('audioValuesFromCommonSelect');
    const commonSelectDevice = (audioValuesFromCommonSelectEl?.selectedOptions??[])[0]?.dataset?.device;
    const defaults = [48000, 'm', 16, 'w', ...DefaultSliceOptions];
    let configValues = configString ? configString.match(/^\d+|[ms]|\d+|[wa]/g) : defaults;
    configValues = configValues.length === 11 ? configValues : defaults;
    let configData = configString && configValues.length === 11? {
        sr: +configValues[0],
        c: configValues[1],
        bd: +configValues[2],
        f: configValues[3],
        go: configValues.slice(4)
    } : {
        sr: +document.getElementById('settingsSampleRate').value,
        c: +document.getElementById('channelsGroup').dataset.channels === 1 ? 'm' : 's',
        bd: +document.getElementById('bitDepthGroup').dataset.bitDepth,
        f: document.getElementById('targetContainerGroup').dataset.container,
        go: [0, ...[...document.querySelectorAll('.acoSliceGridOption')].map(go => +go.value)]
    };

    let workingSR = +(document.getElementById('settingsWorkingSampleRate')?.value || localStorage.getItem('workingSampleRate') || 48000);

    try {
        settings.ditherExports = JSON.parse(document.getElementById('ditherGroup').dataset.dither);
    } catch(e) {}

    if (audioValuesFromCommonSelectEl) {
        toggleSetting('exportWithOtFile', 'ot' === commonSelectDevice, true);
        audioValuesFromCommonSelectEl.value = 'none';
    }

    if (configData.f === 'a') {
        configData.sr = 44100;
        configData.bd = 16;
    }

    if (configData.sr < settings.supportedSampleRates[0] || configData.sr > settings.supportedSampleRates[1]) {
        showToastMessage(
          `ERROR: The sample rate ${configData.sr}Hz is not supported by your browser.\n\nPlease select a sample rate between ${settings.supportedSampleRates[0]}Hz and ${settings.supportedSampleRates[1]}Hz`, 8000);
        return false;
    }
    if (workingSR < settings.supportedSampleRates[0] || workingSR > settings.supportedSampleRates[1]) {
        showToastMessage(
          `ERROR: The sample rate ${workingSR}Hz is not supported by your browser.\n\nPlease select a sample rate between ${settings.supportedSampleRates[0]}Hz and ${settings.supportedSampleRates[1]}Hz`, 8000);
        return false;
    }

    if (files.length > 0 && workingSR !== masterSR) {
        let conf = await dcDialog('confirm',
          `Frequently changing audio working sample rate can degrade the audio quality, particularly in the transients and higher frequencies.\n\n Do you want to continue?`,
          {
              kind: 'warning',
              okLabel: 'Continue'
          }
        );
        if (!conf) {
            return false;
        }
    }
    setLoadingText('Configuring');
    const selectionString = `${configData.f === 'a' ? 'AIF ' : ''}${configData.sr/1000}kHz/${configData.bd}BIT ${configData.c === 'm' ? 'MONO' : 'STEREO'}`;
    configOptionsEl.value = selectionString;
    const selection = `${configData.sr}${configData.c}${configData.bd}${configData.f}${configData.go.join('-')}`;
    settings.lastUsedAudioConfig = selection;
    localStorage.setItem('workingSampleRate', `${workingSR}`);

    let resampleState = false;
    if (workingSR !== masterSR && !onloadRestore) {
        resampleState = true;
    }
    masterSR = workingSR;
    targetSR = configData.sr;
    masterBitDepth = configData.bd;
    masterChannels = configData.c === 'm' ? 1 : 2;
    targetContainer = configData.f;
    sliceOptions = configData.go.map(g => +g);

    document.body.dataset.targetSr = targetSR;
    document.body.dataset.workingSr = workingSR;

    setSliceOptionsFromArray(sliceOptions);

    if (!onloadRestore) {
        checkAndSetAudioContext();
    }

    secondsPerFile = 0;
    secondsPerFile = 'opz' === commonSelectDevice ? 12 : secondsPerFile;
    secondsPerFile = 'op1f' === commonSelectDevice ? 20 : secondsPerFile;
    /*secondsPerFile = 'opxy' === commonSelectDevice ? 20 : secondsPerFile;*/

    toggleSecondsPerFile(false,
      !secondsPerFile ? 0 :
        secondsPerFile
    );
    setEditorConf({
        audioCtx,
        masterSR,
        masterChannels,
        masterBitDepth
    });

    if (commonSelectDevice) {
        settings.exportChainsAsXyPresets = false;
        if ('opxy' === commonSelectDevice) {
            updateExportChainsAsXyPresets(true);
        } else {
            updateUiButtonAction('exportChainsAsXyPresets', '.toggle-op-xy-preset-bundling');
            settings.spacedChainMode = 'dt' === commonSelectDevice;
            updateSpacedChainMode();
        }
    }

    if (files.length > 0) {
        files.filter(f => f.buffer.numberOfChannels > 1).
          forEach(f => f.waveform = false);
    }
    if (resampleState) {
        files = files.map(f => bufferRateResampler(f));
    }
    if (settingsPanelEl.open) {
        settingsPanelEl.close();
    }
    renderList();
}

function checkAudioContextState() {
    if (audioCtx.state === 'closed') {
        setLoadingText('');
        showToastMessage(
          'ERROR: The Audio Context has been closed, please refresh the browser tab.', 30000);
        return true;
    }
    if (['interrupted', 'suspended'].includes(audioCtx.state)) {
        audioCtx.resume();
    }
    return false;
}

function bufferRateResampler(f, workingSR, audioCtxOverride)  {
    let audioBuffer, slices;
    let channel0 = (f.buffer.channel0 || f.buffer.getChannelData(0));
    let channel1 = f.buffer.numberOfChannels === 2 ? (f.buffer.channel1 || f.buffer.getChannelData(1)) : false;
    workingSR = workingSR || masterSR;

    if (f.buffer.sampleRate !== workingSR) {
        let resample, resampleR;
        resample = new Resampler(f.buffer.sampleRate, workingSR, 1,
            channel0);
        resample.resampler(resample.inputBuffer.length);

        if (f.buffer.numberOfChannels === 2) {
            resampleR = new Resampler(f.buffer.sampleRate, workingSR, 1,
                channel1);
            resampleR.resampler(resampleR.inputBuffer.length);
        }

        audioBuffer = (audioCtxOverride??audioCtx).createBuffer(
            f.buffer.numberOfChannels,
            resample.outputBuffer.length,
            workingSR
        );
        audioBuffer.copyToChannel(resample.outputBuffer, 0);
        if (f.buffer.numberOfChannels === 2) {
            audioBuffer.copyToChannel(resampleR.outputBuffer, 1);
        }
        if (Array.isArray(f.meta.slices)) {
            slices = f.meta.slices.map(slice => ({
                ...slice,
                s: Math.round((slice.s / f.buffer.sampleRate) * workingSR),
                /*If the slice end  is the end of the buffer, set it to the end of the resample buffer.*/
                e: slice.e === f.buffer.length ?
                  Math.round(resample.outputBuffer.length) :
                  Math.round((slice.e / f.buffer.sampleRate) * workingSR),
                l: slice.l && slice.l > -1 ? Math.round((slice.l / f.buffer.sampleRate) * workingSR) : -1
            }));
        }

    } else {
        audioBuffer = (audioCtxOverride??audioCtx).createBuffer(
            f.buffer.numberOfChannels,
            f.buffer.length,
            workingSR
        );
        audioBuffer.copyToChannel(channel0, 0);
        if (f.buffer.numberOfChannels === 2) {
            audioBuffer.copyToChannel(channel1, 1);
        }
    }
    return {
        file: f.file,
        meta: {
            ...f.meta,
            slices: Array.isArray(slices) ? slices : f.meta.slices || false,
            length: audioBuffer.length,
            duration: Number(audioBuffer.length / workingSR).toFixed(3)
        },
        buffer: audioBuffer
    };
}

const getFileById = (id) => {
    return files.find(f => f.meta.id === id);
};
const getFileIndexById = (id) => {
    return files.findIndex(f => f.meta.id === id);
};
const getRowElementById = (id, tableId = '#masterList') => {
    return document.querySelector(`${tableId} tr[data-id="${id}"]`);
};
const toggleModifier = (key) => {
    if (key === 'shiftKey' || key === 'ctrlKey' || key === 'metaKey') {
        key = key === 'metaKey' ? 'ctrlKey' : key;
        modifierKeys[key] = !modifierKeys[key];
        document.getElementById('modifierKey' + key).classList[modifierKeys[key]
          ? 'add'
          : 'remove']('active');
        document.body.classList[modifierKeys[key] ? 'add' : 'remove'](
          key + '-mod-down');
    }
};

const closePopUps = () => {
    lastSelectedRow?.focus();
    document.querySelectorAll('.pop-up').
      forEach(w => w.classList.remove('show'));
    document.querySelectorAll('.dialog-pop-up').
      forEach(w => w.open ? w.close() : false);
    stopPlayFile(false, editor.getLastItem());
    renderList();
    try {
        lastSelectedRow = getRowElementById(lastSelectedRow.dataset.id);
        lastSelectedRow.classList.add('selected');
        lastSelectedRow.scrollIntoViewIfNeeded(true);
    } catch (e) {}
};

const arePopUpsOpen = () => {
    return ([...document.querySelectorAll('.pop-up')].some(
        w => w.classList.contains('show')) ||
      document.querySelectorAll('dialog[open]').length > 0);
};

const toggleOptionsPanel = () => {
    const buttonsEl = document.getElementById('allOptionsPanel');
    const toggleButtonEl = document.getElementById('toggleOptionsButton');
    buttonsEl.classList.contains('hidden') ? buttonsEl.classList.remove(
      'hidden') : buttonsEl.classList.add('hidden');
    buttonsEl.classList.contains('hidden') ? toggleButtonEl.classList.add(
      'collapsed') : toggleButtonEl.classList.remove('collapsed');
};

const toggleListVisibility = () => {
    showSamplesList = !showSamplesList;
    renderList(true);
};

function chainFileNamesAvailable(getCount = false) {
    const count = chainFileNames.filter(f => !f.used).length;
    return getCount ? count : count > 0;
}

function getNextChainFileName(length) {
    const chainNameBtnEl = document.querySelector('.chain-name-toggle');
    let item = chainFileNames.filter(f => !f.used)[0];
    item.used = true;
    chainNameBtnEl.dataset.count = `${chainFileNamesAvailable()
      ? chainFileNamesAvailable(true)
      : ''}`;
    chainNameBtnEl.classList[chainNameBtnEl.dataset.count ? 'remove' : 'add'](
      'fade');
    return `${item.name}--[${length}].wav`;
}

function generateChainNames() {
    chainFileNames = [
        ...new Set(files.filter(f => f.file.path).map(f => f.file.path))].map(
      p => ({name: p.replace(/\W+/gi, ''), used: false}));
    renderChainNamePanelContent();
}

async function changeChainName(event, index, action) {
    let item;
    if (action === 'remove-all') {
        event.preventDefault();
        let confirmRemove = await dcDialog('confirm',
          `Are you sure you want to remove all the chain names below?`, { kind: 'warning', okLabel: 'Remove All' });
        if (confirmRemove) {
            chainFileNames = [];
        }
        return renderChainNamePanelContent();
    }
    if (index === undefined) {
        item = {name: '', used: false};
    } else {
        item = chainFileNames[index];
    }
    if ((index > -1) && action === 'remove') {
        event.preventDefault();
        let confirmRemove = await dcDialog('confirm',
          `Are you sure you want to remove the chain name '${item.name}'?`, { kind: 'warning', okLabel: 'Remove' });
        if (confirmRemove) {
            chainFileNames.splice(index, 1);
        }
        return renderChainNamePanelContent();
    } else if ((index > -1) && action === 'reuse') {
        event.preventDefault();
        item.used = false;
        return renderChainNamePanelContent();
    }

    let newName = await dcDialog('prompt',
      'Please enter a name for the chain, names must be unique', {defaultValue: item.name});
    if (newName) {
        item.name = newName;
        if (index === undefined && chainFileNames.findIndex(
          n => n.name.toLowerCase() === newName.toLowerCase()) === -1) {
            chainFileNames.push(item);
        }
        renderChainNamePanelContent();
    }
}

function renderChainNamePanelContent() {
    const chainNameBtnEl = document.querySelector('.chain-name-toggle');
    const chainFileNameListPanelEl = document.getElementById(
      'chainFileNameListPanel');
    const contentEl = chainFileNameListPanelEl.querySelector('.content');
    const namesHtml = chainFileNames.sort((a, b) => a.used - b.used).
      reduce((a, v, i) => a += `
        <tr>
        <td
            class="chain-file-name-option ${v.used ? 'used' : ''}"
            onpointerdown="digichain.changeChainName(event, ${i})"
        >${v.name} </td>
        <td>
        <button title="Remove this name from the list." class="remove-chain float-right button-clear" onpointerdown="digichain.changeChainName(event, ${i}, 'remove')"><i class="gg-remove"></i></button>
        <button title="Reset this name so it can be reused for a sample chain name." class="reuse-chain p-0 float-right button-clear ${v.used
        ? ''
        : 'hidden'}" onpointerdown="digichain.changeChainName(event, ${i}, 'reuse')"><i class="gg-undo"></i></button>
        </td>
        </tr>
`, '');
    chainNameBtnEl.dataset.count = `${chainFileNamesAvailable()
      ? chainFileNamesAvailable(true)
      : ''}`;
    chainNameBtnEl.classList[chainNameBtnEl.dataset.count ? 'remove' : 'add'](
      'fade');
    contentEl.innerHTML = `
    <div class="row">
      <div class="column mh-60vh">
          <table>
              <tr>
                  <th class="p-0"><h5>Sample Chain Names</h5></th>
                  <th class="p-0"><button title="Remove all names from the list." class="remove-chain float-right button-clear" style="transform: translateX(-0.5rem);" onpointerdown="digichain.changeChainName(event, -1, 'remove-all')"><i class="gg-remove"></i></button></th>
              </tr>
              <tbody>
                  ${namesHtml}
              </tbody>
          </table>
      </div>
    </div>
    <div style="padding-top:1rem;">
        <button title="Generates a list of filenames based on the folder path of the files in the list. This will replace all other names in the sample names list." class="button-outline float-left" onpointerdown="digichain.generateChainNames()">Generate</button>
        <button title="Add a name to use for sample chains, if the list is empty, or all the names have already been used, the DigiChain default naming convention will be used. (Names must be unique, caps are ignored.)" class="button float-right" onpointerdown="digichain.changeChainName(event)">Add Name</button>
    </div>
    `;
}

function toggleChainNamePanel() {
    const chainFileNameListPanelEl = document.getElementById(
      'chainFileNameListPanel');
    chainFileNameListPanelEl.open
      ? chainFileNameListPanelEl.close()
      : chainFileNameListPanelEl.showModal();
    if (chainFileNameListPanelEl.open) {
        renderChainNamePanelContent();
    }
}

function closeSplitOptions(event) {
    const el = document.getElementById('splitOptions');
    if (el.open) {
        el.close();
    }
    stopPlayFile(event, lastSelectedRow.dataset.id);
}

const showEditPanel = (event, id, view = 'sample') => {
    let data, folderOptions;
    if (view === 'opExport') {
        lastOpKit = files.filter(f => f.meta.checked);
        data = lastOpKit;
    } else {
        if (id && view !== 'opExport') {
            lastSelectedRow = getRowElementById(id);
        }
        folderOptions = [...new Set(files.map(f => f.file.path))];
        data = getFileById(id || lastSelectedRow.dataset.id);
    }
    showEditor(
      data,
      {
          audioCtx,
          masterSR,
          targetSR,
          masterChannels,
          masterBitDepth,
          storeState: () => storeState(true)
      },
      view,
      folderOptions
    );
};

const closeEditPanel = () => {
    const editPanelEl = document.getElementById('editPanel');
    if (editPanelEl.open) {
        editPanelEl.close();
    }
    files.forEach(f => delete f.meta.editing);
    digichain.stopPlayFile(false, digichain.editor.getLastItem());
    if (document.querySelector('#opExportPanel.show')) {
        return digichain.showEditPanel(event, false, 'opExport');
    }
    digichain.renderList();
};

function isOpExportPanelOpen() {
    return document.querySelector('#opExportPanel.show');
}

function checkShouldExportOtFile(skipExportWithCheck = false) {
    return (settings.exportWithOtFile || skipExportWithCheck) && targetSR === 44100 &&
      targetContainer === 'w';
}

async function setWavLink(file, linkEl, renderAsAif, useTargetSR, bitDepthOverride) {
    let fileName = getNiceFileName('', file, false, true);
    let wav, wavSR, blob;

    fileName = targetContainer === 'a' ?
      fileName.replace('.wav', '.aif') :
      fileName;

    file.meta.slices = file.meta.slices || metaFiles.getByFileInDcFormat(file);

    wav = audioBufferToWav(
      file.buffer, {...file.meta, renderAt: useTargetSR ? targetSR : false}, masterSR, (bitDepthOverride || masterBitDepth),
      masterChannels, settings.deClick,
      (renderAsAif && settings.pitchModifier === 1), settings.pitchModifier, embedSliceData,
      settings.embedCuePoints, settings.embedOrslData
    );
    wavSR = wav.sampleRate;
    wav = wav.buffer;
    blob = new window.Blob([new DataView(wav)], {
        type: renderAsAif && settings.pitchModifier === 1 ? 'audio/aiff' : 'audio/wav'
    });
    if (settings.pitchModifier !== 1) {
        let linkedFile = await fetch(URL.createObjectURL(blob));
        let arrBuffer = await linkedFile.arrayBuffer();
        let pitchedBuffer = await audioCtx.decodeAudioData(arrBuffer);
        let meta = {...file.meta};
        meta.slices = meta.slices.map(slice => ({
            ...slice,
            n: slice.n, s: Math.round(slice.s / settings.pitchModifier),
            e: Math.round(slice.e / settings.pitchModifier),
            l: (!slice.l || slice.l) === -1 ? -1 : Math.round(
              slice.l / settings.pitchModifier)
        }));
        wav = audioBufferToWav(
          pitchedBuffer, {...meta, renderAt: useTargetSR ? targetSR : false}, masterSR, (bitDepthOverride || masterBitDepth),
          masterChannels, settings.deClick,
          renderAsAif, 1, embedSliceData, settings.embedCuePoints, settings.embedOrslData
        );
        wavSR = wav.sampleRate;
        wav = wav.buffer;
        blob = new window.Blob([new DataView(wav)], {
            type: renderAsAif ? 'audio/aiff' : 'audio/wav'
        });
    }

    linkEl.href = URL.createObjectURL(blob);
    linkEl.setAttribute('download', fileName);

    return {blob, sampleRate: wavSR};
}

async function downloadAll(event) {
    const _files = files.filter(f => f.meta.checked);
    const flattenFolderStructure = (event.shiftKey || modifierKeys.shiftKey);
    const links = [];
    const el = document.getElementById('getJoined');
    const renderAsAif = targetContainer === 'a';
    if (_files.length === 0) { return; }
    if (_files.length > 5 && !settings.zipDownloads) {
        const userReadyForTheCommitment = await dcDialog('confirm',
          `You are about to download ${_files.length} files, that will show ${_files.length} pop-ups one after each other..\n\nAre you ready for that??`, {
            kind: 'info', okLabel: 'Absolutely'
          });
        if (!userReadyForTheCommitment) { return; }
    }
    setLoadingText('Processing');

    if (settings.zipDownloads && _files.length > 1) {
        const zip = new JSZip();
        for (const file of _files) {
            const wav = await setWavLink(file, el, renderAsAif, true);
            let fileName = '';
            fileName = targetContainer === 'a' ?
              fileName.replace('.wav', '.aif') :
              fileName;
            if (flattenFolderStructure) {
                fileName = getNiceFileName(
                  '', file, false, true
                );
                fileName = targetContainer === 'a' ?
                  fileName.replace('.wav', '.aif') :
                  fileName;
                zip.file(fileName, wav.blob, {binary: true});
                let otFile = await createAndSetOtFileLink(
                  file.meta.slices ?? [], file, fileName);
                if (otFile) {
                    zip.file(otFile.name, otFile.blob, {binary: true});
                }
            } else {
                let fileName = getNiceFileName('', file, false);
                fileName = targetContainer === 'a' ?
                  fileName.replace('.wav', '.aif') :
                  fileName;
                zip.file(file.file.path + fileName, wav.blob, {binary: true});
                let otFile = await createAndSetOtFileLink(
                  file.meta.slices ?? [], file, fileName);
                if (otFile) {
                    zip.file(file.file.path + otFile.name, otFile.blob,
                      {binary: true});
                }
            }
        }
        const zipName = `digichain_${Date.now()}.zip`;
        if (window.__TAURI__) {
            zip.generateAsync({type: 'uint8array'}).then(async _data => {
                await window.__TAURI__.fs.writeFile(zipName, _data, {
                    baseDir: window.__TAURI__.fs.BaseDirectory.Download,
                    create: true
                });
                setLoadingText('');
                window.__TAURI__.dialog.message(`Saved to the Downloads folder as '${zipName}'.`);
            });
        } else {
            zip.generateAsync({type: 'blob'}).then(blob => {
                const el = document.getElementById('getJoined');
                el.href = URL.createObjectURL(blob);
                el.setAttribute('download', zipName);
                el.click();
                setLoadingText('');
            });
        }
        return;
    }

    for (const file of _files) {
        const link = await downloadFile(file.meta.id);
        link.forEach(l => links.push(l));
    }

    const intervalId = setInterval(() => {
        const lnk = links.shift();
        lnk?.click();
        if (links.length === 0 && lnk) {
            clearInterval(intervalId);
            setLoadingText('');
        }
    }, 500);

}

async function downloadFile(id, fireLink = false, event = {}) {
    const el = getRowElementById(id).querySelector('.wav-link-hidden');
    const metaEl = getRowElementById(id).querySelector('.meta-link-hidden');
    const file = getFileById(id);
    const renderAsAif = targetContainer === 'a';
    await setWavLink(file, el, renderAsAif, true);
    let otFile = await createAndSetOtFileLink(
        file.meta.slices ?? [], file, file.file.name, metaEl);
    if (fireLink && (!settings.shiftClickForFileDownload || (settings.shiftClickForFileDownload && event.shiftKey))) {
        el.click();
        if (otFile) {metaEl.click(); }
    }
    return [el, metaEl];
}

async function attachDragDownloadBlob(event, id) {
    const renderAsAif = targetContainer === 'a';
    let file = getFileById(id);
    let blobLink = {
        href: '',
        setAttribute: function(a, fname) { this.fileName = fname; }
    };
    let blobData = await setWavLink(file, blobLink, renderAsAif, true);
    event.dataTransfer.setData('DownloadURL', `audio/x-wav:${blobLink.fileName}:${blobLink.href}`);
}

function toggleSelectedActionsList() {
    const actionListEl = document.querySelector(
      `.selected-actions-button-list`);
    actionListEl.style.display = actionListEl.style.display === 'none'
      ? 'flex'
      : 'none';
}

function removeSelected() {
    metaFiles.removeSelected();
    files.filter(f => f.meta.checked).forEach(f => remove(f.meta.id, true));
    files = files.filter(f => !f.meta.checked);
    unsorted = unsorted.filter(id => files.find(f => f.meta.id === id));
    importOrder = importOrder.filter(id => unsorted.includes(id));
    setCountValues();
    if (files.length === 0 || unsorted.length === 0) {
        files.forEach(f => f.buffer ? delete f.buffer : false);
        files = [];
        unsorted = [];
        importOrder = [];
    }
    renderList();
    return storeState();
}

function normalizeSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.normalize(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function trimRightSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.trimRight(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

async function condenseSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    let lower = await dcDialog('prompt',
      `Please enter the LOWER threshold (decimal value between 0 and 1)...`);
    if (lower && !isNaN(lower)) {
        lower = Math.abs(+lower);
    } else { return ;}
    let upper = await dcDialog('prompt',
      `Please enter the UPPER threshold (decimal value between 0 and 1)...`);
    if (upper && !isNaN(upper)) {
        upper = Math.abs(+upper);
    } else { return ;}
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.thresholdCondense(event, f, false, +lower, +upper);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function roughStretchSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.roughStretch(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function shortenNameSelected(event, restore = false) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        let nameList = {};
        let nameListArr = [];
        if (!restore) {
            nameList = {};
            nameListArr = files.map(f => {
                nameList[f.meta.id] = {
                    path: f.file.path.split('/').
                      map(p => p.substring(0, 12)).
                      join('/'),
                    name: f.file.name.substring(0, 12) +
                      (f.meta.note ? `-${f.meta.note}` : '')
                };
                nameList[f.meta.id].joined = `${nameList[f.meta.id].path}${nameList[f.meta.id].name}`;
                return {name: nameList[f.meta.id].joined, available: true};
            });
        }
        selected.forEach((f, idx) => {
            f.file.origPath = f.file.origPath || f.file.path;
            f.file.origName = f.file.origName || f.file.name;
            if (restore) {
                f.file.path = f.file.origPath;
                f.file.name = f.file.origName;
            } else {
                const sn = nameList[f.meta.id];
                const names = nameListArr.filter(
                  n => n.name === sn.joined && n.available);
                f.file.path = sn.path;
                f.file.name = names.length === 1 ? sn.name : sn.name +
                  `-${names.length}`;
                names[0].available = false;
            }
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function sanitizeNameSelected(event, restore = false) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');

    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        editor.sanitizeName(event, files, selected, restore);
        renderList();
    }, 250);
}

async function truncateSelected(event) {
    let truncLength = 3;
    if (event.shiftKey || modifierKeys.shiftKey) {
        const userResponse = await dcDialog('prompt',
          `Please enter a custom length in seconds to truncate the selected samples to...`);
        if (userResponse && !isNaN(userResponse)) {
            truncLength = Math.abs(+userResponse) || 3;
        } else { return; }
    }
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.truncate(event, f, false, truncLength);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

async function stretchSelected(event, shortest = false) {
    let sortedItems = files.filter(
      f => f.meta.checked
    ).sort(
      (a, b) => b.buffer.length - a.buffer.length
    );
    if (shortest === true) {
        sortedItems.reverse();
    }
    let stretchLength = sortedItems[0].buffer.length;
    if (event.shiftKey || modifierKeys.shiftKey) {
        const unitOfMeasure = event.ctrlKey || event.metaKey || modifierKeys.ctrlKey ? 'samples' : 'seconds';
        const userResponse = await dcDialog('prompt',
          `Please enter a custom length in ${unitOfMeasure} to stretch the selected samples to...`);
        if (userResponse) {
            if (['x', '*'].includes(userResponse[0])) {
                stretchLength = (bufferLength) => Math.floor(
                  bufferLength * (+userResponse.replace(/[^0-9.]/g, '')));
            } else if (['/', '%', '÷'].includes(userResponse[0])) {
                stretchLength = (bufferLength) => Math.floor(
                  bufferLength / (+userResponse.replace(/[^0-9.]/g, '')));
            } else if (!isNaN(userResponse)) {
                stretchLength = Math.floor(Math.abs(+userResponse) * (unitOfMeasure === 'seconds' ? masterSR : 1));
            }
        }
    }
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            if (typeof stretchLength === 'function') {
                editor.stretch(event, f, false, stretchLength(f.buffer.length));
            } else {
                editor.stretch(event, f, false, stretchLength);
            }
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function reverseSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.reverse(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function shiftSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.shift(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function invertSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.invert(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function flipChannelsSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.flipChannels(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function nudgeCrossingsSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.nudgeCrossings(event, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

async function padWithZeroSelected(event, shortest = false) {
    let customPadLength = 0;
    if (event.shiftKey || modifierKeys.shiftKey) {
        const userResponse = await dcDialog('prompt',
          `Please enter a custom length in seconds to pad the selected samples to...`);
        if (userResponse && !isNaN(userResponse)) {
            customPadLength = Math.floor(Math.abs(+userResponse) * masterSR);
        }
    }
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.padWithZero(event, f, customPadLength, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function serializeSelected(event, method = 'LR') {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(
          f => f.meta.checked && f.buffer.numberOfChannels === 2);
        selected.forEach((f, idx) => {
            editor.serialize(event, f, false, method);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function deserializeSelected(event, method = 'LR') {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(
          f => f.meta.checked && f.buffer.numberOfChannels === 1);
        selected.forEach((f, idx) => {
            editor.deserialize(event, f, false, method);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function pitchUpSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.perSamplePitch(event, 2, -12, f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function doubleSelected(event, pingPong = false) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.double(event, f, pingPong, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function pingPongSelected(event) {
    doubleSelected(event, true);
}

function fuzzSelected(event) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            editor.fade('fuzz', f, false);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

async function crushSelected(event) {
    let crushAmount = 25;
    if (event.shiftKey || modifierKeys.shiftKey) {
        const userResponse = await dcDialog('prompt',
          `Please enter a custom crush amount (25 is the default, above 127 will sound the same)...`);
        if (userResponse && !isNaN(userResponse)) {
            crushAmount = Math.abs(+userResponse);
        }
    }
    crushAmount = Math.min(Math.floor(Math.abs(crushAmount)), 127);

    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(async () => {
        const selected = files.filter(f => f.meta.checked);
        await new Promise(resolve => selected.forEach((f, idx) => {
            editor.perSamplePitch(event, 1, 1, f, false, crushAmount, 8);
            if (idx === selected.length - 1) {
                resolve(true);
            }
        }));
        await new Promise(
          resolve => setTimeout(() => (selected.forEach((f, idx) => {
              //editor.perSamplePitch(event, .5, 12, f, false);
              editor.normalize(event, f, false);
              if (idx === selected.length - 1) {
                  setLoadingText('');
                  resolve(true);
              }
          })), 1000));
        renderList();
    }, 250);
}

function fadeSelected(event, type) {
    files.forEach(f => f.meta.checked ? f.source?.stop() : '');
    setLoadingText('Processing');
    setTimeout(() => {
        const selected = files.filter(f => f.meta.checked);
        selected.forEach((f, idx) => {
            let start = 0,
              end = f.buffer.length < 256 ? f.buffer.length : 256;
            if (type === 'out') {
                start = f.buffer.length < 256 ? 0 : f.buffer.length - 256;
                end = f.buffer.length;
            }
            editor.fade(type, f, false, start, end, true);
            if (idx === selected.length - 1) {
                setLoadingText('');
            }
        });
        renderList();
    }, 250);
}

function showWelcome() {
    if (settings.showWelcomeModalOnLaunchIfListEmpty && unsorted.length === 0) {
        const welcomeModalEl = document.querySelector('#welcomePanelMd');
        const tipEl = document.querySelector('#tipElement');
        const showTipNumber = Math.floor(Math.random() * tipEl.children.length + 1);
        [...tipEl.children].forEach((tip, tipId) => tip.style.display = tipId + 1 === showTipNumber ? 'block' : 'none');
        if (!welcomeModalEl.open) {
            welcomeModalEl.showModal();
        }

    }
}

function pitchExports(value, silent) {
    const octaves = {
        2: 1,
        4: 2,
        8: 3
    };
    if ([.25, .5, 1, 2, 4, 8].includes(+value)) {
        settings.pitchModifier = +value;
        infoEl.textContent = settings.pitchModifier === 1
          ? ''
          : `All exported samples will be pitched up ${octaves[settings.pitchModifier]} octave${settings.pitchModifier >
          2 ? 's' : ''}`;
        if (silent) { return; }
        setCountValues();
        showExportSettingsPanel();
    }
    return value;
}

function toggleSetting(param, value, suppressRerender) {
    if (value === undefined || typeof value === 'boolean') {
        settings[param] = value === undefined ? !settings[param] : value;
    }

    if (param === 'darkModeTheme') {
        document.body.classList[
          settings.darkModeTheme ? 'remove' : 'add'
          ]('light');
    }
    if (param === 'normalizeContrast') {
        document.body.classList[
          settings.normalizeContrast ? 'add' : 'remove'
          ]('normalize-contrast');
    }
    if (param === 'retainSessionState') {
        if (settings.retainSessionState) {
            configDb(true);
        } else {
            clearDbBuffers();
        }
    }
    if (param === 'showTouchModifierKeys') {
        document.querySelector('.touch-buttons').classList[
          settings.showTouchModifierKeys ? 'remove' : 'add'
          ]('hidden');
    }
    if (param === 'playWithPopMarker') {
        settings.playWithPopMarker = value;
        files.forEach(f => f.meta.peak = undefined);
    }
    if (param === 'deClick') {
        settings.deClick = value;
    }
    if (param === 'skipMiniWaveformRender') {
        renderList();
    }
    if (param === 'splitOutExistingSlicesOnJoin') {
        setCountValues();
    }
    if (suppressRerender) { return; }
    showExportSettingsPanel();
}

async function setCustomSecondsPerFileValue(targetEl, size, silent = false) {
    let newValue = size;
    if (!silent) {
        newValue = await dcDialog('prompt',
          `Change max seconds per file "${size}" to what new value?`, {defaultValue: size});
    }
    if (newValue && !isNaN(newValue)) {
        newValue = Math.abs(Math.ceil(+newValue));
        secondsPerFile = +newValue;
        targetEl.textContent = newValue;
    }
    return +newValue;
}

function toggleSecondsPerFile(event, value) {
    const toggleEl = document.querySelector('.toggle-seconds-per-file');
    const toggleSpanEl = document.querySelector(
      '.toggle-seconds-per-file span');
    if (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) {
        value = setCustomSecondsPerFileValue(toggleSpanEl, secondsPerFile) ||
          value;
    }
    if (value !== undefined) {
        secondsPerFile = value;
    } else {
        secondsPerFile = secondsPerFile === 0 ?
          (masterChannels === 2 ? 20 : 12) :
          0;
    }
    if (secondsPerFile === 0) {
        toggleEl.classList.remove('on');
        toggleSpanEl.innerText = 'off';
    } else {
        toggleEl.classList.add('on');
        toggleSpanEl.innerText = `${secondsPerFile}s`;
        selectSliceAmount({
            shiftKey: false,
            target: document.querySelector('.slice-grid-off')
        }, 0);
    }
    setCountValues();
}

function updateSpacedChainMode(toggleSetting) {
    const spacedEl = document.querySelector('button.dl-spaced');
    const chainEl = document.querySelector('button.dl-chain');
    const spacedToggleEl = document.querySelector('.toggle-spaced-chain-mode')
    if (toggleSetting && !settings.exportChainsAsXyPresets) {
        settings.spacedChainMode = !settings.spacedChainMode;
    }
    spacedToggleEl.classList[settings.spacedChainMode ? 'remove' : 'add']('fade');
    spacedEl.style.display = settings.spacedChainMode ? 'block' : 'none';
    chainEl.style.display = settings.spacedChainMode ? 'none' : 'block';
}

function updateUiButtonAction(param, buttonClass, toggleSetting, forceValue) {
    const buttonEl = document.querySelector(buttonClass);
    if (toggleSetting) {
        settings[param] = forceValue === undefined ? !settings[param] : forceValue;
    }
    buttonEl.classList[settings[param]? 'remove' : 'add']('fade');
}

function updateExportChainsAsXyPresets(toggleSetting) {
    if (!settings.exportChainsAsXyPresets && settings.spacedChainMode) {
        updateSpacedChainMode(true);
    }
    updateUiButtonAction('exportChainsAsXyPresets', '.toggle-op-xy-preset-bundling', toggleSetting);
    setCountValues();
}

function toggleHelp() {
    const helpToggleEl = document.querySelector('.toggle-help-panel');
    const helpEnabled = document.body.classList.contains('show-help');
    document.body.classList[helpEnabled ? 'remove' : 'add']('show-help');
    document.querySelector('.help-text').classList[helpEnabled
      ? 'add'
      : 'remove']('hidden');
    helpToggleEl.classList[helpEnabled ? 'add' : 'remove']('fade');
    if (helpToggleEl.dataset.interval) {
        clearInterval(+helpToggleEl.dataset.interval);
        helpToggleEl.dataset.interval = null;
    }
    if (!helpEnabled) {
        const intervalId = setInterval(() => {
            const helpTextEl = document.querySelector('.help-text');
            const activeEl = document.activeElement;
            helpTextEl.textContent = activeEl.title;
            helpTextEl.classList[activeEl.title ? 'remove' : 'add']('fade');
        }, 500);
        helpToggleEl.dataset.interval = `${intervalId}`;
    }
}

function changeOpParam(event, id, param, value) {
    const rowEl = getRowElementById(id);
    const item = getFileById(id);
    if (param === 'bal') {
        event.draggable = false;
        event.preventDefault();
        const balEl = rowEl.querySelector(
          '.channel-options-stereo-opf .channel-balance');
        let newValue = +event.target.value ?? 16384;
        newValue = newValue - newValue % 1024;
        item.meta.opPan = newValue;
    }
    if (param === 'baltoggle') {
        item.meta.opPanAb = !item.meta.opPanAb;
        rowEl.querySelector('.channel-options-stereo-opf').classList[
          item.meta.opPanAb ? 'add' : 'remove']('op-pan-ab-true');
    }
    return false;
}

function showExportSettingsPanel(page = 'settings') {
    const panelEl = document.querySelector('#exportSettingsPanel');
    const panelContentEl = document.querySelector(
      '#exportSettingsPanel .content');

    panelEl.dataset.page = page;

    let panelMarkup = `
      <div class="export-options">
          <span class="${page === 'about' || !page ? 'active': ''}" onpointerdown="digichain.showExportSettingsPanel('about')">About</span>
          <span class="${page === 'audio' ? 'active': ''}" onpointerdown="digichain.showExportSettingsPanel('audio')">Audio Config</span>
          <span class="${page === 'session' || !page ? 'active': ''}" onpointerdown="digichain.showExportSettingsPanel('session')">Session</span>
          <span class="${page === 'settings' ? 'active': ''}" onpointerdown="digichain.showExportSettingsPanel('settings')">Settings</span>
      </div>
    `;
    switch (page) {
        case 'settings':
            panelMarkup += `
      <span class="settings-info">All settings here will persist when the app re-opens.</span>
      <table style="padding-top:0;">
      <thead>
      <tr>
      <th width="68%"></th>
      <th></th>
    </tr>
    </thead>
      <tbody>
      <tr>
      <td><span>Pitch up exported files by octave &nbsp;&nbsp;&nbsp;</span></td>
      <td>    <button onpointerdown="digichain.pitchExports(1)" class="check ${settings.pitchModifier ===
            1 ? 'button' : 'button-outline'}">OFF</button>
      <button onpointerdown="digichain.pitchExports(2)" class="check ${settings.pitchModifier ===
            2 ? 'button' : 'button-outline'}">1</button>
      <button onpointerdown="digichain.pitchExports(4)" class="check ${settings.pitchModifier ===
            4 ? 'button' : 'button-outline'}">2</button>
      <button onpointerdown="digichain.pitchExports(8)" class="check ${settings.pitchModifier ===
            8 ? 'button' : 'button-outline'}">3</button><br></td>
    </tr>
    <tr>
    <td><span>Reverse all even samples in a chain? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('reverseEvenSamplesInChains')"
     title="When enabled, all even samples in chains will be reversed (back-to-back mode)."
     class="check ${settings.reverseEvenSamplesInChains
              ? 'button'
              : 'button-outline'}">${settings.reverseEvenSamplesInChains ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Restore the last used Sample Rate/Bit Depth/Channel? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('restoreLastUsedAudioConfig')" class="check ${settings.restoreLastUsedAudioConfig
              ? 'button'
              : 'button-outline'}">${settings.restoreLastUsedAudioConfig ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Retain session data between browser refreshes? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('retainSessionState')" class="check ${settings.retainSessionState
              ? 'button'
              : 'button-outline'}">${settings.retainSessionState ? 'YES' : 'NO'}</button></td>
    </tr>
      <tr>
      <td><span>Play pop markers when playing back samples?&nbsp;&nbsp;&nbsp;</span></td>
      <td>
      <button onpointerdown="digichain.toggleSetting('playWithPopMarker', 0)" class="check ${settings.playWithPopMarker ===
            0 ? 'button' : 'button-outline'}">OFF</button>
      <button title="0db prevents DT normalization." onpointerdown="digichain.toggleSetting('playWithPopMarker', 1)" class="check ${settings.playWithPopMarker ===
            1 ? 'button' : 'button-outline'}">0db</button>
      <button title="Peak sets pop to loudest sample peak." onpointerdown="digichain.toggleSetting('playWithPopMarker', 2)" class="check ${settings.playWithPopMarker ===
            2 ? 'button' : 'button-outline'}">Peak</button>
      </td>
      </tr>
      <td><span>Try to match start/end sample when cropping/truncating?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Could give shorter length samples than specified but can help
       reduce clicks on looping cropped/truncated samples" onpointerdown="digichain.toggleSetting('attemptToFindCrossingPoint')" class="check ${settings.attemptToFindCrossingPoint
              ? 'button'
              : 'button-outline'}">${settings.attemptToFindCrossingPoint ? 'YES' : 'NO'}</button></td>
    </tr>
        <tr>
      <td><span>De-click exported samples?<br>Helps when importing non-wav files of a different<br>sample rate than the export file, or small buffered audio interfaces. &nbsp;&nbsp;&nbsp;</span></td>
      <td>
      <button onpointerdown="digichain.toggleSetting('deClick', 0)" class="check ${+settings.deClick ===
            0 ? 'button' : 'button-outline'}">OFF</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.1)" class="check ${+settings.deClick ===
            0.1 ? 'button' : 'button-outline'}">&gt;10%</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.2)" class="check ${+settings.deClick ===
            0.2 ? 'button' : 'button-outline'}">&gt;20%</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.3)" class="check ${+settings.deClick ===
            0.3 ? 'button' : 'button-outline'}">&gt;30%</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.4)" class="check ${+settings.deClick ===
            0.4 ? 'button' : 'button-outline'}">&gt;40%</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.5)" class="check ${+settings.deClick ===
            0.5 ? 'button' : 'button-outline'}">&gt;50%</button>
      <button onpointerdown="digichain.toggleSetting('deClick', 0.75)" class="check ${+settings.deClick ===
            0.75 ? 'button' : 'button-outline'}">&gt;75%</button>
      </td>
      </tr>
    <tr>
    <td><span>Download multi-file/joined downloads as one zip file? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('zipDownloads')" class="check ${settings.zipDownloads
              ? 'button'
              : 'button-outline'}">${settings.zipDownloads ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>When exporting stereo, export dual mono files as mono? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Often, stereo files are just the same mono audio data on both channels, if this is the case, export the file as mono." onpointerdown="digichain.toggleSetting('treatDualMonoStereoAsMono')" class="check ${settings.treatDualMonoStereoAsMono
              ? 'button'
              : 'button-outline'}">${settings.treatDualMonoStereoAsMono ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr style="display: none;">
    <td><span>Embed slice information in exported wav files?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Embed the slice information into the wav file in DigiChain format, this includes start, end points and the source file name for the slice." onpointerdown="digichain.toggleSetting('embedSliceData')" class="check ${embedSliceData
              ? 'button'
              : 'button-outline'}">${embedSliceData ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Embed slice information as CUE points in exported wav files?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Embed slice data as wav CUE point markers, compatible with DirtyWave M8 slice sampler. The end points will extend to the start point of the next sample, or the end of the wav file for the last slice." onpointerdown="digichain.toggleSetting('embedCuePoints')" class="check ${settings.embedCuePoints
              ? 'button'
              : 'button-outline'}">${settings.embedCuePoints ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Treat slice data in files as distinct files on join?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="If a file already has slice information, when set to YES these slices will be treated as files when creating chains, if set to NO, per file slice data will be discarded." onpointerdown="digichain.toggleSetting('splitOutExistingSlicesOnJoin')" class="check ${settings.splitOutExistingSlicesOnJoin
              ? 'button'
              : 'button-outline'}">${settings.splitOutExistingSlicesOnJoin ? 'YES' : 'NO'}</button></td>
    </tr>
    <!--<tr>
    <td><span>Embed slice information as Lofi-12 XT points in exported wav files?<br>(Applied only to 12/24 kHz wav exports) &nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Embed slice data in wav file header in the Sonicware custom format for the Lofi-12 XT sampler." onpointerdown="digichain.toggleSetting('embedOrslData')" class="check ${settings.embedOrslData
              ? 'button'
              : 'button-outline'}">${settings.embedOrslData ? 'YES' : 'NO'}</button></td>
    </tr>-->
    <tr>
    <td><span>Create accompanying .ot metadata file?<br>(Applied only to 44.1 kHz 16/24 [non-aif] audio contexts) &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('exportWithOtFile')" class="check ${settings.exportWithOtFile
              ? 'button'
              : 'button-outline'}">${settings.exportWithOtFile ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Limit imports to maximum of 750 files?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="Enforces a limit of 750 files per import, to help prevent crashes on nested folders of many files - disabling may result in slow-downs or timeouts." onpointerdown="digichain.toggleSetting('importFileLimit')" class="check ${settings.importFileLimit
              ? 'button'
              : 'button-outline'}">${settings.importFileLimit ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Skip rendering the mini audio waveform in the list?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="When processing large lists of files, skiping the renderings of the waveform can improve the responsiveness of the browse as no canvas element per row will be rendered." onpointerdown="digichain.toggleSetting('skipMiniWaveformRender')" class="check ${settings.skipMiniWaveformRender
              ? 'button'
              : 'button-outline'}">${settings.skipMiniWaveformRender ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Show Shift/Ctrl modifier touch buttons?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('showTouchModifierKeys')" class="check ${settings.showTouchModifierKeys
              ? 'button'
              : 'button-outline'}">${settings.showTouchModifierKeys ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Shift+Click to download single files from the list?&nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('shiftClickForFileDownload')" class="check ${settings.shiftClickForFileDownload
              ? 'button'
              : 'button-outline'}">${settings.shiftClickForFileDownload ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Use Dark theme as the default? (No = Light theme)&nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('darkModeTheme')" class="check ${settings.darkModeTheme
              ? 'button'
              : 'button-outline'}">${settings.darkModeTheme ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Normalize text/waveform color contrast? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button onpointerdown="digichain.toggleSetting('normalizeContrast')" class="check ${settings.normalizeContrast
              ? 'button'
              : 'button-outline'}">${settings.normalizeContrast ? 'YES' : 'NO'}</button></td>
    </tr>
    <tr>
    <td><span>Show the welcome panel at launch? &nbsp;&nbsp;&nbsp;</span></td>
    <td><button title="The welcome panel will show at launch if the list is empty."
              onpointerdown="digichain.toggleSetting('showWelcomeModalOnLaunchIfListEmpty')" class="check ${settings.showWelcomeModalOnLaunchIfListEmpty
              ? 'button'
              : 'button-outline'}">${settings.showWelcomeModalOnLaunchIfListEmpty ? 'YES' : 'NO'}</button></td>
    </tr>
    </tbody>
    </table>
    `;
            break;
        case 'audio':
            panelMarkup += `
      <table style="padding-top:0;" id="settingAudioConfig">
      <thead>
      <tr>
      <th style="border: none;"></th>
      <th style="border: none;"></th>
    </tr>
    </thead>
      <tbody>
        <tr>
          <td style="border: none;"><span>Working Sample Rate (Hz)&nbsp;&nbsp;&nbsp;</span></td>
          <td style="border: none;">
              <div class="input-set" id="settingsWorkingSampleRateGroup" style="display: flex; align-items: flex-start;">
                  <input type="number" placeholder="Sample Rate between ${settings.supportedSampleRates.toString()}Hz"
                  onfocus="(() => {this.placeholder = this.value; this.value = '';})()"
                  onblur="(() => { this.value = this.value || this.placeholder; this.placeholder = this.dataset.placeholder;})()"
                  id="settingsWorkingSampleRate" value="${masterSR}" data-sample-rate="${masterSR}" list="commonSR"
                  data-placeholder="Sample Rate between ${settings.supportedSampleRates.toString()}"
                  min="${settings.supportedSampleRates[0]}" max="${settings.supportedSampleRates[1]}">
                  <datalist id="commonSR">
                    ${[12000, 24000, 32000, 44100, 48000].map(
              v => '<option value="' + v + '">').join('')}
                  </datalist>
                  <button title="Restore currently active working sample rate" class="button-clear" onpointerdown="(() => {const i = document.getElementById('settingsWorkingSampleRate'); i.value = i.dataset.sampleRate;})()"><i class="gg-undo"></i></button>
              </div>
          </td>
      </tr>
        <tr><td colspan="2"><span><small>Caution: Changing the working sample rate will resample any files currently in the list to the specified sample rate.</small></span><br><br></td></tr>
      <tr>
          <td style="border: none;"><span style="padding-top: 1rem; display: block;">Target Sample Rate (Hz)&nbsp;&nbsp;&nbsp;</span></td>
          <td style="border: none;">
              <div class="input-set ${targetContainer === 'a' ? 'disabled' : ''}" id="settingsSampleRateGroup" style="display: flex; align-items: flex-start; padding-top: .5rem;">
                  <input type="number" placeholder="Sample Rate between ${settings.supportedSampleRates.toString()}Hz"
                  ${targetContainer === 'a' ? 'disabled="disabled"' : ''}
                  onfocus="(() => {this.placeholder = this.value; this.value = '';})()"
                  onblur="(() => { this.value = this.value || this.placeholder; this.placeholder = this.dataset.placeholder;})()"
                  id="settingsSampleRate" value="${targetSR}" data-sample-rate="${targetSR}" list="commonSR"
                  data-placeholder="Sample Rate between ${settings.supportedSampleRates.toString()}"
                  min="${settings.supportedSampleRates[0]}" max="${settings.supportedSampleRates[1]}">
                  <datalist id="commonSR">
                    ${[12000, 24000, 32000, 44100, 48000].map(
                      v => '<option value="' + v + '">').join('')}
                  </datalist>
                  <button title="Restore currently active sample rate" class="button-clear" onpointerdown="(() => {const i = document.getElementById('settingsSampleRate'); i.value = i.dataset.sampleRate;})()"><i class="gg-undo"></i></button>
              </div>
          </td>
      </tr>
      <tr><td colspan="2" style="padding-top: 1.5rem;"></td></tr>
    
      <tr>
      <td><span>Bit Depth&nbsp;&nbsp;&nbsp;</span></td>
      <td>
      <div style="padding: 1.5rem 0;" class="${targetContainer === 'a' ? 'disabled' : ''}" id="bitDepthGroup" data-bit-depth="${masterBitDepth}" onclick="((event, el) => {
          el.dataset.bitDepth = event.target.dataset.bitDepth || el.dataset.bitDepth;
      el.querySelectorAll('button').forEach(b => b.classList = b.dataset.bitDepth === el.dataset.bitDepth ? 'check button' : 'check button-outline');
      document.getElementById('ditherGroup').classList[+el.dataset.bitDepth === 32 ? 'add': 'remove']('disabled');
      })(event, this);">
          <button id="acoBitDepth8" data-bit-depth="8" class="check button${masterBitDepth !== 8 ? '-outline' : ''}">8 Bit</button>
          <button id="acoBitDepth16" data-bit-depth="16" class="check button${masterBitDepth !== 16 ? '-outline' : ''}">16 Bit</button>
          <button id="acoBitDepth24" data-bit-depth="24" class="check button${masterBitDepth !== 24 ? '-outline' : ''}">24 Bit</button>
         <button id="acoBitDepth32" data-bit-depth="32" class="check button${masterBitDepth !== 32 ? '-outline' : ''}">32 Bit</button>
     </div>
      </td>
      </tr>
      <tr>
      <td><span>Dither 8/16/24 Bit Exports&nbsp;&nbsp;&nbsp;</span></td>
      <td>
      <div style="padding: 1.5rem 0;" class="${masterBitDepth === 32 ? 'disabled' : ''}" data-dither="${settings.ditherExports}" id="ditherGroup" onclick="((event, el) => {
          el.dataset.dither = event.target.dataset.dither || el.dataset.dither;
      el.querySelectorAll('button').forEach(b => b.classList = b.dataset.dither === el.dataset.dither ? 'check button' : 'check button-outline');
      })(event, this);">
          <button id="acoDitherNo" data-dither="false" class="check button${!settings.ditherExports || masterBitDepth === 32 ? '' : '-outline'}">NO</button>
          <button id="acoDitherYes" data-dither="true" class="check button${settings.ditherExports && masterBitDepth !== 32 ? '' : '-outline'}">YES</button>
     </div>
      </td>
      </tr>
      <tr>
          <td><span>Channels&nbsp;&nbsp;&nbsp;</span></td>
          <td>
            <div style="padding: 1.5rem 0;" id="channelsGroup" data-channels="${masterChannels}" onclick="((event, el) => {
          el.dataset.channels = event.target.dataset.channels || el.dataset.channels;
      el.querySelectorAll('button').forEach(b => b.classList = b.dataset.channels === el.dataset.channels ? 'check button' : 'check button-outline')
      })(event, this);">
            <button id="acoChannelm" data-channels="1" class="check button${masterChannels !== 1 ? '-outline' : ''}">MONO</button>
              <button id="acoChannels" data-channels="2" class="check button${masterChannels !== 2 ? '-outline' : ''}">STEREO</button>
              </div>
          </td>
      </tr>
    
      <tr>
          <td style="border: none;"><span>Container&nbsp;&nbsp;&nbsp;</span></td>
          <td style="border: none;">
            <div style="padding: 1.5rem 0;" id="targetContainerGroup" data-container="${targetContainer}" onclick="((event, el) => {
          el.dataset.container = event.target.dataset.container || el.dataset.container;
      el.querySelectorAll('button').forEach(b => b.classList = b.dataset.container === el.dataset.container ? 'check button' : 'check button-outline');
      if (el.dataset.container === 'a') {
          document.getElementById('acoBitDepth16').click();
          document.getElementById('bitDepthGroup').classList.add('disabled');
          document.getElementById('settingsSampleRate').value = 44100;
          document.getElementById('settingsSampleRate').disabled = true;
          document.getElementById('settingsSampleRateGroup').classList.add('disabled');
      } else {
            document.getElementById('bitDepthGroup').classList.remove('disabled');
            document.getElementById('settingsSampleRate').disabled = false
            document.getElementById('settingsSampleRateGroup').classList.remove('disabled');
      }
      })(event, this);">
            <button id="acoContainerw" data-container="w" class="check button${targetContainer === 'w' ? '' : '-outline'}">WAV</button>
              <button id="acoContainera" data-container="a" class="check button${targetContainer === 'a' ? '' : '-outline'}">AIF</button>
              </div>
          </td>
      </tr>
        <tr><td colspan="3"><span><small>Note: Choosing AIF will set the sample rate to 44100 and the bit depth to 16 bit.</small></span><br><br></td></tr>
    
      <tr>
    
      <tr>
        <td><span>Slice Grid Options&nbsp;&nbsp;&nbsp;</span></td>
        <td>
            <div id="sliceGridGroup">
               ${[1,2,3,4,5,6].map((g, i) => '<input id="gridSize' + g + '" placeholder="" type="number" class="acoSliceGridOption" onfocus="(() => {this.placeholder = this.value; this.value = \'\';})()" onblur="(() => { this.value = this.value || this.placeholder;})()" list="commonGridSizes" value="' + sliceOptions[i + 1] + '">').join('')}
               <datalist id="commonGridSizes">
                    ${[2,4,8,10,12,15,16,24,30,32,48,60,64,128].map(
              v => '<option value="' + v + '">').join('')}
               </datalist>
            </div>
        </td>
      </tr>
    
      <td style="border-bottom: none;">
        <a class="button" style="margin: 2.5rem 2rem;" onpointerdown="digichain.changeAudioConfig()">Apply Audio Settings</a>
      </td>
      <td style="border-bottom: none;">
        <select id="audioValuesFromCommonSelect" class="btn-audio-config" style="margin: 0 2rem; max-width: 25rem; float: right;" onchange="digichain.setAudioOptionsFromCommonConfig(event)">
            <option value="none" disabled selected>Common Configurations</option>
            <option value="48000m16w0-4-8-16-32-64-128" data-device="dt">Digitakt</option>
            <option value="48000s16w0-4-8-16-32-64-128" data-device="dt">Digitakt II</option>
            <option value="44100s16w0-4-8-16-32-64-128" data-device="m8">Dirtywave M8</option>
            <option value="48000m16w0-8-10-12-15-30-60" data-device="dt">Model:Samples</option>
            <option value="44100s16w0-4-8-16-32-48-64" data-device="ot">Octatrack (16bit)</option>
            <option value="44100s24w0-4-8-16-32-48-64" data-device="ot">Octatrack (24bit)</option>
            <option value="44100s16a0-4-8-12-16-20-24" data-device="op1f">OP-1 Field</option>
            <option value="44100m16a0-4-8-12-16-20-24" data-device="opz">OP-1 / OP-Z</option>
            <option value="44100s16w0-4-8-12-16-20-24" data-device="opxy">OP-XY</option>
            <option value="44100m16w0-4-8-16-24-32-48" data-device="pt">Polyend Tracker</option>
            <option value="44100s16w0-4-8-16-24-32-48" data-device="pt">Polyend Tracker Mini</option>
            <option value="48000m16w0-8-10-12-15-30-60" data-device="dt">Rytm</option>
            <option value="12000m16w0-2-4-8-10-12-15">Sonicware Lofi-12 XT 12kHz</option>
            <option value="24000m16w0-2-4-8-10-12-15">Sonicware Lofi-12 XT 24kHz</option>
            <option value="46875m16w0-3-4-6-8-9-12">TE EP-133 / EP-1320 (mono)</option>
            <option value="46875s16w0-3-4-6-8-9-12">TE EP-133 / EP-1320 (stereo)</option>
        </select>
      </td>
      </tr>
      <tr><td colspan="2"  style="border: none;">&nbsp;</td></tr>
    </tbody>
    </table>
    `;
            break;
        case 'session':
            panelMarkup += `
              <br>
              <span>Export the current list and audio configuration to a DigiChain session file.</span>
              <table id="settingSession">
              <thead>
              <tr>
              <th style="width: 38%;"></th>
              <th></th>
              </tr>
              </thead>
                  <tbody>
                  <tr>
                      <td style="border: none;"><span style="padding-top: 1rem; display: block;">Session File Name&nbsp;&nbsp;&nbsp;</span></td>
                      <td style="border: none;">
                          <div class="input-set" style="display: flex; align-items: flex-start; padding-top: .5rem;">
                              <input type="text" id="sessionFileName" value="digichain_session">
                          </div>
                      </td>
                  </tr>
                  <tr><td colspan="2" style="padding-top: 1.5rem;"></td></tr>
                
                  <tr>
                  <td><span>Include Unselected List Items?&nbsp;&nbsp;&nbsp;</span></td>
                  <td>
                  <div id="sessionIncludeUnselected" style="padding: 1.5rem 0;" data-session-unselected="yes" onclick="((event, el) => {
                      el.dataset.sessionUnselected = event.target.dataset.sessionUnselected || el.dataset.sessionUnselected;
                  el.querySelectorAll('button').forEach(b => b.classList = b.dataset.sessionUnselected === el.dataset.sessionUnselected ? 'check button' : 'check button-outline');
                  })(event, this);">
                      <button data-session-unselected="no" class="check button-outline">No</button>
                      <button data-session-unselected="yes" class="check button">Yes</button>
                 </div>
                  </td>
                  </tr>
            </tbody>
            </table>
            <a class="button" style="margin-left: 2rem;" onclick="digichain.saveSessionUiCall()">Export Session to File</a>
            `
            break;
        case 'about':
        default:
            panelMarkup += `
              <h3 style="padding-top: 2rem;">DigiChain (${document.querySelector('meta[name=version]').content})</h3>
              <p>${document.querySelector('meta[name=description]').content.replaceAll('--', '<br>')}</p>
              <p class="float-left"><a href="https://github.com/brian3kb/digichain/releases/tag/v1.5.0" target="_blank">Change log</a></p>
              <p class="float-right"><a href="https://brianbar.net/" target="_blank">Brian Barnett</a>
              (<a href="https://github.com/brian3kb" target="_blank">brian3kb</a>) </p>
            `;
    }

    panelContentEl.innerHTML = panelMarkup;

    document.getElementById('opExportPanel').classList.remove('show');

    if (!panelEl.open) {
        panelEl.showModal();
    }
}

function getMonoFloat32ArrayFromBuffer(
  buffer, channel, getAudioBuffer = false) {
    return bufferToFloat32Array(buffer, channel, getAudioBuffer, audioCtx,
      masterChannels, masterSR);
}

function showMergePanel() {
    const mergePanelEl = document.getElementById('mergePanel');
    const mergePanelContentEl = document.getElementById('mergePanelContent');
    mergeFiles = files.filter(f => f.meta.checked).map(f => {
        f.meta.pan = f.meta.pan || 'C';
        return f;
    });
    if (mergeFiles.length < 2) {
        return showToastMessage('Merge requires more than one file to be selected.');
    }

    mergePanelContentEl.innerHTML = `
   <div class="row">
   <div class="column mh-60vh">
     <table id="mergeList">
      <thead>
        <tr>
        <th>Filename</th>
        <th>Duration</th>
        <th>Mono Channel Choice</th>
        <th>Panning</th>
        </tr>
      </thead>
    <tbody>
` + mergeFiles.map(mf => buildRowMarkupFromFile(mf, 'merge')).join('') +
      `</tbody>
   </table>
 </div>
</div>
<span class="merge-info">Merging flattens each source sample to mono based on the mixdown choice and pans that mono file hard left/right or centers. If you want to retain a stereo files stereo field in the merge, duplicate it first and choose its L/R mix.</span>
<button class="float-right" onclick="digichain.performMergeUiCall()">Merge Files</button>
`;
    if (!mergePanelEl.open) { mergePanelEl.showModal(); }
}

function performMergeUiCall() {
    const mergePanelEl = document.getElementById('mergePanel');
    setLoadingText('Processing');
    if (files.filter(f => f.meta.checked).length === 0) {
        return;
    }
    mergePanelEl.close();
    setTimeout(() => performMerge(mergeFiles), 100);
}

function performMerge(mFiles) {
    let longest = mFiles[0];
    mFiles.forEach(mf => longest = longest.buffer.length > mf.buffer.length
      ? longest
      : mf);
    let newItem = {
        file: {...longest.file},
        buffer: audioCtx.createBuffer(
          2,
          longest.buffer.length,
          masterSR
        ),
        meta: {
            ...longest.meta,
            channel: 'L',
            isMerge: true,
            editOf: '',
            id: crypto.randomUUID(),
            checked: false
        },
        waveform: false
    };
    for (let i = 0; i < newItem.buffer.length; i++) {
        newItem.buffer.getChannelData(0)[i] = 0;
        newItem.buffer.getChannelData(1)[i] = 0;
    }
    mFiles.forEach((mf, idx) => {
        const panChannel = mf.meta.pan === 'L' ? 0 : 1;
        let data = mf.buffer.getChannelData(0);
        if (mf.buffer.numberOfChannels === 2) {
            data = getMonoFloat32ArrayFromBuffer(mf.buffer, mf.meta?.channel);
        }
        if (mf.meta.pan === 'C') {
            for (let i = 0; i < mf.buffer.length; i++) {
                newItem.buffer.getChannelData(
                  0)[i] = (newItem.buffer.getChannelData(
                  0)[i] + (data[i] || 0)) / 2;
                newItem.buffer.getChannelData(
                  1)[i] = (newItem.buffer.getChannelData(
                  1)[i] + (data[i] || 0)) / 2;
            }
        } else {
            const buffer = newItem.buffer.getChannelData(panChannel);
            for (let i = 0; i < mf.buffer.length; i++) {
                newItem.buffer.getChannelData(panChannel)[i] = buffer[i] === 0 ?
                  (data[i] || 0) :
                  ((buffer[i] + (data[i] || 0)) / 2);
            }
        }

        if (idx === mFiles.length - 1) {
            files.unshift(newItem);
            unsorted.push(newItem.meta.id);
            setLoadingText('');
            renderList();
        }
    });

}

function showBlendPanel() {
    const mergePanelEl = document.getElementById('mergePanel');
    const mergePanelContentEl = document.getElementById('mergePanelContent');
    mergeFiles = files.filter(f => f.meta.checked).map(f => {
        f.meta.pan = f.meta.pan || 'C';
        return f;
    });
    if (mergeFiles.length < 2) {
        return showToastMessage('Blend requires more than one file to be selected.');
    }

    mergePanelContentEl.innerHTML = `
   <div class="row">
   <div class="column mh-60vh">
     <table id="mergeList">
      <thead>
        <tr>
        <th>Filename</th>
        <th>Duration</th>
        <th>Mono Channel Choice</th>
        </tr>
      </thead>
    <tbody>
` + mergeFiles.map(mf => buildRowMarkupFromFile(mf, 'blend')).join('') +
      `</tbody>
   </table>
 </div>
</div>
<div class="row" style="padding-left: 1rem; padding-top: 2rem;">
<label for="blendLength">Blend length: </label>
<select class="btn-audio-config" style="max-width: 100px;margin-left: 1rem;margin-top: -.75rem;" name="blendLength" id="blendLength">
${[16, 32, 64, 128, 256, 512, 1024, 2048, 4096].reduce((a, c) =>
          a += '<option value="' + c + '"' +
            (c === 64 ? 'selected="selected">' : '>') + c + '</option>'
        , '')}
</select>
</div>
<span class="merge-info">EXPERIMENTAL: Blend interpolates between the selected samples by the number of steps specified. Works best when the selected files are approximately the same durations.</span>
<button class="float-right" onclick="digichain.performBlendUiCall()">Blend Files</button>
`;
    if (!mergePanelEl.open) { mergePanelEl.showModal(); }
}

function performBlendUiCall() {
    const blendLengthEl = document.getElementById('blendLength');
    const blendLength = +blendLengthEl.value;
    const blendPanelEl = document.getElementById('mergePanel');
    setLoadingText('Processing');
    if (files.filter(f => f.meta.checked).length === 0 || !blendLength) {
        return;
    }
    blendPanelEl.close();
    setTimeout(() => performBlend(mergeFiles, blendLength), 100);
}

function performBlend(mFiles, blendLength) {
    const blendLengths = mFiles.map((f, i) =>
      Math.floor(blendLength / mFiles.length) +
      (i === mFiles.length - 1 ? blendLength % mFiles.length : 0)
    );

    let blendName = `${getNiceFileName(
      mFiles.at(0).file.name)}-${getNiceFileName(
      mFiles.at(-1).file.name)}_blend`;
    let newItemBuffer = audioCtx.createBuffer(
      1,
      mFiles.reduce((a, f, i) => a += f.buffer.length * blendLengths[i], 0),
      masterSR
    );
    let newItem = {
        file: {
            name: blendName,
            filename: `${blendName}.wav`,
            path: '',
            type: 'audio/wav'
        },
        buffer: newItemBuffer,
        meta: {
            length: newItemBuffer.length,
            duration: Number(newItemBuffer.length / masterSR).toFixed(3),
            startFrame: 0,
            endFrame: newItemBuffer.length,
            isBlend: true,
            editOf: '',
            id: crypto.randomUUID(),
            checked: false
        },
        waveform: false
    };
    for (let i = 0; i < newItem.buffer.length; i++) {
        newItem.buffer.getChannelData(0)[i] = 0;
    }

    let pos = 0;
    mFiles.forEach((mf, idx) => {
        const nextMf = idx === mFiles.length - 1 ? mFiles[0] : mFiles[idx + 1];
        let data = mf.buffer.numberOfChannels === 2 ?
          getMonoFloat32ArrayFromBuffer(mf.buffer, mf.meta?.channel) :
          mf.buffer.getChannelData(0);
        let data2 = nextMf.buffer.numberOfChannels === 2 ?
          getMonoFloat32ArrayFromBuffer(nextMf.buffer, nextMf.meta?.channel) :
          nextMf.buffer.getChannelData(0);

        for (let n = 0; n < blendLengths[idx]; n++) {
            for (let i = 0; i < data.length; i++) {
                newItem.buffer.getChannelData(0)[pos] = (data[i] || 0) +
                  ((n + 1) / blendLengths[idx]) *
                  ((data2[i] || 0) - (data[i] || 0));
                pos++;
            }
        }

        if (idx === mFiles.length - 1) {
            files.unshift(newItem);
            unsorted.push(newItem.meta.id);
            setLoadingText('');
            renderList();
        }
    });

}

function joinAllUICall(event, pad) {
    if (files.length === 0 || files.filter(f => f.meta.checked).length === 0) { return; }
    if (secondsPerFile !== 0) {
        let _files = files.filter(f => f.meta.duration < secondsPerFile);
        if (_files.length === 0) { return;}
    }
    setLoadingText('Processing');
    setTimeout(() => joinAll(event, pad), 500);
}

async function joinAll(
  event, pad = false, filesRemaining = [], fileCount = 0,
  toInternal = false, zip = false) {
    if (files.length === 0) { return; }
    if ((toInternal || settings.updateResampleChainsToList ||
      (event.shiftKey || modifierKeys.shiftKey)) && !settings.exportChainsAsXyPresets) { toInternal = true; }
    try {
        const joinedEl = document.getElementById('getJoined');
        if (
          ((settings.zipDownloads && !toInternal) || settings.exportChainsAsXyPresets) &&
          files.filter(
          f => f.meta.checked).length > 1
        ) {
            zip = zip || new JSZip();
        }

        let _files = filesRemaining.length > 0 ? filesRemaining : files.filter(
          f => f.meta.checked);

        /*Expand any slices into distinct files for processing.*/
        if (filesRemaining.length === 0 && settings.splitOutExistingSlicesOnJoin) {
            const _filesWithSlices = [];
            _files.forEach(
              (f, fIdx) => f.meta?.slices?.length ? _filesWithSlices.push(fIdx) : false
            );
            while (_filesWithSlices.length > 0) {
                const __fileId = _filesWithSlices.pop();
                const __file = _files[__fileId];
                const exploded = splitByOtSlices({}, __file.meta.id, false, 'ot', [], false, true);
                _files.splice(__fileId, 1, ...exploded);
            }
        }

        /*If exporting as XY presets, truncate files to be 20 seconds or less.*/
        if (filesRemaining.length === 0 && settings.exportChainsAsXyPresets) {
            const _filesLongerThanTwentySeconds = [];
            _files.forEach(
              (f, fIdx) => +(f.meta?.duration??0) >= 20 ? _filesLongerThanTwentySeconds.push(fIdx) : false
            );
            while (_filesLongerThanTwentySeconds.length > 0) {
                const __fileId = _filesLongerThanTwentySeconds.pop();
                const __file = _files[__fileId];
                const _flatFile = flattenFile(__file, true);
                delete _flatFile.meta.slices;
                _flatFile.meta.duration = '20.000';
                _flatFile.buffer.channel0 = _flatFile.buffer.channel0.slice(0, (20 * masterSR));
                if (_flatFile.buffer.channel1) {
                    _flatFile.buffer.channel1 = _flatFile.buffer.channel1.slice(0, (20 * masterSR));
                }
                _flatFile.buffer.length = _flatFile.buffer.channel0.length;
                _files.splice(__fileId, 1, ..._flatFile);
            }
        }

        let tempFiles, slices, largest;
        let totalLength = 0;
        let sliceGridT = settings.exportChainsAsXyPresets ? ((sliceGrid > 24 || !sliceGrid) ? 24 : sliceGrid) : sliceGrid;

        if (secondsPerFile === 0) { /*Using slice grid file lengths*/
            tempFiles = _files.splice(0,
              (sliceGridT > 0 ? sliceGridT : _files.length));

            filesRemaining = Array.from(_files);
            _files = tempFiles;
            if (pad && sliceGridT !== 0 && _files.length !== 0) {
                while (_files.length !== sliceGridT) {
                    _files.push(_files[_files.length - 1]);
                }
            }
            largest = _files.reduce(
              (big, cur) => big > cur.buffer.length ? big : cur.buffer.length, 0);
            totalLength = _files.reduce((total, file) => {
                total += pad ? largest : file.buffer.length;
                return total;
            }, 0);

        } else { /*Using max length in seconds (if aif also limit upto 24 files per chain)*/
            _files = _files.filter(f => f.meta.duration < secondsPerFile);
            let maxChainLength = (
              (targetContainer === 'a' || settings.exportChainsAsXyPresets) ? 24 : (sliceGrid === 0
                ? 64
                : sliceGrid));
            const processing = _files.reduce((a, f) => {
                if (
                  (a.duration + +f.meta.duration <=
                    (secondsPerFile * settings.pitchModifier)) &&
                  (a.processed.length < maxChainLength)) {
                    a.duration = a.duration + +f.meta.duration;
                    a.totalLength = a.totalLength + +f.meta.length;
                    a.processed.push(f);
                } else {
                    a.skipped.push(f);
                }
                return a;
            }, {duration: 0, totalLength: 0, processed: [], skipped: []});

            totalLength = processing.totalLength;
            filesRemaining = processing.skipped;
            _files = processing.processed;
        }

        slices = [];
        let offset = 0;
        for (let x = 0; x < _files.length; x++) {
            const fileSliceData = _files[x].meta.slices || metaFiles.getByFileInDcFormat(_files[x]);
            if (fileSliceData.length && settings.splitOutExistingSlicesOnJoin) {
                if (slices.length > 0) {
                    const _slices = JSON.parse(
                      JSON.stringify(fileSliceData));
                    _slices.forEach(slice => {
                        slice.s = slice.s + offset;
                        slice.e = slice.e + offset;
                    });
                    slices = [...slices, ..._slices];
                } else {
                    slices = [...slices, ...fileSliceData];
                }
            } else {
                slices.push({
                    s: offset,
                    e: offset + (pad ? largest : +_files[x].buffer.length),
                    n: _files[x].file.name,
                    p: _files[x].meta.opPan ?? 16384,
                    pab: _files[x].meta.opPanAb ?? false,
                    st: _files[x].meta.opPitch ?? 0
                });
            }
            offset += (pad ? largest : +_files[x].buffer.length);
        }
        slices.forEach(s => {
            s.s = s.s > totalLength ? totalLength : s.s;
            s.e = s.e > totalLength ? totalLength : s.e;
        });
        slices = slices.filter(s => s.s < s.e);

        const path = _files[0].file.path ? `${(_files[0].file.path || '').replace(
          /\//gi, '-')}` : '';
        const _fileName = chainFileNamesAvailable() ?
          getNextChainFileName(_files.length) :
          (
            _files.length === 1 ?
              `${path}chain-${pad ? 'spaced-' : ''}${getNiceFileName('', _files[0], true)}-${fileCount +
          1}--${_files.length}` :
              `${path}chain-${pad ? 'spaced-' : ''}${fileCount + 1}--${_files.length}`
          );

        if (settings.exportChainsAsXyPresets) {
            const xySlices = [];
            const xyFileName = `${sanitizeFileName(_fileName).substring(0, 14)}${fileCount + 1}`.replaceAll(/([-.])/gi, '');
            _files.forEach((f, idx) => {
                let sNum = `${idx + 1}`;
                sNum = sNum.length === 1 ? `0${sNum}` : sNum;

                if (f.buffer.channel0) {
                    f = bufferRateResampler(f);
                }

                f.name = `${xyFileName}${sNum}`;
                if (f.buffer) {
                    const dataView = audioBufferToWav(
                      f.buffer, {...f.meta, renderAt: targetSR}, masterSR, masterBitDepth,
                      masterChannels, settings.deClick,
                      false, settings.pitchModifier, false,
                      false, false
                    );

                    let blob = new window.Blob([dataView.buffer], {
                        type: 'audio/wav'
                    });

                    zip.file(`${xyFileName}.preset/${f.name}.wav`, blob, {binary: true});
                    xySlices.push({
                        s: 0,
                        e: f.buffer.length,
                        l: f.buffer.length,
                        buffer: f.buffer,
                        name: f.name
                    });
                }
            });
            const xyPatchData = buildXyDrumPatchData({}, xySlices);
            zip.file(`${xyFileName}.preset/patch.json`, JSON.stringify(xyPatchData));
        } else {

            const audioArrayBuffer = audioCtx.createBuffer(
              masterChannels,
              totalLength,
              masterSR
            );

            for (let channel = 0; channel < masterChannels; channel++) {
                for (let i = 0; i < totalLength; i++) {
                    audioArrayBuffer.getChannelData(channel)[i] = 0;
                }
            }

            if (masterChannels === 1) {
                joinToMono(audioArrayBuffer, _files, largest, pad, settings.reverseEvenSamplesInChains);
            }
            if (masterChannels === 2) {
                joinToStereo(audioArrayBuffer, _files, largest, pad, settings.reverseEvenSamplesInChains);
            }

            const fileData = {
                file: {
                    name: `${_fileName}.wav`
                }, buffer: audioArrayBuffer, meta: {slices}
            };
            if (toInternal) {

                const wav = await setWavLink(fileData, joinedEl, false, false,
                  (masterBitDepth === 8 ? 8 : 32));
                const fileReader = new FileReader();
                fileReader.readAsArrayBuffer(wav.blob);
                fileReader.fileCount = fileCount;
                fileReader.onload = async (e) => {
                    const fb = e.target.result.slice(0);
                    await (masterSR !== (wav.sampleRate || masterSR)
                      ? new AudioContext(
                        {
                            sampleRate: wav.sampleRate,
                            latencyHint: 'interactive'
                        })
                      : audioCtx).decodeAudioData(e.target.result, buffer => {
                        parseWav(buffer, fb, {
                            lastModified: new Date().getTime(),
                            name: fileData.file.name,
                            embedSliceData: embedSliceData,
                            sampleRate: wav.sampleRate || masterSR,
                            channels: buffer.numberOfChannels,
                            size: (((masterBitDepth === 8 ? 8 : 32) * (wav.sampleRate || masterSR) *
                                (buffer.length / (wav.sampleRate || masterSR))) /
                              8) * buffer.numberOfChannels / 1024,
                            type: 'audio/wav'
                        }, '', true, false);
                        renderList();
                    });
                };

            } else {
                const renderAsAif = targetContainer === 'a';
                if (zip) {
                    const wav = await setWavLink(fileData, joinedEl, renderAsAif, true);
                    fileData.file.name = targetContainer === 'a' ?
                      fileData.file.name.replace('.wav', '.aif') :
                      fileData.file.name;
                    zip.file(fileData.file.name, wav.blob, {binary: true});
                    let otFile = await createAndSetOtFileLink(
                      fileData.meta.slices ?? [], fileData,
                      fileData.file.name);
                    if (otFile) {
                        zip.file(otFile.name, otFile.blob, {binary: true});
                    }
                } else {
                    await setWavLink(fileData, joinedEl, renderAsAif, true);
                    joinedEl.click();
                    let otFile = await createAndSetOtFileLink(
                      fileData.meta.slices ?? [], fileData,
                      fileData.file.name, joinedEl);
                    if (otFile) {joinedEl.click(); }
                }
            }
        }
        if (filesRemaining.length > 0) {
            fileCount++;
            joinAll(event, pad, filesRemaining, fileCount, toInternal, zip);
        } else {
            if (zip) {
                zip.generateAsync({type: 'blob'}).then(blob => {
                    joinedEl.href = URL.createObjectURL(blob);
                    joinedEl.setAttribute('download', `digichain_${Date.now()}.zip`);
                    joinedEl.click();
                });
            }
            renderList();
        }
    } catch (joinError) {
        let errorMessage = `An unexpected error was encountered while building the sample chain(s).`;
        if (joinError) {
            errorMessage += `\n\n "${joinError.toString ? joinError.toString() : JSON.stringify(joinError)}"`;
        }
        setLoadingText('Unexpected Error', 3000);
        showToastMessage(errorMessage, 15000);
        console.log(joinError);
    }
}

function convertChain(event, toSpacedChain = false) {
    const el = document.getElementById('splitOptions');
    const excludeSlices = [...el.querySelectorAll(`div.line.fade`)].map(
      s => +s.dataset.idx);
    const newItem = duplicate(event, lastSelectedRow.dataset.id, true);

    newItem.item.meta.slices = (newItem.item.meta.slices ?
      newItem.item.meta.slices :
      metaFiles.getByFileInDcFormat(
        getFileById(lastSelectedRow.dataset.id))).filter(
      (x, idx) => !excludeSlices.includes(idx));

    if (toSpacedChain && sliceGrid !== 0) {
        while (newItem.item.meta.slices.length < sliceGrid) {
            newItem.item.meta.slices.push(
              JSON.parse(JSON.stringify(newItem.item.meta.slices.at(-1))));
        }
    }

    const sliceLengths = newItem.item.meta.slices.map(s => s.e - s.s);
    const largestSlice = Math.max(...sliceLengths);

    let buffers = newItem.item.meta.slices.map(slice => {
        const buffer = new AudioBuffer({
            numberOfChannels: newItem.item.buffer.numberOfChannels,
            length: (slice.e - slice.s),
            sampleRate: newItem.item.buffer.sampleRate
        });
        for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
            for (let i = 0; i < buffer.length; i++) {
                buffer.getChannelData(
                  channel)[i] = newItem.item.buffer.getChannelData(
                  channel)[slice.s + i] || 0;
            }
        }
        return {buffer, meta: {}};
    });

    if (!toSpacedChain) {
        buffers.forEach(buffer => {
            editor.trimRight(event, buffer, false);
        });
    }
    const trimmedLength = toSpacedChain ?
      (buffers.length * largestSlice) :
      buffers.reduce((length, item) => length += item.buffer.length, 0);
    const trimmedBuffer = new AudioBuffer({
        numberOfChannels: newItem.item.buffer.numberOfChannels,
        length: trimmedLength,
        sampleRate: newItem.item.buffer.sampleRate
    });

    if (trimmedBuffer.numberOfChannels === 1) {
        joinToMono(trimmedBuffer, buffers, largestSlice, toSpacedChain);
    }
    if (trimmedBuffer.numberOfChannels === 2) {
        joinToStereo(trimmedBuffer, buffers, largestSlice, toSpacedChain);
    }

    let progress = 0;
    buffers.forEach((item, idx) => {
        const length = toSpacedChain ? largestSlice : item.buffer.length;
        if (newItem.item.meta.slices) {
            newItem.item.meta.slices[idx].s = progress;
            newItem.item.meta.slices[idx].e = progress + length;
        }
        progress += length;
    });
    newItem.item.buffer = trimmedBuffer;
    newItem.item.meta = {
        ...newItem.item.meta,
        length: trimmedBuffer.length,
        duration: Number(trimmedBuffer.length / masterSR).toFixed(3),
        startFrame: 0, endFrame: trimmedBuffer.length
    };
    delete newItem.item.meta.op1Json;
    newItem.callback(newItem.item, newItem.fileIdx);
    closeSplitOptions();
}

function joinAllByPath(event, pad = false) { //TODO: test and hook into UI
    const filesByPath = {};
    files.filter(f => f.meta.checked).forEach(file => {
        const path = file.file.path.replace(/\//gi, '-');
        filesByPath[path] = filesByPath[path] || [];
        filesByPath[path].push(file);
    });
    for (const fBP of filesByPath) {
        joinAll(event, pad, fBP, fBP.length);
    }
}

const stopPlayFile = (event, id) => {
    const file = getFileById(id || lastSelectedRow?.dataset?.id);
    if (!file) { return; }
    try {
        file?.source?.stop();
    } catch (e) {}
    if (file.meta.playing && file.meta.playing !== true) {
        const [fnType, fnId] = file.meta.playing.split('_');
        window['clear' + fnType](+fnId);
        file.meta.playing = false;
        file.playHead?.remove();
        file.playHead = false;
    }
    file.waveform?.classList?.remove('playing');
    if (file.meta.playing === true) {
        file.meta.playing = false;
    }
    let playHead = file.playHead ||
      file.waveform?.parentElement?.querySelector('.play-head');
    if (playHead) { playHead.remove(); }
};

const playFile = (event, id, loop, start, end) => {
    const file = getFileById(id || lastSelectedRow.dataset.id) || (event.editor && event.file ? event.file : false);
    let playHead;
    loop = loop || (event.shiftKey || modifierKeys.shiftKey) || false;

    stopPlayFile(false, (id || file.meta.id));

    const isAudioCtxClosed = checkAudioContextState();
    if (isAudioCtxClosed) { return; }

    file.source = audioCtx.createBufferSource();
    let buffer = file.meta.channel && masterChannels === 1 ?
      getMonoFloat32ArrayFromBuffer(file.buffer, file.meta.channel, true) :
      file.buffer;

    if (settings.playWithPopMarker && !event?.editor) {
        const popAudio = audioCtx.createBuffer(1, 8, masterSR);
        const popBuffer = audioCtx.createBuffer(buffer.numberOfChannels,
          buffer.length + (popAudio.length * 2), masterSR);
        const popData = popAudio.getChannelData(0);
        let peak;
        if (settings.playWithPopMarker === 2) {
            peak = file.meta.peak ?? editor.normalize(event, file, false, true);
        } else {
            peak = 1;
        }
        new Array(popAudio.length).fill(0).
          forEach((x, i) => popAudio.getChannelData(0)[i] = peak);
        for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
            const channelData = buffer.getChannelData(channel);
            popBuffer.copyToChannel(popData, channel);
            popBuffer.copyToChannel(channelData, channel, popAudio.length);
            popBuffer.copyToChannel(popData, channel,
              popAudio.length + channelData.length);
        }
        buffer = popBuffer;
    }

    file.source.buffer = buffer;
    file.source.connect(audioCtx.destination);
    file.source.loop = loop;

    if (id && !event?.editor &&event.target && event.target !== file.waveform) {
        file.waveform = file.waveform?.tagName === 'CANVAS' ? file.waveform : event.target;
    }

    if (id && !event?.editor && file.waveform && file.waveform.nodeName !== 'BUTTON') {
        playHead = document.createElement('span');
        playHead.classList.add('play-head');
        playHead.style.animationDuration = `${file.meta.duration}s`;
        file.waveform.parentElement.appendChild(playHead);
        file.playHead = playHead;
    }

    file.source.start(
      0,
      start || 0,
      end
    );

    if (id && !event?.editor) {
        file.waveform?.classList?.add('playing');
        if (playHead) {
            playHead.style.animationIterationCount = file.source.loop
              ? 'infinite'
              : 'unset';

            if (file.source.loop) {
                file.meta.playing = 'Interval_' + setInterval(() => {
                    const ph = file.waveform?.parentElement?.querySelector(
                      '.play-head');
                    if (ph) {
                        const phClone = ph.cloneNode(true);
                        ph.remove();
                        file.waveform.parentElement.appendChild(phClone);
                    } else { // Buffer modified while playing, so clear out the meta.
                        stopPlayFile(false, file.meta.id);
                    }
                }, file.meta.duration * 1000);
            } else {
                file.meta.playing = 'Timeout_' + setTimeout(() => {
                    stopPlayFile(false, file.meta.id);
                }, file.meta.duration * 1000);
            }
        } else if (file.source.loop) {
            file.meta.playing = file.source.loop  || 'Timeout_' + setTimeout(() => {
                stopPlayFile(false, file.meta.id);
            }, file.meta.duration * 1000);
        }
    }

};

const playSlice = (event, id, startPoint, endPoint, loop) => {
    if ((event.ctrlKey || event.metaKey || modifierKeys.ctrlKey)) {
        const start = startPoint / masterSR;
        const end = (endPoint / masterSR) - start;
        playFile(event, id, loop, start, end);
    }
};

function sliceAction(event, id, params) {
    const file = getFileById(id);
    const lineEl = event.target.closest('.line');
    if (
      (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) &&
      (event.shiftKey || modifierKeys.shiftKey)
    ) {
        document.getElementById('splitOptions').querySelectorAll(`div.line`).forEach(line => {
            line.classList.remove('file-loop-on');
            line.classList.remove('file-loop-pp');
        });
        const sliceLinesEl = document.getElementById('sliceLines');
        file.meta.otLoop = parseInt(file.meta?.otLoop) < 2 ? file.meta.otLoop+1 : 0;
        if (file.meta.otLoop === 0) {
            file.meta.otLoopStart = 0;
        } else {
            [...document.getElementById('splitOptions').querySelectorAll(`div.line`)].slice(+lineEl.dataset.idx).forEach(
              line => line.classList.add(file.meta.otLoop === 1 ? 'file-loop-on' : 'file-loop-pp')
            );
            file.meta.otLoopStart = +params.startPoint;
        }
        return;
    }

    if ((event.ctrlKey || event.metaKey || modifierKeys.ctrlKey)) {
        playSlice(event, id, +params.startPoint, +params.endPoint, params.loop);
    }
    if ((event.shiftKey || modifierKeys.shiftKey)) {
        const slice = file.meta.slices[+lineEl.dataset.idx];
        if (slice) {
            lineEl.classList.toggle('slice-loop');
            slice.l = slice.l === -1 ? slice.s : -1;
        }
    }
}

const toggleCheck = (event, id, silent = false, ignoreShiftKey = false) => {
    try {
        const rowEl = getRowElementById(id);
        const el = getRowElementById(id).querySelector('.toggle-check');
        const file = getFileById(id);
        event.preventDefault();
        if ((event.shiftKey || modifierKeys.shiftKey) && !ignoreShiftKey) {
            const lastRowId = getFileIndexById(lastLastSelectedRow.dataset.id);
            const thisRowId = getFileIndexById(id);
            const from = Math.min(lastRowId, thisRowId);
            const to = Math.max(lastRowId, thisRowId);
            for (let i = from; i <= to; i++) {
                const loopRow = getRowElementById(files[i].meta.id);
                const check = !(event.ctrlKey || event.metaKey || modifierKeys.ctrlKey);
                files[i].meta.checked = check;
                loopRow.querySelector('.toggle-check').classList[check
                  ? 'remove'
                  : 'add']('button-outline');
                loopRow.classList[check ? 'add' : 'remove']('checked');
            }
        } else {
            file.meta.checked = !file.meta.checked;
            el.classList[file.meta.checked ? 'remove' : 'add'](
              'button-outline');
            rowEl.classList[file.meta.checked ? 'add' : 'remove']('checked');
            if (!file.meta.checked && silent) {
                file.source?.stop();
            }
        }
        lastSort = '';
        setCountValues();
    } catch (err) {
        setCountValues();
    }
};

const changeChannel = async (
  event, id, channel, allowModKey = true, tableId = '#masterList') => {
    const el = getRowElementById(id, tableId).
      querySelector('.channel-option-' + channel);
    const file = getFileById(id);
    if ((event.shiftKey || modifierKeys.shiftKey) && allowModKey) {
        const opts = {
            L: 'audio from the Left channel',
            R: 'audio from the Right channel',
            S: 'Sum both channels of audio to mono',
            D: 'Difference between Left and Right channels'
        };
        const confirmSetAllSelected = await dcDialog('confirm',
          `Confirm setting all selected samples that are stereo to ${opts[channel]}?`);
        if (confirmSetAllSelected) {
            files.filter(f => f.meta.checked && f.buffer.numberOfChannels > 1).
              forEach(f => {
                  f.meta.channel = channel;
                  file.waveform = false;
              });
        }
        if (!modifierKeys.shiftKey &&
          document.body.classList.contains('shiftKey-down')) {
            document.body.classList.remove('shiftKey-down');
        }
        return renderList();
    }
    file.meta.channel = channel;

    if (tableId === '#masterList') {
        file.waveform = false;
        return renderRow(file);
    }
    if (document.getElementById('mergePanel').open &&
      document.getElementById('blendLength')) {
        showBlendPanel();
    } else {
        showMergePanel();
    }
    //file.waveform.getContext('2d').clear();
    //drawWaveform(file, file.waveform, file.buffer.numberOfChannels);
    // getRowElementById(id, tableId).
    //     querySelectorAll('.channel-options a').
    //     forEach(opt => opt.classList.remove('selected'));
    // el.classList.add('selected');
};

const changePan = (event, id, pan) => {
    const el = getRowElementById(id, '#mergeList').
      querySelector('.pan-option-' + pan);
    const file = getFileById(id);
    file.meta.pan = pan;
    //file.waveform.getContext('2d').clear();
    //drawWaveform(file, file.waveform, file.buffer.numberOfChannels);
    getRowElementById(id, '#mergeList').
      querySelectorAll('.pan-options a').
      forEach(opt => opt.classList.remove('selected'));
    el.classList.add('selected');
};

const invertFileSelection = () => {
    if (files.length === 0) { return; }
    files.forEach(file => file.meta.checked = !file.meta.checked);
    renderList();
};

const changeSliceOption = async (targetEl, size, silent = false) => {
    let newValue = size;
    if (!silent) {
        newValue = await dcDialog(
          'prompt',
          `Temporarily change slice value "${size}" to what new value?`,
          {
              inputType: 'number',
              defaultValue: size
          }
        );
    }
    if (newValue && !isNaN(newValue)) {
        newValue = Math.abs(Math.ceil(+newValue));
        sliceOptions[targetEl.dataset.sel] = +newValue;
        targetEl.textContent = newValue;
    }
    return +newValue;
};

const selectSliceAmount = (event, size) => {
    if (!event.target) { return; }
    if ((event.ctrlKey || event.metaKey || modifierKeys.ctrlKey)) {
        if (size === 0) {
            DefaultSliceOptions.forEach((option, index) => changeSliceOption(
              document.querySelector(`.master-slices .sel-${index}`), option,
              true
            ));
            sliceOptions = Array.from(DefaultSliceOptions);
            return selectSliceAmount({shiftKey: true}, 0);
        }
        return selectSliceAmount({shiftKey: true},
          changeSliceOption(event.target, size));
    }
    sliceGrid = size;
    sliceOptions.forEach((option, index) => {
        const el = document.querySelector(`.master-slices .sel-${index}`);
        option === size ?
          el.classList.remove('button-outline') :
          el.classList.add('button-outline');
    });
    setCountValues();
    if (size === 0) {
        files.forEach(f => f.source?.stop());
    }
    if ((event.shiftKey || modifierKeys.shiftKey)) {
        /*Shift+click to change grid and set the selection to the grid size.*/
        files.forEach(f => f.meta.checked = false);
        for (let i = 0; i < (size < files.length ? size : files.length); i++) {
            toggleCheck(event, files[i].meta.id, true, true);
        }
        renderList();
    }
};

const duplicate = (event, id, prepForEdit = false) => {
    const file = getFileById(id);
    const fileIdx = getFileIndexById(id) + 1;
    const item = {file: {...file.file}};
    item.buffer = new AudioBuffer({
        numberOfChannels: file.buffer.numberOfChannels,
        length: file.buffer.length,
        sampleRate: file.buffer.sampleRate
    });
    for (let channel = 0; channel < file.buffer.numberOfChannels; channel++) {
        const ogChannelData = file.buffer.getChannelData(channel);
        const newChannelData = item.buffer.getChannelData(channel);
        newChannelData.set(ogChannelData);
    }
    item.meta = structuredClone(file.meta); // meta sometimes contains a customSlices object.
    item.waveform = false;
    item.meta.playing = false;
    item.meta.id = crypto.randomUUID();
    item.file.name = getUniqueName(files, item.file.name);
    if (prepForEdit) {
        item.meta.editOf = id;
        return {
            item,
            fileIdx,
            callback: (_item, _fileIdx) => {
                files.splice(((event.shiftKey || modifierKeys.shiftKey)
                  ? files.length
                  : _fileIdx), 0, _item);
                unsorted.push(_item.meta.id);
                renderList();
            },
            editorCallback : (_item, _fileIdx) => {
                files.splice(_fileIdx, 0, _item);
                unsorted.push(_item.meta.id);
            }
        };
    }
    item.meta.dupeOf = id;
    files.splice(
      ((event.shiftKey || modifierKeys.shiftKey) ? files.length : fileIdx), 0,
      item);
    unsorted.push(item.meta.id);
    renderList();
};

function splitFromFile(input) {
    const trackButtonsContainerEl = document.querySelector(
      '.slice-from-file-buttons');
    const trackButtonsEl = document.querySelectorAll(
      '.slice-from-file-buttons button');
    if (!input.target?.files?.length) { return; }
    const reader = new FileReader();
    reader.onload = function(e) {
        if (!e.target.result) { return; }
        const json = JSON.parse(e.target.result);
        if (!json.clips) { return; }
        lastSliceFileImport = json.clips.map(clip => ({
            track: clip.ch + 1,
            startPoint: Math.round((clip.start / 44100) * masterSR),
            endPoint: Math.round((clip.stop / 44100) * masterSR)
        }));
        lastSliceFileImport.trackSlices = {};
        lastSliceFileImport.forEach(
          slice => lastSliceFileImport.trackSlices[`t${slice.track}`] = (lastSliceFileImport.trackSlices[`t${slice.track}`] ??
            0) + 1);
        trackButtonsContainerEl.classList.remove('hidden');
        trackButtonsEl.forEach((
          btn,
          i) => btn.textContent = `${lastSliceFileImport.trackSlices[`t${i +
        1}`]}`);
    };
    reader.readAsText(input.target.files[0]);
}

function splitFromTrack(event, track) {
    const sliceGroupEl = document.querySelector(
      `#splitOptions .slice-group`);
    const file = getFileById(sliceGroupEl.dataset.id);
    file.meta.customSlices = {
        slices: lastSliceFileImport.filter(slice => slice.track === track)
    };
    file.meta.customSlices.sliceCount = file.meta.customSlices.slices.length;
    drawSliceLines(file.meta.customSlices.length, file, file.meta.customSlices);
}

const splitByOtSlices = (
  event, id, pushInPlace = false, sliceSource = 'ot',
  excludeSlices = [], saveSlicesMetaOnly = false, returnAsCollection = false) => {
    const file = getFileById(id);
    const pushInPlaceItems = [];
    let otMeta;
    if (sliceSource === 'transient') {
        otMeta = metaFiles.getByFileName('---sliceToTransientCached---');
    } else if (sliceSource === 'ot') {
        otMeta = metaFiles.getByFile(file);
    } else {
        otMeta = file.meta.customSlices ? file.meta.customSlices : false;
    }
    if (!otMeta) { return; }
    if (saveSlicesMetaOnly) {
        file.meta.slices = metaFiles.getByFileInDcFormat(
          sliceSource === 'transient' ?
            '---sliceToTransientCached---' :
            file
        ).filter((x, idx) => !excludeSlices.includes(idx));
        metaFiles.removeByName(
          sliceSource === 'transient' ?
            '---sliceToTransientCached---' :
            file.file.filename
        );
        file.meta.slices = file.meta.slices.length > 0
          ? file.meta.slices
          : false;
        file.meta.op1Json = false;
        splitAction(event, id);
        return;
    }
    for (let i = 0; i < otMeta.sliceCount; i++) {
        if (excludeSlices.includes(i)) {
            continue;
        }
        const newLength = (otMeta.slices[i].endPoint -
          otMeta.slices[i].startPoint);
        if (newLength < 5) { continue; }
        const audioArrayBuffer = audioCtx.createBuffer(
          file.buffer.numberOfChannels,
          newLength,
          masterSR
        );
        const slice = {};
        const uuid = crypto.randomUUID();
        slice.buffer = audioArrayBuffer;
        slice.file = {...file.file};
        if (otMeta.slices[i].name) {
            slice.file.name = otMeta.slices[i].name;
        }
        slice.meta = {
            length: audioArrayBuffer.length,
            duration: Number(audioArrayBuffer.length / masterSR).toFixed(3),
            startFrame: 0, endFrame: audioArrayBuffer.length,
            checked: true, id: uuid,
            sliceNumber: `${file.meta.sliceNumber
              ? file.meta.sliceNumber + '-'
              : ''}${i + 1}`, slicedFrom: file.meta.id,
            channel: audioArrayBuffer.numberOfChannels > 1 ? 'L' : '',
            opPan: otMeta.slices[i].p ?? 16384,
            opPanAb: otMeta.slices[i].pab ?? false,
            opPitch: otMeta.slices[i].st ?? 0
        };
        slice.meta.customSlices = false;
        slice.meta.op1Json = false;
        slice.meta.slices = false;

        file.buffer.getChannelData(0).
          slice(otMeta.slices[i].startPoint, otMeta.slices[i].endPoint).
          forEach((a, idx) => slice.buffer.getChannelData(0)[idx] = a);
        if (file.buffer.numberOfChannels === 2) {
            file.buffer.getChannelData(1).
              slice(otMeta.slices[i].startPoint, otMeta.slices[i].endPoint).
              forEach((a, idx) => slice.buffer.getChannelData(1)[idx] = a);
        }
        if (pushInPlace || returnAsCollection) {
            pushInPlaceItems.push(slice);
        } else {
            files.push(slice);
        }
        if (!returnAsCollection) {
            unsorted.push(uuid);
        }
    }
    if (pushInPlaceItems.length) {
        if (returnAsCollection) {
            return pushInPlaceItems;
        }
        if (isOpExportPanelOpen()) {
            editor.acceptDroppedChainItems(pushInPlaceItems);
        } else {
            files.splice(getFileIndexById(id) + 1, 0, ...pushInPlaceItems);
        }
    }
    renderList();
};

const splitEvenly = (
  event, id, slices, pushInPlace = false, excludeSlices = [],
  saveSlicesMetaOnly = false) => {
    const file = getFileById(id);
    const frameSize = file.buffer.length / slices;
    const pushInPlaceItems = [];
    if (saveSlicesMetaOnly) {
        file.meta.slices = Array.from('.'.repeat(slices)).map((x, i) => ({
            s: Math.round((file.buffer.length / slices) * i),
            e: Math.round((file.buffer.length / slices) * (i + 1)),
            n: '',
            l: -1
        })).filter((x, idx) => !excludeSlices.includes(idx));
        metaFiles.removeByName(file.file.filename);
        file.meta.slices = file.meta.slices.length > 0
          ? file.meta.slices
          : false;
        splitAction(event, id);
        return;
    }
    for (let i = 0; i < slices; i++) {
        if (excludeSlices.includes(i)) {
            continue;
        }
        const audioArrayBuffer = audioCtx.createBuffer(
          file.buffer.numberOfChannels,
          frameSize,
          file.buffer.sampleRate
        );
        const slice = {};
        const uuid = crypto.randomUUID();
        slice.buffer = audioArrayBuffer;
        slice.file = {...file.file};
        slice.meta = {
            length: audioArrayBuffer.length,
            duration: Number(audioArrayBuffer.length / masterSR).toFixed(3),
            startFrame: 0, endFrame: audioArrayBuffer.length,
            checked: true, id: uuid,
            sliceNumber: `${file.meta.sliceNumber
              ? file.meta.sliceNumber + '-'
              : ''}${i + 1}`, slicedFrom: file.meta.id,
            channel: audioArrayBuffer.numberOfChannels > 1 ? 'L' : ''
        };

        file.buffer.getChannelData(0).
          slice((i * frameSize), (i * frameSize) + frameSize).
          forEach((a, idx) => slice.buffer.getChannelData(0)[idx] = a);
        if (file.buffer.numberOfChannels === 2) {
            file.buffer.getChannelData(1).
              slice((i * frameSize), (i * frameSize) + frameSize).
              forEach((a, idx) => slice.buffer.getChannelData(1)[idx] = a);
        }
        if (pushInPlace) {
            pushInPlaceItems.push(slice);
        } else {
            files.push(slice);
        }
        unsorted.push(uuid);
    }
    if (pushInPlaceItems.length) {
        if (isOpExportPanelOpen()) {
            editor.acceptDroppedChainItems(pushInPlaceItems);
        } else {
            files.splice(getFileIndexById(id) + 1, 0, ...pushInPlaceItems);
        }
    }
    renderList();
};

const splitByTransient = (file, threshold = .5) => {
    const frameSize = Math.floor(file.buffer.length / 256);
    let transientPositions = [];
    let lastStart = undefined;
    let lastEnd = undefined;
    for (let i = 0; i < file.buffer.length; i++) {
        if (lastStart === undefined) {
            if (Math.abs(file.buffer.getChannelData(0)[i]) > threshold) {
                lastStart = i;
                i = i + frameSize;
            }
        } else {
            if (lastEnd === undefined) {
                // I want loose equality here as I want 0.000 to be true against 0
                if (Math.abs(file.buffer.getChannelData(0)[i]).toFixed(3) ==
                  0 || i +
                  frameSize > file.buffer.length) {
                    //lastEnd =  i + frameSize > file.buffer.length ? i : i + frameSize;
                    lastEnd = i;
                }
            }
        }

        if (lastStart !== undefined && lastEnd !== undefined) {
            transientPositions.push({
                startPoint: lastStart,
                loopPoint: -1,
                endPoint: lastEnd
            });
            lastStart = undefined;
            lastEnd = undefined;
        }
    }

    transientPositions = transientPositions.filter(s => {
        if (s.startPoint > s.startPoint + 512) {
            return new Array(512).fill(0).every(
              (p, i) => Math.abs(
                file.buffer.getChannelData(0)[s.startPoint - i]) < 0.03);
        } else {
            return true;
        }
    }).map((s, i, a) => {
        s.endPoint = a[i + 1]?.startPoint ??
          (i === a.length - 1 ? file.buffer.length : s.endPoint);
        return s;
    });

// map transient positions into slice object.
    let metaTransient = metaFiles.getByFileName('---sliceToTransientCached---');

    metaTransient.slices = transientPositions;
    metaTransient.sliceCount = metaTransient.slices.length;
    return metaTransient;
};

const splitSizeAction = async (event, slices, threshold) => {
    let file, otMeta;
    const sliceGroupEl = document.querySelector(
      `#splitOptions .slice-group`);
    const optionsEl = document.querySelectorAll(
      `#splitOptions .slice-group button`);
    const convertChainButtonEl = document.getElementById('convertChainButton');

    convertChainButtonEl.style.display = 'none';

    if (slices === 'custom') {
        const customSlices = await dcDialog('prompt', 'Enter the number of slices to equally chop this sample', {inputType: 'number'});
        if (typeof parseInt(customSlices) === 'number') {
            slices = parseInt(customSlices);
        }
    }

    if (slices === 'ot' && sliceGroupEl.dataset.id) {
        file = getFileById(sliceGroupEl.dataset.id);
        otMeta = metaFiles.getByFile(file);
        slices = otMeta?.slices ?? [];
        convertChainButtonEl.style.display = slices.length > 0
          ? 'block'
          : 'none';
    }
    if (slices === 'transient' && sliceGroupEl.dataset.id) {
        file = getFileById(sliceGroupEl.dataset.id);
        otMeta = splitByTransient(file, (+threshold) / 100);
        slices = otMeta?.slices ?? [];
    } else {
        metaFiles.removeByName('---sliceToTransientCached---');
    }

    optionsEl.forEach(option => option.classList.add('button-outline'));
    sliceGroupEl.dataset.sliceCount = typeof slices === 'number'
      ? slices ?? 0
      : otMeta?.sliceCount ?? 0;
    optionsEl.forEach(option => {
        (+option.dataset.sel === +sliceGroupEl.dataset.sliceCount && !otMeta) ||
        (option.dataset.sel === 'ot' && otMeta && otMeta.name !==
          '---sliceToTransientCached---') ||
        (option.dataset.sel === 'transient' && otMeta && otMeta.name ===
          '---sliceToTransientCached---') ?
          option.classList.remove('button-outline') :
          option.classList.add('button-outline');
    });
    drawSliceLines(slices, (file || getFileById(lastSelectedRow.dataset.id)),
      otMeta);
    if (file?.meta?.customSlices) {
        file.meta.customSlices = false;
    }
};

const remove = (id, skipStateStore) => {
    stopPlayFile(false, id);
    const rowEl = getRowElementById(id);
    const fileIdx = getFileIndexById(id);
    const removed = files.splice(fileIdx, 1);
    const unsortIdx = unsorted.findIndex(uuid => uuid === id);
    unsorted.splice(unsortIdx, 1);
    if (removed[0]) {
        metaFiles.removeByName(removed[0].file.name);
        removed.buffer ? delete removed.buffer : false;
    }
    rowEl.classList.add('hide');
    rowEl.remove();
    return skipStateStore ? true : storeState();
};

const move = (event, id, direction) => {
    const from = getFileIndexById(id);
    let item;
    let to = direction === 1 ? (from + 1) : (from - 1);
    if (to === -1) { to = files.length - 1; }
    if (to >= files.length) { to = 0; }
    item = files.splice(from, 1)[0];
    if ((event.shiftKey || modifierKeys.shiftKey)) { /*If shift key, move to top or bottom of list.*/
        from > to ? files.splice(0, 0, item) : files.splice(files.length, 0,
          item);
    } else {
        files.splice(to, 0, item);
    }
    renderList();
};
const sort = (event, by, prop = 'meta') => {
    const groupByChecked = (event.shiftKey || modifierKeys.shiftKey);
    const forLocaleCompare = ['name'];
    const mapOrder = (order, prop, by) => (a, b) => {
        let oA = order.indexOf(a[prop][by]);
        let oB = order.indexOf(b[prop][by]);
        return oA >= oB ? 1 : -1;
    }
    if (by === 'id') {
        if (groupByChecked === true) {
            files.sort(
              () => crypto.randomUUID().localeCompare(crypto.randomUUID()));
        } else {
            const newImports = unsorted.filter(u => !importOrder.includes(u));
            importOrder = [...importOrder, ...newImports];
            files.sort(mapOrder(importOrder, prop, by));
            lastSort = '';
        }
    } else if (by === 'note') {
        const noteOrder = [];
        const notes = [
            'C',
            'C#',
            'Db',
            'D',
            'D#',
            'Eb',
            'E',
            'F',
            'F#',
            'Gb',
            'G',
            'G#',
            'Ab',
            'A',
            'A#',
            'Bb',
            'B'];
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16].forEach(
          o => notes.forEach(n => noteOrder.push(`${n}${o}`)));
        files = files.sort((a, b) => {
            const noteA = a[prop][by];
            const noteB = b[prop][by];
            const noteValueA = noteOrder.indexOf(noteA);
            const noteValueB = noteOrder.indexOf(noteB);
            return noteValueA < noteValueB ? -1 : 1;
        });
        if (lastSort === by) {
            files.reverse();
            lastSort = '';
        } else {
            lastSort = by;
        }
    } else {
        if (lastSort === by) {
            //files.reverse();
            if (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) {
                files.sort((a, b) => (+(b[prop][by].replace(/\D+/gi, ''))  - +(a[prop][by].replace(/\D+/gi, '')) ));
            } else {
                files = forLocaleCompare.includes(by) ?
                  files.sort((a, b) => b[prop][by].localeCompare(a[prop][by])) :
                  files.sort((a, b) => (b[prop][by] - a[prop][by]));
            }
            lastSort = '';
        } else {
            if (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) {
                files.sort((a, b) => (+(a[prop][by].replace(/\D+/gi, '')) - +(b[prop][by].replace(/\D+/gi, '')) ));
            } else {
                files = forLocaleCompare.includes(by) ?
                  files.sort((a, b) => a[prop][by].localeCompare(b[prop][by])) :
                  files.sort((a, b) => (a[prop][by] - b[prop][by]));
            }
            lastSort = by;
        }
    }
    if (groupByChecked === true && by !== 'id') {
        files.sort((a, b) => (b.meta.checked - a.meta.checked));
    }
    if (event.skipRender) {
        return;
    }
    renderList();
};

const selectedHeaderClick = event => {
    if (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) {
        const allChecked = files.every(f => f.meta.checked);
        files.forEach(f => f.meta.checked = !allChecked);
        renderList();
    } else {
        sort(event, 'checked');
    }
};

const handleRowClick = (event, id) => {
    const row = getRowElementById(id);
    if (document.body.classList.contains('loading') || !row) {
        return;
    }
    if (document.querySelector('.pop-up.show')) { return; }
    if (lastSelectedRow) { lastSelectedRow.classList.remove('selected'); }
    row.classList.add('selected');
    lastLastSelectedRow = lastSelectedRow;
    lastSelectedRow = row;
    lastSelectedRow.scrollIntoViewIfNeeded(true);
    setCountValues();

};

const rowDragStart = (event) => {
    if (event.target?.classList?.contains('file-row')) {
        const opExport = document.getElementById('opExportPanel');
        if (!navigator.vendor.startsWith('Apple') && opExport.classList.contains('show')) {
            opExport.style.transform = 'translateX(-9999px)';
            setTimeout(() => opExport.style.transform = 'translateX(0)', 0);
        }
        event.target.classList.add('is-dragging');
        lastSelectedRow = event.target;
        attachDragDownloadBlob(event, event.target.dataset.id);
    }
};

const drawSliceLines = (slices, file, otMeta) => {
    const _slices = typeof slices === 'number'
      ? Array.from('.'.repeat(slices)).map((x, i) => ({
          startPoint: (file.buffer.length / slices) * i,
          endPoint: (file.buffer.length / slices) * (i + 1)
      }))
      : slices;
    const sliceLinesEl = document.getElementById('sliceLines');
    const splitPanelWaveformContainerEl = document.querySelector(
      `#splitOptions .waveform-container`);
    const waveformWidth = splitPanelWaveformContainerEl.dataset.waveformWidth;
    let lines = [];
    if (file && otMeta) {
        let scaleSize = file.buffer.length / waveformWidth;
        lines = otMeta.slices.map(
            (slice, idx) => `
                <div
                    class="line ${(slice.loopPoint??-1) !== -1 ? 'slice-loop' : ''} ${(file.meta?.otLoop === 1 && slice.startPoint >= file.meta?.otLoopStart) ? 'file-loop-on' : ''} ${(file.meta?.otLoop === 2 && slice.startPoint >= file.meta?.otLoopStart) ? 'file-loop-pp' : ''}"
                    data-idx="${idx}"
                    onclick="digichain.sliceAction(event, '${file.meta.id}', {startPoint: '${slice.startPoint}', endPoint: '${slice.endPoint}'})"
                    ondblclick="this.classList[this.classList.contains('fade') ? 'remove' : 'add']('fade')"
                    title="${slice.name || ('Slice ' + (idx + 1))}"
                    style="margin-left:${(slice.startPoint / scaleSize)}px; width:${(slice.endPoint / scaleSize) - (slice.startPoint / scaleSize)}px;"
                ></div>
            `
        );
    } else {
        lines = _slices.map((slice, idx) => `
            <div class="line" data-idx="${idx}" onpointerdown="digichain.playSlice(event, '${file.meta.id}', '${slice.startPoint}', '${slice.endPoint}')" ondblclick="this.classList[this.classList.contains('fade') ? 'remove' : 'add']('fade')"style="margin-left:${(waveformWidth /
                _slices.length) * idx}px; width:${(waveformWidth /
                _slices.length)}px;" title="Slice ${idx + 1}"></div>
        `);
        //
        // lines = _slices.map((slice, idx) => `
        //   <div class="line" onclick="digichain.selectSlice(event)" style="margin-left:${(waveformWidth/_slices.length) * idx}px; width:${(waveformWidth/_slices.length)}px;"></div>
        // `);
    }
    sliceLinesEl.innerHTML = lines.join('');
};

const splitAction = async (event, id, slices, saveSlicesMetaOnly, fromOpExport) => {
    const el = document.getElementById('splitOptions');
    const fileNameEl = document.getElementById('splitFileName');
    const sliceGroupEl = document.querySelector(
      `#splitOptions .slice-group`);
    const sliceByOtButtonEl = document.getElementById('sliceByOtButton');
    const sliceByTransientButtonEl = document.getElementById(
      'sliceByTransientButton');
    const sliceByTransientThresholdEl = document.getElementById(
      'transientThreshold');
    const splitPanelWaveformContainerEl = document.querySelector(
      `#splitOptions .waveform-container`);
    const splitPanelWaveformEl = document.getElementById('splitPanelWaveform');
    const excludeSlices = [...el.querySelectorAll(`div.line.fade`)].map(
      s => +s.dataset.idx);
    let item;
    let otMeta;
    let pushInPlace = (event.shiftKey || modifierKeys.shiftKey || fromOpExport);
    if ((event.target.className.includes('is-') ||
        event.target.parentElement.className.includes('is-')) &&
      (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey)) {
        item = getFileById(id || lastSelectedRow.dataset.id);
        const confirmClear = await dcDialog('confirm', `Clear slice data for ${item.file.name}?`);
        if (confirmClear) {
            item.meta.slices = false;
            if (item.meta.op1Json) {
                item.meta.op1Json = false;
            }
            metaFiles.removeByName(item.file.name);
            reRenderListRow(item.meta.id);
        }
        return;
    }
    if (id) {
        lastSelectedRow = getRowElementById(id);
        sliceGroupEl.dataset.id = id;
    }
    if (slices === true) { slices = sliceGroupEl.dataset.sliceCount; }
    item = getFileById(id || lastSelectedRow.dataset.id);
    if (slices) {
        id = id || item.meta.id;
        if (slices === 'ot' ||
          !sliceByTransientButtonEl.classList.contains('button-outline') ||
          !sliceByOtButtonEl.classList.contains('button-outline') || (fromOpExport && item.meta.slices?.length)) {
            const sliceSource = sliceByTransientButtonEl.classList.contains(
              'button-outline') ? 'ot' : 'transient';
            splitByOtSlices(event, id, pushInPlace, sliceSource, excludeSlices,
              saveSlicesMetaOnly);
        } else {
            if (item.meta.customSlices) {
                splitByOtSlices(event, id, pushInPlace, 'custom', excludeSlices,
                  saveSlicesMetaOnly);
            } else {
                splitEvenly(event, id, slices, pushInPlace, excludeSlices,
                  saveSlicesMetaOnly);
            }
        }
        if (saveSlicesMetaOnly) {
            setTimeout(() => sliceByOtButtonEl.dispatchEvent(new PointerEvent('pointerdown')), 250);
        } else {
            return el.close();
        }
    }
    otMeta = metaFiles.getByFile(item);
    fileNameEl.textContent = getNiceFileName('', item, true);
    sliceByOtButtonEl.style.display = otMeta ? 'inline-block' : 'none';
    sliceByOtButtonEl.textContent = otMeta ? `${otMeta.sliceCount}` : 'OT';
    splitSizeAction(false, 0);
    isOpExportPanelOpen()?.classList?.remove('show');
    if (!el.open) { el.showModal(); }
    drawWaveform(item, splitPanelWaveformEl, item.meta?.channel ?? 0, {
        width: +splitPanelWaveformContainerEl.dataset.waveformWidth, height: 128
    });
    item.meta.customSlices = false;
    if (otMeta?.sliceCount) {
        sliceByOtButtonEl.dispatchEvent(new PointerEvent('pointerdown'));
    }
    reRenderListRow(item.meta.id);
};

const secondsToMinutes = (time) => {
    const mins = Math.floor(time / 60);
    const seconds = Number(time % 60).toFixed(2);
    return mins > 0 ? `${mins}m ${Math.round(+seconds)}s` : `${seconds}s`;
};

const clearModifiers = () => {
    modifierKeys.shiftKey = false;
    modifierKeys.ctrlKey = false;
    document.body.classList.remove('shiftKey-down');
    document.body.classList.remove('ctrlKey-down');
};

const setFileNumTicker = () => {
    const filesSelected = files.filter(f => f.meta.checked);
    const selectionCount = filesSelected.length;
    const isProcessing = processedCount !== 0;
    const fileNumEl = document.getElementById(
      'fileNum');
    fileNumEl.textContent = `${isProcessing ? '   ' : files.length}/${selectionCount}`;
    fileNumEl.classList[isProcessing ? 'add' : 'remove']('gg-spinner');
};

function setCountValues() {
    const filesSelected = files.filter(f => f.meta.checked);
    const selectionCount = filesSelected.length;
    let sliceGridT = settings.exportChainsAsXyPresets ? ((sliceGrid > 24 || !sliceGrid) ? 24 : sliceGrid) : sliceGrid;
    const selectionSlicesCount = settings.splitOutExistingSlicesOnJoin ? filesSelected.reduce(
      (a, f) => a + (f.meta?.slices?.length ? (f.meta.slices.length - 1) : 0), 0
    ) : 0;
    const chainCount = selectionSlicesCount + selectionCount;
    const filesDuration = files.reduce((a, f) => a += +f.meta.duration, 0);
    const filesSelectedDuration = filesSelected.reduce(
      (a, f) => a += +f.meta.duration, 0);
    const joinCount = chainCount === 0 ? 0 : (chainCount > 0 &&
    sliceGridT > 0 ? Math.ceil(chainCount / sliceGridT) : 1);
    const chainText = settings.exportChainsAsXyPresets ? ' Preset' : ' Chain';
    document.getElementById(
      'fileNum').textContent = `${files.length}/${selectionCount}` + (selectionSlicesCount ?
      ` (+${selectionSlicesCount} slices)`: '');
    document.getElementById(
      'fileNum').classList.remove('gg-spinner');
    document.querySelector(
      '.selection-count').textContent = ` ${selectionCount || '-'} `;
    document.querySelector(
      '.selection-count').dataset.selectionCount = `${selectionCount}`;
    document.getElementById(
      'lengthHeaderLink').textContent = `Length (${secondsToMinutes(
      filesSelectedDuration)}/${secondsToMinutes(filesDuration)})`;
    if (secondsPerFile === 0) {
        document.querySelectorAll('.join-count').
          forEach((el, idx) => {
              el.textContent = ` ${
                joinCount === 0
                  ? '-'
                  : joinCount}${idx === 0 ? ' Spaced' : ''}${joinCount === 1
                ? chainText
                : chainText + 's'}`;
              el.dataset.joinCount = `${joinCount}`;
          });
        try {
            document.querySelectorAll('tr').
              forEach(row => row.classList.remove('end-of-grid'));
            /*Can't show the end-joined-file line when slices are treated as distinct files in join operations.*/
            if (!settings.splitOutExistingSlicesOnJoin) {
                document.querySelectorAll('tr.checked').forEach(
                  (row, i) => (i + 1) % sliceGridT === 0 ? row.classList.add(
                    'end-of-grid') : row.classList.remove('end-of-grid')
                );
            }
        } catch (e) {}
    } else { /*When using max length in seconds.*/
        const calcFiles = (items, count = 0) => {
            let progress = {duration: 0, processed: [], skipped: [], count};
            let _items = items.filter(f => +f.meta.duration < secondsPerFile);
            let maxChainLength = (
              targetContainer === 'a' ? 24 : (sliceGridT === 0
                ? 64
                : sliceGridT));
            while (_items.length > 0) {
                progress = _items.reduce((a, f) => {
                    if (a.duration + +f.meta.duration <=
                      (secondsPerFile * settings.pitchModifier) && a.processed.length <
                      maxChainLength) {
                        a.duration = a.duration + +f.meta.duration;
                        a.processed.push(f);
                    } else {
                        a.skipped.push(f);
                    }
                    return a;
                }, progress);
                progress.count++;
                progress.duration = 0;
                progress.processed = [];
                _items = Array.from(progress.skipped);
                progress.skipped = [];
            }
            return progress.count;
        };

        let joinCountSec = filesSelected.length === 0 ? 0 : calcFiles(
          filesSelected);
        document.querySelector(
          '.join-count-chain').textContent = ` ${joinCountSec === 0
          ? '-'
          : joinCountSec}${joinCountSec === 1 ? ' Chain' : ' Chains'}`;
        document.querySelector(
          '.join-count-chain').dataset.joinCount = joinCountSec;
        try {
            document.querySelectorAll('tr').
              forEach(row => row.classList.remove('end-of-grid'));
        } catch (e) {}
    }
    clearModifiers();
}

function reRenderListRow(id) {
    const item = getFileById(id);
    const rowEl = getRowElementById(id);
    rowEl.innerHTML = buildRowMarkupFromFile(item);
    const rowWaveform = rowEl.querySelector('canvas.waveform');
    if (rowWaveform && item.waveform) {
        rowWaveform.replaceWith(item.waveform);
    }
}

const getWaveformElementContent = f => {
    if (settings.skipMiniWaveformRender) {
        return `<i onpointerdown="digichain.playFile(event, '${f.meta.id}')" class="gg-play-button waveform-btn ${f.meta.playing
          ? 'playing'
          : ''}"></i>`;
    }
    return `<canvas onpointerdown="digichain.playFile(event, '${f.meta.id}')" class="waveform waveform-${f.meta.id} ${f.meta.playing
      ? 'playing'
      : ''}"></canvas>`;
};

const buildRowMarkupFromFile = (f, type = 'main') => {
    return type === 'main' ?
      `
    <tr class="file-row ${f.meta.checked
        ? 'checked'
        : ''}" data-id="${f.meta.id}"
          onpointerdown="digichain.handleRowClick(event, '${f.meta.id}')"
          ondragstart="digichain.rowDragStart(event)" draggable="true">
      <td>
          <i class="gg-more-vertical"></i>
      </td>
      <td class="toggle-td">
          <button onpointerdown="digichain.toggleCheck(event, '${f.meta.id}')" class="${f.meta.checked
        ? ''
        : 'button-outline'} check toggle-check">&nbsp;</button>
      </td>
      <td class="move-up-td">
          <button title="Move up in sample list." onclick="digichain.move(event, '${f.meta.id}', -1)" class="button-clear move-up"><i class="gg-chevron-up-r has-shift-mod-i"></i></button>
      </td>
      <td class="move-down-td">
          <button title="Move down in sample list." onclick="digichain.move(event, '${f.meta.id}', 1)" class="button-clear move-down"><i class="gg-chevron-down-r has-shift-mod-i"></i></button>
      </td>
      <td class="waveform-td">` +
        getWaveformElementContent(f) +
      `</td>
      <td class="file-path-td">
      ${(f.file.path + f.file.name).length + 4 > 127
        ?
        '<div title="This files path and name will exceed 127 chars." class="path-exceeds-127">'
        :
        '<div>'
      }
          <span class="file-path">${f.file.path}</span>
          <a title="${settings.shiftClickForFileDownload ? 'Shift+Click to d' : 'D'}ownload processed wav file of sample." class="wav-link" onclick="digichain.downloadFile('${f.meta.id}', true, event)">${getNiceFileName(
        f.file.name)}</a>
          ${f.meta.dupeOf ? ' d' : ''}
          ${f.meta.editOf ? ' e' : ''}
          ${f.meta.isMerge ? ' m' : ''}
          ${f.meta.sliceNumber ? ' s' + f.meta.sliceNumber : ''}
          <a class="wav-link-hidden" target="_blank"></a>
          <a class="meta-link-hidden" target="_blank"></a>
          </div>
      </td>
      <td class="duration-td">
          <span>${f.meta.duration} s</span>
      </td>
      <td class="channel-options-td">
          <div class="channel-options has-shift-mod" style="display: ${f.buffer.numberOfChannels >
      1 && masterChannels === 1 ? 'block' : 'none'}">
          <a title="Left channel" onclick="digichain.changeChannel(event, '${f.meta.id}', 'L')" class="${f.meta.channel ===
      'L' ? 'selected' : ''} channel-option-L">L</a>
          <a title="Sum to mono" onclick="digichain.changeChannel(event, '${f.meta.id}', 'S')" class="${f.meta.channel ===
      'S' ? 'selected' : ''} channel-option-S">S</a>
          <a title="Right channel" onclick="digichain.changeChannel(event, '${f.meta.id}', 'R')" class="${f.meta.channel ===
      'R' ? 'selected' : ''} channel-option-R">R</a>
          <a title="Difference between Left and Right channels" onclick="digichain.changeChannel(event, '${f.meta.id}', 'D')" class="${f.meta.channel ===
      'D' ? 'selected' : ''} channel-option-D">D</a>
          </div>` +

      (targetContainer === 'a' ?
        `<div class="channel-options channel-options-stereo channel-options-stereo-opf ${f.meta.opPanAb
          ? 'op-pan-ab-true'
          : ''}" title="${f.buffer.numberOfChannels === 1
          ? 'Mono sample'
          : 'Stereo sample'}" style="display: ${masterChannels === 2
          ? 'block'
          : 'none'}"
           ondblclick="digichain.changeOpParam(event, '${f.meta.id}', 'baltoggle')"
           >
              <input class="channel-balance" type="range" style="display: ${f.buffer.numberOfChannels ===
        2
          ? 'inline-block'
          : 'none'}" min="0" max="32768" onchange="digichain.changeOpParam(event, '${f.meta.id}', 'bal')" value="${f.meta.opPan ??
        16384}" />
              <i class="gg-shape-circle" style="display: ${f.buffer.numberOfChannels ===
        1 ? 'inline-block' : 'none'}"></i>
              <div style="display: ${f.buffer.numberOfChannels === 2
          ? 'inline-block'
          : 'none'}">
                <span class="op-la"></span>
                <span class="op-rb"></span>
              </div>
          </div>` :
        `<div class="channel-options channel-options-stereo" title="${f.buffer.numberOfChannels ===
        1
          ? 'Mono sample'
          : 'Stereo sample' + (f.meta.dualMono
          ? ' (Dual Mono)'
          : '')}" style="display: ${masterChannels === 2
          ? 'block'
          : 'none'}">
              <i class="gg-shape-circle"></i>
              <i class="gg-shape-circle stereo-circle" style="display: ${f.buffer.numberOfChannels ===
        2 ? 'inline-block' : 'none'}"></i>
          </div>`) +

      `</td>
      <td class="split-td">
          <button title="Slice sample." onpointerdown="digichain.splitAction(event, '${f.meta.id}')" class="button-clear split gg-menu-grid-r ${metaFiles.getByFile(
        f)?.cssClass}" data-slice-count="${f.meta?.slices?.length || f.meta?.op1Json?.sliceCount || ''}"><i class="gg-menu-grid-r has-ctrl-mod-i"></i></button>
      </td>
      <td class="duplicate-td">
          <button title="Duplicate sample." onpointerdown="digichain.duplicate(event, '${f.meta.id}')" class="button-clear duplicate"><i class="gg-duplicate has-shift-mod-i"></i></button>
      </td>
      <td class="toggle-edit-td">
          <button title="Edit" onpointerdown="digichain.showEditPanel(event, '${f.meta.id}')" class="button-clear toggle-edit"><i class="gg-pen"></i></button>
      </td>
      <td class="remove-td">
          <button title="Remove sample (double-click)." ondblclick="digichain.remove('${f.meta.id}')" class="button-clear remove"><i class="gg-trash"></i></button>
      </td>
    </tr>` :
      `
<tr class="file-row" data-id="${f.meta.id}">
  <td class="file-path-td">
    <span class="file-path">${f.file.path}</span>
    <span>${getNiceFileName(
        f.file.name)}</span>
    ${f.meta.dupeOf ? ' d' : ''}
    ${f.meta.editOf ? ' e' : ''}
    ${f.meta.isMerge ? ' m' : ''}
    ${f.meta.sliceNumber ? ' s' + f.meta.sliceNumber : ''}
    <a class="wav-link-hidden" target="_blank"></a>
  </td>
  <td class="duration-td">
    <span>${f.meta.duration} s</span>
  </td>
  <td class="channel-options-td"">
      <div class="channel-options" style="display: ${f.buffer.numberOfChannels >
      1 ? 'block' : 'none'}">
      <a title="Left channel" onclick="digichain.changeChannel(event, '${f.meta.id}', 'L', false, '#mergeList')" class="${f.meta.channel ===
      'L' ? 'selected' : ''} channel-option-L">L</a>
      <a title="Sum to mono" onclick="digichain.changeChannel(event, '${f.meta.id}', 'S', false, '#mergeList')" class="${f.meta.channel ===
      'S' ? 'selected' : ''} channel-option-S">S</a>
      <a title="Right channel" onclick="digichain.changeChannel(event, '${f.meta.id}', 'R', false, '#mergeList')" class="${f.meta.channel ===
      'R' ? 'selected' : ''} channel-option-R">R</a>
      <a title="Difference between Left and Right channels" onclick="digichain.changeChannel(event, '${f.meta.id}', 'D', false, '#mergeList')" class="${f.meta.channel ===
      'D' ? 'selected' : ''} channel-option-D">D</a>
      </div>
      <div class="channel-options channel-options-stereo" title="Mono sample" style="display: ${f.buffer.numberOfChannels ===
      1 ? 'block' : 'none'}">
          <i class="gg-shape-circle"></i>
      </div>
  </td>
  <td class="pan-options-td ${type === 'blend' ? 'hide' : ''}">
      <div class="pan-options" style="display: block;">
      <a title="Hard Left" onclick="digichain.changePan(event, '${f.meta.id}', 'L')" class="${f.meta.pan ===
      'L' ? 'selected' : ''} pan-option-L">L</a>
      <a title="Centre" onclick="digichain.changePan(event, '${f.meta.id}', 'C')" class="${f.meta.pan ===
      'C' ? 'selected' : ''} pan-option-C">C</a>
      <a title="Hard Right" onclick="digichain.changePan(event, '${f.meta.id}', 'R')" class="${f.meta.pan ===
      'R' ? 'selected' : ''} pan-option-R">R</a>
      </div>
  </td>
</tr>`;
};

const drawEmptyWaveforms = (_files) => {
    const canvasElements = document.querySelectorAll('.waveform');
    if (canvasElements.length === 0) {
        document.querySelectorAll('.waveform-btn').forEach((el, i) => {
            if (!_files[i] || _files[i].waveform) { return; }
            _files[i].waveform = el;
        });
        return setCountValues();
    }
    canvasElements.forEach((el, i) => {
        if (!_files[i] || settings.skipMiniWaveformRender) { return; }
        if (_files[i].waveform && _files[i].waveform.nodeName === 'CANVAS' && el.nodeName === 'CANVAS') {
            el.replaceWith(_files[i].waveform);
            if (_files[i].playHead && !_files[i].waveform.nextElementSibling) {
                _files[i].waveform.parentElement.appendChild(
                  _files[i].playHead);
            }
        } else {
            drawWaveform(_files[i], el,
              ((masterChannels > 1 && _files[i].buffer.numberOfChannels > 1)
                ? 'S'
                : _files[i].meta?.channel ?? 0));
            _files[i].waveform = el;
        }
    });
    setCountValues();
};

const renderRow = (item, type) => {
    const rowData = item || getFileById(lastSelectedRow.dataset.id);
    const rowEl = item ? getRowElementById(item.meta.id) : lastSelectedRow;
    rowEl.innerHTML = buildRowMarkupFromFile(rowData, type);
    drawEmptyWaveforms(files);
    setLoadingText('');
};

const renderList = (fromIdb = false) => {
    listEl.innerHTML = showSamplesList ?
      files.map(f => buildRowMarkupFromFile(f)).join('') :
      `<tr><td colspan="14" style="padding: 2.5rem 1rem 0 4rem;"><p>Hiding samples list, press <code>Shift + L</code> to show.</p></td></tr>`;
    if (files.length === 0) {
        listEl.innerHTML = '';
    }
    drawEmptyWaveforms(files);
    if (files.length && !fromIdb) {
        storeState();
    }
    setLoadingText('');
};
const bytesToInt = (bh, bm, bl) => {
    return ((bh & 0x7f) << 7 << 7) + ((bm & 0x7f) << 7) + (bl & 0x7f);
};

function noteFromFileName(name) {
    const match = name.match(/(_| |-)([A-Ga-g](?:#|b)?)(-?\d+)\.\w+$/);
    return match && match.length > 2 ? (match[1] + match[2] +
      (match[3] || '')).replace(/_|-|\./g, '').trim() : '';
}

async function createOtMetaFile() {
    const el = document.getElementById('splitOptions');
    const metaEl = getRowElementById(lastSelectedRow.dataset.id).querySelector('.meta-link-hidden');
    const file = getFileById(lastSelectedRow.dataset.id);
    const excludeSlices = [...el.querySelectorAll(`div.line.fade`)].map(
      s => +s.dataset.idx);
    const slices = metaFiles.getByFileInDcFormat(file).filter(
      (x, idx) => !excludeSlices.includes(idx));

    const otFile = await createAndSetOtFileLink(slices, file, file.file.name, metaEl, true);
    if (otFile) { metaEl.click(); }
}

async function createAndSetOtFileLink(slices, file, fileName, linkEl, skipExportWithCheck) {
    if (checkShouldExportOtFile(skipExportWithCheck) && slices && slices.length > 0) {
        let bufferLength = file.buffer.length;
        const tempo = await detectTempo(file.buffer, fileName);
        let _slices = slices.length > 64 ? slices.slice(0, 64) : slices;
        let data = encodeOt(_slices, bufferLength, tempo?.match??120, {
            loop: file.meta.otLoop??0,
            loopStart: file.meta.otLoopStart??0
        });
        let fName = fileName.replace(/\.[^.]*$/, '.ot')
        if (!data) { return false; }
        let blob = new window.Blob([data], {
            type: 'application/octet-stream'
        });
        if (linkEl) {
            linkEl.href = URL.createObjectURL(blob);
            linkEl.setAttribute('download', fName);
        }
        return {blob: blob, name: fName};
    }
    return false;
}

const parseXml = (xml, fullPath) => {
    let uuid = crypto.randomUUID();
    try {
        const parser = new DOMParser();
        const doc = parser.parseFromString(xml, 'application/xml');
        const docType = doc.childNodes[0].tagName;

        if (docType === 'RenoiseSong' || docType === 'RenoiseInstrument') {
            const path = fullPath.replace('Song.xml', '').replace('Instrument.xml', '');
            const xmlSamples = [...doc.getElementsByTagName('Sample')];
            const sampleSlices = xmlSamples.map(sample => ({
                uuid: crypto.randomUUID(),
                name: sample.getElementsByTagName('Name')[0].textContent,
                loopEnd: +sample.getElementsByTagName('DisplayLength')[0].textContent,
                slices: [...sample.getElementsByTagName('SliceMarker')].map(
                  slice => +slice.getElementsByTagName('SamplePosition')[0].textContent
                )
            })).filter(sample => sample.slices.length > 0)

            sampleSlices.forEach(sample => {
                uuid = sample.uuid;
                metaFiles.push({
                    uuid,
                    name: sample.name,
                    path: path,
                    sliceCount: sample.slices.length,
                    loopEnd: sample.loopEnd,
                    slices: sample.slices.map((slice, idx, slices) => ({
                        startPoint: slice,
                        endPoint: slices[idx + 1] ?? sample.loopEnd,
                        loopPoint: -1
                    }))
                });
                unsorted.push(uuid);
            });
        }
        return uuid;
    } catch (err) {
        return {uuid, failed: true};
    }
};

const parseOt = (fd, file, fullPath) => {
    const uuid = file.uuid || crypto.randomUUID();
    const getInt32 = values => {
        const arr = new Uint8Array(values);
        const view = new DataView(arr.buffer);
        return view.getInt32(0);
    };
    try {
        // Check header is correct.
        if (![
            0x46, 0x4F, 0x52, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x44, 0x50, 0x53,
            0x31, 0x53, 0x4D, 0x50, 0x41].every(
          (b, i) => b === fd[i])
        ) {
            return {uuid, failed: true};
        }
        let loop = getInt32([fd[39], fd[40], fd[41], fd[42]]);
        let loopStart = getInt32([fd[54], fd[55], fd[56], fd[57]]);
        let slices = [];
        let sliceCount = getInt32([fd[826], fd[827], fd[828], fd[829]]);
        let t = 58;
        for (let s = 0; s < sliceCount; s++) {
            if (masterSR === 44100) {
                slices.push({
                    startPoint: getInt32(
                      [fd[t], fd[t + 1], fd[t + 2], fd[t + 3]]),
                    endPoint: getInt32(
                      [fd[t + 4], fd[t + 5], fd[t + 6], fd[t + 7]]),
                    loopPoint: getInt32(
                      [fd[t + 8], fd[t + 9], fd[t + 10], fd[t + 11]])
                });
            } else {
                slices.push({
                    startPoint: Math.round(
                      (getInt32([fd[t], fd[t + 1], fd[t + 2], fd[t + 3]]) /
                        44100) *
                      masterSR),
                    endPoint: Math.round(
                      (getInt32([fd[t + 4], fd[t + 5], fd[t + 6], fd[t + 7]]) /
                        44100) * masterSR),
                    loopPoint: Math.round(
                      (getInt32(
                          [fd[t + 8], fd[t + 9], fd[t + 10], fd[t + 11]]) /
                        44100) * masterSR)
                });
            }
            t = t + 12;
        }
        metaFiles.push({
            uuid,
            name: file.name,
            path: fullPath,
            cssClass: 'is-ot-file',
            otLoop: loop,
            otLoopStart: loopStart,
            sliceCount,
            slices
        });
        unsorted.push(uuid);
        return uuid;
    } catch (err) {
        return {uuid, failed: true};
    }
};
const parseAif = async (
  arrayBuffer, fd, file, fullPath = '', pushToTop = false) => {
    const uuid = file.uuid || crypto.randomUUID();
    let result;
    try {
        let dv = new DataView(arrayBuffer);
        let chunks = {};
        let chunkKeys = ['FORM', 'COMM', 'APPL', 'SSND'];

        const getChunkData = (code, offset) => {
            switch (code) {
                case 'FORM':
                    chunks.form = {
                        offset,
                        id: String.fromCharCode(dv.getUint8(offset),
                          dv.getUint8(offset + 1),
                          dv.getUint8(offset + 2), dv.getUint8(offset + 3)),
                        fileSize: dv.getUint32(offset + 4),
                        type: String.fromCharCode(dv.getUint8(offset + 8),
                          dv.getUint8(offset + 9), dv.getUint8(offset + 10),
                          dv.getUint8(offset + 11))
                    };
                    break;
                case 'COMM':
                    chunks.comm = {
                        offset,
                        id: String.fromCharCode(dv.getUint8(offset),
                          dv.getUint8(offset + 1), dv.getUint8(offset + 2),
                          dv.getUint8(offset + 3)),
                        size: dv.getUint32(offset + 4),
                        channels: dv.getUint16(offset + 8),
                        frames: dv.getUint32(offset + 10),
                        bitDepth: dv.getUint16(offset + 14),
                        sampleRate: ((os) => {
                            const srArr = [];
                            for (let x = os; x < os + 10; x++) {
                                srArr.push(dv.getUint8(x));
                            }
                            return getAifSampleRate(srArr);
                        })(offset + 16)
                    };
                    break;
                case 'APPL'://'op-1':
                    const utf8Decoder = new TextDecoder('utf-8');
                    const scale = 2147483646 / (44100 * (chunks.comm.channels === 2 ? 20 : 12));
                    chunks.json = {
                        id: String.fromCharCode(dv.getUint8(offset),
                          dv.getUint8(offset + 1), dv.getUint8(offset + 2),
                          dv.getUint8(offset + 3)),
                        size: dv.getUint32(offset + 4),
                        scale
                    };
                    let jsonString = utf8Decoder.decode(
                      arrayBuffer.slice(offset + 12,
                        chunks.json.size + offset + 8));
                    chunks.json.data = JSON.parse(
                      jsonString.replace(/\]\}(.|\n)+/gi, ']}').trimEnd());
                    break;
                case 'SSND':
                    chunks.buffer = arrayBuffer.slice(offset + 4);
                    chunks.bufferDv = new DataView(chunks.buffer);
            }
        };

        for (let i = 0; i < dv.byteLength - 4; i++) {
            const code = String.fromCharCode(dv.getUint8(i), dv.getUint8(i + 1),
              dv.getUint8(i + 2), dv.getUint8(i + 3));
            if (chunkKeys.includes(code)) {
                getChunkData(code, i);
                chunkKeys = chunkKeys.filter(k => k !== code);
            }
        }

        /*Only supporting 16bit Aif files, other bit-depths will be skipped.*/
        if (+chunks.comm.bitDepth !== 16) {
            setLoadingText(`Skipping unsupported ${chunks.comm.bitDepth}bit aif file '${file.name}'...`);
            delete chunks.buffer;
            delete chunks.bufferDv;
            dv = false;
            arrayBuffer = false;
            return {uuid, failed: true};
        }

        const offset = 4; // The offset of the first byte of audio data
        const bytesPerSample = chunks.comm.bitDepth / 8;
        const channels = [];
        for (let i = 0; i < chunks.comm.channels; i++) {
            channels.push(new Float32Array(chunks.comm.frames));
        }

        for (let i = 0; i < chunks.comm.channels; i++) {
            let channel = channels[i];
            for (let j = 0; j < chunks.comm.frames; j++) {
                let index = offset;
                index += (j * chunks.comm.channels + i) * bytesPerSample;
                // Sample
                let value = chunks.bufferDv.getInt16(index,
                  chunks.form.type === 'AIFC');
                // Scale range from 0 to 2**bitDepth -> -2**(bitDepth-1) to
                // 2**(bitDepth-1)
                let range = 1 << chunks.comm.bitDepth - 1;
                if (value >= range) {
                    value |= ~(range - 1);
                }
                // Scale range to -1 to 1
                channel[j] = value / range;
                if (j === 0) {
                    channel[j] = 0;
                }
            }
        }

        let resample, resampleR;
        resample = new Resampler(chunks.comm.sampleRate, masterSR, 1,
          channels[0]);
        resample.resampler(resample.inputBuffer.length);

        if (chunks.comm.channels === 2) {
            resampleR = new Resampler(chunks.comm.sampleRate, masterSR, 1,
              channels[1]);
            resampleR.resampler(resampleR.inputBuffer.length);
        }

        const audioArrayBuffer = audioCtx.createBuffer(
          chunks.comm.channels,
          resample.outputBuffer.length,
          masterSR
        );
        if (chunks.comm.channels === 2) {
            for (let i = 0; i < resample.outputBuffer.length; i++) {
                audioArrayBuffer.getChannelData(
                  0)[i] = resample.outputBuffer[i];
                audioArrayBuffer.getChannelData(
                  1)[i] = resampleR.outputBuffer[i];
            }
        } else {
            for (let i = 0; i < resample.outputBuffer.length; i++) {
                audioArrayBuffer.getChannelData(
                  0)[i] = resample.outputBuffer[i];
            }
        }
        const getRelPosition = v => v / chunks.json.scale;

        /*Update the slice points to masterSR - hardcoded to 44100 as OP sample rate will always be this.*/
        if (chunks.json && chunks.json.data.start) {
            chunks.json.data.start = chunks.json.data.start.map(
              (s, i) => Math.floor((getRelPosition(s, i) / 44100) * masterSR));
        }
        if (chunks.json && chunks.json.data.end) {
            chunks.json.data.end = chunks.json.data.end.map(
              (s, i) => Math.floor((getRelPosition(s, i) / 44100) * masterSR));
        }

        const parsedFile = {
            file: {
                lastModified: file.lastModified,
                name: getUniqueName(files, file.name),
                filename: file.name,
                path: fullPath.replace(file.name, ''),
                size: file.size,
                type: file.type
            },
            buffer: audioArrayBuffer, meta: {
                length: audioArrayBuffer.length,
                duration: Number(audioArrayBuffer.length / masterSR).toFixed(3),
                startFrame: 0, endFrame: audioArrayBuffer.length,
                op1Json: chunks.json ? chunks.json.data : false,
                channel: audioArrayBuffer.numberOfChannels > 1 ? 'L' : '',
                checked: true, id: uuid,
                slices: false,
                note: noteFromFileName(file.name)
            }
        };
        const otMeta = metaFiles.getByFile(parsedFile);
        if (otMeta && parsedFile.meta.op1Json) {
            parsedFile.meta.op1Json.sliceCount = otMeta.sliceCount;
        }
        files[pushToTop ? 'unshift' : 'push'](parsedFile);
        unsorted.push(uuid);
        return uuid;
    } catch (err) {
        return {uuid, failed: true};
    }
};

const parseSds = (fd, file, fullPath = '', pushToTop = false) => {
    const uuid = file.uuid || crypto.randomUUID();
    try {
        // Check header is correct.
        if (!(fd[0] === 240 && fd[1] === 126 && fd[3] === 1 && fd[20] ===
          247)) {
            return {uuid, failed: true};
        }
        const bitRate = fd[6];
        const sampleRate = Math.ceil(10e7 / bytesToInt(fd[9], fd[8], fd[7])) *
          10;
        const length = bytesToInt(fd[12], fd[11], fd[10]);
        let loopStart = bytesToInt(fd[15], fd[14], fd[13]);
        let loopEnd = bytesToInt(fd[18], fd[17], fd[16]) + 1;
        const loopType = fd[19];

        if (loopType === 0x7f) { loopStart = loopEnd = length; }
        if (sampleRate < 4000 || sampleRate > 96000) { return false; }
        if (bitRate !== 16) { return false; }

        let idx = fd.findIndex(
          (x, i) => (x === 0xf0 && fd[i + 1] === 0x7e && fd[i + 3] === 0x02 &&
            fd[i + 126] === 0xf7));

        let lengthRead = 0;
        let data = [];

        while (lengthRead < length) {
            for (let t = (idx + 5); t < (idx + 125) && lengthRead <
            length; t += 3) {
                data[lengthRead++] = (((fd[t] << 9) | (fd[t + 1] << 2) |
                  (fd[t + 2] >> 5)) - 0x8000);
            }
            idx = idx + 127;
        }

        const resample = new Resampler(sampleRate, masterSR, 1,
          data.filter(x => x !== undefined));
        resample.resampler(resample.inputBuffer.length);
        const audioArrayBuffer = audioCtx.createBuffer(
          1,
          resample.outputBuffer.length -
          ((resample.outputBuffer.length / 120) * 5),
          masterSR
        );
        resample.outputBuffer.filter(x => x !== undefined).
          forEach((y, i) => audioArrayBuffer.getChannelData(0)[i] = y / 32767);

        files[pushToTop ? 'unshift' : 'push']({
            file: {
                lastModified: file.lastModified,
                name: getUniqueName(files, file.name),
                filename: file.name,
                path: fullPath.replace(file.name, ''),
                size: file.size,
                type: file.type
            },
            buffer: audioArrayBuffer, meta: {
                length: resample.outputBuffer.length,
                loopStart,
                loopEnd,
                loopType,
                duration: Number(resample.outputBuffer.length / masterSR).
                  toFixed(3),
                startFrame: 0,
                endFrame: resample.outputBuffer.length,
                checked: true,
                id: uuid,
                slices: false,
                note: noteFromFileName(file.name)
            }
        });
        unsorted.push(uuid);
        return uuid;
    } catch (err) {
        return {uuid, failed: true};
    }
};

const parsePti = async (buffer, audioDataBuffer, file, fullPath = '') => {
    const uuid = file.uuid || crypto.randomUUID();
    try {
        const audioArrayBuffer = (masterSR !== 44100
          ? new AudioContext(
            {
                sampleRate: 44100,
                latencyHint: 'interactive'
            })
          : audioCtx).createBuffer(1, audioDataBuffer.length - 4, 44100);

        for (let i = 0; i < audioDataBuffer.length - 4; i++) {
            const v = audioDataBuffer[i] / 32768;
            audioArrayBuffer.getChannelData(0)[i] = v < 0 ? Math.max(-1, v) : Math.min(v, 1);
        }

        let resampleBuffer;
        if (masterSR !== 44100) {
            let resample;
            resample = new Resampler(44100, masterSR, 1,
              audioArrayBuffer.getChannelData(0));
            resample.resampler(resample.inputBuffer.length);

            const resampleBuffer = audioCtx.createBuffer(
              1,
              resample.outputBuffer.length,
              masterSR
            );

            for (let i = 0; i < resample.outputBuffer.length; i++) {
                resampleBuffer.getChannelData(
                  0)[i] = resample.outputBuffer[i];
            }
        }

        let dv = new DataView(buffer);
        const sliceCount = dv.getUint8(376);
        let slices = [];
        for (let i = 280; i < 280 + (sliceCount * 2); i += 2) {
            slices.push(dv.getUint16(i, true));
        }
        slices = slices.map(
          slice => (slice / 65535) * (resampleBuffer || audioArrayBuffer).length
        );
        slices = slices.map((slice, sliceIdx) => ({
            s: slice,
            e: sliceIdx !== sliceCount - 1 ? slices[sliceIdx +
            1] : (resampleBuffer || audioArrayBuffer).length,
            l: -1,
            n: `Slice ${sliceIdx + 1}`
        }));

        const parsedFile= {
            file: {
                lastModified: file.lastModified,
                name: getUniqueName(files, file.name),
                filename: file.name,
                path: fullPath.replace(file.name, ''),
                size: file.size,
                type: file.type
            },
            buffer: (resampleBuffer ||audioArrayBuffer), meta: {
                length: (resampleBuffer ||audioArrayBuffer).length,
                duration: Number((resampleBuffer ||audioArrayBuffer).length / masterSR).toFixed(3),
                startFrame: 0, endFrame: (resampleBuffer ||audioArrayBuffer).length,
                channel: (resampleBuffer ||audioArrayBuffer).numberOfChannels > 1 ? 'L' : '',
                checked: true, id: uuid,
                slices: slices.length > 1 ? slices : false,
                note: noteFromFileName(file.name)
            }
        };

        files.push(parsedFile);
        unsorted.push(uuid);
        return uuid;
    } catch (err) {
        return {uuid, failed: true};
    }
};

const parseWav = (
  audioArrayBuffer, arrayBuffer, file, fullPath = '', pushToTop = false,
  checked = true) => {
    const uuid = file.uuid || crypto.randomUUID();
    let slices = false;
    try {
        let dv = new DataView(arrayBuffer);
        for (let i = 0; i < dv.byteLength - 4; i++) {
            const code = String.fromCharCode(dv.getUint8(i), dv.getUint8(i + 1),
              dv.getUint8(i + 2), dv.getUint8(i + 3));
            if (code === 'data') {
                const size = dv.getUint32(i + 4, true);
                if (size && size < dv.byteLength) {
                    i = i < size ? size - 8 : i;
                    continue;
                }
            }
            if (code === 'DCSD' || code === 'LIST') {
                const size = dv.getUint32(i + 4, true);
                const utf8Decoder = new TextDecoder('utf-8');

                let jsonString = '';
                if (code === 'LIST') {
                    const listType = String.fromCharCode(
                      dv.getUint8(i + 8), dv.getUint8(i + 9),
                      dv.getUint8(i + 10), dv.getUint8(i + 11)
                    );
                    if (listType === 'ISBJ'){
                      jsonString = atob(utf8Decoder.decode(
                        arrayBuffer.slice(i + 12, i + 8 + size)
                      ));
                    }
                }
                /*else*/
                jsonString = jsonString || utf8Decoder.decode(
                  arrayBuffer.slice(i + 8, i + 8 + size)
                );

                try {
                    const json = JSON.parse(jsonString.trimEnd());
                    if (json.sr !== masterSR) {
                        slices = json.dcs.map(slice => ({
                            s: Math.round((slice.s / json.sr) * masterSR),
                            e: Math.round((slice.e / json.sr) * masterSR),
                            l: Math.round(
                              ((slice.l || -1) / json.sr) * masterSR),
                            n: slice.n
                        }));
                    } else {
                        slices = json.dcs;
                    }
                } catch (jsonParseErrored) {}
            }
            if (code === 'cue ') {
                const size = dv.getUint32(i + 4, true);
                const cueCount = dv.getUint32(i + 8, true);
                i += 12;
                const wavSr = dv.getUint32(24, true);
                const cuePoints = [];
                for (let ci = 0; ci < cueCount; ci++) {
                    const cueId = dv.getUint32(i, true);
                    const cuePos = dv.getUint32(i + 20, true);
                    cuePoints.push({cueId, cuePos});
                    i += 24;
                }
                slices = slices || [];
                cuePoints.forEach((cue, cueIdx) => slices.push({
                    s: Math.round((cue.cuePos / wavSr) * masterSR),
                    e: cueIdx !== cuePoints.length - 1 ?
                      Math.round((cuePoints[cueIdx + 1].cuePos / wavSr) * masterSR) :
                      Math.round((audioArrayBuffer.length / wavSr) * masterSR),
                    l: -1,
                    n: `Slice ${cue.cueId + 1}`
                }));
            }
            if (code === 'ORSL') {
                const size = dv.getUint32(i + 4);
                const sliceCount = dv.getUint8(i + 8);
                i += 12;
                const slicePoints = [];
                for (let si = 0; si < sliceCount; si++) {
                    const sliceId = dv.getUint8(i);
                    const sliceStart = dv.getUint32(i + 4, true);
                    const sliceEnd = dv.getUint32(i + 8, true);
                    slicePoints.push({sliceId, sliceStart, sliceEnd});
                    i += 32;
                }
                slices = [];
                slicePoints.forEach(slice => slices.push({
                    s: Math.round((slice.sliceStart / file.sampleRate) * masterSR),
                    e: Math.round((slice.sliceEnd / file.sampleRate) * masterSR),
                    l: -1,
                    n: `Slice ${slice.sliceId + 1}`
                }));
            }
        }
    } catch (e) {
        slices = false;
    }
    try {
        /*duration, length, numberOfChannels, sampleRate*/
        let resampledArrayBuffer;

        if (file.sampleRate && file.sampleRate !== masterSR) {
            let resample, resampleR;
            resample = new Resampler(file.sampleRate, masterSR, 1,
              audioArrayBuffer.getChannelData(0));
            resample.resampler(resample.inputBuffer.length);

            if (file.channels === 2) {
                resampleR = new Resampler(file.sampleRate, masterSR, 1,
                  audioArrayBuffer.getChannelData(1));
                resampleR.resampler(resampleR.inputBuffer.length);
            }

            resampledArrayBuffer = audioCtx.createBuffer(
              file.channels,
              resample.outputBuffer.length,
              masterSR
            );

            resampledArrayBuffer.copyToChannel(resample.outputBuffer, 0);
            if (file.channels === 2) {
                resampledArrayBuffer.copyToChannel(resampleR.outputBuffer, 1);
            }
        }

        if (Array.isArray(slices)) {
            /*Set the end point to the length of the buffer is the end is -1*/
            slices.forEach(s => s.e = s.e === -1 ? (resampledArrayBuffer ||
              audioArrayBuffer).length : s.e);
            /*De-dupe the slices list, in the event of both DCSD and cue chunks being found in the wav file data.*/
            const ddSlices = [];
            slices.forEach(
              slice => ddSlices.findIndex(s => s.s === slice.s) > -1
                ? false
                : ddSlices.push(slice));
            slices = ddSlices;
        }
        /*Prefer .ot file slices when available.*/
        const metaFile = metaFiles.getByFileName(file.name);
        let otLoop = 0;
        let otLoopStart = 0;
        if (metaFile && metaFile.slices && metaFile.slices.length > 0) {
            slices = file.name.endsWith('.flac') ?
              metaFile.slices.map((slice, idx) => ({
                  s: (slice.startPoint / metaFile.loopEnd) * (resampledArrayBuffer || audioArrayBuffer).length,
                  e: (slice.endPoint / metaFile.loopEnd) * (resampledArrayBuffer || audioArrayBuffer).length,
                  l: slice.loopPoint
              }))
              : metaFile.slices.map((slice, idx) => ({
                    s: slice.startPoint,
                    e: slice.endPoint,
                    l: slice.loopPoint,
                    n: slice.name || `OT slice ${idx + 1}`
                }));
            otLoop = metaFile.otLoop;
            otLoopStart = metaFile.otLoopStart;
            metaFiles.removeByName(file.name);
        }
        if (Array.isArray(slices)) {
            slices = slices.filter(s => s.s < s.e);
        }

        files[pushToTop ? 'unshift' : 'push']({
            file: {
                lastModified: file.lastModified,
                name: getUniqueName(files, file.name),
                filename: file.name,
                path: fullPath.replace(file.name, ''),
                size: file.size,
                type: file.type
            },
            buffer: (resampledArrayBuffer || audioArrayBuffer),
            meta: {
                sourceBitDepth: file.bitDepth,
                sourceSampleRate: file.sampleRate,
                length: (resampledArrayBuffer || audioArrayBuffer).length,
                duration: Number(
                  (resampledArrayBuffer || audioArrayBuffer).length / masterSR).
                  toFixed(3),
                startFrame: 0,
                endFrame: (resampledArrayBuffer || audioArrayBuffer).length,
                checked: checked,
                id: uuid,
                channel: (resampledArrayBuffer ||
                  audioArrayBuffer).numberOfChannels > 1 ? 'L' : '',
                dualMono: false,
                slices: slices.length > 0 ? slices : false,
                otLoop,
                otLoopStart,
                opPan: 16384,
                opPanAb: false,
                opPitch: 0,
                note: noteFromFileName(file.name)
            }
        });
        unsorted.push(uuid);
        return uuid;
    } catch (err) {
        console.log(err);
        return {uuid, failed: true};
    }
};

const renderListWhenReady = (count, fileCount) => {
    count = count.filter(c => c !== false);
    importOrder = [...new Set(importOrder)];
    if (count.every(c => unsorted.includes(c))) {
        sort({skipRender: true}, 'id');
        processedCount = 0;
        renderList();
    } else {
        setFileNumTicker();
        setTimeout(() => renderListWhenReady(count), 1000);
    }
};

const setLoadingProgress = (count, total) => {
    const el = document.getElementById('loadingText');
    let progress = (count / total) * 100;
    el.style.backgroundImage = `linear-gradient(90deg, #cf8600 ${progress}%, #606c76 ${progress +
    1}%, #606c76 100%)`;
};

const getRandomFileSelectionFrom = (fileCollection) => {
    let selection = [...fileCollection].sort(
      f => crypto.randomUUID().localeCompare(crypto.randomUUID())
    );
    return selection.filter(
      (file, idx) => idx < (sliceGrid > 0 ? sliceGrid : 256) ||
        file.fromArchive);
    //return selection.slice(0, (sliceGrid > 0 ? sliceGrid : 256));
};

const addBlankFile = () => {
    const uuid = crypto.randomUUID();
    checkAndSetAudioContext();
    const audioArrayBuffer = audioCtx.createBuffer(
      masterChannels,
      8,
      masterSR
    );

    for (let channel = 0; channel < masterChannels; channel++) {
        for (let i = 0; i < audioArrayBuffer.length; i++) {
            audioArrayBuffer.getChannelData(channel)[i] = 0;
        }
    }

    const insertAt = lastSelectedRow ? getFileIndexById(
      lastSelectedRow.dataset.id) + 1 : files.length;

    files.splice(insertAt, 0, {
        file: {
            lastModified: Date.now(),
            name: getUniqueName(files, 'blank.wav'),
            filename: 'blank.wav',
            path: '',
            size: 0
        },
        buffer: audioArrayBuffer, meta: {
            length: audioArrayBuffer.length,
            duration: Number(audioArrayBuffer.length / masterSR).toFixed(3),
            startFrame: 0, endFrame: audioArrayBuffer.length,
            checked: true, id: uuid,
            channel: audioArrayBuffer.numberOfChannels > 1 ? 'L' : '',
            dualMono: false,
            slices: false,
            note: ''
        }
    });
    unsorted.push(uuid);
    renderList();
};

const restoreSessionFile = async sessionFile => {
    const zip = new JSZip();
    setLoadingText('Restoring Session');

    await zip.loadAsync(sessionFile);

    let sessionSettings = await zip.file('settings')?.async('uint8array');
    sessionSettings = window.msgpack.decode(sessionSettings);
    masterSR = sessionSettings.workingSR;
    await changeAudioConfig(sessionSettings.lastUsedAudioConfig, true);
    setSliceOptionsFromArray(sessionSettings.sliceOptions);

    let sessionUnsorted = await zip.file('unsorted')?.async('uint8array');
    sessionUnsorted = window.msgpack.decode(sessionUnsorted);
    unsorted = sessionUnsorted;

    let sessionImportOrder = await zip.file('importOrder')?.async('uint8array');
    sessionImportOrder = window.msgpack.decode(sessionImportOrder);
    importOrder = sessionImportOrder;

    let opExportData = await zip.file('opExportData')?.async('uint8array');
    if (opExportData) {
        opExportData = window.msgpack.decode(opExportData);
        if (opExportData.samples && opExportData.opDataConfig) {
            getSetOpExportData(opExportData.samples, opExportData.opDataConfig);
        }
    }

    let sessionFiles = await zip.file('files')?.async('uint8array');
    sessionFiles = window.msgpack.decode(sessionFiles);
    files = sessionFiles.map(f => bufferRateResampler(f));
    renderList(true);
    storeState();
    setLoadingText('');
};

const consumeFileInput = async (event, inputFiles) => {
    setLoadingText('Loading samples');
    const isAudioCtxClosed = checkAudioContextState();
    if (isAudioCtxClosed) { return; }
    checkAndSetAudioContext();

    inputFiles = [...inputFiles];

    /*Restore the first session file found in the files passed - any other dropped data will be skipped.*/
    const sessionFile = inputFiles.find(f => f?.name?.split('.')?.reverse()[0].toLowerCase() === 'dcsd');
    if (sessionFile) {
        const dialogResponse = await dcDialog(
          'confirm',
          `Would you like to restore the session:<br>
          '${sessionFile.name}'?
          <br><br>
          (Items currently in the list will be removed).`,
          { okLabel: 'Restore', cancelLabel: 'Cancel' }
        );
        if (dialogResponse) {
            return restoreSessionFile(sessionFile);
        }
    }

    let _zips = [...inputFiles].filter(
      f => ['zip', 'dtprj', 'xrns', 'xrni'].includes(
        f?.name?.split('.')?.reverse()[0].toLowerCase())
    );

    if (_zips.length > 0) {
        _zips.forEach((archive, zidx) => {
            const zip = new JSZip();
            let prog = 1;
            inputFiles[inputFiles.findIndex(f => f === archive)] = false;
            zip.loadAsync(archive).then(() => {
                const fileCount = Object.keys(zip.files).length;
                const supportedFileCount = settings.importFileLimit &&
                  Object.keys(zip.files).filter(
                    zf => supportedAudioTypes.includes(
                      zf.split('.').at(-1).toLowerCase())
                  ).length;
                if (supportedFileCount + files.length > importFileLimitValue) {
                    loadingEl.textContent = `skipping zip '${archive.name}', files (${supportedFileCount}) will exceed ${importFileLimitValue} file import limit...`;
                    if (zidx === _zips.length - 1) {
                        setTimeout(() => consumeFileInput(event, inputFiles),
                          3000);
                    }
                    return; /*Don't process zip contents if the files count exceed the importLimit if limit is on*/
                }
                for (let key in zip.files) {
                    zip.files[key].async('blob').then(blobData => {
                        blobData.name = key.split('/').at(-1);
                        blobData.fullPath = `${archive.name}/${key}`;
                        blobData.fromArchive = archive.name;
                        inputFiles.push(blobData);
                        blobData.uuid = crypto.randomUUID();
                        if (supportedAudioTypes.some(ext => blobData.name.toLowerCase().endsWith(ext))) {
                            importOrder.push(blobData.uuid);
                        }
                        if (zidx === _zips.length - 1 && prog === fileCount) {
                            consumeFileInput(event, inputFiles);
                        }
                        prog++;
                    });
                }
            });
        });
        return;
    }

    let _files = [...inputFiles].filter(
      f => supportedAudioTypes.includes(
        f?.name?.split('.')?.reverse()[0].toLowerCase())
    );
    let _mFiles = [...inputFiles].filter(
      f => ['ot', 'xml'].includes(f?.name?.split('.')?.reverse()[0].toLowerCase())
    );

    if (event.shiftKey || modifierKeys.shiftKey) {
        _files = getRandomFileSelectionFrom(_files);
    }

    if (settings.importFileLimit && _files.length > importFileLimitValue) {
        _files = _files.filter(
          (file, idx) => idx < importFileLimitValue || file.fromArchive);
    }

    _mFiles.forEach((file, idx) => {
        const reader = new FileReader();
        reader.onload = function(e) {
            file.uuid = crypto.randomUUID();
            file.fullPath = file.fullPath || '';
            if (file.name.toLowerCase().endsWith('.ot')) {
                // binary data
                const buffer = e.target.result;
                const bufferByteLength = buffer.byteLength;
                const bufferUint8Array = new Uint8Array(buffer, 0,
                  bufferByteLength);
                let result = parseOt(bufferUint8Array, file, file.fullPath);
            }
            if (file.name.toLowerCase().endsWith('.xml')) {
                const xmlString = e.target.result;
                parseXml(xmlString, file.fullPath);
            }
        };
        if (file.name.toLowerCase().endsWith('.ot')) {
            reader.readAsArrayBuffer(file);
        } else {
            reader.readAsText(file);
        }
    });
    if (_files.length === 0) {
        return renderList();
    }

    let count = [];

    const checkCount = (idx, filesLength) => {
        if (count.every(c => unsorted.includes(c)) && processedCount >= _files.length - 1) {
            setTimeout(() => renderListWhenReady(count), 1000);
        }
    };
    let error = {
        encountered: false,
        text: '',
        count: 0
    };

    _files.forEach((file, idx) => {
        const reader = new FileReader();
        reader.onload = async function(e) {
            try {
                file.uuid = file.uuid || crypto.randomUUID();
                if (supportedAudioTypes.some(ext => file.name.toLowerCase().endsWith(ext))) {
                    importOrder.push(file.uuid);
                }
                file.fullPath = file.fullPath || '';
                const buffer = e.target.result;

                if (file.name.toLowerCase().endsWith('.syx') ||
                  file.name.toLowerCase().endsWith('.aif') ||
                  file.name.toLowerCase().endsWith('.pti')
                ) {
                    // binary data
                    const bufferByteLength = buffer.byteLength;
                    const bufferUint8Array = new Uint8Array(buffer, 0,
                      bufferByteLength);
                    count.push(file.uuid);
                    let result;
                    if(file.name.toLowerCase().endsWith('.aif')){
                        result = await parseAif(buffer, bufferUint8Array, file,
                          file.fullPath)
                    }
                    if (file.name.toLowerCase().endsWith('.syx')) {
                        result = parseSds(bufferUint8Array, file, file.fullPath);
                    }
                    if (file.name.toLowerCase().endsWith('.pti')) {
                        result = await parsePti(buffer, new Int16Array(buffer, 392), file,
                          file.fullPath)
                    }
                    if (result.failed) {
                        count.splice(count.findIndex(c => c === result.uuid),
                          1);
                    }
                    setLoadingProgress(idx + 1, _files.length);
                    checkCount(idx, _files.length);
                }

                if ((
                    file.name.toLowerCase().endsWith('.wav') ||
                    file.type === 'audio/wav') ||
                  file.name.toLowerCase().endsWith('.flac') ||
                  file.name.toLowerCase().endsWith('.webm') ||
                  file.name.toLowerCase().endsWith('.m4a') ||
                  file.name.toLowerCase().endsWith('.mp3')
                ) {
                    count.push(file.uuid);
                    const fb = buffer.slice(0);

                    if (file.name.toLowerCase().endsWith('.wav') ||
                      file.type === 'audio/wav') {
                        let dv = new DataView(buffer);
                        for (let i = 0; i < dv.byteLength - 4; i++) {
                            const code = String.fromCharCode(dv.getUint8(i),
                              dv.getUint8(i + 1),
                              dv.getUint8(i + 2), dv.getUint8(i + 3));
                            if (i > dv.byteLength || code === 'PAD ') {
                                break;
                            }
                            if (code === 'fmt ') {
                                file.channels = dv.getUint16(i + 10, true);
                                file.sampleRate = dv.getUint32(i + 12, true);
                                file.bitDepth = dv.getUint16(i + 22, true);
                                if (file.channels < 1 || file.sampleRate === 0 || file.bitDepth > 32) {
                                    delete file.channels;
                                    delete file.sampleRate;
                                    delete file.bitDepth;
                                } else {
                                    break;
                                }
                            }
                        }
                    }

                    await (masterSR !== file.sampleRate
                      ? new AudioContext(
                        {
                            sampleRate: file.sampleRate,
                            latencyHint: 'interactive'
                        })
                      : audioCtx).decodeAudioData(buffer, data => {
                        let result = parseWav(data, fb, file, file.fullPath);
                        if (result.failed) {
                            count.splice(
                              count.findIndex(c => c === result.uuid), 1);
                        }
                        setLoadingProgress(idx + 1, _files.length);
                        checkCount(idx, _files.length);
                    }, (error) => {
                        count.splice(count.findIndex(c => c === file.uuid), 1);
                        setLoadingProgress(idx + 1, _files.length);
                        checkCount(idx, _files.length);
                    });
                }
            } catch (err) {
                error.encountered = true;
                error.count++;
                if (file.fromArchive) {
                    error.text = `There was an error extracting files from the zip archive, not all zip files are readable.\n
            Please use store or deflate compression methods, and generate files with either 7zip as zip, or Windows Explorer.`;
                }
                if (error.encountered && error.text && idx === _files.length -
                  1) {
                    showToastMessage(error.text + ` (failed: ${error.count})`, 15000);
                }
            }
            processedCount++;
            setFileNumTicker();
        };
        reader.readAsArrayBuffer(file);
    });

    if (digichain.importInt) { clearInterval(digichain.importInt); }
    digichain.importInt = setInterval(() => {
        if (!document.body.classList.contains('loading')) {
            _files.forEach((v, i) => delete _files[i]);
            _files = [];
            _mFiles = [];
            count = [];
            clearInterval(digichain.importInt);
        }
    }, 10000);
};

const dropHandler = (event) => {
    event.preventDefault();
    checkAndSetAudioContext();
    if (!lastSelectedRow?.classList?.contains('is-dragging')) {
        if (event?.dataTransfer?.items?.length &&
          event?.dataTransfer?.items[0].kind === 'string') {
            try {
                event?.dataTransfer?.items[0].getAsString(async link => {
                    let linkedFile = await fetch(link);
                    if (!linkedFile.url.includes('.wav')) { return; } // probably not a wav file
                    let buffer = await linkedFile.arrayBuffer();
                    const fb = buffer.slice(0);
                    await audioCtx.decodeAudioData(buffer,
                      data => parseWav(data, fb, {
                          lastModified: new Date().getTime(),
                          name: linkedFile.url.split('/').reverse()[0],
                          size: ((masterBitDepth * masterSR *
                              (buffer.length / masterSR)) / 8) *
                            buffer.numberOfChannels / 1024,
                          type: 'audio/wav'
                      }, '', true));
                    renderList();
                });
                return;
            } catch (e) {}
        }
        if (event?.dataTransfer?.items?.length) {
            let toConsume = [];
            let total = event.dataTransfer.items.length;
            toConsume.count = 0;
            const addItem = item => {
                if (item.isFile) {
                    item.file(
                      (file) => {
                          file.fullPath = item.fullPath.replace('/', '');
                          file.uuid = crypto.randomUUID();
                          if (supportedAudioTypes.some(ext => file.name.toLowerCase().endsWith(ext))) {
                              importOrder.push(file.uuid);
                          }
                          toConsume.push(file);
                      }
                    );
                    toConsume.count++;
                    total--;
                } else if (item.isDirectory) {
                    const dirReader = item.createReader();
                    const entryReaderFn = () => dirReader.readEntries(entries => {
                        total += entries.length;
                        for (const entry of entries) {
                            addItem(entry);
                        }
                        total--;
                        if (entries.length > 0) {
                            entryReaderFn();
                        }
                    });
                    entryReaderFn();
                }
            };
            for (const entry of event.dataTransfer.items) {
                const itemAsEntry = entry.getAtEntry
                  ? entry.getAtEntry()
                  : entry.webkitGetAsEntry();
                if (itemAsEntry) {
                    addItem(itemAsEntry);
                }
            }
            let doneInterval = setInterval(() => {
                if (total <= 0 && toConsume.count === toConsume.length) {
                    clearInterval(doneInterval);
                    consumeFileInput(event, toConsume);
                }
            }, 500);
        }
    } else {
        let target = lastDragOverRow || event.target;
        event.target?.classList?.remove('is-dragging');
        lastDragOverRow?.classList?.remove('drag-offset');
        if (document.getElementById('opExportPanel').
          classList.
          contains('show')) {
            // Block row re-ordering while op export side panel is open.
            return;
        }
        while (target && !target.classList.contains('file-row')) {
            target = target.parentElement || document.body;
            target = target.nodeName === 'THEAD' ? document.querySelector(
              'tr.file-row') : target;
            target = target === document.body ? document.querySelector(
              'tr.file-row:last-of-type') : target;
        }
        if (target) {
            const selectedRowUuid = lastSelectedRow.dataset.id;
            let selectedRowId = getFileIndexById(selectedRowUuid);
            let targetRowId = getFileIndexById(target.dataset.id);
            let item = files.splice(selectedRowId, 1)[0];
            files.splice((targetRowId <= selectedRowId ? targetRowId : (targetRowId-1)), 0, item);
            renderList();
            lastSelectedRow = getRowElementById(selectedRowUuid);
            lastSelectedRow.classList.add('selected');
            lastSelectedRow.scrollIntoViewIfNeeded(true);
        }
    }
};

function init() {

    /*Basic browser version detection - we won't prevent trying to use, just an alert.*/
    (() => {
        try {
            const chromeVersion = navigator.userAgent.match(
              /\d+\.\d+\.\d+\.\d+/);
            if (chromeVersion && chromeVersion[0] &&
              +chromeVersion[0].split('.')[0] < 114) {
                return showToastMessage(
                  'Chromium browser versions below 114.x.x are not supported.', 30000);
            }
            const safariVersion = navigator.userAgent.match(
              /Version\/\d+\.\d+\.\d+/);
            if (safariVersion && safariVersion[0] &&
              +safariVersion[0].match(/\d+\.\d+/) < 16.3) {
                return showToastMessage(
                  'Safari browser versions below 16.3 are not supported.', 30000);
            }
            const firefoxVersion = navigator.userAgent.match(
              /Firefox\/\d+\.\d+/);
            if (firefoxVersion && firefoxVersion[0] &&
              +firefoxVersion[0].match(/\d+\.\d+/) < 115) {
                return showToastMessage(
                  'Firefox browser versions below 115.x are not supported.', 30000);
            }
        } catch (e) {}
    })();

    uploadInput.addEventListener(
      'change',
      () => consumeFileInput({shiftKey: modifierKeys.shiftKey},
        uploadInput.files),
      false
    );
    uploadInput.addEventListener(
      'click',
      (event) => {
          if (event.ctrlKey || event.metaKey || modifierKeys.ctrlKey) {
              event.preventDefault();
              event.stopPropagation();
              addBlankFile();
          }
      },
      false
    );

    document.body.addEventListener(
      'dragover',
      (event) => {
          event.preventDefault();
          if (
            lastSelectedRow &&
            lastSelectedRow.classList.contains('is-dragging') &&
            !document.getElementById('opExportPanel').
            classList.contains('show')
          ) {
              const dragOverRow = document.elementsFromPoint(event.clientX, event.clientY).filter(
                el => el.tagName === 'TD'
              ).map(
                td => td.parentElement
              ).find(
                r => r !== lastSelectedRow && r.classList.contains('file-row')
              );
              if (dragOverRow && dragOverRow !== lastDragOverRow) {
                  dragOverRow.classList.add('drag-offset');
                  lastDragOverRow?.classList?.remove('drag-offset');
                  lastDragOverRow = dragOverRow;
              }
          }
      },
      false
    );

    document.body.addEventListener(
      'drop',
      dropHandler,
      false
    );

    if (window.__TAURI__) {
        window.__TAURI__.event.listen('tauri://drag-drop', dropHandler);
    }

    document.body.addEventListener('keyup', (event) => {
        clearModifiers();
    });

    /* clear the indexedDb store completely on unload if there are no files,
    this is more a Safari/WebKit issue where removed data hangs around even
    after removal from the object store, this ensures it's fully removed on exit.

    Close the active audio context.
    */
    addEventListener(
      navigator.vendor.startsWith('Apple') ? 'unload' : 'beforeunload',
      (event) => {
          if (!files.length) {
              clearIndexedDb();
          }
          audioCtx?.close();
      }
    );

    /* disable the right-click context menu unless the shift-key is pressed.*/
    window.addEventListener('contextmenu', (event) => {
        if (!event.shiftKey) {
            event.preventDefault();
        }
    });

    document.body.addEventListener('keydown', (event) => {
        const numberKeys = [
            'Digit1',
            'Digit2',
            'Digit3',
            'Digit4',
            'Digit5',
            'Digit6',
            'Digit7',
            'Digit8',
            'Digit9',
            'Digit0'];
        const eventCodes = [
            'ArrowDown',
            'ArrowUp',
            'Escape',
            'Enter',
            'KeyD',
            'KeyE',
            'KeyG',
            'KeyH',
            'KeyI',
            'KeyL',
            'KeyP',
            'KeyR',
            'KeyS',
            'KeyX',
            ...numberKeys
        ];
        if (keyboardShortcutsDisabled) { return; }

        if (event.shiftKey) { document.body.classList.add('shiftKey-down'); }
        if (event.ctrlKey || event.metaKey) {
            document.body.classList.add('ctrlKey-down');
        }
        if (event.code === 'Escape') {
            if (files.length && !(event.shiftKey || modifierKeys.shiftKey)) {
                files.filter(f => f.meta.playing && f.meta.id).
                  forEach(f => stopPlayFile(false, f.meta.id));
            }
            if (document.querySelector('#dcDialog').open) {
                event.preventDefault();
                return;
            }
            event.preventDefault();
            return closePopUps();
        }

        if (
          document.activeElement.nodeName === 'INPUT' &&
          document.activeElement.disabled === false
        ) {
            return;
        }

        if (event.shiftKey && (event.code === 'KeyK' || event.code === 'Slash')) {
            const shortcutsPanel = document.getElementById('keyboardShortcuts');
            shortcutsPanel.open ? shortcutsPanel.close() : shortcutsPanel.showModal();
            event.preventDefault();
            return;
        }

        if (arePopUpsOpen()) {
            // Don't listen for keyboard commands when popups are open.
            // If editor panel is open, use these shortcuts.
            if (document.getElementById('editPanel').open) {
                if (event.code === 'KeyP') {
                    event.altKey
                      ? digichain.editor.editorPlayFile(event, false, true)
                      : digichain.editor.editorPlayFile(event);
                } else if (masterChannels === 1 &&
                  (event.code === 'KeyL' || event.code === 'KeyR' ||
                    event.code ===
                    'KeyS' || event.code === 'KeyD')) {
                    digichain.editor.changeChannel(event,
                      event.code.replace('Key', ''));
                } else if (event.code === 'KeyN') {
                    digichain.editor.sliceCreate(event);
                } else if (event.code === 'KeyU') {
                    digichain.editor.sliceUpdate(event);
                } else if (event.code === 'KeyX') {
                    digichain.editor.sliceRemove(event);
                }
            }
            event.preventDefault();
            return;
        }

        if (numberKeys.includes(event.code)) {
            let id = +event.code.charAt(event.code.length - 1);
            const selected = files.filter(f => f.meta.checked);
            id = id === 0 ? 9 : (id - 1);
            if (event.code !== 'Digit0' && (!event.metaKey || !event.altKey)) { event.preventDefault();}
            if (selected[id]) {
                event.altKey ?
                  stopPlayFile(false, selected[id].meta.id) :
                  playFile(false, selected[id].meta.id,
                    (event.shiftKey || modifierKeys.shiftKey));
            }
            if (event.shiftKey && (event.metaKey || event.ctrlKey)) {
                document.body.classList.remove('shiftKey-down');
                document.body.classList.remove('ctrlKey-down');
            }
        }

        if (event.code === 'ArrowDown' &&
          (!lastSelectedRow || !lastSelectedRow.isConnected)) {
            lastSelectedRow = document.querySelector('#fileList tr');
            event.preventDefault();
            return;
        }
        if (files.length && (event.code === 'KeyI')) {
            event.preventDefault();
            return invertFileSelection();
        }
        if (files.length && (event.code === 'KeyE')) {
            const editPanelEl = document.getElementById('editPanel');
            if ((event.shiftKey || modifierKeys.shiftKey)) {
                setTimeout(() => {
                    if (editPanelEl.open) {
                        const editFileNameEl = document.getElementById(
                          'editFileName');
                        const editFilePathEl = document.getElementById(
                          'editFilePath');
                        editFileNameEl.removeAttribute('readonly');
                        editFilePathEl.removeAttribute('readonly');
                        editFileNameEl.focus();
                    }
                }, 100);
            }
            event.preventDefault();
            return lastSelectedRow
              ? showEditPanel(lastSelectedRow.dataset.id)
              : false;
        }
        if (event.code === 'KeyH' &&
          (event.shiftKey || modifierKeys.shiftKey)) {
            event.preventDefault();
            toggleOptionsPanel();
        }
        if (event.code === 'KeyL' &&
          (event.shiftKey || modifierKeys.shiftKey)) {
            event.preventDefault();
            toggleListVisibility();
        }
        if (event.code === 'KeyG' &&
          (event.shiftKey || modifierKeys.shiftKey)) {
            event.preventDefault();
            document.body.classList.contains('grid-view')
              ? document.body.classList.remove('grid-view')
              : document.body.classList.add('grid-view');
        }
        if (eventCodes.includes(event.code) && lastSelectedRow &&
          lastSelectedRow?.isConnected) {
            if (event.code === 'ArrowDown' &&
              lastSelectedRow.nextElementSibling) {
                if (!(event.shiftKey || modifierKeys.shiftKey)) {
                    event.preventDefault();
                    return handleRowClick(event,
                      lastSelectedRow.nextElementSibling.dataset.id);
                }
                event.preventDefault();
                let idx = getFileIndexById(lastSelectedRow.dataset.id);
                let item = files.splice(idx, 1)[0];
                files.splice(idx + 1, 0, item);
                lastSelectedRow.nextElementSibling.after(lastSelectedRow);
                lastSelectedRow.scrollIntoViewIfNeeded(true);
                setCountValues();
            } else if (event.code === 'ArrowUp' &&
              lastSelectedRow.previousElementSibling) {
                if (!(event.shiftKey || modifierKeys.shiftKey)) {
                    return handleRowClick(event,
                      lastSelectedRow.previousElementSibling.dataset.id);
                }
                event.preventDefault();
                let idx = getFileIndexById(lastSelectedRow.dataset.id);
                let item = files.splice(idx, 1)[0];
                files.splice(idx - 1, 0, item);
                lastSelectedRow.previousElementSibling.before(lastSelectedRow);
                lastSelectedRow.scrollIntoViewIfNeeded(true);
                setCountValues();
            } else if (event.code === 'Enter') {
                event.preventDefault();
                toggleCheck(event, lastSelectedRow.dataset.id);
            } else if (event.code === 'KeyP') {
                event.preventDefault();
                event.altKey
                  ? stopPlayFile(false, lastSelectedRow.dataset.id)
                  : playFile(event, lastSelectedRow.dataset.id);
            } else if (masterChannels === 1 &&
              (event.code === 'KeyL' || event.code === 'KeyR' || event.code ===
                'KeyS' || event.code === 'KeyD')) {
                event.preventDefault();
                const item = getFileById(lastSelectedRow.dataset.id);
                if (item.meta.channel) {
                    event.preventDefault();
                    changeChannel(event, lastSelectedRow.dataset.id,
                      event.code.replace('Key', ''));
                }
            }
        }
    });

    /*Actions based on restored local storage states*/
    pitchExports(settings.pitchModifier, true);
    document.querySelector('.touch-buttons').classList[
      settings.showTouchModifierKeys ? 'remove' : 'add'
      ]('hidden');
    if (settings.darkModeTheme === null) {
        settings.darkModeTheme = window.matchMedia(
          '(prefers-color-scheme: dark)').matches;
    }
    document.querySelector(`.logo h3`).dataset.version = document.querySelector(
      'meta[name=version]').content;
    document.body.classList[
      settings.darkModeTheme ? 'remove' : 'add'
      ]('light');
    document.body.classList[
      settings.normalizeContrast ? 'add' : 'remove'
      ]('normalize-contrast');
    if (settings.restoreLastUsedAudioConfig) {
        changeAudioConfig(settings.lastUsedAudioConfig, true);
    } else {
        document.getElementById('audioConfigOptions').value = settings.defaultAudioConfigText;
        setEditorConf({
            audioCtx,
            masterSR,
            masterChannels,
            masterBitDepth
        });
    }
    updateSpacedChainMode();
    updateUiButtonAction('updateResampleChainsToList', '.toggle-top-list');
    updateUiButtonAction('exportChainsAsXyPresets', '.toggle-op-xy-preset-bundling');
    setTimeout(() => toggleOptionsPanel(), 250);
    configDb();
    document.getElementById('modifierKeyctrlKey').textContent= navigator.userAgent.indexOf('Mac') !== -1 ? 'CMD' : 'CTRL';
}

async function clearIndexedDb() {
    await db.close();
    await indexedDB.deleteDatabase('digichain');
    if (settings.retainSessionState) {
        configDb(true);
    }
}

function configDb(skipLoad = false, callback) {
    if (!settings.retainSessionState) {
        return clearIndexedDb();
    }
    dbReq = indexedDB.open('digichain', 1);
    dbReq.onsuccess = () => {
        db = dbReq.result;
        checkAndSetAudioContext();
        if (!skipLoad) {
            setLoadingText('Restoring Session');
            loadState();
        }
        if (callback) {
            callback();
        }
    };

    dbReq.onupgradeneeded = event => {
        db = event.target.result;
        db.createObjectStore('state');
    };
}
async function storeState(onlyOpExport = false) {
    if (!settings.retainSessionState) {
        return new Promise(resolve => resolve(true));
    }
    if (!db || !dbReq || dbReq.readyState !== 'done') {
        configDb(true, () => storeState());
        return new Promise(resolve => resolve(true));
    }
    const transaction = db.transaction(['state'], 'readwrite', {durability: 'relaxed'});
    const objectStore = transaction.objectStore('state');

    objectStore.put(window.msgpack.encode(getSetOpExportData(false,false,true)), 'opExportData');
    if (onlyOpExport) {
        return;
    }

    importOrder = importOrder.filter(id => unsorted.includes(id));
    objectStore.put(unsorted, 'unsorted');
    objectStore.put(importOrder, 'importOrder');
    return new Promise(resolve => {
        objectStore.put(files.map(f => {
            if (f === files.at(-1)) {
                setTimeout(() => resolve(true), 2000);
            }
            return flattenFile(f);
        }), 'files');
    });
}

function loadState(skipConfirm = false) {
    if (!settings.retainSessionState) {
        return showWelcome();
    }
    const transaction = db.transaction(['state'], 'readonly');
    const objectStore = transaction.objectStore('state');
    let requestUnsorted = objectStore.get('unsorted');
    let requestImportOrder = objectStore.get('importOrder');

    requestUnsorted.onsuccess = () => {
        if (requestUnsorted.result) {
            unsorted = requestUnsorted.result;
        }
        showWelcome();
    }
    requestImportOrder.onsuccess = () => {
        if (requestImportOrder.result) {
            importOrder = requestImportOrder.result;
        }
    }
    let requestOpExportData = objectStore.get('opExportData');
    requestOpExportData.onsuccess = () => {
        if (requestOpExportData.result) {
            const opExportData = window.msgpack.decode(requestOpExportData.result);
            getSetOpExportData(opExportData.samples, opExportData.opDataConfig);
        }
    }
    let requestFiles = objectStore.get('files');
    requestFiles.onsuccess = async () => {
        if (requestFiles.result && requestFiles.result.length > 0) {

            if (!skipConfirm) {
                const proceed = await dcDialog(
                  'confirm',
                  `There are ${requestFiles.result.length} files from your last session, would you like to restore them?`,
                  {
                      kind: 'info',
                      okLabel: 'Restore',
                      cancelLabel: 'Discard',
                  }
                );
                if (!proceed) {
                    clearDbBuffers();
                    setLoadingText('');
                    return ;
                }
            }

            files = requestFiles.result.map(f => bufferRateResampler(f));

            renderList(true);

        } else {
            setLoadingText('');
        }
    }
}
function clearDbBuffers() {
    db.transaction(['state'], 'readwrite', {durability: 'relaxed'}).objectStore('state').clear();
    clearIndexedDb();
}

function saveSessionUiCall() {
    const settingsPanelEl = document.getElementById('exportSettingsPanel');
    const sessionFileName = document.querySelector('#sessionFileName').value;
    const sessionIncludeUnselected = document.querySelector('#sessionIncludeUnselected').dataset.sessionUnselected === 'yes';

    if (!sessionFileName) {
        return showToastMessage('Please specify a session file name.');
    }
    if ((sessionIncludeUnselected && files.length === 0) || (!sessionIncludeUnselected && files.filter(f => f.meta.checked).length === 0)) {
        return showToastMessage('Session must include at least one file.');
    }
    setLoadingText('Exporting Session');
    saveSession(sessionFileName, sessionIncludeUnselected);
    if (settingsPanelEl.open) {
        settingsPanelEl.close();
    }
}

function saveSession(sessionFileName = 'digichain_session', includeUnselected = false) {
    const zip = new JSZip();
    const zipFileOptions = {
        compression: "DEFLATE",
        compressionOptions: {
            level: 9
        }
    };
    const data = (includeUnselected ? files : files.filter(f => f.meta.checked)).map(f => flattenFile(f));
    const sessionSettings = {
        lastUsedAudioConfig: settings.lastUsedAudioConfig,
        workingSR: masterSR,
        sliceOptions
    };

    zip.file('files', window.msgpack.encode(data), zipFileOptions);
    zip.file('unsorted', window.msgpack.encode(unsorted), zipFileOptions);
    zip.file('importOrder', window.msgpack.encode(importOrder), zipFileOptions);
    zip.file('settings', window.msgpack.encode(sessionSettings), zipFileOptions);

    const opExportData = getSetOpExportData(false,false,true);
    if (opExportData.samples.length > 0) {
        zip.file('opExportData', window.msgpack.encode(opExportData), zipFileOptions);
    }

    zip.generateAsync({
        type: "blob",
        compression: "DEFLATE"
    }).then(blob => {
        const el = document.getElementById('getJoined');
        el.href = URL.createObjectURL(blob);
        el.setAttribute('download', `${sessionFileName}.dcsd`);
        el.click();
        setLoadingText('');
        showToastMessage(`'${sessionFileName}.dcsd'<br>session file created.`, 10000);
    });
}

if ('launchQueue' in window) {
    window.launchQueue.setConsumer((launchParams) => {
        if (launchParams.files && launchParams.files.length) {
            consumeFileInput({}, launchParams.files);
        }
    });
}

try {
    init();
} catch (err) {
    let alertText = 'An unexpected error was encountered, please refresh the page. ';
    if (navigator.brave) {
        alertText += 'If you are using Brave browser, please disable Brave Shields for digichain.brianbar.net.';
    }
    showToastMessage(alertText, 30000);
    console.log(err);
}

/*Expose properties/methods used in html events to the global scope.*/
window.digichain = {
    sliceOptions: () => sliceOptions,
    lastSelectedFile: () => getFileById(lastSelectedRow?.dataset?.id),
    saveSession,
    saveSessionUiCall,
    changeAudioConfig,
    removeSelected,
    toggleSelectedActionsList,
    trimRightSelected,
    roughStretchSelected,
    truncateSelected,
    normalizeSelected,
    reverseSelected,
    shiftSelected,
    invertSelected,
    flipChannelsSelected,
    pitchUpSelected,
    doubleSelected,
    pingPongSelected,
    fuzzSelected,
    crushSelected,
    fadeSelected,
    stretchSelected,
    shortenNameSelected,
    sanitizeNameSelected,
    serializeSelected,
    deserializeSelected,
    condenseSelected,
    nudgeCrossingsSelected,
    padWithZeroSelected,
    showMergePanel,
    showBlendPanel,
    sort,
    selectedHeaderClick,
    renderList,
    renderRow,
    joinAll: joinAllUICall,
    performMergeUiCall,
    performBlendUiCall,
    selectSliceAmount,
    toggleCheck,
    move,
    playFile,
    playSlice,
    sliceAction,
    stopPlayFile,
    downloadFile,
    downloadAll,
    changeChannel,
    changePan,
    duplicate,
    remove,
    handleRowClick,
    rowDragStart,
    splitAction,
    splitEvenly,
    splitFromFile,
    splitSizeAction,
    splitFromTrack,
    convertChain,
    toggleModifier,
    toggleListVisibility,
    toggleOptionsPanel,
    showExportSettingsPanel,
    showEditPanel,
    closeEditPanel,
    closeSplitOptions,
    createOtMetaFile,
    pitchExports,
    toggleSetting,
    toggleSecondsPerFile,
    updateSpacedChainMode,
    updateUiButtonAction,
    updateExportChainsAsXyPresets,
    changeOpParam,
    toggleHelp,
    toggleChainNamePanel,
    changeChainName,
    generateChainNames,
    removeMetaFile,
    getSlicesFromMetaFile,
    setAudioOptionsFromCommonConfig,
    bufferRateResampler,
    showWelcome,
    editor
};

import {
    audioBufferToWav, bufferToFloat32Array,
    deClick, detectTempo,
    Resampler,
    getResampleIfNeeded, dcDialog,
    joinToStereo, showToastMessage, buildXyDrumPatchData,
    setLoadingText
} from './resources.js';
import {settings} from './settings.js';

const editPanelEl = document.getElementById('editPanel');
const editableItemsEl = document.getElementById('editableItems');
const editEl = document.getElementById('editorPanelContent');

const opExportPanelEl = document.getElementById('opExportPanel');
const opExportEl = document.getElementById('opExportPanelContent');
const rightButtonsEl = document.querySelector('.right-buttons');

const views = ['sample', 'slice', 'opExport'];

const xyRxp = str =>
  str.replaceAll(/[\[\{<]/g, '(').
    replaceAll(/[\]\}>]/g, ')').
    replaceAll(/[^a-zA-Z0-9\s#\-\(\)]/g, '-').
    replaceAll(/-{3,}/g, '-');

let editing;
let conf; // {audioCtx, masterSR, targetSR, masterChannels, masterBitDepth}
let multiplier = 1;
let selection = {
    start: 0,
    end: 0,
    step: 0,
    selStart: true
};
let showStereoWaveform = false;
let shouldSnapToZeroCrossing = false;

let folders = [];

let samples = [];
let opDataConfig = Array.from({ length: 24 }).map(i => ({}));

export function setEditorConf(options) {
    conf = options;
}

export function showEditor(data, options, view = 'sample', folderOptions = []) {
    conf = options;
    folders = folderOptions;
    if (view === 'sample') {
        if (editing && editing.meta) {
            editing.meta.editing = false;
        }
        editing = data;
        multiplier = 1;
        selection.end = editing.buffer.length;
        selection.start = 0;
        selection.step = editing.buffer.length / (1024 * multiplier);
        selection.selStart = true;
        showStereoWaveform = conf.masterChannels > 1;
        editing.meta.editing = true;
        render();
        return;
    }
    if (view === 'opExport') {
        samples.selected = false;
        /*Rehydrate state if it came from localstorage */
        if (samples.find(f => f?.buffer?.channel0)) {
            samples.forEach(f => {
               if (!f?.buffer?.channel0) { return; }
                const audioBuffer = conf.audioCtx.createBuffer(
                  f.buffer.numberOfChannels,
                  f.buffer.length,
                  conf.masterSR
                );
                audioBuffer.copyToChannel(f.buffer.channel0, 0);
                if (f.buffer.numberOfChannels === 2) {
                    audioBuffer.copyToChannel(f.buffer.channel1, 1);
                }
                f.buffer = audioBuffer;
            });
        }
        renderOpExport();
        opExportPanelEl.classList.add('show');
        rightButtonsEl.classList.add('fade');
    }
}

function render() {
    renderEditableItems();
    renderEditor(editing);
    updateSelectionEl();
    if (!editPanelEl.open) { editPanelEl.showModal(); }
    renderSliceList();
    renderEditPanelWaveform();
}

function getOpKeyData(keyId) {
    const center = samples.find(f => f.meta.opKeyId === keyId && f.meta.opKeyPosition === -1);
    const left = samples.find(f => f.meta.opKeyId === keyId && f.meta.opKeyPosition === 0);
    const right = samples.find(f => f.meta.opKeyId === keyId && f.meta.opKeyPosition === 1);

    return {
        center, left, right,
        hasData:  !!(center || left || right),
        length: Math.max(center?.buffer?.length??0, left?.buffer?.length??0, right?.buffer?.length??0)
    };
}

function removeOpKeyData(keyId, zones = []) {
    const toRemove = samples.map((s, i) => s.meta.opKeyId === keyId && zones.includes(s.meta.opKeyPosition) ? i : false).filter(i => i !== false);
    toRemove.forEach(i => samples.splice(i, 1));
    renderOpExport();
}

function calculateSamplesLengths() {
    const lengths = samples.reduce((acc, val) => {
        acc[val.meta.opKeyId] = acc[val.meta.opKeyId] || 0;
        acc[val.meta.opKeyId] = acc[val.meta.opKeyId] > val.buffer.length ? acc[val.meta.opKeyId] : val.buffer.length;
        return acc;
    }, {});

    samples.buffersLength = Object.keys(lengths).reduce((acc, val) => acc + lengths[val], 0);
    samples.maxBuffersLength = (samples.buffersLength < (20 * 44100) && !samples.xyMultiOut) ? (20 * 44100) : (24 * 20 * 44100);
    samples.isXyOnly = samples.buffersLength > (20 * 44100);
}

function addOpKeyData(keyId, zone, opData) {
    const fIdx = samples.findIndex(i => i.meta.opKeyId === keyId && i.meta.opKeyPosition === zone);
    if (fIdx !== -1) {
        samples[fIdx] = opData;
    } else {
        samples.push(opData);
    }
    calculateSamplesLengths();
}

async function dropOpKey(event, keyId, zone = -1) {
    event?.target?.classList?.remove('drag-over');
    if (zone !== -1 && event.stopPropagation) {
        event?.stopPropagation();
    }
    const lastSelectedFile = event.buffer ? event : digichain.lastSelectedFile();
    if (!lastSelectedFile) { return; }

    if (lastSelectedFile.meta.duration > 20) {
        await dcDialog('alert', `Skipping sample '${lastSelectedFile.file.filename}' as it is ${lastSelectedFile.meta.duration} seconds in length, samples must be less than 20 seconds.`);
        return;
    }

    const file = {...lastSelectedFile, file: {...lastSelectedFile.file}, meta: {...lastSelectedFile.meta}};
    const rsFile = getResampleIfNeeded(file.meta, lastSelectedFile.buffer, 44100);

    rsFile.file = {...file.file, ...rsFile.file};
    rsFile.meta.opKey = {};
    rsFile.meta.channel = rsFile.buffer.numberOfChannels > 1 ? 'S' : rsFile.meta.channel;
    rsFile.meta.opKeyId = keyId;
    rsFile.meta.opKeyPosition = zone;
    addOpKeyData(keyId, zone, rsFile);
    sanitizeName(event, samples, [rsFile]);
    opDataConfig[keyId].linkedTo = false;

    if (rsFile.meta.opPitch) {
        opDataConfig[keyId].st = rsFile.meta.opPitch;
    }
    if (rsFile.meta.opPan) {
        opDataConfig[keyId].p = rsFile.meta.opPan;
    }
    if (rsFile.meta.opPanAb) {
        opDataConfig[keyId].pab = rsFile.meta.opPanAb;
    }

    renderOpExport();
}

function opKeySelected(event, keyId) {
    if (samples.linkMode) {
        if (keyId === samples.selected || opDataConfig.some(c => c.linkedTo === `${keyId}`)) { return ;}
        opDataConfig[keyId].linkedTo = opDataConfig[keyId].linkedTo === `${samples.selected}` ? false : `${samples.selected}`;
        removeOpKeyData(keyId, [-1, 0, 1]);
    } else {
        samples.selected = samples.selected === keyId ? false : keyId;
    }
    renderOpExport();
}

function renderKey(color, index) {
    const keyData = getOpKeyData(index);
    const fileNames = {
        center: getNiceFileName('', keyData?.center, true),
        left: getNiceFileName('', keyData?.left, true),
        right: getNiceFileName('', keyData?.right, true)
    }
    return `
    <div class="op-key ${color} key-${index} ${samples.selected === index ? 'selected' : ''}"
         ondragenter="this.classList.add('drag-over')"
         ondragleave="this.classList.remove('drag-over')"
         data-has-data="${keyData.hasData ? '1' : '0'}"
         onclick="digichain.editor.opKeySelected(event, ${index})"
         >
        <div class="left-a"
           ondragenter="this.classList.add('drag-over')"
           ondragleave="this.classList.remove('drag-over')"
           ondrop="digichain.editor.dropOpKey(event, ${index}, 0)"
           title="${fileNames.left ? (fileNames.left + '.') : ''}"
        >L</div>
        <div class="center-c"
           ondrop="digichain.editor.dropOpKey(event, ${index})"
           title="${fileNames.center ? (fileNames.center + '.') : ''}"
        >${opDataConfig[index].linkedTo ? '<div class="op-key-linked"><i class="gg-link"></i> ' + (+opDataConfig[index].linkedTo + 1) + '</div>': ''}</div>
        <div class="right-b"
           ondragenter="this.classList.add('drag-over')"
           ondragleave="this.classList.remove('drag-over')"
           ondrop="digichain.editor.dropOpKey(event, ${index}, 1)"
           title="${fileNames.right ? (fileNames.right + '.') : ''}"
        >R</div>
    </div>
  `;
}

function editOpSlice(zone) {
    const opData = getOpKeyData(samples.selected);
    showEditor(opData[zone], conf);
}

function renderOpKeyDetails() {
    if (samples.selected === false || samples.linkMode) {
        return '';
    }

    const opData = getOpKeyData(samples.selected);
    const opKeyConfig = opDataConfig[samples.selected];

    const opKeyDetailMarkup = (zone, zoneId, caption) => {
        return `
        <div class="op-key-detail-title">${caption}
        ` + ( zone !== 'center' && opData[zone] ? `<div class="channel-options has-shift-mod" style="display: ${opData[zone].buffer.numberOfChannels >
        1 ? 'block' : 'none'}">
          <a title="Left channel" onclick="digichain.editor.changeChannel(event, 'L', '${zone}')" class="${opData[zone].meta.channel ===
        'L' ? 'selected' : ''} channel-option-L">L</a>
          <a title="Sum to mono" onclick="digichain.editor.changeChannel(event, 'S', '${zone}')" class="${opData[zone].meta.channel ===
        'S' ? 'selected' : ''} channel-option-S">S</a>
          <a title="Right channel" onclick="digichain.editor.changeChannel(event, 'R', '${zone}')" class="${opData[zone].meta.channel ===
        'R' ? 'selected' : ''} channel-option-R">R</a>
          <a title="Difference between Left and Right channels" onclick="digichain.editor.changeChannel(event, 'D', '${zone}')" class="${opData[zone].meta.channel ===
        'D' ? 'selected' : ''} channel-option-D">D</a>
          </div>` : '') +
        `</div>
        <div class="op-key-detail op-key-details-${zone}">
            <span class="op-key-detail-name">${getNiceFileName('', opData[zone], true)??''}</span>
            <button ${opData[zone] ? '' : 'disabled="disabled"'} title="Edit" onclick="digichain.editor.editOpSlice('${zone}')" class="button-clear toggle-edit"><i class="gg-pen"></i></button>
            <button ${opData[zone] ? '' : 'disabled="disabled"'} title="Remove sample (double-click)." ondblclick="digichain.editor.removeOpKeyData(${samples.selected}, [${-1}])" class="button-clear remove"><i class="gg-trash"></i></button>
        </div>
        <div class="op-key-spacer"></div>
        `;
    };

    const opControlsMarkup = () => {
        return `
        <div class="op-key-details-controls">
            <span>Panning</span>
            <div class="channel-options channel-options-stereo channel-options-stereo-opf ${opKeyConfig.pab
              ? 'op-pan-ab-true'
              : ''}" style="display: block; border: 1px solid #40392e;"
               ondblclick="digichain.editor.changeOpParam({target:{value: 16384}}, 'p')"
               >
                  <input class="channel-balance" type="range" style="display: inline-block;"
                  min="0" max="32768" onchange="digichain.editor.changeOpParam(event, 'p')" value="${opKeyConfig.p ?? 16384}" />
                  <div style="display: inline-block;">
                    <span class="op-la"></span>
                    <span class="op-rb"></span>
                  </div>
              </div>
        </div>
        
        <div class="op-key-details-controls">
            <a onclick="digichain.editor.changeOpParam(event, 'pab')" title="Only applicable to OP-1 Field Exports." style="padding-top: .75rem;">L/R ↔ A/B Toggle</a>
            <span></span>
        </div>
        <br>
        <div class="op-key-details-controls">
            <div class="slice-options input-set" style="width: 100%;">
                  <label for="opPlayMode" class="before-input" style="margin-top: -.15rem;">Play Mode</label>
                  <select name="opPlayMode" id="opPlayMode" onchange="digichain.editor.changeOpParam(event, 'pm')" style="width: 100%; color:inherit;">
                    <option value="4096" ${+opKeyConfig?.pm === 4096 ? 'selected' : '' }>Gate</option>
                    <option value="20480" ${+opKeyConfig?.pm === 20480 ? 'selected' : '' }>Group</option>
                    <option value="28672" ${+opKeyConfig?.pm === 28672 ? 'selected' : '' }>Loop</option>
                    <option value="12288" ${!opKeyConfig.pm || +opKeyConfig?.pm === 12288 ? 'selected' : '' }>One Shot</option>
                  </select>
            </div>
        </div>
        <div class="op-key-details-controls" style="margin-top: .5rem;">
            <span style="margin-top: -.75rem;">Play Direction</span>
            <button class="button button-outline" style="padding: 0 .75rem; min-width: 8rem;" onclick="digichain.editor.changeOpParam({target:{value: ${!opKeyConfig.r || +opKeyConfig?.r === 8192 ? 24576 : 8192}}}, 'r')">${!opKeyConfig.r || +opKeyConfig?.r === 8192 ? 'Forward' : 'Reverse'}</button>
        </div>
        `;
    };

    return `
    <div style="display: flex; justify-content: space-between;">
        <h5>${samples.selected + 1} / 24</h5>
        <div style="padding-right: .25rem; margin-top: -.5rem; opacity: .7;">
            <button class="button-clear move-up" onclick="digichain.editor.opKeySelected(event, ${samples.selected === 0 ? 23 : (samples.selected - 1)})"><i class="gg-chevron-up-r has-shift-mod-i"></i></button>
            <button class="button-clear move-down" onclick="digichain.editor.opKeySelected(event, ${samples.selected === 23 ? 0 : (samples.selected + 1)})"><i class="gg-chevron-down-r has-shift-mod-i"></i></button>
        </div>
    </div>
    ` + (opKeyConfig.linkedTo ?
      `<div class="op-key-details-buttons">
        <div class="op-key-detail-title">Samples Linked to Key ${+opKeyConfig.linkedTo + 1}</div>
    </div>
    <div class="op-key-spacer"></div>` + opControlsMarkup():
    `<div class="op-key-details-buttons">
        ${opKeyDetailMarkup('center', -1, 'Main')}
        ${opKeyDetailMarkup('left', 0, 'Left')}
        ${opKeyDetailMarkup('right', 1, 'Right')}
    </div>` + opControlsMarkup()
    );
}

function changeOpParam(event, key, id) {
    const opKeyConfig = opDataConfig[id || samples.selected];
    if (event?.target?.value) {
        opKeyConfig[key] = +event.target.value;
    } else {
        opKeyConfig[key] = !opKeyConfig[key];
        if (event.shiftKey && key === 'pab') {
            opDataConfig.forEach(opdc => opdc.pab = opKeyConfig[key]);
        }
    }
    renderOpExport();
}

function getKitName() {
    return samples.kitName || `dc${new Date().toJSON().replaceAll(/^\d{4}|\-|T|:|\.|\d{2}Z$/gi, '')}`;
}

export function getSetOpExportData(_samples, _opDataConfig, forExport) {
    if (_samples?.length === 0) {
        samples = [];
        samples.selected = false;
        opDataConfig = Array.from({ length: 24 }).map(i => ({}));
    } else if (_samples && _opDataConfig){
        samples = _samples;
        samples.selected = samples.selected || false;
        opDataConfig = _opDataConfig;
    }
    if (forExport) {
        if (samples.find(f => f?.buffer?.channel0)) {
            return {samples, opDataConfig};
        }
        return {
            opDataConfig,
            samples: samples.map(f => ({
                  ...f,
                  buffer: f.buffer ? {
                      duration: f.buffer.duration,
                      length: f.buffer.length,
                      numberOfChannels: f.buffer.numberOfChannels,
                      sampleRate: f.buffer.sampleRate,
                      channel0: f.buffer.getChannelData(0),
                      channel1: f.buffer.numberOfChannels > 1 ? f.buffer.getChannelData(1) : false
                  } : false
              })
            )
        };
    }
    return {samples, opDataConfig};
}

async function renderOpExport(reset = false) {
    if (reset) {
        const confirmReset = await dcDialog('confirm', 'Reset OP Export kit config?', {kind: 'warning', okLabel: 'Reset'});
        if (confirmReset) {
            getSetOpExportData([]);
        }
    }

    const keys = {
        black: [1, 3, 5, 8, 10, 13, 15, 17, 20, 22],
        white: [0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18, 19, 21, 23]
    };
    const isBlackKeySelected = keys.black.find(k => k === samples.selected);
    if (samples.length === 0) {
        samples.buffersLength = 0;
        samples.maxBuffersLength = 20 * 44100;
    } else {
        calculateSamplesLengths();
    }
    const xyMultiOut = samples.buffersLength > (20 * 44100) ? true : samples.xyMultiOut;
    samples.xyMultiOut = xyMultiOut;
    opExportEl.innerHTML = `
    <div>
        <div class="op-key-details">${renderOpKeyDetails()}</div>
        <div class="op-keys row ${samples.selected !== false && samples.linkMode ? 'in-link-mode' : ''}" style="display: flex; flex-direction: ${isBlackKeySelected && !samples.linkMode ? 'row-reverse' : 'row'};">
                <div class="white-keys float-right">${keys.white.reduce(
          (a, i) => a += renderKey('white', i), '')}</div>
            <div class="black-keys float-right" style="${isBlackKeySelected && !samples.linkMode ? 'margin-left: .75rem;' : ''}">${keys.black.reduce(
          (a, i) => a += renderKey('black', i), '')}</div>
        </div>
        <div class="op-samples-length-bar" data-caption="${Math.floor((samples.buffersLength / samples.maxBuffersLength) * 100)}% (${Number(samples.buffersLength / 44100).toFixed(3)}s)">
            <div class="fill" style="width: ${Math.floor((samples.buffersLength / samples.maxBuffersLength) * 100)}%;"></div>
        </div>
        <div class="op-buttons row" style="justify-content: space-between;">
            <button style="padding: 0 .75rem;"
            title="Toggle building the kit as a single audio sample or as multiple audio sample files in the created XY preset. \n\nNote: If the combined samples length is greater than 20 seconds, Field export will be disabled and XY multi file ouput enabled by default."
            class="button float-right button-outline" onclick="digichain.editor.toggleOpExportSetting(event, 'xyMultiOut')" ${samples.isXyOnly ? 'disabled="disabled"' : ''}>XY ${xyMultiOut ? 'Multi File' : 'Single File'}</button>
            <button title="Toggle Link Selection Mode" onclick="digichain.editor.toggleOpExportSetting(event, 'linkMode')" class="button-clear toggle-link" style="opacity: ${samples.linkMode ? 1 : .2}; visibility: ${samples.selected !== false ? 'visible' : 'hidden'};"><i class="gg-link"></i></button>
        </div>
        <div class="op-buttons row">
            <input type="text" placeholder="Kit Name" onblur="digichain.editor.toggleOpExportSetting(event, 'kitName')" value="${samples.kitName??''}">
            <button ondrop="digichain.splitAction(event, false, true, false, true)" title="Spreads a chain across the kit, this will replace any existing samples in the kit." class="button-outline op-chain-drop-zone">Drop Chain</button>
        </div>
        <div class="op-buttons row" style="justify-content: space-between;">
            <button class="button float-right" onclick="digichain.editor.buildXyKit()">Build XY Kit</button>
            <button class="button float-right" onclick="digichain.editor.buildOpKit()" ${samples.isXyOnly ? 'disabled="disabled"' : ''}>Build Field Kit</button>
            <span>&nbsp;</span>
            <span>&nbsp;</span>
            <button title="Clear Kit" class="float-right button-clear" style="opacity:.7;" onpointerdown="digichain.editor.renderOpExport(true)"><i class="gg-remove"></i></button>
        </div>
    </div>
  `;
    conf.storeState();
}
function toggleOpExportSetting(event, setting) {
    if (setting === 'kitName') {
        samples[setting] = event?.target?.value || '';
        const temp = {file: {path: '', name: samples[setting]}, meta: {id: crypto.randomUUID()}};
        sanitizeName(event, [temp], [temp]);
        samples[setting] = temp.file.name;
        event.target.value = samples[setting];
    } else {
        if (setting === 'linkMode' && !getOpKeyData(samples.selected)?.hasData) {
            return ;
        }
        samples[setting] = !samples[setting];
        renderOpExport();
    }
}

async function acceptDroppedChainItems(droppedFiles = []) {
    droppedFiles.forEach((f, idx) => {
        const idxAsString = `0${idx + 1}`.slice(-2);
        f.file.name = `Chain Slice ${idxAsString}.wav`;
    });
    if (droppedFiles?.length && droppedFiles.length > 24) {
        const userValue = await dcDialog(
          'prompt',
          `The dropped chain contains ${droppedFiles.length} slices, please specify the slice number to start from to populate the kit`,
          { inputType: 'number' });
        if (userValue === false) { return; }
        let startFrom = Math.abs(parseInt(userValue));
        startFrom = startFrom > droppedFiles.length ? droppedFiles.length : startFrom;
        droppedFiles = droppedFiles.slice(startFrom);
    }
    const userTargetValue = await dcDialog(
      'confirm',
      'Place samples in the Left, Center, or Right channel per key?',
      {
          cancelLabel: 'Left',
          centerLabel: 'Right',
          okLabel: 'Center'
      }
    );
    const placement = userTargetValue === true ? -1 : userTargetValue === false ? 0 : 1;
    droppedFiles.slice(0, 24).forEach((f, idx) => dropOpKey(f, idx, placement));
    renderOpExport();
}

function consolidateOpKeysToKit() {
    const kit = opDataConfig.map((key, keyId) => {
        const keySamples = getOpKeyData(key.linkedTo || keyId);
        keySamples.left = keySamples.left ?
          bufferToFloat32Array(keySamples.left.buffer, keySamples.left.meta.channel, true, conf.audioCtx, 1, 44100) :
          false;
        keySamples.right = keySamples.right ?
          bufferToFloat32Array(keySamples.right.buffer, keySamples.right.meta.channel, true, conf.audioCtx, 1, 44100) :
          false;

        if (key.linkedTo) {
            return {
                ...key
            };
        }

        if (!keySamples.hasData) {
            return {
                blank: true,
                ...key
            };
        }

        let combinedBuffer = conf.audioCtx.createBuffer(
          2,
          keySamples.length || 1,
          44100
        );

        for (let i = 0; i < keySamples.length; i++) {
            const centerValLeft = keySamples.center ? keySamples.center.buffer.getChannelData(0)[i] : 0;
            const centerValRight = keySamples.center ? keySamples.center.buffer.getChannelData(
              keySamples.center.buffer.numberOfChannels - 1)[i] : 0;
            const leftVal = keySamples.left ? keySamples.left.getChannelData(0)[i] : 0;
            const rightVal = keySamples.right ? keySamples.right.getChannelData(0)[i] : 0;

            let combLeft = 0;
            let combRight = 0;

            if (keySamples.center && keySamples.left) {
                combLeft = (centerValLeft + leftVal) / 2;
            } else {
                combLeft = keySamples.center ? centerValLeft : leftVal;
            }

            if (keySamples.center && keySamples.right) {
                combRight = (centerValRight + rightVal) / 2;
            } else {
                combRight = keySamples.center ? centerValRight : rightVal;
            }

            combinedBuffer.getChannelData(0)[i] = combLeft;
            combinedBuffer.getChannelData(1)[i] = combRight;
        }

        return {
            samples: keySamples,
            buffer: combinedBuffer,
            length: combinedBuffer.length,
            ...key
        };
    });

    kit.totalLength = kit.reduce((acc, val) => acc + (val.length || 0), 0);
    return kit;
}

function serializeOpKitToSingleBuffer() {
    const kit = consolidateOpKeysToKit();
    /*Loop over the keys with samples data assigned first*/
    let lastValidKey = -1;
    for (let s = 0; s < kit.length; s++) {
        if (!kit[s].blank && !kit[s].linkedTo) {
            kit[s].s = (s === 0 || lastValidKey === -1) ? 0 : kit[lastValidKey].e;
            kit[s].e = kit[s].s + kit[s].length;
            lastValidKey = s;
        }
    }
    /*Then loop over the blank and linkedTo keys to match up to the mapped sample keys*/
    for (let s = 0; s < kit.length; s++) {
        if (kit[s].blank) {
            kit[s].s = kit.totalLength;
            kit[s].e = kit.totalLength;
        }
        if (kit[s].linkedTo) {
            const key = +kit[s].linkedTo;
            kit[s].s = kit[key].s;
            kit[s].e = kit[key].e;
            kit[s].length = kit[key].length;
        }
    }

    const kitAudio = conf.audioCtx.createBuffer(
      2,
      kit.totalLength,
      44100
    );
    joinToStereo(kitAudio, kit.filter(key => key.buffer));

    return {
        buffer: kitAudio,
        slices: kit.map(k=> {
            const {buffer,samples,...slice} = k;
            return slice;
        })
    };
}

function buildOpKit(type = 'aif', kitName) {
    setLoadingText('Building Field Kit');
    const kit = serializeOpKitToSingleBuffer();
    kitName = kitName || samples.kitName || getKitName();
    const linkEl = document.querySelector('.aif-link-hidden');
    const abtwMeta = {
        slices: kit.slices.filter(s => !s.blank),
        renderAt: type === 'aif' ? '44100' : conf.targetSR
    };
    const dataView = audioBufferToWav(kit.buffer, abtwMeta, conf.masterSR, 16, 2, false, (type === 'aif'));
    let blob = new window.Blob([dataView.buffer], {
        type: type === 'aif' ? 'audio/aiff' : 'audio/wav'
    });
    if (type === 'wav') {
        return {
            buffer: kit.buffer,
            blob,
            slices: dataView.slices || kit.slices.filter(s => !s.blank)
        };
    }
    linkEl.href = URL.createObjectURL(blob);
    linkEl.setAttribute('download', `${kitName}.aif`);
    setLoadingText('');
    linkEl.click();
}

function buildXyKit() {
    const kitName = samples.kitName || getKitName();
    const zip = new JSZip();
    let xyPatchData;
    setLoadingText('Building XY Kit');
    if (samples.xyMultiOut) {
        const kit = consolidateOpKeysToKit();
        kit.forEach((slice, idx) => {
            if (!slice.blank) {
                let sNum = `${slice.buffer ? idx + 1 : +slice.linkedTo + 1}`;
                sNum = sNum.length === 1 ? `0${sNum}` : sNum;
                slice.name = `${kitName}${sNum}`;
                slice.l = slice.length;
            }
            if (slice.buffer) {
                const dataView = audioBufferToWav(slice.buffer, {slices: false, renderAt: conf.targetSR}, conf.masterSR, 16, 2);
                let blob = new window.Blob([dataView.buffer], {
                    type: 'audio/wav'
                });
                zip.file(`${slice.name}.wav`, blob, {binary: true});
                slice.s = 0;
                slice.e = slice.buffer.length;
                slice.fc = slice.length || slice.e;
            }
        });
        kit.forEach(slice => {
            if (slice.linkedTo) {
                const key = +slice.linkedTo;
                slice.s = kit[key].s;
                slice.e = kit[key].e;
                slice.fc = kit[key].fc;
            }
        });
        xyPatchData = buildXyDrumPatchData({kitName}, kit.filter(s => !s.blank));
    } else {
        const {buffer, blob, slices} = buildOpKit('wav', kitName);
        xyPatchData = buildXyDrumPatchData({buffer, kitName}, slices);
        zip.file(`${kitName}.wav`, blob, {binary: true});
    }
    zip.file('patch.json', JSON.stringify(xyPatchData));
    zip.generateAsync({type: 'blob'}).then(zipBlob => {
        const el = document.getElementById('getJoined');
        el.href = URL.createObjectURL(zipBlob);
        el.setAttribute('download', `${kitName}.preset.zip`);
        setLoadingText('');
        el.click();
    });
}

function toggleSnapToZero(event) {
    const btnEl = event.target;
    shouldSnapToZeroCrossing = !shouldSnapToZeroCrossing;
    btnEl.classList[shouldSnapToZeroCrossing ? 'remove' : 'add']('button-outline');
}

async function detectBpm(event) {
    const btnEl = event.target;
    const detectBufferArray = editing.buffer.getChannelData(0).slice(selection.start, selection.end);
    const detectBuffer = conf.audioCtx.createBuffer(1, detectBufferArray.length, conf.masterSR);
    detectBuffer.getChannelData(0).set(detectBufferArray);
    const bpm = await detectTempo(detectBuffer);
    editing.tempo = bpm?.match || false;
    btnEl.textContent = `${editing.tempo||''} BPM`;
}

function sliceSelect(event) {
    const sliceSelectEl = document.querySelector('#sliceSelection');
    const selectionEl = document.querySelector('#editLines .edit-line');
    if (+sliceSelectEl.value === -1) {
        return resetSelectionPoints();
    }
    const slices = digichain.getSlicesFromMetaFile(editing);
    const slice = slices.at(+sliceSelectEl.value);
    selection.start = slice.s;
    selection.end = slice.e;
    updateSelectionEl();
    selectionEl.scrollIntoViewIfNeeded();
}

function sliceUpdate(event) {
    const sliceSelectEl = document.querySelector('#sliceSelection');
    if (+sliceSelectEl.value === -1) {
        return;
    }
    const slices = digichain.getSlicesFromMetaFile(editing);
    const slice = slices.at(+sliceSelectEl.value);
    slice.s = selection.start;
    slice.e = selection.end;
    slice.l = -1;
    digichain.removeMetaFile(editing.meta.id);
    editing.meta.slices = slices;
}

function sliceRemove(event) {
    const sliceSelectEl = document.querySelector('#sliceSelection');
    if (+sliceSelectEl.value === -1) {
        return;
    }
    const slices = digichain.getSlicesFromMetaFile(editing);
    editing.meta.slices = slices.filter(
      (slice, idx) => idx !== +sliceSelectEl.value
    );
    digichain.removeMetaFile(editing.meta.id);
    editing.meta.slices = editing.meta.slices.length ? editing.meta.slices : false;
    sliceSelectEl.value = -1;
    selection.start = 0;
    selection.end = editing.buffer.length;
    updateSelectionEl();
    renderSliceList();
}

function sliceCreate(event) {
    const slices = digichain.getSlicesFromMetaFile(editing);
    const slice = slices.push({
        n: '',
        s: selection.start,
        e: selection.end,
        l: -1
    });
    digichain.removeMetaFile(editing.meta.id);
    editing.meta.slices = slices;
    renderSliceList();
    const sliceSelectEl = document.querySelector('#sliceSelection');
    sliceSelectEl.value = slices.length > 0 ? slices.length - 1 : -1;
}

export function renderEditor(item) {
    editing = item === editing ? editing : item;
    const canvasMarkup = `
  <canvas class="edit-panel-waveform"
        oncontextmenu="return false;"
        onpointerdown="digichain.editor.changeSelectionPoint(event)"
        ></canvas>
  `;
    editEl.innerHTML = `
<div class="slice-options input-set">
  <label for="sliceSelection" class="before-input">Slice</label>
  <select title="Choose a slice marker to edit." name="sliceSelection" id="sliceSelection" onchange="digichain.editor.sliceSelect(event);"></select>
<div style="display: ${editing.meta.opKey ? 'none' : 'inline-block'}; margin-top: .2rem; padding-left: .5rem;">
  <button title="Update the slice marker start/end points." onpointerdown="digichain.editor.sliceUpdate(event);" class="button-outline">Update Slice</button>
  <button title="Remove the current slice marker." onpointerdown="digichain.editor.sliceRemove(event);" class="button-outline">Remove Slice</button>
  <button title="Add the current range as a new slice marker." onpointerdown="digichain.editor.sliceCreate(event);" class="button-outline">New Slice</button>
</div>
<div style="display:inline-block; margin-top: .2rem; padding-left: .5rem;">
  <button title="Snap selections to zero crossings?" onpointerdown="digichain.editor.toggleSnapToZero(event);" class="button ${shouldSnapToZeroCrossing ? '' : 'button-outline'}">Snap to Zero</button>
  <button title="Detect BPM from selection." onpointerdown="digichain.editor.detectBpm(event);" class="button button-clear"> BPM</button>
</div>
</div>
<div class="above-waveform-buttons">
  <div class="sample-selection-buttons text-align-left float-left">
      <button title="Clicking on the waveform will set the selection start point." onpointerdown="digichain.editor.setSelStart(true);" class="button check btn-select-start">Start</button>
    <button title="Clicking on the waveform will set the selection end point." onpointerdown="digichain.editor.setSelStart(false);" class="button-outline check btn-select-end">End</button>
      <button title="Reset the waveform selection to the whole sample." onpointerdown="digichain.editor.resetSelectionPoints();" class="button-outline check">All</button>
  </div>
  <div class="channel-options editor-channel-options float-right" style="border: 0.1rem solid #d79c4e; display: ${(editing.buffer.numberOfChannels >
    1 && conf.masterChannels === 1) || (editing.meta.opKey && editing.meta.opKeyPosition !== -1) ? 'inline-block' : 'none'}">
            <a title="Left channel" onpointerdown="digichain.editor.changeChannel(event, 'L')" class="${editing.meta.channel ===
    'L' ? 'selected' : ''} channel-option-L">L</a>
            <a title="Sum to mono" onpointerdown="digichain.editor.changeChannel(event, 'S')" class="${editing.meta.channel ===
    'S' ? 'selected' : ''} channel-option-S">S</a>
            <a title="Right channel" onpointerdown="digichain.editor.changeChannel(event, 'R')" class="${editing.meta.channel ===
    'R' ? 'selected' : ''} channel-option-R">R</a>
            <a title="Difference between Left and Right channels" onpointerdown="digichain.editor.changeChannel(event, 'D')" class="${editing.meta.channel ===
    'D' ? 'selected' : ''} channel-option-D">D</a>
  </div>
</div>

  <div class="playback-controls text-align-right float-left" style="position: absolute;">
    <button title="Play selection" onpointerdown="digichain.editor.editorPlayFile(event);" class="button-clear check"><i class="gg-play-button"></i></button>
    <button title="Loop playback of selection" onpointerdown="digichain.editor.editorPlayFile(event, true);" class="button-clear check"><i class="gg-repeat"></i></button>
    <button title="Stop playback" onpointerdown="digichain.editor.editorPlayFile(event, false, true);" class="button-clear check"><i class="gg-play-stop"></i></button>
  </div>
  <div class="zoom-level text-align-right float-right">
    <button title="Toggle waveform width / height zooming"  class="zoom-waveform-height button-outline check" onpointerdown="digichain.editor.zoomLevel('editor-height', 1)"><i class="gg-arrows-v"></i><span>${settings.wavePanelHeight / 128}x</span></button>
    <button title="Zoom out waveform view." class="zoom-out button-outline check" style="width:2.5rem;" onpointerdown="digichain.editor.zoomLevel('editor', .5)">-</button>
    <button title="Reset zoom level waveform view."  class="zoom-reset button-outline check" onpointerdown="digichain.editor.zoomLevel('editor', 1)">1x</button>
    <button title="Zoom in on waveform view."  class="zoom-in button-outline check" style="width:2.5rem;" onpointerdown="digichain.editor.zoomLevel('editor', 2)">+</button>
  </div>

 </div>
  <div class="waveform-container" style="height: ${settings.wavePanelHeight}px;">
    <div>
    ${Array.from('.'.repeat(
        (
          (editing.meta.opKey && editing.meta.opKeyPosition !== -1) ? 1 :
            (Math.floor(
              (conf.masterChannels + editing.buffer.numberOfChannels) / 2))
        )
      )
    ).
      reduce((a, v) => a += canvasMarkup, '')}
      <div id="editLines">
        <div class="edit-line" style="height: ${settings.wavePanelHeight}px; margin-top: -${settings.wavePanelHeight + 8}px;"></div>
      </div>
    </div>
  </div>

  <div class="sample-op-buttons show-sample-duration" data-sample-duration="${editing.meta.duration}s">
  <div class="edit-btn-group float-left">

  <button title="Normalize the volume of the sample." class="normalize button button-outline" onclick="digichain.editor.normalize(event)">Normalize</button>

  <button title="Reverses the sample playback" class="reverse button button-outline" onclick="digichain.editor.reverse(event)">Reverse</button>
  <button title="Crop the sample to the selected area. Shift+Click to crop selection to a new sample. Shift+(Ctrl/Cmd)+Click to crop selection to a new sample and open the new sample in the editor." class="trim-right button button-outline has-ctrl-mod has-shift-mod" onclick="digichain.editor.truncate(event)">Crop</button>
  <button title="Fade in the selected audio." class="fade-in button button-outline" onclick="digichain.editor.fade('in')">Fade In</button>
  <button title="Silence the selected audio." class="silence button button-outline" onclick="digichain.editor.fade()">Silence</button>
  <button title="Increase the gain of the selected audio." class="louder button button-outline" onclick="digichain.editor.adjustGain(event, 1.1)">Louder</button>
  <button title="Decrease the gain of the selected audio." class="quieter button button-outline" onclick="digichain.editor.adjustGain(event, 0.9)">Quieter</button>
  <button title="Fade out the selected audio." class="fade-out button button-outline" onclick="digichain.editor.fade('out')">Fade Out</button>
</div>
<div class="edit-btn-group float-right">
    <div class="edit-pitch-btn-group pitch-semi-tones">
    <button title="Lower pitch by 12 semi-tones" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, .5, 12)">-12</button>
    <button title="Lower pitch by 1 semi-tone" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(-1/12), 1)">-1</button>
    &nbsp;<a href="javascript:;" onclick="digichain.editor.togglePitchSemitoneCents(event, 'cent')" title="Click to toggle between semi-tones and cents."> Pitch (semitones) </a>&nbsp;
    <button title="Increase pitch by 1 semi-tone" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(1/12), -1)">+1</button>
    <button title="Increase pitch by 12 semi-tones" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2, -12)">+12</button>
    </div>
    <div class="edit-pitch-btn-group pitch-cents hide">
    <button title="Lower pitch by 10 cents" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(-1/120), 1)">-10</button>
    <button title="Lower pitch by 1 cent" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(-1/1200), 1)">-1</button>
    &nbsp;<a href="javascript:;" onclick="digichain.editor.togglePitchSemitoneCents(event, 'semi')" title="Click to toggle between semi-tones and cents." style="display: inline-block; width: 13rem;"> Pitch (cents) </a>&nbsp;
    <button title="Increase pitch by 1 cent" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(1/1200), 1)">+1</button>
    <button title="Increase pitch by 10 cents" class="pitch button-outline check" onclick="digichain.editor.perSamplePitch(event, 2**(1/120), 1)">+10</button>
    </div>
    <br>
      <button title="Trims any zero valued audio from the end of the sample. Shift+click to trim both left and right." class="trim-right button button-outline" onclick="digichain.editor.trimRight(event)">Trim Right</button>
      <button class="trim-right button button-outline hide ${editing.buffer.numberOfChannels >
    1 ? '' : 'hide'}" onclick="digichain.editor.interpolate(event)">Interpolate</button>
  </div>
</div>
  <span class="edit-info">
    Normalize, Silence, Louder, Quieter, Fade In, Fade Out, Crop, and Reverse affect the selected part of the sample; Trim Right and Pitch Adjustments affect the whole sample.<br>
    Note: sample operations are destructive, applied immediately, no undo. Pitch adjustments are done via sample-rate, cumulative changes will affect sample quality.
  </span>
  <div class="file-nav-buttons" style="visibility: ${editing.meta.opKey ? 'hidden' : 'visible'};">
    <button title="Edit previous file" class="prev-file button button-clear check" onpointerdown="digichain.editor.changeSelectedFile(event, -1)">Prev</button>
    <button title="Edit next file" class="next-file button button-clear check" onpointerdown="digichain.editor.changeSelectedFile(event, 1)">Next</button>
  </div>
  `;
}

function renderEditableItems() {
    editableItemsEl.innerHTML = `
      <div class="input-set">
      <label for="editFileName" class="before-input">File Name</label>
      <input type="text" onkeyup="digichain.editor.updateFile(event)" placeholder="Sample file name" id="editFileName" value="${getNiceFileName(
      '', editing, true)}" readonly>
      <button class="button-clear" onpointerdown="digichain.editor.toggleReadOnlyInput('editFileName')"><i class="gg-pen"></i></button>
    </div><br>
    <div class="input-set" style="display: ${editing.meta.opKey ? 'none' : 'flex'};">
    <label for="editFilePath" class="before-input">File Path</label>
      <input type="text" onkeyup="digichain.editor.updateFile(event)" placeholder="File path of the sample (if known)" id="editFilePath" value="${editing.file.path}" id="editFilePath" list="folderOptions" readonly>
      <datalist id="folderOptions">
        ${folders.map(f => '<option value="' + f + '">').join('')}
      </datalist>
      <button class="button-clear" onpointerdown="digichain.editor.toggleReadOnlyInput('editFilePath')"><i class="gg-pen"></i></button>
    </div>
  `;
}

function renderSliceList() {
    const sliceSelectEl = document.querySelector('#sliceSelection');
    const slices = digichain.getSlicesFromMetaFile(editing);
    if (Array.isArray(slices)) {
        sliceSelectEl.innerHTML = slices.reduce((a, v, i) => a += `
        <option value="${i}">${i + 1}</option>
    `, '<option value="-1">None</option>');
    }
    const selectedSlice = slices.findIndex(
      s => s.s === selection.start && s.e === selection.end);
    if (selectedSlice !== -1) {
        sliceSelectEl.value = selectedSlice;
    }
}

function renderEditPanelWaveform(multiplier = 1) {
    const waveformWidth = 1024 * multiplier;
    const editPanelWaveformEl = document.querySelector(`.edit-panel-waveform`);
    const editPanelWaveformEls = document.querySelectorAll(
      `.edit-panel-waveform`);
    const durationIndicatorEl = document.querySelector(`.show-sample-duration`);
    if (
      (showStereoWaveform && (editing.meta.opKey && editing.meta.opKeyPosition === -1)) ||
      (showStereoWaveform && !editing.meta.opKey)
    ) {
        editPanelWaveformEls.forEach((editPanelWaveformEl, idx) => {
            drawWaveform(editing, editPanelWaveformEl, idx, {
                width: waveformWidth,
                height: (settings.wavePanelHeight / editPanelWaveformEls.length),
                multiplier
            });
        });
    } else {
        drawWaveform(editing, editPanelWaveformEl, -1, {
            width: waveformWidth, height: settings.wavePanelHeight, multiplier
        });
    }
    if (durationIndicatorEl) {
        durationIndicatorEl.dataset.sampleDuration = `${editing.meta.duration}s`;
    }

}

export function drawWaveform(file, el, channel, dimensions) {
    let drawResolution = Math.floor(file.buffer.length / 32);
    let drawBuffer;
    if (file.buffer.length > 512) {
        drawResolution = (drawResolution > 4096 ? 4096 : drawResolution) *
          (((dimensions?.multiplier || 0) * 2) || 1);
    } else {
        drawResolution = file.buffer.length;
    }
    drawResolution = drawResolution > file.buffer.length
      ? file.buffer.length
      : drawResolution;
    if (channel === 0 || channel === 1) {
        drawBuffer = file.buffer.getChannelData(channel);
    } else {
        drawBuffer = bufferToFloat32Array(file.buffer,
          Number.isInteger(channel) ? file.meta?.channel : channel);
    }
    if (file.buffer.numberOfChannels > 1) {
        let dualMonoCheck = [];
        for (let y = 0; y < file.buffer.length; y += Math.floor(
          file.buffer.length / drawResolution)) {
            dualMonoCheck.push((file.buffer.getChannelData(0)[y] -
              file.buffer.getChannelData(1)[y]) / 2);
        }
        file.meta.dualMono = dualMonoCheck.every(x => x === 0);
    }

    draw(drawBuffer, file.meta.id, el, dimensions);
}

export function getNiceFileName(name, file, excludeExtension, includePath) {
    let fname = file ? `${file.file.name.replace(/\.[^.]*$/,
        '')}${file.meta?.dupeOf ? '-d' : ''}${file.meta?.sliceNumber ? '-s' +
        file.meta.sliceNumber : ''}.wav` :
      name.replace(
        /\.syx$|\.wav$|\.aif$|\.flac$|\.webm$|\.m4a$|\.pti$/, '');
    fname = (includePath && file.file.path) ? `${file.file.path.replace(/\//gi,
      '-')}` + fname : fname;
    return excludeExtension ? fname.replace(/\.[^.]*$/, '') : fname;
}

export function getUniqueName(files, name) {
    const parts = name.split('.');
    const ext = parts.pop();
    const fname = parts.join('.');
    const count = files.filter(
      f => (f.file.name || f.file.filename).includes(fname)).length;
    return count > 0 ? `${fname}-${count + 1}.${ext}` : name;
}

function draw(data, id, canvas, dimensions) {
    // set up the canvas
    const dpr = window.devicePixelRatio || 1;
    const padding = 0;
    canvas.width = dimensions?.width || 150; //canvas.offsetWidth * dpr;
    canvas.height = dimensions?.height || 60;// (canvas.offsetHeight + padding * 2) * dpr;
    const ctx = canvas.getContext('2d');
    //ctx.scale(dpr, dpr);
    ctx.translate(0, canvas.offsetHeight / 2 + padding); // set Y = 0 to be in the middle of the canvas

    // draw the line segments
    const width = canvas.offsetWidth;
    const drawHeight = Math.floor(canvas.offsetHeight * 0.85);

    const samplesPerLine = data.length / width;

    ctx.lineWidth = 1; // how thick the line is
    ctx.strokeStyle = '#a8a8a8'; // what color our line is
    ctx.beginPath();

    ctx.moveTo(0, data[0] * drawHeight/2);

    for (let x = 0; x < width; x++) {
        const startingIndex = Math.floor(x * samplesPerLine);
        const endingIndex = Math.floor(((x+1) * samplesPerLine) - 1);

        let min = data[startingIndex];
        let max = data[startingIndex];

        for (let j = startingIndex; j<endingIndex; j++) {
            min = (data[j] < min) ? data[j] : min;
            max = (data[j] > max) ? data[j] : max;
        }

        ctx.lineTo(x, min * drawHeight/2);
        ctx.lineTo(x, max * drawHeight/2);
    }

    ctx.stroke();
}

function updateFile(event) {
    const target = event.target;
    if (!target) { return; }
    if (target.id === 'editFileName') {
        editing.file.name = target.value;
    }
    if (target.id === 'editFilePath') {
        editing.file.path = target.value;
    }
}

function toggleReadOnlyInput(inputId) {
    const input = document.getElementById(inputId);
    input.readOnly ? input.removeAttribute('readonly') : input.setAttribute(
      'readonly', true);
}

function togglePitchSemitoneCents(event, toggle) {
    const semiTonesDiv = document.querySelector('.pitch-semi-tones');
    const centsDiv = document.querySelector('.pitch-cents');

    semiTonesDiv.classList[toggle === 'cent' ? 'add' : 'remove']('hide');
    centsDiv.classList[toggle === 'semi' ? 'add' : 'remove']('hide');
}

function changeChannel(event, channel, opDataZone) {
    if (opDataZone !== undefined) {
        getOpKeyData(samples.selected)[opDataZone].meta.channel = channel;
        return renderOpExport();
    }
    editing.meta.channel = channel;
    render();
}

function getSelectionStartPoint() {
    return Math.round(selection.start / selection.step);
}

function getSelectionEndPoint() {
    const end = Math.floor((selection.end - selection.start) / selection.step);
    const max = (1024 * multiplier) - getSelectionStartPoint();
    return end > max ? max : end;
}

function updateSelectionEl() {
    const selectionEl = document.querySelector('#editLines .edit-line');
    const width = getSelectionEndPoint() >= (1024 * multiplier) ? (1024 *
      multiplier) : getSelectionEndPoint();
    selectionEl.style.marginLeft = `${getSelectionStartPoint()}px`;
    selectionEl.style.width = `${width}px`;
    selectionEl.classList[+(editing.buffer.getChannelData(0)[selection.start]??1).toFixed(4) === 0 ? 'add' : 'remove']('start-is-zero-crossing');
    selectionEl.classList[+(editing.buffer.getChannelData(0)[selection.end]??1).toFixed(4) === 0 ? 'add' : 'remove']('end-is-zero-crossing');
    if (!selection.start || selection.start === 0) {
        selectionEl.classList.remove('start-is-zero-crossing');
    }
    if (!selection.end || selection.end === editing.buffer.length) {
        selectionEl.classList.remove('end-is-zero-crossing');
    }

}

function zoomLevel(view, level) {
    if (view === 'editor-height') {
        const currentMultiple = settings.wavePanelHeight / 128;
        if (currentMultiple >=4) {
            settings.wavePanelHeight = 128;
        } else {
            settings.wavePanelHeight = 128 * (currentMultiple + 1);
        }
        level = multiplier;
        renderEditor(editing);
        renderSliceList();
    }
    if (view.startsWith('editor')) {
        const selectionEl = document.querySelector('#editLines .edit-line');
        if (level !== 1 && view !== 'editor-height') {
            level = multiplier * level;
        }
        const step = editing.buffer.length / (1024 * level);
        if ((1024 * level) < 1024 || (1024 * level) > 32768 || step < 1) {
            return showToastMessage('Unable to zoom any further');
        }
        renderEditPanelWaveform(level);
        selection.step = step;
        multiplier = level;
        updateSelectionEl();
        selectionEl.scrollIntoViewIfNeeded();
    }
}

function setSelStart(value) {
    const startBtnEl = document.querySelector('.btn-select-start');
    const endBtnEl = document.querySelector('.btn-select-end');
    selection.selStart = Math.abs(Math.round(value));
    startBtnEl.classList[!value ? 'add' : 'remove']('button-outline');
    endBtnEl.classList[value ? 'add' : 'remove']('button-outline');
}

function snapToZeroCrossing(snapEnd = false) {
    if (!shouldSnapToZeroCrossing) {
        return;
    }
    if (snapEnd) {
        for (let i = (selection.end ?? editing.buffer.length); editing.buffer.length > i; i--) {
            if (+editing.buffer.getChannelData(0)[i].toFixed(4) === 0 || i === 0) {
                selection.end = i;
                break;
            }
        }
    } else {
        for (let i = (selection.start ?? 0); i < editing.buffer.length; i++) {
            if (+editing.buffer.getChannelData(0)[i].toFixed(4) === 0 || i === editing.buffer.length) {
                selection.start = i;
                break;
            }
        }
    }
    selection.start = selection.start < 0 ? 0 : selection.start;
    selection.end = selection.end > editing.buffer.length ? editing.buffer.length : selection.end;
}

function changeSelectionPoint(event, shiftKey = false) {
    event.preventDefault();
    const lastSelection = JSON.parse(JSON.stringify(selection));
    const max = (1024 * multiplier);
    if ((event.shiftKey || shiftKey) || !selection.selStart) { //set end point if shift key is down
        let end = 0;
        if (event.offsetX <= max && event.offsetX > -1) {
            end = Math.round(event.offsetX * selection.step);
        } else if (event.offsetX > max) {
            end = editing.buffer.length;
        }
        selection.end = end;
        if (event.ctrlKey || event.metaKey) {
            selection.start = lastSelection.end;
        }
        selection.start = selection.start >= selection.end
          ? selection.end - 1
          : selection.start;
        snapToZeroCrossing(true);
    } else {
        let start = 0;
        if (event.offsetX <= max && event.offsetX > -1) {
            start = Math.round(event.offsetX * selection.step);
        } else if (event.offsetX > max) {
            start = editing.buffer.length;
        }
        selection.start = start;
        if (event.ctrlKey || event.metaKey) {
            selection.end = lastSelection.start;
        }
        selection.end = selection.end <= selection.start
          ? selection.start + 1
          : selection.end;
        snapToZeroCrossing();
    }
    selection.end = selection.end >= editing.buffer.length
      ? editing.buffer.length
      : selection.end;
    //selection.start = selection.start >= selection.end? selection.end - 50 : selection.start;
    selection.start = selection.start >= selection.end
      ? selection.end - 1
      : selection.start;
    updateSelectionEl();
}

function resetSelectionPoints() {
    selection.start = 0;
    selection.end = editing.buffer.length;
    selection.selStart = true;
    updateSelectionEl();
}

function reSamplePitch(
  event, pitchValue, pitchSteps, item, renderEditPanel = true, volumeAdjust = 1,
  bitDepthOverride) {
    item = item || editing;

    if (item.buffer.length < 1024 && pitchValue > 1) {
        return showToastMessage('Sample too small to be pitched up further.');
    }

    const newSR = (conf.masterSR * pitchValue);
    let audioArrayBuffer;

    if (volumeAdjust !== 1) {
        audioArrayBuffer = conf.audioCtx.createBuffer(
          item.buffer.numberOfChannels,
          item.buffer.length,
          conf.masterSR
        );
        for (let channel = 0; channel <
        item.buffer.numberOfChannels; channel++) {
            for (let i = 0; i < item.buffer.length; i++) {
                audioArrayBuffer.getChannelData(
                  channel)[i] = item.buffer.getChannelData(channel)[i] /
                  volumeAdjust;
            }
        }
    }

    const pitchedWav = audioBufferToWav((audioArrayBuffer || item.buffer),
      {...item.meta, bypassStereoAsDualMono: true}, newSR, (bitDepthOverride || 32), item.buffer.numberOfChannels,
      0.4).buffer;
    const pitchedBlob = new window.Blob([new DataView(pitchedWav)], {
        type: 'audio/wav'
    });
    (async () => {
        let linkedFile = await fetch(URL.createObjectURL(pitchedBlob));
        let arrBuffer = await linkedFile.arrayBuffer();
        await new AudioContext(
          {sampleRate: newSR, latencyHint: 'interactive'}).decodeAudioData(
          arrBuffer, buffer => {

              let resampledArrayBuffer;
              let resample, resampleR;
              resample = new Resampler(newSR, conf.masterSR, 1,
                buffer.getChannelData(0));
              resample.resampler(resample.inputBuffer.length);

              if (item.buffer.numberOfChannels === 2) {
                  resampleR = new Resampler(newSR, conf.masterSR, 1,
                    buffer.getChannelData(1));
                  resampleR.resampler(resampleR.inputBuffer.length);
              }

              resampledArrayBuffer = conf.audioCtx.createBuffer(
                item.buffer.numberOfChannels,
                resample.outputBuffer.length,
                conf.masterSR
              );

              if (item.buffer.numberOfChannels === 2) {
                  for (let i = 0; i < resample.outputBuffer.length; i++) {
                      resampledArrayBuffer.getChannelData(
                        0)[i] = resample.outputBuffer[i];
                      resampledArrayBuffer.getChannelData(
                        1)[i] = resampleR.outputBuffer[i];
                  }
              } else {
                  for (let i = 0; i < resample.outputBuffer.length; i++) {
                      resampledArrayBuffer.getChannelData(
                        0)[i] = resample.outputBuffer[i];
                  }
              }

              item.buffer = resampledArrayBuffer;
              item.meta = {
                  ...item.meta,
                  opPitch: (item.meta.opPitch ?? 0) + (512 * pitchSteps),
                  length: resampledArrayBuffer.length,
                  duration: Number(resampledArrayBuffer.length / conf.masterSR).
                    toFixed(3),
                  startFrame: 0, endFrame: resampledArrayBuffer.length,
                  note: false,
                  editing: false,
                  slices: item.meta.slices ? item.meta.slices.map(slice => ({
                      ...slice,
                      n: slice.n, s: Math.round(slice.s / pitchValue),
                      e: Math.round(slice.e / pitchValue)
                  })) : false
              };
              if (renderEditPanel) {
                  renderEditPanelWaveform(multiplier);
                  selection.end = Math.abs(Math.round(selection.end / pitchValue));
                  selection.start = Math.abs(Math.round(selection.start / pitchValue));
                  selection.step = item.buffer.length / (1024 * multiplier);
                  updateSelectionEl();
                  item.waveform = false;
              }
          });
    })();
}

function adjustGain(event, gain, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    let maxSample = 0;
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        for (let i = selection.start; i < selection.end; i++) {
            if (item.buffer.getChannelData(channel)[i]) {
                item.buffer.getChannelData(
                  channel)[i] = item.buffer.getChannelData(channel)[i] * gain;
            }
            maxSample = Math.max(Math.abs(channel[i]), maxSample);
        }
    }

    maxSample = !maxSample ? 1 : maxSample;
    item.meta.peak = maxSample;
    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function normalize(event, item, renderEditPanel = true, findPeakOnly = false) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    let maxSample = 0;
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel);
        for (let i = selection.start; i < selection.end; i++) {
            maxSample = Math.max(Math.abs(data[i]), maxSample);
        }
    }
    maxSample = !maxSample ? 1 : maxSample;
    item.meta.peak = maxSample;
    if (findPeakOnly) {
        return maxSample;
    }
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        for (let i = selection.start; i < selection.end; i++) {
            if (item.buffer.getChannelData(channel)[i] &&
              item.buffer.getChannelData(channel)[i] / maxSample !== 0) {
                item.buffer.getChannelData(
                  channel)[i] = item.buffer.getChannelData(channel)[i] /
                  maxSample;
            }
        }
    }
    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function interpolate(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      1,
      item.buffer.length,
      conf.masterSR
    );

    for (let i = 0; i < item.buffer.length; i++) {
        const value = i + 2 < item.buffer.length ? (item.buffer.getChannelData(
          i % 2)[i] + item.buffer.getChannelData(i % 2)[i + 2]) / 2 :
          item.buffer.getChannelData(i % 2)[i];
        audioArrayBuffer.getChannelData(0)[i] = value;
    }

    item.buffer = audioArrayBuffer;
    item.meta.channel = 'L';
    showStereoWaveform = false;

    if (renderEditPanel) {
        item.meta.editing = false;
        editPanelEl.close();
        digichain.stopPlayFile(false, digichain.editor.getLastItem());
        setTimeout(() => digichain.showEditPanel(event, item.meta.id), 250);
    }
    item.waveform = false;
}

function fade(
  type, item, renderEditPanel = true, start = 0, end = 0, absolute = false) {
    if (!renderEditPanel && item) {
        selection.start = start;
        selection.end = end > 0 ? end : item.buffer.length;
    }
    item = item || editing;

    const numChannels = item.buffer.numberOfChannels;
    const sampleRate = item.buffer.sampleRate;
    const fadeDuration = (selection.end - selection.start);
    const numSamples = fadeDuration * numChannels;
    const fadeSamples = fadeDuration * sampleRate;

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel);
        if (type === 'out') {
            if (absolute) {
                data[selection.end] = 0;
            }
            for (let i = selection.start; i < selection.end; i++) {
                data[i] = data[i] *
                  ((fadeDuration - (i - selection.start)) / fadeDuration);
            }
        } else if (type === 'in') {
            if (absolute) {
                data[selection.start] = 0;
            }
            for (let i = selection.end; i > selection.start; i--) {
                data[i] = data[i] /
                  ((fadeDuration - (i - selection.end)) / fadeDuration);
            }
        } else if (type === 'fuzz') {
            for (let i = selection.start; i < selection.end; i++) {
                const dA = data[i] > 0 ? data[i] + 0.001 : data[i] - 0.001;
                const x = ((fadeDuration + i) / fadeDuration) /
                  dA * Math.random();
                data[i] = Math.abs(x) > 1 ? dA : x;
            }
        } else {
            for (let i = selection.end; i > selection.start; i--) {
                data[i] = 0;
            }
        }
    }

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function reverse(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    if (event.shiftKey && (event.ctrlKey || event.metaKey)) {
        return paulStretch(event, item, renderEditPanel);
    }

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel).
          slice(selection.start, selection.end).
          reverse();
        let dataCount = 0;
        for (let i = selection.start; i < selection.end; i++) {
            item.buffer.getChannelData(channel)[i] = data[dataCount];
            dataCount++;
        }
    }
    item.meta = {...item.meta};
    if (selection.start === 0 && selection.end === item.buffer.length) {
        item.meta.slices = item.meta.slices ? item.meta.slices.map(slice => ({
            ...slice,
            n: slice.n, s: selection.end - slice.e,
            e: selection.end - slice.s
        })) : false;
    } else {
        //item.meta.slices = false;
    }

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function shift(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel).slice(0);
        let dataCount = Math.floor(selection.end / 2);
        for (let i = selection.start; i < selection.end; i++) {
            item.buffer.getChannelData(channel)[i] = data[dataCount];
            dataCount++;
            dataCount = dataCount > selection.end ? 0 : dataCount;
        }
    }
    item.meta = {...item.meta};
    if (selection.start === 0 && selection.end === item.buffer.length) {
        item.meta.slices = item.meta.slices ? item.meta.slices.map(slice => ({
            ...slice,
            n: slice.n, s: selection.end - slice.e,
            e: selection.end - slice.s
        })) : false;
    } else {
        //item.meta.slices = false;
    }

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function flipChannels(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    if (item.buffer.numberOfChannels  === 1) {
        return;
    }

    const channel0 = new Float32Array(item.buffer.getChannelData(0));
    const channel1 = new Float32Array(item.buffer.getChannelData(1));

    item.buffer.copyToChannel(channel0, 1);
    item.buffer.copyToChannel(channel1, 0);

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function invert(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        const data = item.buffer.getChannelData(channel);
        for (let i = selection.start; i < selection.end; i++) {
            data[i] = -data[i];
        }
    }

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function nudgeCrossings(event, item, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel);
        for (let i = selection.start; i < selection.end; i++) {
            item.buffer.getChannelData(channel)[i] = data[i] === 0 ? 0.003 : data[i];
        }
    }
    item.meta = {...item.meta};
    if (selection.start === 0 && selection.end === item.buffer.length) {
        item.meta.slices = item.meta.slices ? item.meta.slices.map(slice => ({
            ...slice,
            n: slice.n, s: selection.end - slice.e,
            e: selection.end - slice.s
        })) : false;
    } else {
        //item.meta.slices = false;
    }

    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function trimRight(event, item, renderEditPanel = true, ampFloor = 0.003, trimLeft = false) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    if (event.shiftKey) {
        trimLeft = true;
    }

    let trimIndex = [];
    let trimLeftIndex = [0];
    let newBufferLength = item.buffer.length;

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        trimIndex.push(item.buffer.length);
        let data = item.buffer.getChannelData(channel);
        for (let i = item.buffer.length; i > 0; i--) {
            if (Math.abs(data[i]) > ampFloor && data[i] !== undefined &&
              data[i] !== null) {
                trimIndex[channel] = i + 1;
                break;
            }
        }
    }
    newBufferLength = +Math.max(...trimIndex);

    if (trimLeft) {
        for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
            let data = item.buffer.getChannelData(channel);
            for (let i = 0; i < newBufferLength; i++) {
                if (Math.abs(data[i]) > ampFloor && data[i] !== undefined &&
                  data[i] !== null) {
                    trimLeftIndex[channel] = i + 1;
                    break;
                }
            }
        }
        newBufferLength = newBufferLength - +Math.max(...trimLeftIndex);
    }

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      newBufferLength,
      conf.masterSR
    );
    let bufferOffset = +Math.max(...trimLeftIndex);
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        for (let i = 0; i < audioArrayBuffer.length; i++) {
            audioArrayBuffer.getChannelData(
              channel)[i] = item.buffer.getChannelData(channel)[i + bufferOffset];
        }
    }
    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices && item.meta.slices.length > 0) {
        item.meta.slices = false;
        //item.meta.slices[item.meta.slices.length - 1].e = item.buffer.length;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
        //renderEditPanelWaveform(multiplier);
    }
    item.waveform = false;
}

function thresholdCondense(event, item, renderEditPanel = true, lower = 0.003, upper = 1) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      item.buffer.length,
      conf.masterSR
    );

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let data = item.buffer.getChannelData(channel);
        let aabIndex = selection.start;
        for (let i = selection.start; i < item.buffer.length; i++) {
            const absValueLast = Math.abs(data[(i - 1 > 0 ? i - 1 : 0)]);
            const absValue = Math.abs(data[i]);
            const absValueNext = Math.abs(data[(i + 1 < item.buffer.length ? i + 1: item.buffer.length)]);
            if ((absValue > lower && absValue < upper) || absValueNext.toFixed(4) === 0|| absValueLast.toFixed(4) === 0) {
                audioArrayBuffer.getChannelData(channel)[aabIndex] = data[i] < 0 ? -absValue : absValue;
                aabIndex++;
            }
        }
    }
    item.buffer = audioArrayBuffer;

    trimRight(event, item, renderEditPanel, 0, false);
}

async function paulStretch(
  event, item, renderEditPanel = true, stretchFactor = 16, grainSize = .1, overlap = .5
) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const numberOfChannels = item.buffer.numberOfChannels;
    const sampleRate = item.buffer.sampleRate;
    const bufferDuration = item.buffer.duration;
    const grainSpacing = (grainSize * overlap) / stretchFactor;

    const newLength = Math.ceil(bufferDuration * stretchFactor);
    const newSamples = Math.ceil(newLength * sampleRate);

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      numberOfChannels,
      newSamples,
      conf.masterSR
    );

    let sourceOffset = 0;
    let targetOffset = 0;

    while (sourceOffset < bufferDuration) {
        const grainSamples = Math.floor(grainSize * sampleRate);
        const targetSamples = Math.min(grainSamples,
          (newSamples - targetOffset));

        for (let channel = 0; channel < numberOfChannels; channel++) {
            const inputData = item.buffer.getChannelData(channel);
            const outputData = audioArrayBuffer.getChannelData(channel);

            for (let i = 0; i < targetSamples; i++) {
                const sampleIndex = Math.floor((sourceOffset * sampleRate) + i);
                if (sampleIndex < inputData.length && (targetOffset + i) < newSamples) {
                    outputData[targetOffset + i] += inputData[sampleIndex] * 0.5;
                }
            }
        }

        sourceOffset += grainSpacing;
        targetOffset += targetSamples;
    }

    function applyEffects(buffer) {
        const offlineCtx = new OfflineAudioContext(
          buffer.numberOfChannels,
          buffer.length,
          buffer.sampleRate
        );

        const source = offlineCtx.createBufferSource();
        source.buffer = buffer;

        // Reverb Effect
        const convolver = offlineCtx.createConvolver();
        convolver.buffer = createReverbImpulse(offlineCtx);

        // Delay Effect
        const delay = offlineCtx.createDelay();
        delay.delayTime.value = 0.3; // 300ms delay

        const feedback = offlineCtx.createGain();
        feedback.gain.value = 0.4;
        delay.connect(feedback);
        feedback.connect(delay);

        // Gain (to balance levels)
        const gain = offlineCtx.createGain();
        gain.gain.value = 0.8;

        // Audio Routing
        source.connect(convolver);
        convolver.connect(delay);
        delay.connect(gain);
        gain.connect(offlineCtx.destination);

        source.start();
        return offlineCtx.startRendering();
    }

    function createReverbImpulse(audioCtx) {
        const length = audioCtx.sampleRate * 3;
        const impulse = audioCtx.createBuffer(2, length, audioCtx.sampleRate);
        for (let channel = 0; channel < 2; channel++) {
            let impulseData = impulse.getChannelData(channel);
            for (let i = 0; i < length; i++) {
                impulseData[i] = (Math.random() * 2 - 1) * (1 - i / length); // Exponential decay
            }
        }
        return impulse;
    }

    await applyEffects(audioArrayBuffer);

    item.buffer = audioArrayBuffer;

    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices && item.meta.slices.length > 0) {
        item.meta.slices[item.meta.slices.length - 1].e = item.buffer.length;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;
}

function roughStretch(event, item, renderEditPanel = true, stretchFactor = 2, addNStretch = false) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    let windowSize = 4 * conf.masterSR;
    windowSize = windowSize > item.buffer.length / 16 ?
        Math.floor(item.buffer.length / 16) : windowSize;

    let stepSize = Math.floor(windowSize / 4);

    let windowCount = Math.ceil(item.buffer.length / stepSize);

    let windows = [];
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        windows.push([]);
    }

    for (let win = 0; win < windowCount; win++) {
        for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
            const data = item.buffer.getChannelData(channel).slice(win * stepSize, (win * stepSize) + windowSize);
            let winData = new Float32Array(data.length);
            for (let w = 0; w < data.length; w++) {
                winData[w] = data[w];
                winData[w] = winData[w] > 1 ? 1: winData[w];
                winData[w] = winData[w] < -1 ? -1 : winData[w];
            }
            windows[channel].push(winData);
        }
    }

    const newLength = Math.round(item.buffer.length * stretchFactor);
    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      newLength,
      conf.masterSR
    );

    for (let winIdx = 0; winIdx < windowCount; winIdx++) {
        let startPos = winIdx * (windowSize/2);
        for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
            for (let i = 0; i < windows[channel][winIdx].length; i++) {
                if (!audioArrayBuffer.getChannelData(channel)[startPos + i]) {
                    audioArrayBuffer.getChannelData(channel)[startPos + i] = windows[channel][winIdx][i];
                } else {
                    audioArrayBuffer.getChannelData(channel)[startPos + i] = [startPos+i-2, startPos+i-1, startPos+i, startPos+i+1, startPos+i+2].reduce((acc, v) => acc + (audioArrayBuffer.getChannelData(channel)[v]??0 + windows[channel][winIdx][v]??0) , 0) / 5;
                }

            }
        }
    }

    if (addNStretch) {
        let regularStretchedBuffer = stretch(event, item, renderEditPanel, audioArrayBuffer.length, true);

        for (let channel = 0; channel < audioArrayBuffer.numberOfChannels; channel++) {
            for (let i = 0; i < audioArrayBuffer.length; i++) {
                audioArrayBuffer.getChannelData(channel)[i] = (audioArrayBuffer.getChannelData(channel)[i] + regularStretchedBuffer.getChannelData(channel)[i]) / 2;
            }

            const deClickedBuffer = deClick(audioArrayBuffer.getChannelData(channel), 0.4);
            audioArrayBuffer.copyToChannel(deClickedBuffer, channel);
        }
    } else {
        for (let channel = 0; channel < audioArrayBuffer.numberOfChannels; channel++) {
            const deClickedBuffer = deClick(audioArrayBuffer.getChannelData(channel), .4);
            audioArrayBuffer.copyToChannel(deClickedBuffer, channel);
        }
    }

    item.buffer = audioArrayBuffer;

    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices && item.meta.slices.length > 0) {
        item.meta.slices[item.meta.slices.length - 1].e = item.buffer.length;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;

    //normalize(event, item, renderEditPanel);
}

function perSamplePitch(
  event, pitchValue, pitchSteps, item, renderEditPanel = true, volumeAdjust = 1,
  bitDepthOverride) {
    (item || editing).meta.editing = true;
    if (event.shiftKey) {
        stretch(event, item, renderEditPanel,
          ((item || editing).buffer.length / pitchValue));
    } else {
        reSamplePitch(event, pitchValue, pitchSteps, item, renderEditPanel,
          volumeAdjust, bitDepthOverride);
    }
}

function stretch(event, item, renderEditPanel = true, targetLength, returnBufferOnly = false) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const originalLength = item.buffer.length;
    const factor = targetLength / originalLength;
    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      targetLength,
      conf.masterSR
    );

    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        for (let i = 0; i < targetLength; i++) {
            const index = i / factor;
            const lowerIndex = Math.floor(index);
            const upperIndex = Math.ceil(index);
            const interpolationFactor = index - lowerIndex;

            if (upperIndex >= originalLength) {
                audioArrayBuffer.getChannelData(
                  channel)[i] = item.buffer.getChannelData(channel)[lowerIndex];
            } else {
                audioArrayBuffer.getChannelData(channel)[i] =
                  (1 - interpolationFactor) *
                  item.buffer.getChannelData(channel)[lowerIndex] +
                  interpolationFactor *
                  item.buffer.getChannelData(channel)[upperIndex];
            }
        }
    }

    if (returnBufferOnly) {
        return audioArrayBuffer;
    }

    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        //opPitch: (item.meta.opPitch??0) + (512 * pitchSteps),
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length,
        note: false,
        editing: false,
        slices: item.meta.slices ? item.meta.slices.map(slice => ({
            ...slice,
            n: slice.n, s: Math.round(slice.s * factor),
            e: Math.round(slice.e * factor)
        })) : false
    };
    if (renderEditPanel) {
        renderEditPanelWaveform(multiplier);
        selection.end = Math.abs(Math.round(selection.end * factor));
        selection.start = Math.abs(Math.round(selection.start * factor));
        selection.step = item.buffer.length / (1024 * multiplier);
        updateSelectionEl();
        item.waveform = false;
    }

}

function truncate(event, item, renderEditPanel = true, lengthInSeconds = 3) {
    let duplicate;
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = conf.masterSR * lengthInSeconds;
    }
    item = item || editing;

    if (event.shiftKey && renderEditPanel) {
        duplicate = digichain.duplicate(event, item.meta.id, true);
        item = duplicate.item;
    }

    if (settings.attemptToFindCrossingPoint) {
        // match start and end sample values
        for (let i = (selection.start -
          Math.floor(((selection.start / 4) * 3))); i < selection.end; i++) {
            if (
              (item.buffer.getChannelData(0)[selection.end - i] ===
                selection.start) &&
              (item.buffer.numberOfChannels > 1 ? item.buffer.getChannelData(
                1)[selection.end - i] === selection.start : true)
            ) {
                selection.end = selection.end - i;
            }
        }
    }

    let truncIndex = selection.end - selection.start;

    if (truncIndex > item.buffer.length) {
        // don't need to truncate as sample is shorter than the trim length.
        return;
    }

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      truncIndex,
      conf.masterSR
    );
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let x = 0;
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(
              channel)[x] = item.buffer.getChannelData(channel)[i];
            x++;
        }
    }

    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices) {
        item.meta.slices = false;
    }
    digichain.removeMetaFile(item.meta.id);
    if (renderEditPanel && !duplicate) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;

    if (duplicate) {
        duplicate.editorCallback(item, duplicate.fileIdx);
        if (event.ctrlKey || event.metaKey) {
            showToastMessage(`Editing cropped duplicate, '${item.file.name}'`, 5000);
            showEditor(item, conf, 'sample', folders);
        } else {
            showToastMessage(`Cropped duplicate saved to list as, '${item.file.name}'`, 5000);
        }
    }
}

function double(event, item, reverse = false, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      item.buffer.length * 2,
      conf.masterSR
    );
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let x = 0;
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(
              channel)[x] = item.buffer.getChannelData(channel)[i];
            x++;
        }
        let data = item.buffer.getChannelData(channel).
          slice(selection.start, selection.end);
        if (reverse) {
            data = data.reverse();
        }
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(channel)[x] = data[i];
            x++;
        }

    }
    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices) {
        item.meta.slices = false;
    }
    if (item.meta.op1Json) {
        item.meta.op1Json = false;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;
}

function padWithZero(event, item, padLength = 0, renderEditPanel = true) {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      item.buffer.numberOfChannels,
      item.buffer.length + (padLength === 0 ? 2 : +padLength),
      conf.masterSR
    );
    for (let channel = 0; channel < item.buffer.numberOfChannels; channel++) {
        let x = 0;
        let data = item.buffer.getChannelData(channel).
          slice(selection.start, selection.end);
        audioArrayBuffer.getChannelData(channel)[x] = 0;
        x++;
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(channel)[x] = data[i];
            x++;
        }
        audioArrayBuffer.getChannelData(channel)[x] = 0;
    }
    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices) {
        item.meta.slices = false;
    }
    if (item.meta.op1Json) {
        item.meta.op1Json = false;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;
}

function deserialize(event, item, renderEditPanel = true, method = 'LR') {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = Math.floor(item.buffer.length / method.split('').length);
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      2,
      selection.end,
      conf.masterSR
    );

    let x = 0;
    method.split('').forEach((channel, idx) => {
        const buffer = item.buffer.getChannelData(0);
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(idx)[i] = buffer[x];
            x++;
        }
    });

    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices) {
        item.meta.slices = false;
    }
    if (item.meta.op1Json) {
        item.meta.op1Json = false;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;
}

function serialize(event, item, renderEditPanel = true, method = 'LR') {
    if (!renderEditPanel && item) {
        selection.start = 0;
        selection.end = item.buffer.length;
    }
    item = item || editing;

    const audioArrayBuffer = conf.audioCtx.createBuffer(
      1,
      item.buffer.length * method.split('').length,
      conf.masterSR
    );

    let x = 0;
    method.split('').forEach(channel => {
        const buffer = bufferToFloat32Array(item.buffer, channel);
        for (let i = selection.start; i < selection.end; i++) {
            audioArrayBuffer.getChannelData(0)[x] = buffer[i];
            x++;
        }
    });

    item.buffer = audioArrayBuffer;
    item.meta = {
        ...item.meta,
        length: audioArrayBuffer.length,
        duration: Number(audioArrayBuffer.length / conf.masterSR).toFixed(3),
        startFrame: 0, endFrame: audioArrayBuffer.length
    };
    if (item.meta.slices) {
        item.meta.slices = false;
    }
    if (item.meta.op1Json) {
        item.meta.op1Json = false;
    }
    if (renderEditPanel) {
        showEditor(editing, conf, 'sample', folders);
    }
    item.waveform = false;
}

function editorPlayFile(event, loop = false, stop = false) {
    let start = selection.start / conf.masterSR;
    let end = (selection.end / conf.masterSR) - start;
    start = start < 0 ? 0 : start;
    end = end > editing.buffer.length ? editing.buffer.length : end;
    clearTimeout(editorPlayFile.nextLoop);
    if (stop || !editPanelEl.open) {
        digichain.stopPlayFile(event, editing.meta.id);
        return;
    }
    digichain.playFile({editor: true, file: editing}, editing.meta.id, false, start, end);
    if (loop) {
        editorPlayFile.nextLoop = setTimeout(() => editorPlayFile(event, loop),
          end * 1000);
    }
}

function changeSelectedFile(event, direction = 1) {
    const newSelected = document.querySelector('#fileList tr.selected')?.[direction === 1 ? 'nextElementSibling' : 'previousElementSibling'];
    if (newSelected && newSelected.tagName === 'TR') {
        digichain.handleRowClick({}, newSelected.dataset.id);
        digichain.showEditPanel({}, newSelected.dataset.id);
    }
}

export function sanitizeFileName(value = '') {
    return xyRxp(value.replace(/\.[^.]*$/, ''));
}

function sanitizeName(event, files = [], selected = [], restore = false) {
    let nameList = {};
    let nameListArr = [];
    if (!restore) {
        nameList = {};
        nameListArr = files.map(f => {
            nameList[f.meta.id] = {
                path: f.file.path.split('/').
                  map(p => xyRxp(p)).
                  join('/'),
                name: xyRxp(f.file.name.replace(/\.[^.]*$/, '')) +
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
}

export const editor = {
    updateFile,
    changeSelectedFile,
    toggleReadOnlyInput,
    togglePitchSemitoneCents,
    zoomLevel,
    changeSelectionPoint,
    resetSelectionPoints,
    setSelStart,
    editorPlayFile,
    adjustGain,
    normalize,
    fade,
    trimRight,
    thresholdCondense,
    truncate,
    interpolate,
    perSamplePitch,
    double,
    stretch,
    paulStretch,
    roughStretch,
    nudgeCrossings,
    padWithZero,
    buildOpKit,
    buildXyKit,
    dropOpKey,
    opKeySelected,
    editOpSlice,
    changeOpParam,
    removeOpKeyData,
    renderOpExport,
    toggleOpExportSetting,
    acceptDroppedChainItems,
    sliceUpdate,
    sliceCreate,
    sliceRemove,
    sliceSelect,
    toggleSnapToZero,
    detectBpm,
    changeChannel,
    getLastItem: () => editing?.meta?.id,
    reverse,
    shift,
    invert,
    flipChannels,
    serialize,
    deserialize,
    sanitizeName
};

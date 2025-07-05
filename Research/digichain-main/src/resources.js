/*!
DigiChain v1.4.17-latest [ https://digichain.brianbar.net/ ]
<https://github.com/brian3kb/digichain>

(c) 2023 Brian Barnett <me [at] brianbar.net>
[ @brian3kb ]
Licensed under AGPLv3 <https://github.com/brian3kb/digichain/blob/main/LICENSE>

DigiChain bundled resources:
[MIT license] JSZip  : <https://github.com/Stuk/jszip/blob/main/LICENSE.markdown>
[MIT license] Pako : <https://github.com/nodeca/pako/blob/main/LICENSE>
[MIT license] msgpack-lite : <https://github.com/kawanet/msgpack-lite>
[MIT license] Modified version of Audiobuffer-to-wav : <https://github.com/Experience-Monks/audiobuffer-to-wav/blob/master/LICENSE.md>
[MIT license] Modified version of Audiobuffer-to-aiff : <https://github.com/hunjunior/audiobuffer-to-aiff/blob/master/LICENSE>

Brian referenced the following during development:
[BSD-3] MIDI-SDS, for how the Machine Drum stores audio data in syx files : <https://github.com/eh2k/uwedit/blob/master/core/MidiSDS.cpp> / <https://github.com/eh2k/uwedit/blob/master/LICENSE.txt>
[Unlicense] OctaChainer, how to read/write .ot binary files correctly : <https://github.com/KaiDrange/OctaChainer/blob/master/otwriter.cpp> / <https://github.com/KaiDrange/OctaChainer/blob/master/License.txt>
Tips and Tricks on drawing array buffers to the canvas element: <https://css-tricks.com/making-an-audio-waveform-visualizer-with-vanilla-javascript/>
[MIT License] Basic beat detection : https://github.com/JMPerez/beats-audio-api/blob/gh-pages/script.js / http://joesul.li/van/beat-detection-using-web-audio/
*/
import {settings} from './settings.js';

export const opToXyValues = {
    pan: () => 0,
    playmode: value => {
        switch (value) {
            case 4096:
                return 'gate';
            case 20480:
                return 'group';
            case 28672:
                return 'loop';
            case 12288:
            default:
                return 'oneshot';
        }
    },
    reverse: value => value === 24576,
    volume: () => 0,
    pitch: value => (value || value !== 0 ? Math.round((value / 512) / 12) : 0) || 0,
};

/* check the last 256 samples per slice to nudge to a zero crossing*/
const nudgeEndToZero = (start, end, buffer, seekRegion = 256) => {
    if (!buffer) {
        return end;
    }
    const isStereo = buffer.numberOfChannels > 1;
    let firstZeroCrossingLeft, lastZeroCrossingLeft;
    for (let i = (end ?? buffer.length); buffer.length > i; i--) {
        if (i < start || i < (end - seekRegion)) {
            return end;
        }
        if (+buffer.getChannelData(0)[i].toFixed(4) === 0 || i === 0) {
            if (isStereo === false){
                return i;
            }
            firstZeroCrossingLeft = firstZeroCrossingLeft || i;
            lastZeroCrossingLeft = i;

        }
        if (isStereo && +buffer.getChannelData(1)[i].toFixed(4) === 0 || i === 0) {
            if (lastZeroCrossingLeft === i) {
                return i;
            }
        }
    }
    return firstZeroCrossingLeft || end;
};

export function buildOpData(slices = [], numChannels, audioBuffer = false, returnTemplate = false) {
    const template = slices?.length ? {
        attack: new Array(24).fill(0),
        drum_version: 2,
        dyna_env: [0, 8192, 0, 8192, 0, 0, 0, 0],
        end: new Array(24).fill(0),
        fx_active: false,
        fx_params: [8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000],
        fx_type: 'delay',
        lfo_active: false,
        lfo_params: [16000, 16000, 16000, 16000, 0, 0, 0, 0],
        lfo_type: 'tremolo',
        mtime: 1682173750,
        name: 'DigiChain Kit',
        octave: 0,
        original_folder: 'DigiChain',
        pan: new Array(24).fill(16384),
        pan_ab: new Array(24).fill(false),
        pitch: new Array(24).fill(0),
        playmode: new Array(24).fill(12288), /*4096 = ->, 12288 = ->|, 20480 = ->G, 28672 = loop */
        reverse: new Array(24).fill(8192), /*8192 = ->, 24576 = <- */
        start: new Array(24).fill(0),
        stereo: numChannels === 2,
        type: 'drum',
        volume: new Array(24).fill(8192)
    } : {
        adsr: [64, 10746, 32767, 10000, 4000, 64, 4000, 18021],
        base_freq: 440,
        fade: 0,
        fx_active: false,
        fx_params: [8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000],
        fx_type: 'delay',
        knobs: [0, 0, 0, 8600, 12000, 0, 0, 8192],
        lfo_active: false,
        lfo_params: [16000, 0, 0, 16000, 0, 0, 0, 0],
        lfo_type: 'tremolo',
        mtime: 1683144375,
        name: 'DigiChain Sample',
        octave: 0,
        original_folder: 'DigiChain',
        stereo: numChannels === 2,
        synth_version: 3,
        type: 'sampler'
    };
    if (returnTemplate) { return template; }
    const opData = JSON.parse(JSON.stringify(template));
    if (!slices?.length || slices?.length === 0) {
        return opData; /*Return single synth sampler template*/
    }

    const scale = 2147483646 / (44100 * (numChannels === 2 ? 20 : 12));
    const s = slices.map(slice => ({
        p: slice.p??16384,
        pab: slice.pab || false,
        st: (slice.st > 24576 ? 24576 : (slice.st < -24576 ? -24576 : slice.st)) || 0,
        pm: slice.pm??12288,
        r: slice.r??8192,
        s: Math.floor(slice.s * scale),
        e: Math.floor(nudgeEndToZero(slice.s, slice.e, audioBuffer) * scale)
    }));

    for (let idx = 0; idx < 24; idx++) {
        let slice = s.shift();
        opData.pan[idx] = slice.p;
        opData.pan_ab[idx] = slice.pab;
        opData.pitch[idx] = slice.st;
        opData.playmode[idx] = slice.pm;
        opData.reverse[idx] = slice.r;
        opData.start[idx] = slice.s;
        opData.end[idx] = slice.e;
        s.push(slice);
    }
    return opData;
}

export function buildXyRegionFromSlice(slice, index) {
    return {
        'fade.in': 0,
        'fade.out': 0,
        'framecount': slice.fc || (slice.e - slice.s),
        'gain': 0,
        'hikey': 53 + index,
        'lokey': 53 + index,
        'pan': opToXyValues.pan(slice.p),
        'pitch.keycenter': 60,
        'playmode': opToXyValues.playmode(slice.pm),
        'reverse': opToXyValues.reverse(slice.r),
        'sample': `${slice.name || 'slice_' + (index + 1)}.wav`,
        'sample.end': slice.e,
        'sample.start': slice.s || 0,
        'transpose': opToXyValues.pitch(slice.st),
        'tune': 0
    };
}

export function buildXyDrumPatchData(file, slices = []) {
    const _slices = slices.map(slice => ({
        ...slice,
        fc: slice.fc || (slice.e - slice .s),
        e: nudgeEndToZero(slice.s, slice.e, slice.buffer || file.buffer),
        name: (file.buffer ? file.kitName : slice.name)??''
    }));
    const modulationDefault = () => ({'amount': 16384, 'target': 0});
    const template = {
        'engine': {
            'bendrange': 8191,
            'highpass': 0,
            'modulation': {
                'aftertouch': modulationDefault(),
                'modwheel': modulationDefault(),
                'pitchbend': modulationDefault(),
                'velocity': modulationDefault()
            },
            'params': Array.from({length: 8}).fill(16384),
            'playmode': 'poly',
            'portamento.amount': 0,
            'portamento.type': 32767,
            'transpose': 0,
            'tuning.root': 0,
            'tuning.scale': 0,
            'velocity.sensitivity': 19660,
            'volume': 28505,
            'width': 0
        },
        'envelope': {
            'amp': {
                'attack': 0,
                'decay': 0,
                'release': 32767,
                'sustain': 32604
            },
            'filter': {
                'attack': 0,
                'decay': 0,
                'release': 32767,
                'sustain': 32767
            }
        },
        'fx': {
            'active': false,
            'params': [22014, 0, 4423, 0, 0, 32767, 0, 0],
            'type': 'z lowpass'
        },
        'lfo': {
            'active': false,
            'params': [14848, 16384, 19000, 16384, 0, 0, 0, 0],
            'type': 'tremolo'
        },
        'octave': 0,
        'platform': 'OP-XY',
        'regions': _slices.map(buildXyRegionFromSlice),
        "type": "drum",
        "version": 4
    };
    return template;
}

function buildXyMultiSamplerRegionFromSlice(slice, index) {
    return {
        'framecount': slice.fc,
        'hikey': slice.hk, /* 0 - 92*/
        'lokey': 0,
        'loop.crossfade': 0,
        'loop.end': slice.fc,
        'loop.onrelease': false,
        'loop.start': 0,
        'pitch.keycenter': slice.pkc || slice.hk,
        'reverse': false,
        'sample': `${slice.name || 'slice_' + (index + 1)}.wav`,
        'sample.end': slice.e,
        'sample.start': slice.s || 0,
        'tune': 0
    };
}

export function buildXyMultiSamplePatchData(file, slices = []) {
    return {
        'engine': {
            'bendrange': 13653,
            'highpass': 1638,
            'modulation': {
                'aftertouch': { 'amount': 16383, 'target': 0 },
                'modwheel': { 'amount': 16383, 'target': 0 },
                'pitchbend': { 'amount': 16383, 'target': 0 },
                'velocity': { 'amount': 32767, 'target': 17694 }
            },
            'params': [16384, 16384, 16384, 16384, 16384, 16384, 16384, 16384],
            'playmode': 'poly',
            'portamento.amount': 128,
            'portamento.type': 32767,
            'transpose': 0,
            'tuning.root': 0,
            'tuning.scale': 0,
            'velocity.sensitivity': 26540,
            'volume': 21295,
            'width': 0
        },
        'envelope': {
            'amp': { 'attack': 0, 'decay': 32767, 'release': 3276, 'sustain': 32767 },
            'filter': { 'attack': 0, 'decay': 0, 'release': 3276, 'sustain': 32767 }
        },
        'fx': {
            'active': false,
            'params': [12697, 3440, 163, 0, 0, 32767, 0, 0],
            'type': 'svf'
        },
        'lfo': {
            'active': false,
            'params': [23095, 16384, 15889, 16000, 0, 0, 0, 0],
            'type': 'tremolo'
        },
        'octave': 0,
        'platform': 'OP-XY',
        'regions': slices.sort((a, b) => a.hk - b.hk).map(buildXyMultiSamplerRegionFromSlice),
        'type': 'multisampler',
        'version': 4
    };

}

export function showToastMessage(messageString, duration = 3000) {
    const attachToEl = [...document.querySelectorAll('dialog')].find(d => d.open) || document.body;
    const toast = document.createElement('div');
    const existingToast = attachToEl.querySelectorAll('.toast');
    if (existingToast.length > 0) {
        existingToast.forEach(et => et.classList.add('fadeOutUp'));
    }
    toast.classList.add('toast');
    toast.classList.add('fadeInDown');
    toast.innerHTML = messageString;
    attachToEl.appendChild(toast);
    setTimeout(() => {
        setTimeout(() => toast.remove(), 500);
        toast.classList.add('fadeOutUp');
    }, duration);
}

export async function dcDialog(type = 'message', messageString = '', config = {}) {
    const msgTypes = {message: 'alert', ask: 'prompt', confirm: 'confirm', prompt: 'prompt'};

    if (type === 'prompt' || type === 'confirm' || type === 'alert') {
        return await new Promise(resolve => {
            const dcDialogEl = document.querySelector('#dcDialog');

            dcDialogEl.innerHTML = `
                <div class="content">
                    <div class="prompt">${messageString}</div>
                    <input
                        style="display: ${type === 'prompt' ? 'block' : 'none'};"
                        type="${config.inputType??'text'}"
                        class="prompt-input"
                        value="${config.defaultValue??''}"
                    >
                    <div class="buttons-group">
                        <button type="submit" class="prompt-ok">${config.okLabel??'OK'}</button>` +
              (config.centerLabel ? `<button class="prompt-center button-outline" style="margin-left: 2rem;">${config.centerLabel}</button>` : '') +
                        `<button class="prompt-cancel button-outline ${type === 'alert' ? 'hidden' : ''}">${config.cancelLabel??'Cancel'}</button>
                    </div>
                </div>
            `;

            const promptInputEl = document.querySelector('#dcDialog .content .prompt-input');
            const promptCancelEl = document.querySelector('#dcDialog .content .prompt-cancel');
            const promptCenterEl = document.querySelector('#dcDialog .content .prompt-center');
            const promptOkEl = document.querySelector('#dcDialog .content .prompt-ok');

            promptCancelEl.onclick = () => {
                resolve(config.defaultValue??false);
                dcDialogEl.close();
            };
            promptOkEl.onclick = () => {
                resolve(type === 'prompt' ? (promptInputEl.value||'') : true);
                dcDialogEl.close();
            };

            if (promptCenterEl) {
                promptCenterEl.onclick = () => {
                    resolve(type === 'prompt' ? (promptInputEl.value||'') : 'center');
                    dcDialogEl.close();
                };
            }

            dcDialogEl.onkeydown = dcDialogEvent => {
                if (dcDialogEvent.code === 'Escape') {
                    return promptCancelEl.click();
                }
                if (dcDialogEvent.code === 'Enter') {
                    setTimeout(() => promptOkEl.click(), 100);
                }
            };

            if (!dcDialogEl.open) {
                dcDialogEl.showModal();
                setTimeout(() => type !== 'prompt' ? dcDialogEl.focus() : (() => {
                    promptInputEl.select();
                    promptInputEl.focus();
                })(), 50);
            }
        });
    }

    if (window.__TAURI__) {
        return await window.__TAURI__.dialog[type](messageString, config);
    }
    return await window[msgTypes[type]](messageString);
}

export function flattenFile(f, cloneProperties) {
    return {
        file: cloneProperties ? structuredClone(f.file) : f.file,
        meta: cloneProperties ? structuredClone(f.meta) : f.meta,
        buffer: {
            duration: f.buffer.duration,
            length: f.buffer.length,
            numberOfChannels: f.buffer.numberOfChannels,
            sampleRate: f.buffer.sampleRate,
            channel0: new Float32Array(f.buffer.getChannelData(0)),
            channel1: f.buffer.numberOfChannels > 1 ? new Float32Array(f.buffer.getChannelData(1)) : false
        }
    };
}

export function bufferToFloat32Array(
  buffer, channel, getAudioBuffer = false, audioCtx, masterChannels, masterSR) {
    let result = getAudioBuffer ?
      audioCtx.createBuffer(
        masterChannels,
        buffer.length,
        masterSR
      ) : new Float32Array(buffer.length);

    if (channel === 'S' && buffer.numberOfChannels > 1) {
        for (let i = 0; i < buffer.length; i++) {
            (getAudioBuffer
              ? result.getChannelData(0)
              : result)[i] = (buffer.getChannelData(0)[i] +
              buffer.getChannelData(1)[i]) / 2;
        }
    } else if (channel === 'D' && buffer.numberOfChannels > 1) {
        for (let i = 0; i < buffer.length; i++) {
            (getAudioBuffer
              ? result.getChannelData(0)
              : result)[i] = (buffer.getChannelData(0)[i] -
              buffer.getChannelData(1)[i]) / 2;
        }
    } else {
        const _channel = channel === 'R' && buffer.numberOfChannels > 1 ? 1 : 0;
        for (let i = 0; i < buffer.length; i++) {
            (getAudioBuffer
              ? result.getChannelData(0)
              : result)[i] = buffer.getChannelData(_channel)[i];
        }
    }
    return result;
}

export function joinToMono(audioArrayBuffer, _files, largest, pad, reverseEvenSamplesInChains) {
    let totalWrite = 0;
    _files.forEach((file, idx) => {
        const bufferLength = pad ? largest : file.buffer.length;

        let result = bufferToFloat32Array(file.buffer,
          file?.meta?.channel);

        if (reverseEvenSamplesInChains && (idx + 1) % 2 === 0) {
            for (let i = 0; i < bufferLength; i++) {
                audioArrayBuffer.getChannelData(0)[totalWrite] = result[bufferLength - i] || 0;
                totalWrite++;
            }
        } else {
            for (let i = 0; i < bufferLength; i++) {
                audioArrayBuffer.getChannelData(0)[totalWrite] = result[i] || 0;
                totalWrite++;
            }
        }
    });
}

export function joinToStereo(audioArrayBuffer, _files, largest, pad, reverseEvenSamplesInChains) {
    let totalWrite = 0;
    _files.forEach((file, idx) => {
        const bufferLength = pad ? largest : file.buffer.length;
        let result = [
            new Float32Array(file.buffer.length),
            new Float32Array(file.buffer.length)];

        for (let i = 0; i < file.buffer.length; i++) {
            result[0][i] = file.buffer.getChannelData(0)[i];
            result[1][i] = file.buffer.getChannelData(
              file.buffer.numberOfChannels === 2 ? 1 : 0)[i];
        }

        if (reverseEvenSamplesInChains && (idx + 1) % 2 === 0) {
            for (let i = 0; i < bufferLength; i++) {
                audioArrayBuffer.getChannelData(0)[totalWrite] = result[0][bufferLength - i] || 0;
                audioArrayBuffer.getChannelData(1)[totalWrite] = result[1][bufferLength - i] || 0;
                totalWrite++;
            }
        } else {
            for (let i = 0; i < bufferLength; i++) {
                audioArrayBuffer.getChannelData(0)[totalWrite] = result[0][i] || 0;
                audioArrayBuffer.getChannelData(1)[totalWrite] = result[1][i] || 0;
                totalWrite++;
            }
        }
    });
}

export function encodeOt(slices, bufferLength, tempo = 120, optional = {}) {
    const dv = new DataView(new ArrayBuffer(0x340));
    const header = [
          0x46,
          0x4F,
          0x52,
          0x4D,
          0x00,
          0x00,
          0x00,
          0x00,
          0x44,
          0x50,
          0x53,
          0x31,
          0x53,
          0x4D,
          0x50,
          0x41,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x02,
          0x00
    ];
    const bpm = tempo * 6 * 4;
    const samplesLength = bufferLength;

    const bars = +((samplesLength / 44100) / ((60 / tempo) * 4)).toFixed(2);
    const loopBars = +(((samplesLength - (optional.loopStart??0)) / 44100) / ((60 / tempo) * 4)).toFixed(2);

    header.forEach((x, i) => dv.setUint8(i, x));
    dv.setUint32(0x17, bpm);
    dv.setUint32(0x1B, bars * 100); // trim length
    dv.setUint32(0x1F, loopBars * 100); // loop length
    dv.setUint32(0x23, optional.stretch??0); // time stretch off/on/beat 0/2/3
    dv.setUint32(0x27, optional.loop??0); // loop off/on/ping-pong 0/1/2
    dv.setUint16(0x2B, 0x30); // gain
    dv.setUint8(0x2D, 0xFF); // quantize
    dv.setUint32(0x2E, 0); // trim start
    dv.setUint32(0x32, samplesLength); // trim end
    dv.setUint32(0x36, optional.loopStart??0); // loop start

    let offset = 0x3A;
    for (let i = 0; i < 64; i++) {
        dv.setUint32(offset, slices[i]?.s ?? 0);
        dv.setUint32(offset + 4, slices[i]?.e ?? 0);
        dv.setUint32(offset + 8, slices[i]?.l ?? -1);
        offset += 12;
    }

    dv.setUint32(0x33A, slices.length); // slice count
    let checksum = 0;
    for (let i = 0x10; i < dv.byteLength; i++) {
        checksum += dv.getUint8(i);
    }

    dv.setUint16(0x33E, checksum);

    return dv;
}

export function deClick(audioArray, threshold) {
    const bufferLength = audioArray.length;
    if (!threshold || threshold === 0) {
        return audioArray;
    }
    const _threshold = +threshold;
    for (let i = 1; i < bufferLength - 1; i++) {
        const average = (audioArray[i - 1] + audioArray[i + 1]) / 2;
        if (Math.abs(audioArray[i] - average) > _threshold) {
            audioArray[i] = average;
        }
    }
    return audioArray;
}

export function getResampleIfNeeded(meta, buffer, sampleRate) {
    const targetSR = meta.renderAt || sampleRate;
    const targetAudioCtx = new AudioContext(
      {sampleRate: targetSR, latencyHint: 'interactive'});
    return digichain.bufferRateResampler({
        file: {sampleRate: targetSR},
        meta,
        buffer
    }, targetSR, targetAudioCtx);
}

export function audioBufferToWav(
  buffer, meta, sampleRate, bitDepth, masterNumChannels,
  deClickThreshold = false, renderAsAif = false, pitchModifier = 1,
  embedSliceData = false, embedCuePoints = true, embedOrslData = false) {
    const treatDualMonoStereoAsMono = settings.treatDualMonoStereoAsMono &&
      !meta.editing && !meta.bypassStereoAsDualMono;

    let resample;
    if (!meta.editing && meta.renderAt) {
        resample = getResampleIfNeeded(meta, buffer, sampleRate);
        sampleRate = resample.buffer.sampleRate;
        meta = resample.meta;
        buffer = resample.buffer;
    }

    let numChannels = buffer.numberOfChannels;
    let format = (meta?.float32 || bitDepth === 32) ? 3 : 1;
    sampleRate = sampleRate * pitchModifier;

    let result;
    if (meta.channel && masterNumChannels === 1) {
        numChannels = 1;
        if (meta.channel === 'L') { result = buffer.getChannelData(0); }
        if (meta.channel === 'R') { result = buffer.getChannelData(1); }
        if (meta.channel === 'S') {
            result = new Float32Array(buffer.length);
            for (let i = 0; i < buffer.length; i++) {
                result[i] = (buffer.getChannelData(0)[i] +
                  buffer.getChannelData(1)[i]) / 2;
            }
        }
        if (meta.channel === 'D') {
            result = new Float32Array(buffer.length);
            for (let i = 0; i < buffer.length; i++) {
                result[i] = (buffer.getChannelData(0)[i] -
                  buffer.getChannelData(1)[i]) / 2;
            }
        }
        result = deClick(result, deClickThreshold);
    } else {
        if (numChannels === 2 &&
          !(meta.dualMono && treatDualMonoStereoAsMono)) {
            //result = interleave(buffer.getChannelData(0), buffer.getChannelData(1));
            result = interleave(
              deClick(buffer.getChannelData(0), deClickThreshold),
              deClick(buffer.getChannelData(1), deClickThreshold));
        } else {
            numChannels = 1;
            result = deClick(buffer.getChannelData(0), deClickThreshold);
        }
    }

    return renderAsAif ?
      encodeAif(
        result, sampleRate, numChannels,
        buildOpData(meta?.slices, numChannels, buffer)
      ) :
      encodeWAV(
        result, format, sampleRate, numChannels, bitDepth, buffer.length,
        meta?.slices, pitchModifier, embedSliceData, embedCuePoints, embedOrslData
      );
}

DataView.prototype.setInt24 = function(pos, val, littleEndian) {
    this.setInt8(pos, val & ~4294967040, littleEndian);
    this.setInt16(pos + 1, val >> 8, littleEndian);
};

export function encodeWAV(
  samples, format, sampleRate, numChannels, bitDepth, inputBufferLength, slices, pitchModifier = 1,
  embedSliceData = false, embedCuePoints = true, embedOrslData = false) {

    const hasSlices = slices &&
      Array.isArray(slices) &&
      slices.length !== 0 &&
      (
        slices.length > 1 ||
        (slices.length === 1 && (slices[0].s !== 0 || slices[0].e < inputBufferLength))
      );

    let bytesPerSample = bitDepth / 8;
    let blockAlign = numChannels * bytesPerSample;
    let sliceData = [];
    let buffer;
    let riffSize = 36 + samples.length * bytesPerSample;
    let bufferLength = 44 + samples.length * bytesPerSample;
    let sliceCueLength = 0;
    let sliceOrslLength = 0;

    let _slices = hasSlices ? (pitchModifier === 1 ? slices : slices.map(
      slice => ({
          n: slice.n, s: Math.round(slice.s / pitchModifier),
          e: Math.round(slice.e / pitchModifier),
          l: (!slice.l || slice.l === -1) ? -1 : Math.round(
            slice.l / pitchModifier)
      }))) : [];

    if (hasSlices) {
        if (embedSliceData) {
            sliceData = `{"sr": ${sampleRate}, "dcs":` +
              JSON.stringify(_slices) + '}';
            sliceData = btoa(sliceData);
            sliceData = sliceData.padEnd(
              sliceData.length + sliceData.length % 4, ' ');
            bufferLength += (sliceData.length + 12);
            riffSize += (sliceData.length + 12);
        }
        if (embedCuePoints) {
            sliceCueLength = (12 + (24 * slices.length));
            bufferLength += sliceCueLength;
            riffSize += sliceCueLength;
        }
        /*if (embedOrslData && (sampleRate === 12000 || sampleRate === 24000)) {
            sliceOrslLength = (12 + (32 * slices.length));
            bufferLength += sliceOrslLength;
            riffSize += sliceOrslLength;
        }*/
    }

    buffer = new ArrayBuffer(bufferLength);
    let view = new DataView(buffer);

    /* RIFF identifier */
    writeString(view, 0, 'RIFF');
    /* RIFF chunk length */
    view.setUint32(4, riffSize, true);
    /* RIFF type */
    writeString(view, 8, 'WAVE');
    /* format chunk identifier */
    writeString(view, 12, 'fmt ');
    /* format chunk length */
    view.setUint32(16, 16, true);
    /* sample format (raw) */
    view.setUint16(20, format, true);
    /* channel count */
    view.setUint16(22, numChannels, true);
    /* sample rate */
    view.setUint32(24, sampleRate, true);
    /* byte rate (sample rate * block align) */
    view.setUint32(28, sampleRate * blockAlign, true);
    /* block align (channel count * bytes per sample) */
    view.setUint16(32, blockAlign, true);
    /* bits per sample */
    view.setUint16(34, bitDepth, true);
    /* data chunk identifier */
    writeString(view, 36, 'data');
    /* data chunk length */
    view.setUint32(40, samples.length * bytesPerSample, true);
    if (bitDepth === 16) { // Raw PCM
        floatTo16BitPCM(view, 44, samples);
    } else if (bitDepth === 24) {
        floatTo24BitPCM(view, 44, samples);
    } else if (bitDepth === 8) {
        floatTo8BitPCM(view, 44, samples);
    } else {
        writeFloat32(view, 44, samples);
    }
    if (hasSlices) {
        if (embedSliceData) {
            /*Store DCSD as LIST chunk header to keep wav format valid*/
            writeString(view,
              view.byteLength - (sliceData.length + 12) - sliceCueLength,
              'LIST');
            /*LIST DCSD custom chunk size*/
            view.setUint32(
              view.byteLength - (sliceData.length + 8) - sliceCueLength,
              sliceData.length + 4,
              true);
            /*Using ISBJ as the LIST type ID : Description of the contents of the file (subject)*/
            writeString(view,
              view.byteLength - (sliceData.length + 4) - sliceCueLength,
              'ISBJ');
            /*DCSD custom chunk data*/
            writeString(view,
              view.byteLength - sliceData.length - sliceCueLength,
              sliceData);
        }
        if (embedCuePoints) {
            writeString(view, view.byteLength - sliceCueLength, 'cue ');
            view.setUint32(view.byteLength - sliceCueLength + 4,
              sliceCueLength - 8,
              true);
            view.setUint32(view.byteLength - sliceCueLength + 8, slices.length,
              true);

            for (let sIdx = 0; sIdx < slices.length; sIdx++) {
                const increment = 12 + (sIdx * 24);
                /*Cue id*/
                view.setUint32(view.byteLength - sliceCueLength + increment,
                  sIdx,
                  true);
                /*Cue position*/
                view.setUint32(view.byteLength - sliceCueLength + increment + 4,
                  0,
                  true);
                /*Cue data chunk sig*/
                writeString(view,
                  view.byteLength - sliceCueLength + increment + 8,
                  'data');
                /*Cue chunk start zero value*/
                view.setUint32(
                  view.byteLength - sliceCueLength + increment + 12, 0,
                  true);
                /*Cue block start zero value*/
                view.setUint32(
                  view.byteLength - sliceCueLength + increment + 16, 0,
                  true);
                /*Cue point sample start position*/
                view.setUint32(
                  view.byteLength - sliceCueLength + increment + 20,
                  _slices[sIdx].s, true);
            }
        }
        /*if (embedOrslData && (sampleRate === 12000 || sampleRate === 24000)) {
            writeString(view, view.byteLength - sliceOrslLength, 'ORSL');
            // Chunk size
            view.setUint32(view.byteLength - sliceOrslLength + 4, (slices.length * 32) + 4, true);
            // Slice count
            view.setUint32(view.byteLength - sliceOrslLength + 8, slices.length, true);

            for (let sIdx = 0; sIdx < slices.length; sIdx++) {
                const increment = 12 + (sIdx * 32);
                // Slice number
                view.setUint32(view.byteLength - sliceOrslLength + increment,
                  sIdx,
                  true);
                // Start point
                view.setUint32(view.byteLength - sliceOrslLength + increment + 4,
                  _slices[sIdx].s,
                  true);
                // End point
                view.setUint32(view.byteLength - sliceOrslLength + increment + 8,
                  _slices[sIdx].e,
                  true);
                // Level default of 100
                view.setUint32(view.byteLength - sliceOrslLength + increment + 12,
                  100,
                  true);
            }
        }*/
    }

    return {
        buffer,
        sampleRate,
        slices: slices && _slices ? slices.map((s, sIdx) => ({
            ...s,
            ...(_slices[sIdx] || {})
        })) : []
    };
}

export function getAifSampleRate(input) {
    const sampleRateTable = {
        8000: [64, 11, 250, 0, 0, 0, 0, 0, 0, 0],
        11025: [64, 12, 172, 68, 0, 0, 0, 0, 0, 0],
        16000: [64, 12, 250, 0, 0, 0, 0, 0, 0, 0],
        22050: [64, 13, 172, 68, 0, 0, 0, 0, 0, 0],
        32000: [64, 13, 250, 0, 0, 0, 0, 0, 0, 0],
        37800: [64, 14, 147, 168, 0, 0, 0, 0, 0, 0],
        44056: [64, 14, 172, 24, 0, 0, 0, 0, 0, 0],
        44100: [64, 14, 172, 68, 0, 0, 0, 0, 0, 0],
        47250: [64, 14, 184, 146, 0, 0, 0, 0, 0, 0],
        48000: [64, 14, 187, 128, 0, 0, 0, 0, 0, 0],
        50000: [64, 14, 195, 80, 0, 0, 0, 0, 0, 0],
        50400: [64, 14, 196, 224, 0, 0, 0, 0, 0, 0],
        88200: [64, 15, 172, 68, 0, 0, 0, 0, 0, 0],
        96000: [64, 15, 187, 128, 0, 0, 0, 0, 0, 0],
        176400: [64, 16, 172, 68, 0, 0, 0, 0, 0, 0],
        192000: [64, 16, 187, 128, 0, 0, 0, 0, 0, 0],
        352800: [64, 17, 172, 68, 0, 0, 0, 0, 0, 0],
        2822400: [64, 20, 172, 68, 0, 0, 0, 0, 0, 0],
        5644800: [64, 21, 172, 68, 0, 0, 0, 0, 0, 0]
    };
    if (typeof input === 'number') {
        return sampleRateTable[input] ?? false;
    }
    if (Array.isArray(input) && input.length === 10) {
        for (let sr in sampleRateTable) {
            if (sampleRateTable[sr].every((v, i) => v === input[i])) {
                return +sr;
            }
        }
    }
}

function addSampleRateToAiffData(view, offset, sr = 44100) {
    const sampleRate = getAifSampleRate(sr);
    for (let i = 0; i < 10; i++) {
        view.setUint8(offset + i, sampleRate[i]);
    }
}

export function encodeAif(audioData, sampleRate, numberOfChannels, opJsonData) {
    let jsonData = JSON.parse(JSON.stringify(opJsonData));
    jsonData.stereo = numberOfChannels === 2;

    function audioBufferToAiff(buffer) {
        const numChannels = buffer.numberOfChannels;
        const sampleRate = buffer.sampleRate;

        let result;
        if (numChannels === 2) {
            result = interleave(buffer.getChannelData(0),
              buffer.getChannelData(1));
        } else {
            result = buffer.getChannelData(0);
        }

        return encodeAIFF(result, sampleRate, numChannels);
    }

    function encodeAIFF(samples, sampleRate, numChannels) {
        let numBytesPerSample = 2;
        let totalNumAudioSampleBytes = samples.length * numBytesPerSample;
        let soundDataChunkSize = totalNumAudioSampleBytes + 8;
        let fileSizeInBytes = 0x1042 + totalNumAudioSampleBytes - 8;

        let buffer = new ArrayBuffer(
          0x1042 + samples.length * numBytesPerSample);
        let view = new DataView(buffer);

        // HEADER
        writeString(view, 0, 'FORM');

        view.setInt32(4, fileSizeInBytes);

        writeString(view, 8, 'AIFF');

        // COMM
        writeString(view, 12, 'COMM');
        view.setInt32(16, 18);
        view.setInt16(20, numChannels);
        view.setInt32(22, samples.length / numChannels); // num samples per channel
        view.setInt16(26, 16); // bit depth
        addSampleRateToAiffData(view, 28, sampleRate);

        // APPL
        writeString(view, 38, 'APPL');
        view.setInt32(42, 0x1004);
        writeString(view, 46, 'op-1');
        writeApplData(view, jsonData, 50);

        let offset = 0x1032;

        // SSND
        writeString(view, offset, 'SSND');
        view.setInt32(offset + 4, soundDataChunkSize);
        view.setInt32(offset + 8, 0); // offset
        view.setInt32(offset + 12, 0); // block size

        offset = offset + 16; //0x1042

        const noise = () =>  settings.ditherExports ? (Math.random() - Math.random()) / 65536 : 0;
        for (let i = 0; i < samples.length; i++) {
            const sample = Math.max(-1, Math.min(1, samples[i] + noise()));
            view.setInt16(offset, Math.round(sample * 32767));
            offset += 2;
        }

        return {buffer, sampleRate};
    }

    function writeApplData(dataView, data, offset) {
        const encDataRaw = JSON.stringify(data) + '\n';
        const encData = encDataRaw.length % 2 === 0 ? encDataRaw : (encDataRaw +
          '\n');
        let pad = 0x1004 - encData.length - 4;
        writeString(dataView, offset, encData);
        offset += encData.length;
        if (pad > 0) {
            new Array(pad).fill(0x20).forEach(p => {
                dataView.setUint8(offset, p);
                offset++;
            });
        }
    }

    return audioData.numberOfChannels ?
      new DataView(audioBufferToAiff(audioData).buffer) :
      encodeAIFF(audioData, sampleRate, numberOfChannels);
}

function interleave(inputL, inputR) {
    var length = inputL.length + inputR.length;
    var result = new Float32Array(length);

    var index = 0;
    var inputIndex = 0;

    while (index < length) {
        result[index++] = inputL[inputIndex];
        result[index++] = inputR[inputIndex];
        inputIndex++;
    }
    return result;
}

function writeFloat32(output, offset, input) {
    for (let i = 0; i < input.length; i++, offset += 4) {
        output.setFloat32(offset, input[i], true);
    }
}

function floatTo8BitPCM(output, offset, input) {
    const noise = () => settings.ditherExports ? (Math.random() - Math.random()) / 255 : 0;
    for (let i = 0; i < input.length; i++, offset++) {
        //const s = Math.max(-1, Math.min(1, input[i]));
        const s = Math.floor(Math.max(-1, Math.min(1, input[i] + noise())) * 127 + 128);
        output.setInt8(offset, s);
    }
}

function floatTo16BitPCM(output, offset, input) {
    const noise = () =>  settings.ditherExports ? (Math.random() - Math.random()) / 65536 : 0;
    for (let i = 0; i < input.length; i++, offset += 2) {
        const s = Math.max(-1, Math.min(1, input[i] + noise()));
        output.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
    }
}

function floatTo24BitPCM(output, offset, input) {
    const noise = () => settings.ditherExports ? (Math.random() - Math.random()) / (1 << 24) : 0;
    for (let i = 0; i < input.length; i++, offset += 3) {
        const s = Math.floor((input[i] + noise()) * 8388608 + 0.5);
        output.setInt24(offset, s, true);
    }
}

function writeString(view, offset, string) {
    for (let i = 0; i < string.length; i++) {
        view.setUint8(offset + i, string.charCodeAt(i));
    }
}

export function Resampler(fromSampleRate, toSampleRate, channels, inputBuffer) {
    //JavaScript Audio Resampler
    //Copyright (C) 2011-2015 Grant Galitz
    //Released to Public Domain https://raw.githubusercontent.com/taisel/XAudioJS/master/resampler.js
    //Input Sample Rate:
    this.fromSampleRate = +fromSampleRate;
    //Output Sample Rate:
    this.toSampleRate = +toSampleRate;
    //Number of channels:
    this.channels = channels | 0;
    //Type checking the input buffer:
    if (typeof inputBuffer != 'object') {
        throw (new Error('inputBuffer is not an object.'));
    }
    if (!(inputBuffer instanceof Array) &&
      !(inputBuffer instanceof Float32Array) &&
      !(inputBuffer instanceof Float64Array)) {
        throw (new Error(
          'inputBuffer is not an array or a float32 or a float64 array.'));
    }
    this.inputBuffer = inputBuffer;
    //Initialize the resampler:
    this.initialize();
}

Resampler.prototype.initialize = function() {
    //Perform some checks:
    if (this.fromSampleRate > 0 && this.toSampleRate > 0 && this.channels > 0) {
        if (this.fromSampleRate == this.toSampleRate) {
            //Setup a resampler bypass:
            this.resampler = this.bypassResampler;		//Resampler just returns what was passed through.
            this.ratioWeight = 1;
            this.outputBuffer = this.inputBuffer;
        } else {
            this.ratioWeight = this.fromSampleRate / this.toSampleRate;
            if (this.fromSampleRate < this.toSampleRate) {
                /*
                  Use generic linear interpolation if upsampling,
                  as linear interpolation produces a gradient that we want
                  and works fine with two input sample points per output in this case.
                */
                this.compileLinearInterpolationFunction();
                this.lastWeight = 1;
            } else {
                /*
                  Custom resampler I wrote that doesn't skip samples
                  like standard linear interpolation in high downsampling.
                  This is more accurate than linear interpolation on downsampling.
                */
                this.compileMultiTapFunction();
                this.tailExists = false;
                this.lastWeight = 0;
            }
            this.initializeBuffers();
        }
    } else {
        throw (new Error('Invalid settings specified for the resampler.'));
    }
};
Resampler.prototype.compileLinearInterpolationFunction = function() {
    var toCompile = 'var outputOffset = 0;\
    if (bufferLength > 0) {\
        var buffer = this.inputBuffer;\
        var weight = this.lastWeight;\
        var firstWeight = 0;\
        var secondWeight = 0;\
        var sourceOffset = 0;\
        var outputOffset = 0;\
        var outputBuffer = this.outputBuffer;\
        for (; weight < 1; weight += ' + this.ratioWeight + ') {\
            secondWeight = weight % 1;\
            firstWeight = 1 - secondWeight;';
    for (var channel = 0; channel < this.channels; ++channel) {
        toCompile += 'outputBuffer[outputOffset++] = (this.lastOutput[' +
          channel + '] * firstWeight) + (buffer[' + channel +
          '] * secondWeight);';
    }
    toCompile += '}\
        weight -= 1;\
        for (bufferLength -= ' + this.channels +
      ', sourceOffset = Math.floor(weight) * ' + this.channels + '; sourceOffset < bufferLength;) {\
            secondWeight = weight % 1;\
            firstWeight = 1 - secondWeight;';
    for (var channel = 0; channel < this.channels; ++channel) {
        toCompile += 'outputBuffer[outputOffset++] = (buffer[sourceOffset' +
          ((channel > 0) ? (' + ' + channel) : '') +
          '] * firstWeight) + (buffer[sourceOffset + ' +
          (this.channels + channel) + '] * secondWeight);';
    }
    toCompile += 'weight += ' + this.ratioWeight + ';\
            sourceOffset = Math.floor(weight) * ' + this.channels + ';\
        }';
    for (var channel = 0; channel < this.channels; ++channel) {
        toCompile += 'this.lastOutput[' + channel +
          '] = buffer[sourceOffset++];';
    }
    toCompile += 'this.lastWeight = weight % 1;\
    }\
    return outputOffset;';
    this.resampler = Function('bufferLength', toCompile);
};
Resampler.prototype.compileMultiTapFunction = function() {
    var toCompile = 'var outputOffset = 0;\
    if (bufferLength > 0) {\
        var buffer = this.inputBuffer;\
        var weight = 0;';
    for (var channel = 0; channel < this.channels; ++channel) {
        toCompile += 'var output' + channel + ' = 0;';
    }
    toCompile += 'var actualPosition = 0;\
        var amountToNext = 0;\
        var alreadyProcessedTail = !this.tailExists;\
        this.tailExists = false;\
        var outputBuffer = this.outputBuffer;\
        var currentPosition = 0;\
        do {\
            if (alreadyProcessedTail) {\
                weight = ' + this.ratioWeight + ';';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'output' + channel + ' = 0;';
    }
    toCompile += '}\
            else {\
                weight = this.lastWeight;';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'output' + channel + ' = this.lastOutput[' + channel + '];';
    }
    toCompile += 'alreadyProcessedTail = true;\
            }\
            while (weight > 0 && actualPosition < bufferLength) {\
                amountToNext = 1 + actualPosition - currentPosition;\
                if (weight >= amountToNext) {';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'output' + channel +
          ' += buffer[actualPosition++] * amountToNext;';
    }
    toCompile += 'currentPosition = actualPosition;\
                    weight -= amountToNext;\
                }\
                else {';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'output' + channel + ' += buffer[actualPosition' +
          ((channel > 0) ? (' + ' + channel) : '') + '] * weight;';
    }
    toCompile += 'currentPosition += weight;\
                    weight = 0;\
                    break;\
                }\
            }\
            if (weight <= 0) {';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'outputBuffer[outputOffset++] = output' + channel + ' / ' +
          this.ratioWeight + ';';
    }
    toCompile += '}\
            else {\
                this.lastWeight = weight;';
    for (channel = 0; channel < this.channels; ++channel) {
        toCompile += 'this.lastOutput[' + channel + '] = output' + channel + ';';
    }
    toCompile += 'this.tailExists = true;\
                break;\
            }\
        } while (actualPosition < bufferLength);\
    }\
    return outputOffset;';
    this.resampler = Function('bufferLength', toCompile);
};
Resampler.prototype.bypassResampler = function(upTo) {
    return upTo;
};
Resampler.prototype.initializeBuffers = function() {
    //Initialize the internal buffer:
    var outputBufferSize = (Math.ceil(
      this.inputBuffer.length * this.toSampleRate / this.fromSampleRate /
      this.channels * 1.000000476837158203125) * this.channels) + this.channels;
    try {
        this.outputBuffer = new Float32Array(outputBufferSize);
        this.lastOutput = new Float32Array(this.channels);
    } catch (error) {
        this.outputBuffer = [];
        this.lastOutput = [];
    }
};

export function detectTempo(audioBuffer, fileName = '') {
    return new Promise((resolve, reject) => {
        function getPeaks(data) {
            let partSize = 22050,
                parts = data[0].length / partSize,
                peaks = [];

            for (let i = 0; i < parts; i++) {
                let max = 0;
                for (let j = i * partSize; j < (i + 1) * partSize; j++) {
                    let volume = Math.max(Math.abs(data[0][j]), Math.abs(data[1][j]));
                    if (!max || (volume > max.volume)) {
                        max = {
                            position: j,
                            volume: volume
                        };
                    }
                }
                peaks.push(max);
            }

            peaks.sort((a, b) => b.volume - a.volume);
            peaks = peaks.splice(0, peaks.length * 0.5);
            peaks.sort((a, b) => a.position - b.position);

            return peaks;
        }

        function getIntervals(peaks) {
            const groups = [];
            peaks.forEach((peak, index) => {
                for (let i = 1; (index + i) < peaks.length && i < 10; i++) {
                    const group = {
                        tempo: (60 * 44100) / (peaks[index + i].position - peak.position),
                        count: 1
                    };
                    while (group.tempo < 90) {
                        group.tempo *= 2;
                    }
                    while (group.tempo > 180) {
                        group.tempo /= 2;
                    }
                    group.tempo = Math.round(group.tempo);

                    if (
                        !(groups.some(
                            interval => (interval.tempo === group.tempo ? interval.count++ : 0)
                        ))) {
                        groups.push(group);
                    }
                }
            });
            return groups;
        }

        const offlineContext = new window.OfflineAudioContext(2, 30 * 44100, 44100);

        function findTempo(buffer) {
            // Try to find from file name first
            const fileNameMatch = fileName.match(/(?:^|[\s-_])(\d+)(?![0-9])/g);
            if (fileNameMatch && fileNameMatch[0]) {
                const bpm = parseInt(fileNameMatch[0].replace(/[^0-9]/g, ''));
                if (bpm && bpm > 0) {
                    resolve({
                        match: bpm,
                        alternatives: []
                    });
                    return;
                }
            }
            // If not found, try to find from audio data
            const source = offlineContext.createBufferSource();
            source.buffer = buffer;
            const lowpass = offlineContext.createBiquadFilter();
            lowpass.type = 'lowpass';
            lowpass.frequency.value = 150;
            lowpass.Q.value = 1;
            source.connect(lowpass);
            const highpass = offlineContext.createBiquadFilter();
            highpass.type = 'highpass';
            highpass.frequency.value = 100;
            highpass.Q.value = 1;
            lowpass.connect(highpass);
            highpass.connect(offlineContext.destination);
            source.start(0);
            offlineContext.startRendering();
        }

        offlineContext.oncomplete = function(e) {
            const buffer = e.renderedBuffer;
            const peaks = getPeaks([buffer.getChannelData(0), buffer.getChannelData(1)]);
            const top = getIntervals(peaks).sort(function(intA, intB) {
                return intB.count - intA.count;
            }).splice(0, 5);

            resolve({
                match: Math.round(top[1].tempo > top[0].tempo ? top[1].tempo : top[0].tempo),
                alternatives: top
            });
        };

        findTempo(audioBuffer);
    });

}

export function Paula() {
    const pChannel = () => ({
        en: false,
        lch: 0,
        lcl: 0,
        len: 0,
        per: 0,
        vol: 0,
        ciata: 0,
        offset: 0,
        ex: false,
        start: 0,
        length: 0
    });

    return (monoAudioArrayBuffer, sampleRate = 44100, callbacks = {}, ciaTimerInterval = 0, regionNTSC = false) => {
        const numChannels = 4;
        const fps = 50;

        const callback = {
            vBlank: () => {},
            audioInterrupt: () => {},
            ciaTimer: () => {},

            ...callbacks
        };

        let ciata = ciaTimerInterval;
        let clock = regionNTSC ? 3579545 : 3579545;
        let clockAdvance = clock / sampleRate;
        let ciaClockAdvance = clockAdvance / 5;

        let frameCount = 0;
        let ciaClock = 0;

        let frameAdvance = fps / sampleRate;

        let channel = [];

        let ram = new DataView(monoAudioArrayBuffer);

        for (let i = 0; i < numChannels; i++) {
            channel.push(pChannel());
        }

        const channelLatch = ch => {
            ch.start = ch.lch << 16 | ch.lcl;
            ch.length = ch.len * 2;
            ch.offset = 0;
            callback.audioInterrupt(ch);
        };

        // Get Next Sample Value;
        return (output = 0) => {
            if (Math.floor(frameCount + frameAdvance) > frameCount) {
                frameCount--;
                callback.vBlank();
            }

            frameCount = frameCount + frameAdvance;

            if (Math.floor(ciaClock + ciaClockAdvance) > ciaTimerInterval) {
                ciaClock = ciaClock - ciaTimerInterval;
                ciaTimerInterval = ciata;
                callback.ciaTimer();
            }

            ciaClock = ciaClock + ciaClockAdvance;

            channel.forEach(ch => {
                if (ch.en) {
                    if (ch.ex === false) {
                        channelLatch(ch);
                        ch.ex = true;
                    }

                    ch.offset = ch.offset + (clockAdvance / ch.per);

                    let offset = Math.floor(ch.offset);

                    if (offset >= ch.length) {
                        channelLatch(ch);
                        offset = 0;
                    }

                    let delta = ch.offset = offset;

                    let current = ram.getInt8(ch.start + offset);
                    let next = ((offset + 1) < ch.length) ?
                      ram.getInt8(ch.start + offset + 1) :
                      ram.getInt8(ch.start);
                    output = output + (ch.vol * (current + delta * (next - current)));
                } else {
                    ch.ex = false;
                }
            });
            return output / 32768;
        };
    };
}

export function setLoadingText(text = 'Loading', dismissTimeout) {
    const loadingEl = document.getElementById('loadingText');
    if (!text) {
        loadingEl.textContent = 'Loading';
        document.body.classList.remove('loading');
        return;
    }

    loadingEl.textContent = text;
    document.body.classList.add('loading');

    if (dismissTimeout) {
        setTimeout(() => document.body.classList.remove('loading'), parseInt(dismissTimeout));
    }
}

CanvasRenderingContext2D.prototype.clear =
  CanvasRenderingContext2D.prototype.clear || function(preserveTransform) {
      if (preserveTransform) {
          this.save();
          this.setTransform(1, 0, 0, 1, 0, 0);
      }

      this.clearRect(0, 0, this.canvas.width, this.canvas.height);
      this.beginPath();

      if (preserveTransform) {
          this.restore();
      }
  };

/*scrollIntoViewIfNeeded shim*/
if (!Element.prototype.scrollIntoViewIfNeeded) {
    Element.prototype.scrollIntoViewIfNeeded = function(centerIfNeeded) {
        centerIfNeeded = arguments.length === 0 ? true : !!centerIfNeeded;

        const parent = this.parentElement;
        const parentComputedStyle = window.getComputedStyle(parent, null);
        const parentBorderTopWidth = parseInt(
          parentComputedStyle.getPropertyValue('border-top-width'));
        const parentBorderLeftWidth = parseInt(
          parentComputedStyle.getPropertyValue('border-left-width'));
        const overTop = this.offsetTop - parent.offsetTop < parent.scrollTop;
        const overBottom = (this.offsetTop - parent.offsetTop +
            this.clientHeight - parentBorderTopWidth) >
          (parent.scrollTop + parent.clientHeight);
        const overLeft = this.offsetLeft - parent.offsetLeft <
          parent.scrollLeft;
        const overRight = (this.offsetLeft - parent.offsetLeft +
            this.clientWidth - parentBorderLeftWidth) >
          (parent.scrollLeft + parent.clientWidth);
        const alignWithTop = overTop && !overBottom;

        if ((overTop || overBottom) && centerIfNeeded) {
            parent.scrollTop = this.offsetTop - parent.offsetTop -
              parent.clientHeight / 2 - parentBorderTopWidth +
              this.clientHeight / 2;
        }

        if ((overLeft || overRight) && centerIfNeeded) {
            parent.scrollLeft = this.offsetLeft - parent.offsetLeft -
              parent.clientWidth / 2 - parentBorderLeftWidth +
              this.clientWidth / 2;
        }

        if ((overTop || overBottom || overLeft || overRight) &&
          !centerIfNeeded) {
            this.scrollIntoView(alignWithTop);
        }
    };
}

// noinspection
export const ptiDefaultHeaderJson = '{"0":84,"1":73,"2":1,"3":0,"4":1,"5":5,"6":0,"7":1,"8":9,"9":9,"10":9,"11":9,"12":116,"13":1,"14":0,"15":0,"16":1,"17":0,"18":0,"19":0,"20":0,"21":98,"22":108,"23":97,"24":110,"25":107,"26":0,"27":0,"28":0,"29":0,"30":0,"31":0,"32":0,"33":0,"34":0,"35":0,"36":0,"37":0,"38":0,"39":0,"40":0,"41":0,"42":0,"43":0,"44":0,"45":0,"46":0,"47":0,"48":0,"49":0,"50":0,"51":0,"52":0,"53":0,"54":0,"55":0,"56":0,"57":0,"58":0,"59":0,"60":16,"61":0,"62":0,"63":0,"64":0,"65":8,"66":0,"67":0,"68":0,"69":0,"70":0,"71":0,"72":0,"73":0,"74":0,"75":0,"76":5,"77":0,"78":0,"79":0,"80":1,"81":0,"82":254,"83":255,"84":255,"85":255,"86":0,"87":0,"88":0,"89":0,"90":0,"91":0,"92":0,"93":0,"94":128,"95":63,"96":0,"97":0,"98":0,"99":0,"100":0,"101":0,"102":0,"103":0,"104":0,"105":0,"106":128,"107":63,"108":232,"109":3,"110":0,"111":1,"112":0,"113":0,"114":128,"115":63,"116":0,"117":0,"118":0,"119":0,"120":0,"121":0,"122":0,"123":0,"124":0,"125":0,"126":128,"127":63,"128":232,"129":3,"130":0,"131":0,"132":0,"133":0,"134":128,"135":63,"136":0,"137":0,"138":0,"139":0,"140":0,"141":0,"142":0,"143":0,"144":0,"145":0,"146":128,"147":63,"148":232,"149":3,"150":0,"151":0,"152":0,"153":0,"154":128,"155":63,"156":0,"157":0,"158":0,"159":0,"160":0,"161":0,"162":0,"163":0,"164":0,"165":0,"166":128,"167":63,"168":232,"169":3,"170":0,"171":0,"172":0,"173":0,"174":128,"175":63,"176":0,"177":0,"178":0,"179":0,"180":0,"181":0,"182":0,"183":0,"184":0,"185":0,"186":128,"187":63,"188":232,"189":3,"190":0,"191":0,"192":0,"193":0,"194":128,"195":63,"196":0,"197":0,"198":0,"199":0,"200":0,"201":0,"202":0,"203":0,"204":0,"205":0,"206":128,"207":63,"208":232,"209":3,"210":0,"211":0,"212":2,"213":0,"214":0,"215":0,"216":0,"217":0,"218":0,"219":63,"220":2,"221":0,"222":0,"223":0,"224":0,"225":0,"226":0,"227":63,"228":2,"229":0,"230":0,"231":0,"232":0,"233":0,"234":0,"235":63,"236":2,"237":0,"238":0,"239":0,"240":0,"241":0,"242":0,"243":63,"244":2,"245":0,"246":0,"247":0,"248":0,"249":0,"250":0,"251":63,"252":2,"253":0,"254":0,"255":0,"256":0,"257":0,"258":0,"259":63,"260":0,"261":0,"262":128,"263":63,"264":0,"265":0,"266":0,"267":0,"268":0,"269":0,"270":0,"271":0,"272":50,"273":0,"274":0,"275":0,"276":50,"277":0,"278":0,"279":0,"280":0,"281":0,"282":0,"283":0,"284":0,"285":0,"286":0,"287":0,"288":0,"289":0,"290":0,"291":0,"292":0,"293":0,"294":0,"295":0,"296":0,"297":0,"298":0,"299":0,"300":0,"301":0,"302":0,"303":0,"304":0,"305":0,"306":0,"307":0,"308":0,"309":0,"310":0,"311":0,"312":0,"313":0,"314":0,"315":0,"316":0,"317":0,"318":0,"319":0,"320":0,"321":0,"322":0,"323":0,"324":0,"325":0,"326":0,"327":0,"328":0,"329":0,"330":0,"331":0,"332":0,"333":0,"334":0,"335":0,"336":0,"337":0,"338":0,"339":0,"340":0,"341":0,"342":0,"343":0,"344":0,"345":0,"346":0,"347":0,"348":0,"349":0,"350":0,"351":0,"352":0,"353":0,"354":0,"355":0,"356":0,"357":0,"358":0,"359":0,"360":0,"361":0,"362":0,"363":0,"364":0,"365":0,"366":0,"367":0,"368":0,"369":0,"370":0,"371":0,"372":0,"373":0,"374":0,"375":0,"376":1,"377":0,"378":185,"379":1,"380":0,"381":0,"382":0,"383":0,"384":0,"385":0,"386":16,"387":0,"388":0,"389":0,"390":0,"391":0}';

// If building for macOS, enable Darwin extensions.
#if defined(DREX_MAC) && (DREX_MAC == 1)
  #define _DARWIN_C_SOURCE 1
  #include <CoreFoundation/CoreFoundation.h>
#endif

#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <vector>
#include <sstream>
#include <iomanip>
#include <cmath>
#include <cstring>
#include <sys/stat.h>

#ifndef DREX_MAC
# ifdef REX_MAC
#  define DREX_MAC REX_MAC
# else
#  define DREX_MAC 1
# endif
#endif
#ifndef DREX_WINDOWS
# ifdef REX_WINDOWS
#  define DREX_WINDOWS REX_WINDOWS
# else
#  define DREX_WINDOWS 0
# endif
#endif

typedef int32_t REX_int32_t;
typedef int16_t REX_int16_t;
typedef int8_t  REX_int8_t;

#include "REX.h"

#if defined(DREX_MAC) && (DREX_MAC == 1)
# include <sys/xattr.h>
# include <unistd.h>
# include <dlfcn.h>
#endif

using namespace std;

// ---------------------------------------------------------------------
// WAV writing helper
// ---------------------------------------------------------------------
static void writeInt32LE(FILE* out, int32_t v) {
    uint8_t b[4] = { uint8_t(v & 0xFF), uint8_t((v >> 8) & 0xFF), uint8_t((v >> 16) & 0xFF), uint8_t((v >> 24) & 0xFF) };
    fwrite(b, 1, 4, out);
}
static void writeInt16LE(FILE* out, int16_t v) {
    uint8_t b[2] = { uint8_t(v & 0xFF), uint8_t((v >> 8) & 0xFF) };
    fwrite(b, 1, 2, out);
}
static void writeInt24LE(FILE* out, int32_t v) {
    // v in signed 24-bit range
    uint8_t b[3] = { uint8_t(v & 0xFF), uint8_t((v >> 8) & 0xFF), uint8_t((v >> 16) & 0xFF) };
    fwrite(b, 1, 3, out);
}
static void writeWav(FILE* out, int frames, int channels, int bitsPerSample, int sampleRate, float** buffers) {
    int bytesPerSample = bitsPerSample / 8;
    int blockAlign       = channels * bytesPerSample;
    int byteRate         = sampleRate * blockAlign;
    int dataSize         = frames * blockAlign;
    // RIFF header
    fwrite("RIFF", 1, 4, out);
    writeInt32LE(out, 36 + dataSize);
    fwrite("WAVE", 1, 4, out);
    // fmt subchunk
    fwrite("fmt ", 1, 4, out);
    writeInt32LE(out, 16);
    writeInt16LE(out, 1); // PCM
    writeInt16LE(out, int16_t(channels));
    writeInt32LE(out, sampleRate);
    writeInt32LE(out, byteRate);
    writeInt16LE(out, int16_t(blockAlign));
    writeInt16LE(out, int16_t(bitsPerSample));
    // data subchunk
    fwrite("data", 1, 4, out);
    writeInt32LE(out, dataSize);
    for (int i = 0; i < frames; ++i) {
        for (int ch = 0; ch < channels; ++ch) {
            float x = buffers[ch] ? buffers[ch][i] : 0.0f;
            x = max(-1.0f, min(1.0f, x));
            switch (bitsPerSample) {
                case 16: {
                    int16_t s = int16_t(lrintf(x * 32767.0f));
                    writeInt16LE(out, s);
                    break;
                }
                case 24: {
                    int32_t s = int32_t(lrintf(x * 8388607.0f));
                    writeInt24LE(out, s);
                    break;
                }
                case 32: {
                    int32_t s = int32_t(lrintf(x * 2147483647.0f));
                    writeInt32LE(out, s);
                    break;
                }
                default: {
                    // fallback to 16-bit
                    int16_t s = int16_t(lrintf(x * 32767.0f));
                    writeInt16LE(out, s);
                    break;
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
// Path utilities and debug
// ---------------------------------------------------------------------
#if defined(DREX_WINDOWS) && (DREX_WINDOWS == 1)
static bool path_exists(const string& p) {
    DWORD a = GetFileAttributesA(p.c_str());
    return a != INVALID_FILE_ATTRIBUTES;
}
static bool path_is_directory(const string& p) {
    DWORD a = GetFileAttributesA(p.c_str());
    return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY);
}
#else
static bool path_exists(const string& p) { struct stat s; return stat(p.c_str(), &s) == 0; }
static bool path_is_directory(const string& p) { struct stat s; return stat(p.c_str(), &s) == 0 && S_ISDIR(s.st_mode); }
#endif

static void print_bundle_debug(const string& bundle_path) {
    cout << "--- Bundle Diagnostics ---" << endl;
    if (!path_exists(bundle_path)) {
        cerr << "❌ Bundle path does not exist: " << bundle_path << endl;
        return;
    }
    if (!path_is_directory(bundle_path)) {
        cerr << "❌ Not a directory: " << bundle_path << endl;
        return;
    }
#if defined(DREX_MAC) && (DREX_MAC == 1)
    string dylib = bundle_path + "/Contents/MacOS/REX Shared Library";
    if (!path_exists(dylib)) {
        cerr << "❌ Binary not found: " << dylib << endl;
    } else {
        cout << "✅ Found binary: " << dylib << endl;
        cout << "→ file check: "; system((string("file \"") + dylib + "\"").c_str());
        char buf[1024]; ssize_t len = getxattr(bundle_path.c_str(), "com.apple.quarantine", buf, sizeof(buf), 0, 0);
        if (len > 0) cout << "⚠️ Quarantine: " << string(buf, len) << endl;
        else        cout << "✅ No quarantine." << endl;
        cout << "→ codesign verify: "; system((string("codesign --verify --deep --verbose=4 \"") + bundle_path + "\"").c_str());
    }
#endif
    cout << "---------------------------" << endl;
}

// ---------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------
int main(int argc, char** argv) {
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " input.rx2 output.wav output.txt sdk_path" << endl;
        return 1;
    }
    const char* rx2Path = argv[1];
    const char* wavPath = argv[2];
    const char* cmdPath = argv[3];
    const char* sdkPath = argv[4];

    print_bundle_debug(sdkPath);

    // Read RX2
    ifstream in(rx2Path, ios::binary);
    if (!in) { cerr << "Failed to open RX2: " << rx2Path << endl; return 1; }
    in.seekg(0, ios::end);
    size_t fileSize = in.tellg();
    in.seekg(0);
    vector<char> fileBuffer(fileSize);
    in.read(fileBuffer.data(), fileSize);
    in.close();
    cout << "Loaded RX2: " << rx2Path << ", size: " << fileSize << " bytes" << endl;

    // Initialize SDK
    auto initErr = REX::REXInitializeDLL_DirPath(sdkPath);
    cout << "REXInitializeDLL_DirPath returned: " << initErr << endl;
    REX::REXHandle handle = nullptr;
    auto err = REX::REXCreate(&handle, fileBuffer.data(), int(fileSize), nullptr, nullptr);
    cout << "REXCreate returned: " << err << ", handle: " << handle << endl;
    if (err != REX::kREXError_NoError || !handle) { cerr << "❌ REXCreate failed." << endl; return 1; }

    // Get info & set native rate
    REX::REXInfo info;
    if (REX::REXGetInfo(handle, sizeof(info), &info) != REX::kREXError_NoError) { cerr << "❌ REXGetInfo failed." << endl; return 1; }
    if (REX::REXSetOutputSampleRate(handle, info.fSampleRate) != REX::kREXError_NoError) { cerr << "❌ REXSetOutputSampleRate failed." << endl; return 1; }
    REX::REXGetInfo(handle, sizeof(info), &info);

    double realTempo = info.fTempo / 1000.0;
    double realOrig  = info.fOriginalTempo / 1000.0;
    cout << "=== Header === Ch=" << info.fChannels
         << " SR=" << info.fSampleRate
         << " Slices=" << info.fSliceCount << endl;
    cout << fixed << setprecision(3)
         << "Tempo=" << realTempo << " BPM";
    if (info.fOriginalTempo)
        cout << " (Orig=" << realOrig << " BPM)";
    cout << endl;
    cout << "PPQ Len=" << info.fPPQLength
         << " TS=" << info.fTimeSignNom << "/" << info.fTimeSignDenom
         << " BD=" << info.fBitDepth << endl;

    // Slice info
    vector<REX::REXSliceInfo> sliceInfos(info.fSliceCount);
    for (int i = 0; i < info.fSliceCount; ++i)
        REX::REXGetSliceInfo(handle, i, sizeof(sliceInfos[i]), &sliceInfos[i]);
    cout << "=== Slice Info ===" << endl;
    for (int i = 0; i < info.fSliceCount; ++i)
        cout << "Slice " << (i+1)
             << ": PPQ=" << sliceInfos[i].fPPQPos
             << ", Len=" << sliceInfos[i].fSampleLength << endl;

    // Compute full-loop frames
    int totalFrames = int(round(info.fSampleRate * (60.0/realTempo) * (info.fPPQLength/15360.0)));
    cout << "Full-loop frames: " << totalFrames << endl;

    // Compute markers
    vector<int> markers;
    markers.reserve(sliceInfos.size());
    for (auto& s : sliceInfos) {
        double rel = double(s.fPPQPos) / double(info.fPPQLength);
        int m = int(round(rel * totalFrames));
        markers.push_back(m < 1 ? 1 : m);
    }

    string base = wavPath; if (auto d = base.rfind('.'); d != string::npos) base.resize(d);

    ostringstream cmdStream;
    // Extract & write slices
    for (int i = 0; i < info.fSliceCount; ++i) {
        int len = sliceInfos[i].fSampleLength;
        vector<float> L(len), R(info.fChannels==2 ? len : 0);
        float* bufs[2] = { L.data(), info.fChannels==2 ? R.data() : nullptr };
        if (REX::REXRenderSlice(handle, i, len, bufs) != REX::kREXError_NoError) continue;
        ostringstream fn; fn << base << "_slice" << setw(3) << setfill('0') << (i+1) << ".wav";
        FILE* out = fopen(fn.str().c_str(), "wb");
        if (out) {
            writeWav(out, len, info.fChannels, info.fBitDepth, info.fSampleRate, bufs);
            fclose(out);
            cout << "Wrote " << fn.str() << " marker=" << markers[i] << " len=" << len << endl;
            cmdStream << "renoise.song().selected_sample:insert_slice_marker(" << markers[i] << ")\n";
        }
    }

    // Print & save Renoise commands
    cout << "--- Renoise Commands ---" << endl
         << cmdStream.str() << "-----------------------" << endl;
    ofstream txt(cmdPath); txt << cmdStream.str(); txt.close();
    cout << "Commands saved to: " << cmdPath << endl;

    // Reconstruct full loop
    vector<float> fullL(totalFrames), fullR(info.fChannels==2 ? totalFrames : 0);
    for (int i = 0; i < info.fSliceCount; ++i) {
        int len = sliceInfos[i].fSampleLength;
        vector<float> L2(len), R2(info.fChannels==2 ? len : 0);
        float* bufs2[2] = { L2.data(), info.fChannels==2 ? R2.data() : nullptr };
        double rel = double(sliceInfos[i].fPPQPos) / double(info.fPPQLength);
        int start = int(round(rel * totalFrames));
        cout << "Place slice " << (i+1) << " at " << start << endl;
        if (REX::REXRenderSlice(handle, i, len, bufs2) == REX::kREXError_NoError) {
            for (int j = 0; j < len; ++j) {
                int idx = start + j;
                if (idx < totalFrames) {
                    fullL[idx] = L2[j];
                    if (info.fChannels==2) fullR[idx] = R2[j];
                }
            }
        }
    }

    FILE* fullOut = fopen((base + ".wav").c_str(), "wb");
    if (fullOut) {
        float* outs[2] = { fullL.data(), info.fChannels==2 ? fullR.data() : nullptr };
        writeWav(fullOut, totalFrames, info.fChannels, info.fBitDepth, info.fSampleRate, outs);
        fclose(fullOut);
        cout << "Full loop saved: " << base << ".wav" << endl;
    }

    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();
    return 0;
}

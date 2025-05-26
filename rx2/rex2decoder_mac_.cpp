// If building for macOS, enable Darwin extensions.
#if defined(DREX_MAC) && (DREX_MAC == 1)
  #define _DARWIN_C_SOURCE 1
  #include <CoreFoundation/CoreFoundation.h>
#endif

#include <cstdint>
#include "REX.h"
#include "Wav.h"

#include <fstream>
#include <iostream>
#include <vector>
#include <sstream>
#include <iomanip>
#include <cassert>
#include <cmath>
#include <cstring>
#include <sys/stat.h>

#if defined(DREX_MAC) && (DREX_MAC == 1)
  #include <sys/xattr.h>
  #include <unistd.h>
  #include <dlfcn.h>
#elif defined(DREX_WINDOWS) && (DREX_WINDOWS == 1)
  #include <windows.h>
#endif

using namespace std;

// ---------------------------------------------------------------------
// Diagnostics and file/path utilities
// ---------------------------------------------------------------------
#if defined(DREX_WINDOWS) && (DREX_WINDOWS == 1)
bool path_exists(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES);
}
bool path_is_directory(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES && (attrib & FILE_ATTRIBUTE_DIRECTORY));
}
#else
#include <sys/stat.h>
bool path_exists(const string& path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0;
}
bool path_is_directory(const string& path) {
    struct stat st;
    if (stat(path.c_str(), &st) != 0) return false;
    return S_ISDIR(st.st_mode);
}
#endif

void print_bundle_debug(const string& bundle_path) {
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
        cout << "→ file check:";
        system((string("file \"") + dylib + "\"").c_str());
        char buf[1024];
        ssize_t len = getxattr(bundle_path.c_str(), "com.apple.quarantine", buf, sizeof(buf), 0, 0);
        if (len > 0) cout << "⚠️ Quarantine: " << string(buf, len) << endl;
        else cout << "✅ No quarantine." << endl;
        cout << "→ codesign verify:";
        system((string("codesign --verify --deep --verbose=4 \"") + bundle_path + "\"").c_str());
    }
#endif
    cout << "---------------------------" << endl;
}

int main(int argc, char** argv) {
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " input.rx2 output.wav output.txt sdk_path" << endl;
        return 1;
    }
    const char* rx2Path  = argv[1];
    const char* wavPath  = argv[2];
    const char* cmdPath  = argv[3];
    const char* sdkPath  = argv[4];

    print_bundle_debug(sdkPath);

    // Load RX2 file
    ifstream in(rx2Path, ios::binary);
    if (!in) { cerr << "Failed to open RX2: " << rx2Path << endl; return 1; }
    in.seekg(0, ios::end);
    size_t sz = in.tellg(); in.seekg(0);
    vector<char> buf(sz);
    in.read(buf.data(), sz); in.close();
    cout << "Loaded RX2 (" << sz << " bytes)" << endl;

    // Init SDK
    REX::REXError err = REX::REXInitializeDLL_DirPath(sdkPath);
    cout << "REXInitializeDLL_DirPath returned: " << err << endl;
    if (err != REX::kREXError_NoError) return 1;

    // Create handle
    REX::REXHandle handle = nullptr;
    err = REX::REXCreate(&handle, buf.data(), int(sz), nullptr, nullptr);
    cout << "REXCreate returned: " << err << ", handle=" << handle << endl;
    if (err != REX::kREXError_NoError || !handle) return 1;

    // Get initial info for sample rate
    REX::REXInfo info{};
    err = REX::REXGetInfo(handle, sizeof(info), &info);
    if (err != REX::kREXError_NoError) { cerr << "REXGetInfo failed: " << err << endl; return 1; }

    // Print header info
    cout << "=== Header Information ===" << endl;
    cout << "Channels:       " << info.fChannels << endl;
    cout << "Sample Rate:    " << info.fSampleRate << endl;
    cout << "Slice Count:    " << info.fSliceCount << endl;
    double realTempo = info.fTempo / 1000.0;
    double realOriginalTempo = info.fOriginalTempo / 1000.0;
    cout << fixed << setprecision(3);
    cout << "Tempo:          " << realTempo << " BPM";
    if (info.fOriginalTempo) cout << " (Original: " << realOriginalTempo << " BPM)";
    cout << endl;
    cout << "Loop PPQ Length:" << info.fPPQLength << endl;
    cout << "Time Signature: " << info.fTimeSignNom << "/" << info.fTimeSignDenom << endl;
    cout << "Bit Depth:      " << info.fBitDepth << endl;
    cout << "==========================" << endl;

    // Force SDK to render at native rate
    err = REX::REXSetOutputSampleRate(handle, info.fSampleRate);
    if (err != REX::kREXError_NoError) { cerr << "REXSetOutputSampleRate failed: " << err << endl; return 1; }

    // Re-fetch info under correct rate
    err = REX::REXGetInfo(handle, sizeof(info), &info);
    if (err != REX::kREXError_NoError) { cerr << "REXGetInfo #2 failed: " << err << endl; return 1; }

    // Read slice metadata
    vector<REX::REXSliceInfo> slices(info.fSliceCount);
    cout << "=== Slice Information ===" << endl;
    for (int i = 0; i < info.fSliceCount; ++i) {
        err = REX::REXGetSliceInfo(handle, i, sizeof(slices[i]), &slices[i]);
        if (err == REX::kREXError_NoError) {
            cout << "Slice " << setw(3) << (i+1) << ": PPQPos=" << slices[i].fPPQPos
                 << ", SampleLen=" << slices[i].fSampleLength << endl;
        } else {
            cerr << "GetSliceInfo["<<i<<"] err: "<<err<< endl;
        }
    }
    cout << "==========================" << endl;

    // Prepare base name and JSON commands
    string base = wavPath;
    if (auto p = base.find_last_of('.'); p != string::npos) base.resize(p);
    ostringstream cmd;

    // Extract slices
    int sampleRate = info.fSampleRate;
    int channels   = info.fChannels;

    for (int i = 0; i < info.fSliceCount; ++i) {
        int len = slices[i].fSampleLength;
        vector<float> bufL(len);
        vector<float> bufR;
        if (channels == 2) bufR.resize(len);
        float* render[2] = { bufL.data(), channels==2 ? bufR.data() : bufL.data() };

        err = REX::REXRenderSlice(handle, i, len, render);
        if (err != REX::kREXError_NoError) {
            cerr << "REXRenderSlice failed for slice "<<(i+1)<<" with error: "<<err<< endl;
            continue;
        }

        ostringstream sliceName;
        sliceName << base << "_slice" << setw(3) << setfill('0') << (i+1) << ".wav";
        string fn = sliceName.str();
        FILE* out = fopen(fn.c_str(), "wb");
        if (out) {
            WriteWave(out, len, channels, 16, sampleRate, render);
            fclose(out);
            int marker = (int)round((double)slices[i].fPPQPos / info.fPPQLength * (sampleRate * (60.0 / realTempo) * (info.fPPQLength / 15360.0)));
            if (marker < 1) marker = 1;
            cout << "Slice "<< setw(3) << (i+1) << setfill(' ') << " saved as "<< fn
                 << ", marker: "<< marker << ", length: "<< len << " frames" << endl;
            cmd << "renoise.song().selected_sample:insert_slice_marker("<<marker<<")\n";
        } else {
            cerr << "Failed to write slice file "<<fn<< endl;
        }
    }

    // Write slice commands text
    ofstream txt(cmdPath);
    if (txt) {
        txt << cmd.str();
        txt.close();
        cout << "Renoise slice commands written to: "<< cmdPath << endl;
    } else {
        cerr << "Failed to open output text file: "<< cmdPath << endl;
    }

    // Full-loop reconstruction
    double quarters = info.fPPQLength / 15360.0;
    double duration = (60.0 / realTempo) * quarters;
    int totalFrames = (int)round(sampleRate * duration);
    cout << "Calculated full loop duration: "<< duration << " seconds, "<< totalFrames << " frames."<< endl;

    vector<float> fullL(totalFrames, 0.0f);
    vector<float> fullR;
    if (channels == 2) fullR.resize(totalFrames, 0.0f);

    for (int i = 0; i < info.fSliceCount; ++i) {
        int len = slices[i].fSampleLength;
        vector<float> bufL2(len);
        vector<float> bufR2;
        if (channels == 2) bufR2.resize(len);
        float* r2[2] = { bufL2.data(), channels==2 ? bufR2.data() : bufL2.data() };
        err = REX::REXRenderSlice(handle, i, len, r2);
        if (err != REX::kREXError_NoError) {
            cerr << "REXRenderSlice failed for slice "<<(i+1)<<" with error: "<<err<< endl;
            continue;
        }
        int start = (int)round((double)slices[i].fPPQPos / info.fPPQLength * totalFrames);
        cout << "Placing slice "<< setw(3)<<(i+1)<<" at output sample index: "<< start << endl;
        for (int j = 0; j < len; ++j) {
            int idx = start + j;
            if (idx < totalFrames) {
                fullL[idx] = r2[0][j];
                if (channels == 2) fullR[idx] = r2[1][j];
            }
        }
    }

    // Write full-loop WAV
    ostringstream fullName;
    fullName << base << "_full.wav";
    string fnFull = fullName.str();
    FILE* outFull = fopen(fnFull.c_str(), "wb");
    if (outFull) {
        float* ptrs[2] = { fullL.data(), channels==2 ? fullR.data() : fullL.data() };
        WriteWave(outFull, totalFrames, channels, 16, sampleRate, ptrs);
        fclose(outFull);
        cout << "Full loop -> "<< fnFull << endl;
    } else {
        cerr << "Failed to write full-loop WAV: "<< fnFull << endl;
    }

    // Cleanup
    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();
    return 0;
}

// If building for macOS, enable Darwin extensions.
#if defined(DREX_MAC) && (DREX_MAC == 1)
  #define _DARWIN_C_SOURCE 1
  #include <CoreFoundation/CoreFoundation.h>
#endif

#include <cstdint>
// Make sure REX_MAC/DREX_MAC and REX_WINDOWS/DREX_WINDOWS are defined
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

// Define platform integer types for the SDK
typedef int32_t REX_int32_t;
typedef int16_t REX_int16_t;
typedef int8_t  REX_int8_t;

#include "REX.h"

#include <fstream>
#include <iostream>
#include <vector>
#include <sstream>
#include <iomanip>
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
// WAV Writing Helper Functions (inlined to avoid external deps)
// ---------------------------------------------------------------------
static void writeInt32LE(FILE* out, int32_t value) {
    uint8_t bytes[4] = {
        (uint8_t)( value        & 0xFF),
        (uint8_t)((value >>  8) & 0xFF),
        (uint8_t)((value >> 16) & 0xFF),
        (uint8_t)((value >> 24) & 0xFF)
    };
    fwrite(bytes, 1, 4, out);
}
static void writeInt16LE(FILE* out, int16_t value) {
    uint8_t bytes[2] = {
        (uint8_t)( value        & 0xFF),
        (uint8_t)((value >>  8) & 0xFF)
    };
    fwrite(bytes, 1, 2, out);
}
static void writeWav(FILE* out, int frames, int channels, int bitsPerSample, int sampleRate, float** buffers) {
    int blockAlign = channels * (bitsPerSample/8);
    int byteRate   = sampleRate * blockAlign;
    int dataSize   = frames * blockAlign;
    // RIFF header
    fwrite("RIFF",1,4,out);
    writeInt32LE(out, 36 + dataSize);
    fwrite("WAVE",1,4,out);
    // fmt subchunk
    fwrite("fmt ",1,4,out);
    writeInt32LE(out, 16);
    writeInt16LE(out, (int16_t)1); // PCM
    writeInt16LE(out, (int16_t)channels);
    writeInt32LE(out, sampleRate);
    writeInt32LE(out, byteRate);
    writeInt16LE(out, (int16_t)blockAlign);
    writeInt16LE(out, (int16_t)bitsPerSample);
    // data subchunk
    fwrite("data",1,4,out);
    writeInt32LE(out, dataSize);
    for (int i = 0; i < frames; ++i) {
        for (int ch = 0; ch < channels; ++ch) {
            float v = buffers[ch][i];
            if (v > 1.0f)  v = 1.0f;
            if (v < -1.0f) v = -1.0f;
            int16_t samp = (int16_t)lrintf(v * 32767.0f);
            writeInt16LE(out, samp);
        }
    }
}

// ---------------------------------------------------------------------
// Diagnostics and file/path utilities
// ---------------------------------------------------------------------
#if defined(DREX_WINDOWS) && (DREX_WINDOWS == 1)
bool path_exists(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return attrib != INVALID_FILE_ATTRIBUTES;
}
bool path_is_directory(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES) && (attrib & FILE_ATTRIBUTE_DIRECTORY);
}
#else
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
#if defined(DREX_MAC) && (DREX_MAC==1)
    string dylib = bundle_path + "/Contents/MacOS/REX Shared Library";
    if (!path_exists(dylib)) {
        cerr << "❌ Binary not found: " << dylib << endl;
    } else {
        cout << "✅ Found binary: " << dylib << endl;
        cout << "→ file check: ";
        system((string("file \"") + dylib + "\"").c_str());
        char buf[1024];
        ssize_t len = getxattr(bundle_path.c_str(), "com.apple.quarantine", buf, sizeof(buf), 0, 0);
        if (len > 0) cout << "⚠️ Quarantine: " << string(buf, len) << endl;
        else        cout << "✅ No quarantine." << endl;
        cout << "→ codesign verify: ";
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

    // Read RX2 file into memory
    ifstream in(rx2Path, ios::binary);
    if (!in) {
        cerr << "Failed to open RX2: " << rx2Path << endl;
        return 1;
    }
    in.seekg(0, ios::end);
    size_t fileSize = in.tellg();
    in.seekg(0);
    vector<char> fileBuffer(fileSize);
    in.read(fileBuffer.data(), fileSize);
    in.close();
    cout << "Loaded RX2: " << rx2Path << ", size: " << fileSize << " bytes" << endl;

    // Initialize SDK
    REX::REXError initErr = REX::REXInitializeDLL_DirPath(sdkPath);
    cout << "REXInitializeDLL_DirPath returned: " << initErr << endl;
    if (initErr != REX::kREXError_NoError) {
        cerr << "DLL initialization failed." << endl;
        return 1;
    }

    // Create REX handle
    REX::REXHandle handle = nullptr;
    REX::REXError createErr = REX::REXCreate(&handle,
                            fileBuffer.data(), static_cast<int>(fileSize),
                            nullptr, nullptr);
    cout << "REXCreate returned: " << createErr << ", handle: " << handle << endl;
    if (createErr != REX::kREXError_NoError || !handle) {
        cerr << "REXCreate failed or returned null handle." << endl;
        return 1;
    }

    // Extract header
    REX::REXInfo info;
    REX::REXError infoErr = REX::REXGetInfo(handle, sizeof(info), &info);
    if (infoErr != REX::kREXError_NoError) {
        cerr << "REXGetInfo failed: " << infoErr << endl;
        return 1;
    }

    // ---- PATCH starts here ----
    // Force the SDK to use the RX2’s native sample rate for rendering:
    {
      REX::REXError rateErr = REX::REXSetOutputSampleRate(handle, info.fSampleRate);
      if (rateErr != REX::kREXError_NoError) {
        cerr << "❌ REXSetOutputSampleRate failed: " << rateErr << endl;
        return 1;
      }
    }
    // Re-fetch info so slice lengths etc. are computed at the correct rate:
    infoErr = REX::REXGetInfo(handle, sizeof(info), &info);
    if (infoErr != REX::kREXError_NoError) {
      cerr << "REXGetInfo failed after setting sample rate: " << infoErr << endl;
      return 1;
    }
    // ---- PATCH ends here ----

    // Print header info
    cout << "=== Header Information ===" << endl;
    cout << "Channels:       " << info.fChannels << endl;
    cout << "Sample Rate:    " << info.fSampleRate << endl;
    cout << "Slice Count:    " << info.fSliceCount << endl;
    double realTempo       = info.fTempo / 1000.0;
    double realOrigTempo   = info.fOriginalTempo / 1000.0;
    cout << fixed << setprecision(3);
    cout << "Tempo:          " << realTempo << " BPM";
    if (info.fOriginalTempo)
        cout << " (Original: " << realOrigTempo << " BPM)";
    cout << endl;
    cout << "Loop PPQ Length: " << info.fPPQLength << endl;
    cout << "Time Signature:  " << info.fTimeSignNom << "/" << info.fTimeSignDenom << endl;
    cout << "Bit Depth:       " << info.fBitDepth << endl;
    cout << "==========================" << endl;

    // Extract slice info
    vector<REX::REXSliceInfo> sliceInfos;
    for (int i = 0; i < info.fSliceCount; ++i) {
        REX::REXSliceInfo slice;
        REX::REXError sliceErr = REX::REXGetSliceInfo(handle, i, sizeof(slice), &slice);
        if (sliceErr == REX::kREXError_NoError)
            sliceInfos.push_back(slice);
        else
            cerr << "REXGetSliceInfo failed for slice " << i
                 << " with error: " << sliceErr << endl;
    }
    cout << "=== Slice Information ===" << endl;
    for (size_t i = 0; i < sliceInfos.size(); ++i) {
        cout << "Slice " << setw(3) << (i+1)
             << ": PPQ Position = " << sliceInfos[i].fPPQPos
             << ", Sample Length = " << sliceInfos[i].fSampleLength << endl;
    }
    cout << "==========================" << endl;

    // Compute full-loop duration
    double quarters = info.fPPQLength / 15360.0;
    double duration = (60.0 / realTempo) * quarters;
    int totalFrames = int(round(info.fSampleRate * duration));
    cout << "Calculated full loop duration: " << duration
         << " seconds, " << totalFrames << " frames." << endl;

    // Compute slice markers
    vector<int> sliceMarkers;
    for (auto &s : sliceInfos) {
        int marker = int(round(double(s.fPPQPos) / info.fPPQLength * totalFrames));
        if (marker < 1) marker = 1;
        sliceMarkers.push_back(marker);
    }

    // Base name for slices
    string base = wavPath;
    if (auto p = base.find_last_of('.'); p != string::npos)
        base.resize(p);

    // Prepare Renoise commands
    ostringstream cmdStream;

    // Extract & write each slice
    for (size_t i = 0; i < sliceInfos.size(); ++i) {
        int len = sliceInfos[i].fSampleLength;
        vector<float> left(len), right;
        if (info.fChannels == 2) right.resize(len);

        float* buffers[2] = {
          left.data(),
          info.fChannels == 2 ? right.data() : left.data()
        };

        REX::REXError renderErr = REX::REXRenderSlice(handle, i, len, buffers);
        if (renderErr != REX::kREXError_NoError) {
            cerr << "REXRenderSlice failed for slice " << (i+1)
                 << " error: " << renderErr << endl;
            continue;
        }

        ostringstream fn;
        fn << base << "_slice" << setw(3) << setfill('0') << (i+1) << ".wav";
        FILE* out = fopen(fn.str().c_str(), "wb");
        if (out) {
            writeWav(out, len, info.fChannels, 16, info.fSampleRate, buffers);
            fclose(out);
            cout << "Slice " << setw(3) << (i+1)
                 << " saved as " << fn.str()
                 << ", marker: " << sliceMarkers[i]
                 << ", length: " << len << " frames" << endl;
            cmdStream << "renoise.song().selected_sample:insert_slice_marker("
                      << sliceMarkers[i] << ")\n";
        } else {
            cerr << "Failed to write slice file " << fn.str() << endl;
        }
    }

    // Write Renoise commands
    ofstream txt(cmdPath);
    if (txt) {
        txt << cmdStream.str();
        txt.close();
        cout << "Renoise slice commands written to: " << cmdPath << endl;
    } else {
        cerr << "Failed to open output text file: " << cmdPath << endl;
    }

    // Reconstruct full loop
    vector<float> fullL(totalFrames, 0.0f), fullR;
    if (info.fChannels == 2) fullR.resize(totalFrames, 0.0f);

    for (size_t i = 0; i < sliceInfos.size(); ++i) {
        int len = sliceInfos[i].fSampleLength;
        vector<float> left2(len), right2;
        if (info.fChannels == 2) right2.resize(len);

        float* buf2[2] = {
          left2.data(),
          info.fChannels == 2 ? right2.data() : left2.data()
        };

        REX::REXError renderErr = REX::REXRenderSlice(handle, i, len, buf2);
        if (renderErr != REX::kREXError_NoError) {
            cerr << "REXRenderSlice failed for slice " << (i+1)
                 << " error: " << renderErr << endl;
            continue;
        }

        int start = int(round(double(sliceInfos[i].fPPQPos)
                        / info.fPPQLength * totalFrames));
        cout << "Placing slice " << setw(3) << (i+1)
             << " at output sample index: " << start << endl;

        for (int j = 0; j < len; ++j) {
            int idx = start + j;
            if (idx < totalFrames) {
                fullL[idx] = buf2[0][j];
                if (info.fChannels == 2) fullR[idx] = buf2[1][j];
            }
        }
    }

    // Write full-loop WAV
    ostringstream fnFull;
    fnFull << base << "_full.wav";
    FILE* fullOut = fopen(fnFull.str().c_str(), "wb");
    if (fullOut) {
        float* outs[2] = {
          fullL.data(),
          info.fChannels == 2 ? fullR.data() : fullL.data()
        };
        writeWav(fullOut, totalFrames, info.fChannels, 16, info.fSampleRate, outs);
        fclose(fullOut);
        cout << "Full loop -> " << fnFull.str() << endl;
    } else {
        cerr << "Failed to write full-loop WAV: " << fnFull.str() << endl;
    }

    // Cleanup
    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();
    return 0;
}

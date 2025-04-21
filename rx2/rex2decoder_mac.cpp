// If building for macOS, enable Darwin extensions.
#if defined(DREX_MAC) && (DREX_MAC == 1)
  #define _DARWIN_C_SOURCE 1
  #include <CoreFoundation/CoreFoundation.h>
#endif

#include <cstdint>
#include "REX.h"

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
  // Additional Windows-specific includes and stubs can be added here.
#endif

using namespace std;

// ---------------------------------------------------------------------
// Utility functions for diagnostics and file/path checking
// ---------------------------------------------------------------------
#if defined(DREX_WINDOWS) && (DREX_WINDOWS == 1)
// Windows versions of path routines using Win32 API.
bool path_exists(const std::string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES);
}

bool path_is_directory(const std::string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES &&
            (attrib & FILE_ATTRIBUTE_DIRECTORY));
}
#else
// Unix/macOS implementations.
bool path_exists(const std::string& path) {
    struct stat buffer;
    return stat(path.c_str(), &buffer) == 0;
}

bool path_is_directory(const std::string& path) {
    struct stat buffer;
    if (stat(path.c_str(), &buffer) != 0)
        return false;
    return S_ISDIR(buffer.st_mode);
}
#endif

void print_bundle_debug(const std::string& bundle_path) {
    cout << "--- Bundle Diagnostics ---" << endl;
    if (!path_exists(bundle_path)) {
        cerr << "❌ Bundle path does not exist: " << bundle_path << endl;
        return;
    }
    if (!path_is_directory(bundle_path)) {
        cerr << "❌ Bundle path is not a directory: " << bundle_path << endl;
        return;
    }
#if defined(DREX_MAC) && (DREX_MAC == 1)
    std::string dylib_path = bundle_path + "/Contents/MacOS/REX Shared Library";
    if (!path_exists(dylib_path)) {
        cerr << "❌ Binary not found at: " << dylib_path << endl;
    } else {
        cout << "✅ Found binary: " << dylib_path << endl;
        std::string cmd = "file \"" + dylib_path + "\"";
        cout << "→ Running: " << cmd << endl;
        system(cmd.c_str());
        char quarantine[1024];
        ssize_t len = getxattr(bundle_path.c_str(), "com.apple.quarantine",
                                 quarantine, sizeof(quarantine), 0, 0);
        if (len > 0) {
            cout << "⚠️  Quarantine attribute found: ";
            cout.write(quarantine, len);
            cout << endl;
        } else {
            cout << "✅ No quarantine attribute found." << endl;
        }
        std::string codesign_cmd = "codesign --verify --deep --verbose=4 \"" + bundle_path + "\"";
        cout << "→ Running codesign check..." << endl;
        system(codesign_cmd.c_str());
    }
#endif
    cout << "---------------------------" << endl;
}

// ---------------------------------------------------------------------
// WAV Writing Helper Functions (no extra printouts)
// ---------------------------------------------------------------------
void writeInt32LE(ofstream &out, int32_t value) {
    char bytes[4];
    bytes[0] = (char)(value & 0xff);
    bytes[1] = (char)((value >> 8) & 0xff);
    bytes[2] = (char)((value >> 16) & 0xff);
    bytes[3] = (char)((value >> 24) & 0xff);
    out.write(bytes, 4);
}

void writeInt16LE(ofstream &out, int16_t value) {
    char bytes[2];
    bytes[0] = (char)(value & 0xff);
    bytes[1] = (char)((value >> 8) & 0xff);
    out.write(bytes, 2);
}

void writeWav(const string &wavPath, int channels, int sampleRate, int frameCount, float** buffers) {
    ofstream out(wavPath, ios::binary);
    if (!out) {
        cerr << "Failed to open WAV output file: " << wavPath << endl;
        return;
    }
    int bitsPerSample = 32; // IEEE float format
    int blockAlign = channels * (bitsPerSample / 8);
    int byteRate = sampleRate * blockAlign;
    int dataSize = frameCount * blockAlign;
    int chunkSize = 36 + dataSize;
    // RIFF header
    out.write("RIFF", 4);
    writeInt32LE(out, chunkSize);
    out.write("WAVE", 4);
    // fmt subchunk
    out.write("fmt ", 4);
    writeInt32LE(out, 16);
    writeInt16LE(out, 3); // IEEE float
    writeInt16LE(out, (int16_t)channels);
    writeInt32LE(out, sampleRate);
    writeInt32LE(out, byteRate);
    writeInt16LE(out, (int16_t)blockAlign);
    writeInt16LE(out, (int16_t)bitsPerSample);
    // data subchunk
    out.write("data", 4);
    writeInt32LE(out, dataSize);
    // Write interleaved sample data.
    for (int i = 0; i < frameCount; ++i) {
        for (int ch = 0; ch < channels; ++ch) {
            out.write(reinterpret_cast<const char*>(&buffers[ch][i]), sizeof(float));
        }
    }
    out.close();
}

// ---------------------------------------------------------------------
// Upsample a channel buffer from inLen frames to outLen frames using linear interpolation.
// ---------------------------------------------------------------------
vector<float> upsampleChannel(const vector<float>& input, int outLen) {
    int inLen = input.size();
    vector<float> output(outLen);
    if (inLen < 2 || outLen < 2) {
        output = input;
        return output;
    }
    for (int i = 0; i < outLen; i++) {
        double srcIndex = i * (double)(inLen - 1) / (double)(outLen - 1);
        int idx0 = (int) floor(srcIndex);
        int idx1 = (idx0 < inLen - 1) ? idx0 + 1 : idx0;
        double frac = srcIndex - idx0;
        output[i] = (float)((1.0 - frac) * input[idx0] + frac * input[idx1]);
    }
    return output;
}

// ---------------------------------------------------------------------
// Main Program: Extract metadata, render slices individually, 
// reconstruct full loop WAV file, output JSON, 
// and print slice marker insertion lines at the END.
// ---------------------------------------------------------------------
int main(int argc, char** argv) {
    // Updated usage: now expecting 5 arguments.
    // For example:
    //   ./rex2decoder input.rx2 output.wav output.txt path-to-SDK
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " input.rx2 output.wav output.txt sdk_path" << endl;
        return 1;
    }
    const char* rx2Path = argv[1];
    const char* wavPath = argv[2];
    const char* jsonPath = argv[3];
    const char* sdkPath = argv[4];

    // (Optional) perform diagnostics on the provided SDK bundle.
    print_bundle_debug(sdkPath);

    // Read the RX2 file into memory.
    ifstream file(rx2Path, ios::binary);
    if (!file) {
        cerr << "Failed to open RX2 file: " << rx2Path << endl;
        return 1;
    }
    file.seekg(0, ios::end);
    size_t fileSize = file.tellg();
    file.seekg(0);
    vector<char> fileBuffer(fileSize);
    file.read(fileBuffer.data(), fileSize);
    file.close();
    cout << "Loaded RX2 file: " << rx2Path << ", size: " << fileSize << " bytes" << endl;

    // Initialize the REX DLL/dynamic library.
    // Instead of a hard-coded path, we use the sdkPath from the command line.
    REX::REXError initErr = REX::REXInitializeDLL_DirPath(sdkPath);
    cout << "REXInitializeDLL_DirPath returned: " << initErr << endl;
    if (initErr != REX::kREXError_NoError) {
        cerr << "DLL initialization failed." << endl;
        return 1;
    }

    // Create a REX handle.
    REX::REXHandle handle = nullptr;
    REX::REXError createErr = REX::REXCreate(&handle, fileBuffer.data(), static_cast<int>(fileSize), nullptr, nullptr);
    cout << "REXCreate returned: " << createErr << ", handle: " << handle << endl;
    if (createErr != REX::kREXError_NoError || !handle) {
        cerr << "REXCreate failed or returned null handle." << endl;
        return 1;
    }

    // Extract header.
    REX::REXInfo info;
    REX::REXError infoErr = REX::REXGetInfo(handle, sizeof(info), &info);
    if (infoErr != REX::kREXError_NoError) {
        cerr << "REXGetInfo failed with error: " << infoErr << endl;
        return 1;
    }
    cout << "=== Header Information ===" << endl;
    cout << "Channels:       " << info.fChannels << endl;
    cout << "Sample Rate:    " << info.fSampleRate << endl;
    cout << "Slice Count:    " << info.fSliceCount << endl;
    double realTempo = info.fTempo / 1000.0;
    double realOriginalTempo = info.fOriginalTempo / 1000.0;
    cout << "Tempo:          " << info.fTempo << " (Real BPM: " << realTempo << " BPM)" << endl;
    cout << "Original Tempo: " << info.fOriginalTempo << " (Real BPM: " << realOriginalTempo << " BPM)" << endl;
    cout << "Loop Length (PPQ):    " << info.fPPQLength << endl;
    cout << "Time Signature:       " << info.fTimeSignNom << "/" << info.fTimeSignDenom << endl;
    cout << "Bit Depth:      " << info.fBitDepth << endl;
    cout << "==========================" << endl;

    // Extract creator info.
    REX::REXCreatorInfo creator;
    REX::REXError creatorErr = REX::REXGetCreatorInfo(handle, sizeof(creator), &creator);
    bool hasCreatorInfo = (creatorErr == REX::kREXError_NoError);
    if (hasCreatorInfo) {
        cout << "=== Creator Information ===" << endl;
        cout << "Name:       " << creator.fName << endl;
        cout << "Copyright:  " << creator.fCopyright << endl;
        cout << "URL:        " << creator.fURL << endl;
        cout << "Email:      " << creator.fEmail << endl;
        cout << "FreeText:   " << creator.fFreeText << endl;
        cout << "===========================" << endl;
    } else {
        cout << "No creator information available." << endl;
    }

    // Extract slice info.
    vector<REX::REXSliceInfo> sliceInfos;
    for (int i = 0; i < info.fSliceCount; i++) {
        REX::REXSliceInfo slice;
        REX::REXError sliceErr = REX::REXGetSliceInfo(handle, i, sizeof(slice), &slice);
        if (sliceErr == REX::kREXError_NoError)
            sliceInfos.push_back(slice);
        else
            cerr << "REXGetSliceInfo failed for slice index " << i 
                 << " with error: " << sliceErr << endl;
    }
    cout << "=== Slice Information ===" << endl;
    for (size_t i = 0; i < sliceInfos.size(); i++) {
        cout << "Slice " << setfill('0') << setw(3) << (i+1) << setfill(' ')
             << ": PPQ Position = " << sliceInfos[i].fPPQPos
             << ", Sample Length = " << sliceInfos[i].fSampleLength << endl;
    }
    cout << "=========================" << endl;

    // Compute full loop duration.
    double quarters = info.fPPQLength / 15360.0;
    double duration = (60.0 / realTempo) * quarters;
    int totalFrames = (int) round(info.fSampleRate * duration);
    cout << "Calculated full loop duration: " << duration << " seconds, " 
         << totalFrames << " frames." << endl;

    // Compute slice marker positions.
    vector<int> sliceMarkers;
    for (size_t i = 0; i < sliceInfos.size(); i++) {
        int marker = (int) round(((double)sliceInfos[i].fPPQPos / info.fPPQLength) * totalFrames);
        if (marker < 1) marker = 1;
        sliceMarkers.push_back(marker);
    }

    // Determine base name for slice WAV files.
    string baseName = wavPath;
    size_t pos = baseName.find_last_of('.');
    if (pos != string::npos)
        baseName = baseName.substr(0, pos);

    // Extract each slice individually and save (print one line per slice).
    for (size_t i = 0; i < sliceInfos.size(); i++) {
        int sliceFrameCount = sliceInfos[i].fSampleLength;
        vector<float> sliceBufferLeft(sliceFrameCount);
        vector<float> sliceBufferRight;
        float* sliceChannels[2] = { nullptr, nullptr };
        if (info.fChannels == 2) {
            sliceBufferRight.resize(sliceFrameCount);
            sliceChannels[0] = sliceBufferLeft.data();
            sliceChannels[1] = sliceBufferRight.data();
        } else {
            sliceChannels[0] = sliceBufferLeft.data();
            sliceChannels[1] = nullptr;
        }
        REX::REXError sliceRenderErr = REX::REXRenderSlice(handle, i, sliceFrameCount, sliceChannels);
        if (sliceRenderErr == REX::kREXError_NoError) {
            ostringstream sliceFileName;
            sliceFileName << baseName << "_slice" << setfill('0') << setw(3) << (i+1) << ".wav";
            float* finalChannels[2] = { sliceChannels[0], (info.fChannels == 2 ? sliceChannels[1] : sliceChannels[0]) };
            // Write WAV file without extra printing.
            {
                ofstream out(sliceFileName.str(), ios::binary);
                if (out) {
                    int bitsPerSample = 32;
                    int blockAlign = info.fChannels * (bitsPerSample / 8);
                    int byteRate = info.fSampleRate * blockAlign;
                    int dataSize = sliceFrameCount * blockAlign;
                    int chunkSize = 36 + dataSize;
                    out.write("RIFF", 4);
                    writeInt32LE(out, chunkSize);
                    out.write("WAVE", 4);
                    out.write("fmt ", 4);
                    writeInt32LE(out, 16);
                    writeInt16LE(out, 3);
                    writeInt16LE(out, (int16_t)info.fChannels);
                    writeInt32LE(out, info.fSampleRate);
                    writeInt32LE(out, byteRate);
                    writeInt16LE(out, (int16_t)blockAlign);
                    writeInt16LE(out, (int16_t)bitsPerSample);
                    out.write("data", 4);
                    writeInt32LE(out, dataSize);
                    for (int j = 0; j < sliceFrameCount; j++) {
                        for (int ch = 0; ch < info.fChannels; ch++) {
                            out.write(reinterpret_cast<const char*>(&finalChannels[ch][j]), sizeof(float));
                        }
                    }
                    out.close();
                } else {
                    cerr << "Failed to write slice file " << sliceFileName.str() << endl;
                }
            }
            int marker = sliceMarkers[i];
            cout << "Slice " << setfill('0') << setw(3) << (i+1) << setfill(' ')
                 << " saved as " << sliceFileName.str()
                 << ", marker: " << marker 
                 << ", length: " << sliceInfos[i].fSampleLength << " frames" << endl;
        } else {
            cerr << "REXRenderSlice failed for slice " << (i+1) << " with error: " << sliceRenderErr << endl;
        }
    }

    // Reconstruct full-loop audio by placing each slice into its proper position.
    vector<float> fullLeft(totalFrames, 0.0f);
    vector<float> fullRight;
    if (info.fChannels == 2)
        fullRight.resize(totalFrames, 0.0f);
    
    for (size_t i = 0; i < sliceInfos.size(); i++) {
        int sliceFrameCount = sliceInfos[i].fSampleLength;
        vector<float> sliceBufferLeft(sliceFrameCount);
        vector<float> sliceBufferRight;
        float* sliceChannels[2] = { nullptr, nullptr };
        if (info.fChannels == 2) {
            sliceBufferRight.resize(sliceFrameCount);
            sliceChannels[0] = sliceBufferLeft.data();
            sliceChannels[1] = sliceBufferRight.data();
        } else {
            sliceChannels[0] = sliceBufferLeft.data();
            sliceChannels[1] = sliceBufferLeft.data();
        }
        REX::REXError sliceRenderErr = REX::REXRenderSlice(handle, i, sliceFrameCount, sliceChannels);
        if (sliceRenderErr != REX::kREXError_NoError) {
            cerr << "REXRenderSlice failed for slice " << (i+1) << " with error: " << sliceRenderErr << endl;
            continue;
        }
        int startSample = (int) round(((double)sliceInfos[i].fPPQPos / info.fPPQLength) * totalFrames);
        cout << "Placing slice " << setfill('0') << setw(3) << (i+1) << setfill(' ')
             << " at output sample index: " << startSample << endl;
        for (int j = 0; j < sliceFrameCount; j++) {
            if (startSample + j < totalFrames) {
                fullLeft[startSample + j] = sliceChannels[0][j];
                if (info.fChannels == 2)
                    fullRight[startSample + j] = sliceChannels[1][j];
            }
        }
    }
    
    // Write the full-loop audio.
    float* finalChannels[2] = { fullLeft.data(), (info.fChannels == 2 ? fullRight.data() : fullLeft.data()) };
    writeWav(wavPath, info.fChannels, info.fSampleRate, totalFrames, finalChannels);

    // Print slice marker insertion lines.
    cout << "Slice marker insertion lines:" << endl;
    for (size_t i = 0; i < sliceMarkers.size(); i++) {
        int marker = sliceMarkers[i];
        if (marker < 1) marker = 1;
        cout << "renoise.song().selected_sample:insert_slice_marker(" << marker << ")" << endl;
    }

    // Build Renoise script commands output.
    ostringstream txt;
    for (size_t i = 0; i < sliceMarkers.size(); i++) {
        int marker = sliceMarkers[i];
        if (marker < 1) marker = 1;
        txt << "renoise.song().selected_sample:insert_slice_marker(" 
            << marker << ")\n";
    }

    // Write text file with the Renoise commands.
    ofstream txtFile(jsonPath);
    if (!txtFile) {
        cerr << "Failed to open output text file: " << jsonPath << endl;
    } else {
        txtFile << txt.str();
        txtFile.close();
        cout << "Renoise slice commands written to: " << jsonPath << endl;
    }
        
    // Cleanup.
    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();

    return 0;
}

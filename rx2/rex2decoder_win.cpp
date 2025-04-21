// rex2decoder_win.cpp
//
// This version of the decoder is reformatted to compile only for Windows
// using the REX SDK files (rex.h and rex.c) provided by Reason Studios.
// All macOS-specific code paths have been removed.
// 
// Compilation command (example):
//   x86_64-w64-mingw32-g++ rex2decoder_win.cpp REX.c -o rex2decoder_win.exe \
//       -I/Users/esaruoho/Downloads/rx2 -DREX_MAC=0 -DREX_WINDOWS=1 -DREX_DLL_LOADER=1

#include <windows.h>
#include <shlobj.h>
#include <wchar.h>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <vector>
#include <sstream>
#include <iomanip>
#include <cassert>
#include <cmath>
#include <cstring>
#include <sys/stat.h>

// Before including the SDK header, we define REX_TYPES_DEFINED
// and provide a definition for REX_int32_t. This prevents REX.h from
// trying to auto-detect types.
#include "REX.h"

using namespace std;

// -------------------------------
// Utility: Convert UTF-8 char* string to std::wstring
// -------------------------------
wstring ConvertToWide(const char* str) {
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    wstring wstr(len, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, str, -1, &wstr[0], len);
    if (!wstr.empty() && wstr.back() == L'\0')
        wstr.pop_back();
    return wstr;
}

// -------------------------------
// File/Path Diagnostics for Windows
// -------------------------------
bool path_exists(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES);
}

bool path_is_directory(const string& path) {
    DWORD attrib = GetFileAttributesA(path.c_str());
    return (attrib != INVALID_FILE_ATTRIBUTES &&
            (attrib & FILE_ATTRIBUTE_DIRECTORY));
}

void print_bundle_debug(const string& bundle_path) {
    cout << "--- Bundle Diagnostics ---" << endl;
    if (!path_exists(bundle_path)) {
        cerr << "❌ Bundle path does not exist: " << bundle_path << endl;
        return;
    }
    if (!path_is_directory(bundle_path)) {
        cerr << "❌ Bundle path is not a directory: " << bundle_path << endl;
        return;
    }
    // For Windows, we expect the DLL to be located in the provided folder with the name "REX Shared Library.dll".
    string dll_path = bundle_path + "\\REX Shared Library.dll";
    if (!path_exists(dll_path)) {
        cerr << "❌ DLL not found at: " << dll_path << endl;
    } else {
        cout << "✅ Found DLL: " << dll_path << endl;
    }
    cout << "---------------------------" << endl;
}

// -------------------------------
// WAV Writing Helper Functions
// -------------------------------
void writeInt32LE(ofstream &out, int32_t value) {
    char bytes[4];
    bytes[0] = static_cast<char>(value & 0xff);
    bytes[1] = static_cast<char>((value >> 8) & 0xff);
    bytes[2] = static_cast<char>((value >> 16) & 0xff);
    bytes[3] = static_cast<char>((value >> 24) & 0xff);
    out.write(bytes, 4);
}

void writeInt16LE(ofstream &out, int16_t value) {
    char bytes[2];
    bytes[0] = static_cast<char>(value & 0xff);
    bytes[1] = static_cast<char>((value >> 8) & 0xff);
    out.write(bytes, 2);
}

void writeWav(const string &wavPath, int channels, int sampleRate, int frameCount, float** buffers) {
    ofstream out(wavPath, ios::binary);
    if (!out) {
        cerr << "Failed to open WAV output file: " << wavPath << endl;
        return;
    }
    int bitsPerSample = 32; // IEEE floating-point format
    int blockAlign = channels * (bitsPerSample / 8);
    int byteRate = sampleRate * blockAlign;
    int dataSize = frameCount * blockAlign;
    int chunkSize = 36 + dataSize;
    // RIFF header.
    out.write("RIFF", 4);
    writeInt32LE(out, chunkSize);
    out.write("WAVE", 4);
    // 'fmt ' subchunk.
    out.write("fmt ", 4);
    writeInt32LE(out, 16);
    writeInt16LE(out, 3); // IEEE float
    writeInt16LE(out, static_cast<int16_t>(channels));
    writeInt32LE(out, sampleRate);
    writeInt32LE(out, byteRate);
    writeInt16LE(out, static_cast<int16_t>(blockAlign));
    writeInt16LE(out, static_cast<int16_t>(bitsPerSample));
    // 'data' subchunk.
    out.write("data", 4);
    writeInt32LE(out, dataSize);
    for (int i = 0; i < frameCount; ++i) {
        for (int ch = 0; ch < channels; ++ch) {
            out.write(reinterpret_cast<const char*>(&buffers[ch][i]), sizeof(float));
        }
    }
    out.close();
}

// -------------------------------
// Upsample Helper Function
// -------------------------------
vector<float> upsampleChannel(const vector<float>& input, int outLen) {
    int inLen = input.size();
    vector<float> output(outLen);
    if (inLen < 2 || outLen < 2) {
        output = input;
        return output;
    }
    for (int i = 0; i < outLen; i++) {
        double srcIndex = i * (double)(inLen - 1) / (double)(outLen - 1);
        int idx0 = static_cast<int>(floor(srcIndex));
        int idx1 = (idx0 < inLen - 1) ? idx0 + 1 : idx0;
        double frac = srcIndex - idx0;
        output[i] = static_cast<float>((1.0 - frac) * input[idx0] + frac * input[idx1]);
    }
    return output;
}

// -------------------------------
// Main Program (Windows-only)
// -------------------------------
int main(int argc, char** argv) {
    // Expected usage: input.rx2 output.wav output.txt sdk_path
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " input.rx2 output.wav output.txt sdk_path" << endl;
        return 1;
    }
    const char* rx2Path = argv[1];
    const char* wavPath = argv[2];
    const char* txtPath = argv[3];
    const char* sdkPath = argv[4];

    // Print diagnostics for the provided SDK folder.
    print_bundle_debug(sdkPath);

    // Read the RX2 file into memory.
    ifstream file(rx2Path, ios::binary);
    if (!file) {
        cerr << "Failed to open RX2 file: " << rx2Path << endl;
        return 1;
    }
    file.seekg(0, ios::end);
    size_t fileSize = static_cast<size_t>(file.tellg());
    file.seekg(0);
    vector<char> fileBuffer(fileSize);
    file.read(fileBuffer.data(), fileSize);
    file.close();
    cout << "Loaded RX2 file: " << rx2Path << ", size: " << fileSize << " bytes" << endl;

    // Initialize the REX DLL/dynamic library.
    // Note: REXInitializeDLL_DirPath for Windows expects a wide-character string.
    wstring sdkPathW = ConvertToWide(sdkPath);
    REX::REXError initErr = REX::REXInitializeDLL_DirPath(sdkPathW.c_str());
    cout << "REXInitializeDLL_DirPath returned: " << initErr << endl;
    if (initErr != REX::kREXError_NoError) {
        cerr << "DLL initialization failed." << endl;
        return 1;
    }

    // Create a REX object.
    REX::REXHandle handle = nullptr;
    REX::REXError createErr = REX::REXCreate(&handle, fileBuffer.data(), static_cast<REX_int32_t>(fileSize), nullptr, nullptr);
    cout << "REXCreate returned: " << createErr << ", handle: " << handle << endl;
    if (createErr != REX::kREXError_NoError || !handle) {
        cerr << "REXCreate failed or returned null handle." << endl;
        return 1;
    }

    // Retrieve header information.
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

    // Retrieve creator information.
    REX::REXCreatorInfo creator;
    REX::REXError creatorErr = REX::REXGetCreatorInfo(handle, sizeof(creator), &creator);
    if (creatorErr == REX::kREXError_NoError) {
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

    // Retrieve slice information.
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
        cout << "Slice " << setfill('0') << setw(3) << (i + 1) << setfill(' ')
             << ": PPQ Position = " << sliceInfos[i].fPPQPos
             << ", Sample Length = " << sliceInfos[i].fSampleLength << endl;
    }
    cout << "==========================" << endl;

    // Calculate full-loop duration.
    double quarters = info.fPPQLength / 15360.0;
    double duration = (60.0 / realTempo) * quarters;
    int totalFrames = static_cast<int>(round(info.fSampleRate * duration));
    cout << "Calculated full loop duration: " << duration << " seconds, " 
         << totalFrames << " frames." << endl;

    // Compute slice marker positions.
    vector<int> sliceMarkers;
    for (size_t i = 0; i < sliceInfos.size(); i++) {
        int marker = static_cast<int>(round(((double)sliceInfos[i].fPPQPos / info.fPPQLength) * totalFrames));
        if (marker < 1)
            marker = 1;
        sliceMarkers.push_back(marker);
    }

    // Determine the base name for individual slice WAV files.
    string baseName = wavPath;
    size_t dotPos = baseName.find_last_of('.');
    if (dotPos != string::npos)
        baseName = baseName.substr(0, dotPos);

    // Extract each slice and write individual WAV files.
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
            sliceFileName << baseName << "_slice" << setfill('0') << setw(3) << (i + 1) << ".wav";
            float* finalChannels[2] = { sliceChannels[0], (info.fChannels == 2 ? sliceChannels[1] : sliceChannels[0]) };
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
                    writeInt16LE(out, static_cast<int16_t>(info.fChannels));
                    writeInt32LE(out, info.fSampleRate);
                    writeInt32LE(out, byteRate);
                    writeInt16LE(out, static_cast<int16_t>(blockAlign));
                    writeInt16LE(out, static_cast<int16_t>(bitsPerSample));
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
            cout << "Slice " << setfill('0') << setw(3) << (i + 1) << setfill(' ')
                 << " saved as " << sliceFileName.str()
                 << ", marker: " << marker 
                 << ", length: " << sliceInfos[i].fSampleLength << " frames" << endl;
        } else {
            cerr << "REXRenderSlice failed for slice " << (i + 1) << " with error: " << sliceRenderErr << endl;
        }
    }

    // Reconstruct full-loop audio.
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
            cerr << "REXRenderSlice failed for slice " << (i + 1) << " with error: " << sliceRenderErr << endl;
            continue;
        }
        int startSample = static_cast<int>(round(((double)sliceInfos[i].fPPQPos / info.fPPQLength) * totalFrames));
        cout << "Placing slice " << setfill('0') << setw(3) << (i + 1) << setfill(' ')
             << " at output sample index: " << startSample << endl;
        for (int j = 0; j < sliceFrameCount; j++) {
            if (startSample + j < totalFrames) {
                fullLeft[startSample + j] = sliceChannels[0][j];
                if (info.fChannels == 2)
                    fullRight[startSample + j] = sliceChannels[1][j];
            }
        }
    }
    
    // Write full-loop WAV file.
    float* finalChannels[2] = { fullLeft.data(), (info.fChannels == 2 ? fullRight.data() : fullLeft.data()) };
    writeWav(wavPath, info.fChannels, info.fSampleRate, totalFrames, finalChannels);

    // Output slice marker commands.
    cout << "Slice marker insertion lines:" << endl;
    ostringstream txt;
    for (size_t i = 0; i < sliceMarkers.size(); i++) {
        int marker = sliceMarkers[i];
        if (marker < 1)
            marker = 1;
        cout << "renoise.song().selected_sample:insert_slice_marker(" << marker << ")" << endl;
        txt << "renoise.song().selected_sample:insert_slice_marker(" << marker << ")\n";
    }
    ofstream txtFile(txtPath);
    if (!txtFile) {
        cerr << "Failed to open output text file: " << txtPath << endl;
    } else {
        txtFile << txt.str();
        txtFile.close();
        cout << "Renoise slice commands written to: " << txtPath << endl;
    }
        
    // Cleanup.
    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();

    return 0;
}

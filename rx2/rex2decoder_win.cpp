// rex2decoder_win.cpp
//
// This version of the decoder is reformatted to compile only for Windows
// using the REX SDK files (rex.h and rex.c) provided by Reason Studios.
// All macOS-specific code paths have been removed.
// 
// Compilation command (example):
//   x86_64-w64-mingw32-g++ rex2decoder_win.cpp Wav.c REX.c -o rex2decoder_win.exe \
//       -I/Users/esaruoho/Downloads/rx2 -DREX_MAC=0 -DREX_WINDOWS=1 -DREX_DLL_LOADER=1

#include "Wav.h"
#include <windows.h>
#include <shlobj.h>
#include <wchar.h>
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

#include "REX.h"

using namespace std;

// Latency compensation for preview rendering (adjust this value based on testing)
// Positive values shift markers later, negative values shift them earlier
const int PREVIEW_LATENCY_COMPENSATION = -64; // Start with -64 frames (about 1.45ms at 44.1kHz)

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

// ---------------------------------------------------------------------
// Preview render function like REX Test App (Windows version)
// ---------------------------------------------------------------------
REX::REXError previewRenderFullLoop(REX::REXHandle handle, const string& wavPath, const string& txtPath) {
    REX::REXError result;
    REX::REXInfo info;
    float* renderSamples = nullptr;
    float* renderBuffers[2] = {nullptr, nullptr};
    int lengthFrames = 0;
    int framesRendered = 0;

    result = REX::REXGetInfo(handle, sizeof(REX::REXInfo), &info);
    if (result != REX::kREXError_NoError) {
        return result;
    }

    // Calculate length in frames of preview rendered loop (same formula as REX Test App)
    // Use double precision to minimize rounding errors
    double exactLength = (double)info.fSampleRate * 1000.0 * (double)info.fPPQLength / ((double)info.fTempo * 256.0);
    lengthFrames = (int)round(exactLength);

    cout << "=== LENGTH CALCULATION DEBUG ===" << endl;
    cout << "REX Test App formula: (sampleRate * 1000.0 * PPQLength) / (tempo * 256)" << endl;
    cout << "Step by step:" << endl;
    cout << "  Sample Rate: " << info.fSampleRate << endl;
    cout << "  PPQ Length: " << info.fPPQLength << endl;
    cout << "  Tempo: " << info.fTempo << " (internal units)" << endl;
    cout << "  Real BPM: " << (info.fTempo / 1000.0) << endl;
    cout << "  Calculation: (" << info.fSampleRate << " * 1000.0 * " << info.fPPQLength << ") / (" << info.fTempo << " * 256)" << endl;
    cout << "  = " << (info.fSampleRate * 1000.0 * info.fPPQLength) << " / " << (info.fTempo * 256) << endl;
    cout << "  = " << exactLength << " (exact)" << endl;
    cout << "  = " << lengthFrames << " frames (after rounding)" << endl;
    cout << "  Precision difference: " << (exactLength - lengthFrames) << " frames" << endl;
    cout << "=================================" << endl;

    cout << "Calculated preview length: " << lengthFrames << " frames" << endl;

    // Allocate memory for all channels
    renderSamples = (float*)malloc(info.fChannels * lengthFrames * sizeof(float));
    if (renderSamples == nullptr) {
        cerr << "Malloc failed for preview render" << endl;
        return REX::kREXError_OutOfMemory;
    } 

    // Set up channel pointers
    renderBuffers[0] = &renderSamples[0];
    if (info.fChannels == 2) {
        renderBuffers[1] = &renderSamples[lengthFrames];
    } else {
        renderBuffers[1] = nullptr;
    }

    // Set preview tempo to original tempo
    result = REX::REXSetPreviewTempo(handle, info.fTempo);
    if(result != REX::kREXError_NoError) {
        cerr << "REXSetPreviewTempo failed: " << result << endl;
        free(renderSamples);
        return result;
    }

    // Start preview
    result = REX::REXStartPreview(handle);
    if(result != REX::kREXError_NoError) {
        cerr << "REXStartPreview failed: " << result << endl;
        free(renderSamples);
        return result;
    }

    // Render in small batches like REX Test App
    while (framesRendered != lengthFrames) {
        int remaining = lengthFrames - framesRendered;
        int todo = remaining;
        float* tmpRenderBuffers[2] = {nullptr, nullptr};

        if(todo > 64) {
            todo = 64;
        }

        tmpRenderBuffers[0] = renderBuffers[0] + framesRendered;
        if(renderBuffers[1] != nullptr) {
            tmpRenderBuffers[1] = renderBuffers[1] + framesRendered;
        }

        result = REX::REXRenderPreviewBatch(handle, todo, tmpRenderBuffers);
        if(result != REX::kREXError_NoError) {
            cerr << "REXRenderPreviewBatch failed: " << result << endl;
            free(renderSamples);
            return result;
        }

        framesRendered += todo;
    }
    
    // Stop preview
    result = REX::REXStopPreview(handle);
    if(result != REX::kREXError_NoError) {
        cerr << "REXStopPreview failed: " << result << endl;
        free(renderSamples);
        return result;
    }

    // Write the WAV file using the same WriteWave function as REX Test App
    FILE* outputFile = fopen(wavPath.c_str(), "wb");
    if (outputFile != nullptr) {
        WriteWave(outputFile, lengthFrames, info.fChannels, 16, info.fSampleRate, renderBuffers);
        fclose(outputFile);
        cout << "Full loop written to: " << wavPath << endl;
    } else {
        cerr << "Failed to open output WAV file: " << wavPath << endl;
        free(renderSamples);
        return REX::kREXError_Undefined;
    }

    // Calculate slice markers for Renoise and write txt file
    // Use the actual rendered length, not a separate calculation
    cout << "=== COMPREHENSIVE SLICE DEBUG ANALYSIS ===" << endl;
    cout << "Original file info:" << endl;
    cout << "  Sample Rate: " << info.fSampleRate << " Hz" << endl;
    cout << "  Tempo: " << info.fTempo << " (Real BPM: " << (info.fTempo / 1000.0) << ")" << endl;
    cout << "  PPQ Length: " << info.fPPQLength << " PPQ units" << endl;
    cout << "  Total Slices: " << info.fSliceCount << endl;
    cout << endl;
    
    cout << "Rendered preview info:" << endl;
    cout << "  Total rendered frames: " << lengthFrames << endl;
    cout << "  Rendered duration: " << (double)lengthFrames / info.fSampleRate << " seconds" << endl;
    cout << "  Frames per PPQ unit: " << (double)lengthFrames / info.fPPQLength << endl;
    cout << endl;
    
    cout << "=== DETAILED SLICE ANALYSIS ===" << endl;
    ostringstream txt;
    
    for (int i = 0; i < info.fSliceCount; i++) {
        REX::REXSliceInfo slice;
        REX::REXError sliceErr = REX::REXGetSliceInfo(handle, i, sizeof(slice), &slice);
        if (sliceErr == REX::kREXError_NoError) {
            // Calculate frame position in the actual rendered WAV using the same method as REX Test App
            double ratio = (double)slice.fPPQPos / (double)info.fPPQLength;
            int rawFramePosition = (int)round(ratio * lengthFrames);
            int framePosition = rawFramePosition + PREVIEW_LATENCY_COMPENSATION;
            if (framePosition < 1) framePosition = 1;
            
            // Calculate slice end position (next slice start or end of loop)
            int nextSliceStart = lengthFrames; // Default to end of loop
            if (i < info.fSliceCount - 1) {
                REX::REXSliceInfo nextSlice;
                REX::REXError nextSliceErr = REX::REXGetSliceInfo(handle, i + 1, sizeof(nextSlice), &nextSlice);
                if (nextSliceErr == REX::kREXError_NoError) {
                    double nextRatio = (double)nextSlice.fPPQPos / (double)info.fPPQLength;
                    int rawNextStart = (int)round(nextRatio * lengthFrames);
                    nextSliceStart = rawNextStart + PREVIEW_LATENCY_COMPENSATION;
                }
            }
            int sliceLength = nextSliceStart - framePosition;
            
            // Time calculations
            double sliceStartTime = (double)framePosition / info.fSampleRate;
            double sliceEndTime = (double)nextSliceStart / info.fSampleRate;
            double sliceDuration = sliceEndTime - sliceStartTime;
            
            cout << "Slice " << setfill('0') << setw(3) << (i+1) << setfill(' ') << ":" << endl;
            cout << "  PPQ Position: " << slice.fPPQPos << " / " << info.fPPQLength;
            cout << " (ratio: " << fixed << setprecision(6) << ratio << ")" << endl;
            cout << "  Original Sample Length: " << slice.fSampleLength << " samples" << endl;
            cout << "  Raw Frame Position: " << rawFramePosition << endl;
            cout << "  Latency Compensation: " << PREVIEW_LATENCY_COMPENSATION << " frames" << endl;
            cout << "  Final Frame Start: " << framePosition << endl;
            cout << "  Rendered Frame End: " << nextSliceStart << endl;
            cout << "  Rendered Slice Length: " << sliceLength << " frames" << endl;
            cout << "  Time Start: " << fixed << setprecision(6) << sliceStartTime << "s" << endl;
            cout << "  Time End: " << fixed << setprecision(6) << sliceEndTime << "s" << endl;
            cout << "  Time Duration: " << fixed << setprecision(6) << sliceDuration << "s" << endl;
            
            // Show the math step by step
            cout << "  Math: " << slice.fPPQPos << " / " << info.fPPQLength << " * " << lengthFrames;
            cout << " = " << ratio << " * " << lengthFrames << " = " << (ratio * lengthFrames);
            cout << " → " << rawFramePosition << " + (" << PREVIEW_LATENCY_COMPENSATION << ") = " << framePosition << endl;
            
            cout << "  Renoise command: renoise.song().selected_sample:insert_slice_marker(" << framePosition << ")" << endl;
            cout << endl;
            
            txt << "renoise.song().selected_sample:insert_slice_marker(" << framePosition << ")\n";
        } else {
            cout << "ERROR: Failed to get slice " << (i+1) << " info: " << sliceErr << endl;
        }
    }
    
    cout << "=== SUMMARY ===" << endl;
    cout << "Applied latency compensation: " << PREVIEW_LATENCY_COMPENSATION << " frames" << endl;
    cout << "Total analysis complete. Check frame positions against actual audio transients." << endl;
    cout << "If positions are still off:" << endl;
    cout << "  - Adjust PREVIEW_LATENCY_COMPENSATION constant (currently " << PREVIEW_LATENCY_COMPENSATION << ")" << endl;
    cout << "  - Positive values shift markers later in time" << endl;
    cout << "  - Negative values shift markers earlier in time" << endl;
    cout << "  - Each frame = " << fixed << setprecision(3) << (1000.0 / info.fSampleRate) << "ms at " << info.fSampleRate << "Hz" << endl;
    cout << "=============================================" << endl;

    // Write text file with Renoise commands
    ofstream txtFile(txtPath);
    if (txtFile) {
        txtFile << txt.str();
        txtFile.close();
        cout << "Renoise slice commands written to: " << txtPath << endl;
    } else {
        cerr << "Failed to open output text file: " << txtPath << endl;
    }

    free(renderSamples);
    return REX::kREXError_NoError;
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
    REX::REXError createErr = REX::REXCreate(&handle, fileBuffer.data(), static_cast<int>(fileSize), nullptr, nullptr);
    cout << "REXCreate returned: " << createErr << ", handle: " << handle << endl;
    if (createErr != REX::kREXError_NoError || !handle) {
        cerr << "REXCreate failed or returned null handle." << endl;
        return 1;
    }

    // Extract header information
    REX::REXInfo info;
    REX::REXError infoErr = REX::REXGetInfo(handle, sizeof(info), &info);
    if (infoErr != REX::kREXError_NoError) {
        cerr << "REXGetInfo failed with error: " << infoErr << endl;
        return 1;
    }
    
    // Set output sample rate to native rate
    REX::REXError sampleRateErr = REX::REXSetOutputSampleRate(handle, info.fSampleRate);
    if (sampleRateErr != REX::kREXError_NoError) {
        cerr << "REXSetOutputSampleRate failed with error: " << sampleRateErr << endl;
        return 1;
    }
    
    // Re-fetch info after setting sample rate
    infoErr = REX::REXGetInfo(handle, sizeof(info), &info);
    if (infoErr != REX::kREXError_NoError) {
        cerr << "REXGetInfo #2 failed with error: " << infoErr << endl;
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

    // Extract creator info
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

    // Extract slice info
    cout << "=== Slice Information ===" << endl;
    for (int i = 0; i < info.fSliceCount; i++) {
        REX::REXSliceInfo slice;
        REX::REXError sliceErr = REX::REXGetSliceInfo(handle, i, sizeof(slice), &slice);
        if (sliceErr == REX::kREXError_NoError) {
            cout << "Slice " << setfill('0') << setw(3) << (i+1) << setfill(' ')
                 << ": PPQ Position = " << slice.fPPQPos
                 << ", Sample Length = " << slice.fSampleLength << endl;
        } else {
            cerr << "REXGetSliceInfo failed for slice index " << i 
                 << " with error: " << sliceErr << endl;
        }
    }
    cout << "=========================" << endl;

    // Render full loop using preview API (like REX Test App)
    REX::REXError renderErr = previewRenderFullLoop(handle, wavPath, txtPath);
    if (renderErr != REX::kREXError_NoError) {
        cerr << "Preview render failed with error: " << renderErr << endl;
    }
        
    // Cleanup
    REX::REXDelete(&handle);
    REX::REXUninitializeDLL();

    return 0;
}

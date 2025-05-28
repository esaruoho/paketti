x86_64-w64-mingw32-g++ -static rex2decoder_win.cpp Wav.c REXSDK_Win_1.9.2/REX.c -o rex2decoder_win.exe \
  -I/Users/esaruoho/Downloads/rx2 \
  -DREX_MAC=0 -DREX_WINDOWS=1 -DREX_DLL_LOADER=1 \
  -DREX_TYPES_DEFINED -DREX_int32_t=int \
  -static-libstdc++ -static-libgcc -lversion

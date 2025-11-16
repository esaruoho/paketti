##clang++ -Wc++17-extensions rex2decoder_mac.cpp /Users/esaruoho/Downloads/rx2/REX.c -o rex2decoder -I /Users/esaruoho/Downloads/rx2/REXSDK_Mac_1.9.2 -DREX_MAC=1 -DREX_WINDOWS=0 -DREX_DLL_LOADER=1 -framework CoreFoundation
clang++ rex2decoder_mac.cpp Wav.c /Users/esaruoho/Downloads/rx2/REX.c -o rex2decoder_mac -I /Users/esaruoho/Downloads/rx2/REXSDK_Mac_1.9.2 -DREX_MAC=1 -DREX_WINDOWS=0 -DREX_DLL_LOADER=1 -framework CoreFoundation
./rex2decoder_mac billy.rx2 billy.wav billy.txt /Users/esaruoho/Downloads/rx2

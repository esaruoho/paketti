clang++ rex2decoder_mac.cpp /Users/esaruoho/Downloads/rx2/REX.c -o rex2decoder -I /Users/esaruoho/Downloads/rx2/REXSDK_Mac_1.9.2 -DREX_MAC=1 -DREX_WINDOWS=0 -DREX_DLL_LOADER=1 -framework CoreFoundation
./rex2decoder 262.rx2 262.wav 262.txt /Users/esaruoho/Downloads/rx2

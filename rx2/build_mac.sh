#!/bin/bash

clang++ \
  -std=c++17 \
  -arch x86_64 \
  -arch arm64 \
  rex2decoder_mac.cpp \
  REX.c \
  Wav.c \
  -o rex2decoder_mac \
  -I ./ \
  -I /Users/esaruoho/Downloads/rx2/REXSDK_Mac_1.9.2 \
  -DREX_MAC=1 -DDREX_MAC=1 \
  -DREX_WINDOWS=0 \
  -framework CoreFoundation

#!/bin/bash

# Find Android NDK dynamically if not set
if [ -z "$ANDROID_NDK_ROOT" ] && [ -n "$ANDROID_HOME" ]; then
    export ANDROID_NDK_ROOT=$(ls -1d $ANDROID_HOME/ndk/* | tail -n 1)
elif [ -z "$ANDROID_NDK_ROOT" ]; then
    export ANDROID_NDK_ROOT=$(ls -1d ~/Android/Sdk/ndk/* | tail -n 1)
fi

echo "Using NDK: $ANDROID_NDK_ROOT"

# Change to the app directory (one level up from scripts)
cd "$(dirname "$0")/.."

# Ensure jniLibs directory exists
mkdir -p android/app/src/main/jniLibs/arm64-v8a

# Copy libc++_shared.so from NDK
cp "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
   android/app/src/main/jniLibs/arm64-v8a/

# Build the APK (arm64 only to avoid 32-bit cargo target feature panic in llama-cpp)
flutter run --release

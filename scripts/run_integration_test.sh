#!/bin/bash

# Configuration
DEVICE_ID="HA1EY3WF"
PACKAGE_NAME="com.hejitech.appforge"
ASSETS_DIR="test_assets"
MODEL_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"
TOKENIZER_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/tokenizer.json"
TOKENIZER_FALLBACK_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B/resolve/main/tokenizer.json"

# Get local IP address for emulator connection
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "Detected Local IP: $LOCAL_IP"

# 1. Prepare Host Assets
mkdir -p "$ASSETS_DIR"
if [ ! -f "$ASSETS_DIR/model.gguf" ]; then
    echo "Downloading model to host..."
    curl -L "$MODEL_URL" -o "$ASSETS_DIR/model.gguf"
fi

if [ ! -f "$ASSETS_DIR/tokenizer.json" ]; then
    echo "Downloading tokenizer to host..."
    curl -L "$TOKENIZER_URL" -o "$ASSETS_DIR/tokenizer.json"
    if [ ! -s "$ASSETS_DIR/tokenizer.json" ]; then
        echo "Fallback to base tokenizer..."
        curl -L "$TOKENIZER_FALLBACK_URL" -o "$ASSETS_DIR/tokenizer.json"
    fi
fi

# 2. Build and Install App (needed for run-as to work)
echo "Building and installing app to ensure directory exists..."
cd app
flutter build apk --debug --target-platform android-arm64
adb -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-debug.apk
cd ..

# 3. Push Assets to Device
echo "Pushing model files to device..."
adb -s "$DEVICE_ID" push "$ASSETS_DIR/model.gguf" /data/local/tmp/model.gguf
adb -s "$DEVICE_ID" push "$ASSETS_DIR/tokenizer.json" /data/local/tmp/tokenizer.json

echo "Moving files to app private directory..."
# Use run-as to copy files to the app's internal storage
# The path in logs was /data/user/0/com.hejitech.appforge/app_flutter/
adb -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME mkdir -p app_flutter"
adb -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME cp /data/local/tmp/model.gguf app_flutter/model.gguf"
adb -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME cp /data/local/tmp/tokenizer.json app_flutter/tokenizer.json"
adb -s "$DEVICE_ID" shell "rm /data/local/tmp/model.gguf /data/local/tmp/tokenizer.json"

# 3. NDK and Native Libs (same as before)
if [ -z "$ANDROID_NDK_ROOT" ] && [ -n "$ANDROID_HOME" ]; then
    export ANDROID_NDK_ROOT=$(ls -1d $ANDROID_HOME/ndk/* | tail -n 1)
elif [ -z "$ANDROID_NDK_ROOT" ]; then
    export ANDROID_NDK_ROOT=$(ls -1d ~/Android/Sdk/ndk/* | tail -n 1)
fi
echo "Using NDK: $ANDROID_NDK_ROOT"
mkdir -p app/android/app/src/main/jniLibs/arm64-v8a
cp "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
   app/android/app/src/main/jniLibs/arm64-v8a/

# 4. Start Firebase Emulators
echo "Starting Firebase Emulators..."
firebase emulators:start --only auth,firestore,storage &
EMULATOR_PID=$!

echo "Waiting for emulators to start..."
while ! nc -z localhost 8080; do   
  sleep 1
done
echo "Emulators are ready."

# 5. Run the integration test
echo "Running integration test on Lenovo tablet ($DEVICE_ID)..."
cd app
flutter test integration_test/local_model_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=LOCAL_IP=$LOCAL_IP

TEST_EXIT_CODE=$?

# 6. Cleanup
echo "Stopping Firebase Emulators (PID $EMULATOR_PID)..."
kill $EMULATOR_PID

exit $TEST_EXIT_CODE

#!/usr/bin/env bash
# run_custom_prompt_test.sh
# Runs the integration test with a custom system prompt on the Lenovo tablet.
set -euo pipefail

DEVICE_ID="HA1EY3WF"   # Lenovo YT-K606F
APP_PACKAGE="com.hejitech.appforge"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
TOKENIZER_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct/resolve/main/tokenizer.json"
HOST_CACHE_DIR="${HOME}/.cache/appforge_model"
MODEL_FILE="${HOST_CACHE_DIR}/model.gguf"
TOKENIZER_FILE="${HOST_CACHE_DIR}/tokenizer.json"
DEVICE_APP_DIR="/data/data/${APP_PACKAGE}/app_flutter"

# Default custom prompt if none provided
CUSTOM_PROMPT="${1:-"You are MicroForge. Build tiny apps with Alpine.js/Tailwind. REQUIRED FORMAT: <name>App Name</name> <icon>Emoji</icon> <design>Desc</design> <version>1.0.0</version> <release_notes>Notes</release_notes> <forge>HTML/JS code</forge>. Example: <name>Hi</name> <icon>👋</icon> <design>doc</design> <version>1.0</version> <release_notes>v1</release_notes> <forge><div class=\"p-4 bg-blue-100\" x-data=\"{n:0}\"><button @click=\"n++\" x-text=\"n\"></button></div></forge>. Keep code ultra-concise."}"
USER_PROMPT="${2:-"build a todo app"}"

echo "=== Custom Prompt Local AI Test ==="
echo "System Prompt: ${CUSTOM_PROMPT}"
echo "User Prompt: ${USER_PROMPT}"

# ── 1. Ensure model is on device ─────────────────────────────────────────────
mkdir -p "${HOST_CACHE_DIR}"
# Remove if too small (likely failed download)
if [ -f "${MODEL_FILE}" ] && [ $(stat -c%s "${MODEL_FILE}") -lt 1000000 ]; then
  rm "${MODEL_FILE}"
fi
if [ ! -f "${MODEL_FILE}" ]; then
  echo "Downloading model to host cache..."
  curl -L --progress-bar -o "${MODEL_FILE}" "${MODEL_URL}"
fi
if [ -f "${TOKENIZER_FILE}" ] && [ $(stat -c%s "${TOKENIZER_FILE}") -lt 1000 ]; then
  rm "${TOKENIZER_FILE}"
fi
if [ ! -f "${TOKENIZER_FILE}" ]; then
  echo "Downloading tokenizer to host cache..."
  curl -L --progress-bar -o "${TOKENIZER_FILE}" "${TOKENIZER_URL}"
fi

# Check if already on device to save time
SHARED_TMP="/sdcard/Android/data/com.hejitech.appforge/files"
if adb -s "${DEVICE_ID}" shell "ls ${SHARED_TMP}/model.gguf" >/dev/null 2>&1; then
  echo "Model already in external files location."
else
  echo "Pushing model files to external files location ${DEVICE_ID}..."
  adb -s "${DEVICE_ID}" shell "mkdir -p ${SHARED_TMP}"
  adb -s "${DEVICE_ID}" push "${MODEL_FILE}" "${SHARED_TMP}/model.gguf"
  adb -s "${DEVICE_ID}" push "${TOKENIZER_FILE}" "${SHARED_TMP}/tokenizer.json"
fi

# ── 2. Setup port forwarding for emulators ───────────────────────────────────
echo "Setting up port forwarding for Firebase emulators..."
adb -s "${DEVICE_ID}" reverse tcp:9099 tcp:9099
adb -s "${DEVICE_ID}" reverse tcp:8080 tcp:8080
adb -s "${DEVICE_ID}" reverse tcp:9199 tcp:9199

# ── 3. Run integration test ────────────────────────────────────────────────────
echo "Running integration test..."
HOST_IP=$(hostname -I | awk '{print $1}')
cd app

# Grant storage permission if possible (needed for some Android versions to read /sdcard)
adb -s "${DEVICE_ID}" shell pm grant com.hejitech.appforge android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true
adb -s "${DEVICE_ID}" shell pm grant com.hejitech.appforge android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true

flutter test \
  integration_test/custom_prompt_test.dart \
  -d "${DEVICE_ID}" \
  --dart-define="CUSTOM_SYSTEM_PROMPT=${CUSTOM_PROMPT}" \
  --dart-define="USER_PROMPT=${USER_PROMPT}" \
  --dart-define="LOCAL_IP=${HOST_IP}" \
  --timeout 600s

EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 0 ]; then
  echo "✅ Test PASSED"
else
  echo "❌ Test FAILED"
fi

exit ${EXIT_CODE}

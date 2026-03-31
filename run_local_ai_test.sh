#!/usr/bin/env bash
# run_local_ai_test.sh
# Runs the local AI performance integration test on the Lenovo tablet.
# Downloads the model once on the host and pushes it to the device to avoid
# re-downloading during the test.
set -euo pipefail

DEVICE_ID="HA1EY3WF"   # Lenovo YT-K606F
APP_PACKAGE="com.hejitech.appforge"
MODEL_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"
TOKENIZER_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B/resolve/main/tokenizer.json"
HOST_CACHE_DIR="${HOME}/.cache/appforge_model"
MODEL_FILE="${HOST_CACHE_DIR}/model.gguf"
TOKENIZER_FILE="${HOST_CACHE_DIR}/tokenizer.json"
DEVICE_APP_DIR="/data/data/${APP_PACKAGE}/app_flutter"

echo "=== Local AI Performance Test ==="

# ── 1. Download model on host (once) ──────────────────────────────────────────
mkdir -p "${HOST_CACHE_DIR}"

if [ ! -f "${MODEL_FILE}" ]; then
  echo "Downloading model to host cache..."
  curl -L --progress-bar -o "${MODEL_FILE}" "${MODEL_URL}"
else
  echo "Model already cached at ${MODEL_FILE}"
fi

if [ ! -f "${TOKENIZER_FILE}" ]; then
  echo "Downloading tokenizer to host cache..."
  curl -L --progress-bar -o "${TOKENIZER_FILE}" "${TOKENIZER_URL}"
else
  echo "Tokenizer already cached at ${TOKENIZER_FILE}"
fi

# ── 2. Push model files to device ─────────────────────────────────────────────
echo "Pushing model files to device ${DEVICE_ID}..."

# Need run-as or root; use adb shell run-as for debug builds, or push to sdcard then move
SDCARD_TMP="/sdcard/appforge_model_tmp"
adb -s "${DEVICE_ID}" shell mkdir -p "${SDCARD_TMP}"

echo "  Pushing model.gguf..."
adb -s "${DEVICE_ID}" push "${MODEL_FILE}" "${SDCARD_TMP}/model.gguf"

echo "  Pushing tokenizer.json..."
adb -s "${DEVICE_ID}" push "${TOKENIZER_FILE}" "${SDCARD_TMP}/tokenizer.json"

# Move into app's documents directory (requires the app to be installed)
echo "  Moving files into app documents directory..."
adb -s "${DEVICE_ID}" shell "run-as ${APP_PACKAGE} mkdir -p ${DEVICE_APP_DIR}" 2>/dev/null || true
adb -s "${DEVICE_ID}" shell "cp ${SDCARD_TMP}/model.gguf ${DEVICE_APP_DIR}/model.gguf" 2>/dev/null || \
  adb -s "${DEVICE_ID}" shell "run-as ${APP_PACKAGE} cp ${SDCARD_TMP}/model.gguf ${DEVICE_APP_DIR}/model.gguf"
adb -s "${DEVICE_ID}" shell "cp ${SDCARD_TMP}/tokenizer.json ${DEVICE_APP_DIR}/tokenizer.json" 2>/dev/null || \
  adb -s "${DEVICE_ID}" shell "run-as ${APP_PACKAGE} cp ${SDCARD_TMP}/tokenizer.json ${DEVICE_APP_DIR}/tokenizer.json"
adb -s "${DEVICE_ID}" shell rm -rf "${SDCARD_TMP}"

echo "  Model files ready on device."

# ── 3. Run integration test ────────────────────────────────────────────────────
echo "Running integration test on device ${DEVICE_ID}..."
cd "$(dirname "$0")/app"

flutter test \
  integration_test/local_ai_performance_test.dart \
  -d "${DEVICE_ID}" \
  --timeout 600s \
  2>&1 | tee /tmp/local_ai_test_output.txt

EXIT_CODE=${PIPESTATUS[0]}

if [ ${EXIT_CODE} -eq 0 ]; then
  echo ""
  echo "✅ Test PASSED — local model successfully built a micro-app."
else
  echo ""
  echo "❌ Test FAILED — check /tmp/local_ai_test_output.txt for details."
  echo "   If the model failed to produce <forge> output, tighten the compact"
  echo "   system prompt in app/lib/main.dart (compactSystemPrompt variable)."
fi

exit ${EXIT_CODE}

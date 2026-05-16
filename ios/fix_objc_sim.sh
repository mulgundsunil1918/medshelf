#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Workaround for objective_c 9.3.0 + Xcode 26 iOS-26 simulator bug.
#
# Flutter's native-assets build emits objective_c.framework into
# .../Runner.app/Frameworks/, but the objective_c Dart package calls
# dlopen('objective_c.framework/objective_c') — a path WITHOUT the
# @rpath/ prefix, so dyld resolves it relative to the .app ROOT, not
# Frameworks/. On an Intel host the native-assets slice is also the
# wrong arch (arm64 vs the x86_64 simulator), so we recompile from the
# pub-cache source for the active simulator arch and drop it at the
# .app root where dlopen actually looks.
#
# Simulator-only: real-device / archive builds use the normal arm64
# slice and don't hit the dlopen-path bug, so this is a NO-OP there.
# ─────────────────────────────────────────────────────────────────────────────
set -e

if [ "${PLATFORM_NAME}" != "iphonesimulator" ]; then
  echo "fix_objc_sim: not a simulator build — skipping."
  exit 0
fi

APP_ROOT="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
SRC_FRAMEWORK="${APP_ROOT}/Frameworks/objective_c.framework"
DEST_FRAMEWORK="${APP_ROOT}/objective_c.framework"

if [ ! -d "${SRC_FRAMEWORK}" ]; then
  echo "fix_objc_sim: objective_c.framework not embedded yet — skipping."
  exit 0
fi

ARCH="${ARCHS%% *}"   # active arch (x86_64 on Intel, arm64 on Apple Silicon)
SRC_DIR="${HOME}/.pub-cache/hosted/pub.dev/objective_c-9.3.0/src"
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

if [ ! -d "${SRC_DIR}" ]; then
  echo "fix_objc_sim: objective_c-9.3.0 source not found — copying embedded slice as-is."
  rm -rf "${DEST_FRAMEWORK}"
  cp -R "${SRC_FRAMEWORK}" "${DEST_FRAMEWORK}"
  exit 0
fi

echo "fix_objc_sim: rebuilding objective_c for ${ARCH} simulator…"
TMP_OUT="$(mktemp -d)/objective_c.framework"
mkdir -p "${TMP_OUT}"

clang -arch "${ARCH}" \
  -mios-simulator-version-min=13.0 \
  -isysroot "${SDK_PATH}" \
  -I "${SRC_DIR}" \
  -I "${SRC_DIR}/include" \
  -fobjc-arc \
  -framework Foundation \
  -dynamiclib \
  -install_name "@rpath/objective_c.framework/objective_c" \
  -o "${TMP_OUT}/objective_c" \
  "${SRC_DIR}/objective_c.c" \
  "${SRC_DIR}/objective_c.m" \
  "${SRC_DIR}/objective_c_bindings_generated.m" \
  "${SRC_DIR}/input_stream_adapter.m" \
  "${SRC_DIR}/ns_number.m" \
  "${SRC_DIR}/observer.m" \
  "${SRC_DIR}/protocol.m" \
  "${SRC_DIR}/include/dart_api_dl.c"

# Preserve Info.plist / signature scaffolding from the embedded copy.
cp "${SRC_FRAMEWORK}/Info.plist" "${TMP_OUT}/Info.plist" 2>/dev/null || true

rm -rf "${DEST_FRAMEWORK}"
cp -R "${TMP_OUT}" "${DEST_FRAMEWORK}"
echo "fix_objc_sim: installed ${ARCH} objective_c.framework at .app root."

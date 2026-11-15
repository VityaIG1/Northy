#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Northy — LibXray (Xray-core) Core Builder & Geo Assets Fetcher
# Builds the official XTLS/libXray CGo bridge (github.com/XTLS/libXray) into a
# static LibXray.xcframework and downloads geoip/geosite data used by the
# Xray routing rules (geoip:private, geosite:category-ru, geoip:ru).
#
# Env overrides:
#   LIBXRAY_TAG          libXray git tag to build (default: v26.10.31)
#   FORCE_LIBXRAY_BUILD  set to 1 to rebuild even if a cached framework exists
#   BUILD_SIMULATOR      set to 1 to also include ios-arm64-simulator slice
#
# Requirements (macOS): Go (`brew install go`) + Xcode with iOS SDK.
# Usage: ./scripts/build_libxray.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

LIBXRAY_TAG="${LIBXRAY_TAG:-v26.10.31}"
LIBXRAY_REPO="https://github.com/XTLS/libXray.git"
LIBXRAY_CHECKOUT="${ROOT_DIR}/Vendor/libxray"

FRAMEWORKS_DIR="${ROOT_DIR}/Frameworks"
XCFRAMEWORK_PATH="${FRAMEWORKS_DIR}/LibXray.xcframework"
TAG_MARKER="${FRAMEWORKS_DIR}/LibXray.tag"
GEO_DIR="${FRAMEWORKS_DIR}/geo"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

mkdir -p "${FRAMEWORKS_DIR}" "${GEO_DIR}" "$(dirname "${LIBXRAY_CHECKOUT}")"

echo "=========================================================="
echo ">> LibXray core builder (tag: ${LIBXRAY_TAG})"
echo "=========================================================="

# --- [1/4] Cached framework shortcut (used by Codemagic cache) ----------------

if [ "${FORCE_LIBXRAY_BUILD:-0}" != "1" ] \
   && [ -d "${XCFRAMEWORK_PATH}" ] \
   && [ -f "${TAG_MARKER}" ] \
   && [ "$(cat "${TAG_MARKER}")" = "${LIBXRAY_TAG}" ]; then
  echo ">> [Core] Cached framework matches ${LIBXRAY_TAG} — skipping core build"
else
  # --- [1a] Toolchain checks ---------------------------------------------------

  command -v go >/dev/null 2>&1 || {
    echo "ERROR: Go toolchain not found. Install it with 'brew install go'."; exit 1;
  }
  command -v xcodebuild >/dev/null 2>&1 || {
    echo "ERROR: Xcode/xcodebuild not found. Install Xcode and run 'xcode-select -s'.";
    exit 1;
  }
  export PATH="$PATH:$(go env GOPATH)/bin"

  # --- [1b] Fetch libXray source at the pinned tag -----------------------------

  if [ -d "${LIBXRAY_CHECKOUT}/.git" ]; then
    echo ">> [Core] Reusing existing checkout at ${LIBXRAY_CHECKOUT}"
    git -C "${LIBXRAY_CHECKOUT}" fetch --tags origin 2>/dev/null || true
    git -C "${LIBXRAY_CHECKOUT}" checkout "${LIBXRAY_TAG}"
  else
    echo ">> [Core] Cloning ${LIBXRAY_REPO} (${LIBXRAY_TAG})..."
    git clone --depth 1 --branch "${LIBXRAY_TAG}" "${LIBXRAY_REPO}" "${LIBXRAY_CHECKOUT}"
  fi

  # --- [1c] Build static CGo bridge archive via Go CGo ------------------------
  # Note: cgo_bridge defines package main with //export CGoInvoke & CGoFree.
  # We compile it with -buildmode=c-archive into a static archive (.a) + header (.h),
  # then package it with xcodebuild -create-xcframework.

  BUILD_TEMP="${ROOT_DIR}/build/libxray_build"
  rm -rf "${BUILD_TEMP}" "${XCFRAMEWORK_PATH}"
  mkdir -p "${BUILD_TEMP}/ios-arm64" "${BUILD_TEMP}/include"

  IPHONEOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
  MIN_IOS_VERSION="15.0"
  IOS_FLAGS="-isysroot ${IPHONEOS_SDK} -miphoneos-version-min=${MIN_IOS_VERSION} -arch arm64"

  echo ">> [Core] Compiling libXray.a for iOS (arm64) via CGo — this takes ~3-5 min..."
  (
    cd "${LIBXRAY_CHECKOUT}"
    CGO_ENABLED=1 \
    GOOS=ios \
    GOARCH=arm64 \
    GOFLAGS="-tags=ios" \
    CC="$(xcrun --sdk iphoneos --find clang)" \
    CXX="$(xcrun --sdk iphoneos --find clang++)" \
    CGO_CFLAGS="${IOS_FLAGS}" \
    CGO_CXXFLAGS="${IOS_FLAGS}" \
    CGO_LDFLAGS="${IOS_FLAGS} -Wl,-Bsymbolic-functions" \
    go build \
      -trimpath \
      -ldflags="-buildid=" \
      -buildmode=c-archive \
      -o "${BUILD_TEMP}/ios-arm64/libXray.a" \
      ./cgo_bridge
  )

  # Copy generated header and write umbrella module map
  cp "${BUILD_TEMP}/ios-arm64/libXray.h" "${BUILD_TEMP}/include/libXray.h"
  cat <<'EOF' > "${BUILD_TEMP}/include/module.modulemap"
module LibXray {
  umbrella header "libXray.h"
  export *
  module * { export * }
}
EOF

  XCFRAMEWORK_ARGS=("-library" "${BUILD_TEMP}/ios-arm64/libXray.a" "-headers" "${BUILD_TEMP}/include")

  # Optional simulator slice for local debugging
  if [ "${BUILD_SIMULATOR:-0}" = "1" ]; then
    SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || true)"
    if [ -n "${SIM_SDK}" ]; then
      echo ">> [Core] Compiling libXray.a for iOS Simulator (arm64)..."
      mkdir -p "${BUILD_TEMP}/ios-arm64-simulator"
      SIM_FLAGS="-isysroot ${SIM_SDK} -mios-simulator-version-min=${MIN_IOS_VERSION} -arch arm64"
      (
        cd "${LIBXRAY_CHECKOUT}"
        CGO_ENABLED=1 \
        GOOS=ios \
        GOARCH=arm64 \
        GOFLAGS="-tags=ios" \
        CC="$(xcrun --sdk iphonesimulator --find clang)" \
        CXX="$(xcrun --sdk iphonesimulator --find clang++)" \
        CGO_CFLAGS="${SIM_FLAGS}" \
        CGO_CXXFLAGS="${SIM_FLAGS}" \
        CGO_LDFLAGS="${SIM_FLAGS} -Wl,-Bsymbolic-functions" \
        go build \
          -trimpath \
          -ldflags="-buildid=" \
          -buildmode=c-archive \
          -o "${BUILD_TEMP}/ios-arm64-simulator/libXray.a" \
          ./cgo_bridge
      )
      XCFRAMEWORK_ARGS+=("-library" "${BUILD_TEMP}/ios-arm64-simulator/libXray.a" "-headers" "${BUILD_TEMP}/include")
    fi
  fi

  echo ">> [Core] Packaging LibXray.xcframework..."
  xcodebuild -create-xcframework "${XCFRAMEWORK_ARGS[@]}" -output "${XCFRAMEWORK_PATH}"

  rm -rf "${BUILD_TEMP}"
  echo "${LIBXRAY_TAG}" > "${TAG_MARKER}"

  # --- [1d] Symbol gate: CGoInvoke/CGoFree MUST be exported --------------------

  FW_SLICE_DIR="${XCFRAMEWORK_PATH}/ios-arm64"
  FW_BIN=""
  if [ -f "${FW_SLICE_DIR}/libXray.a" ]; then
    FW_BIN="${FW_SLICE_DIR}/libXray.a"
  else
    for candidate in "${FW_SLICE_DIR}"/*.a "${FW_SLICE_DIR}"/*.framework/*; do
      if [ -f "${candidate}" ]; then FW_BIN="${candidate}"; break; fi
    done
  fi

  if [ -z "${FW_BIN}" ] || [ ! -f "${FW_BIN}" ]; then
    echo "ERROR: Could not locate the framework binary under ${FW_SLICE_DIR}."
    exit 1
  fi

  if ! nm -gU "${FW_BIN}" 2>/dev/null | grep -q "_CGoInvoke"; then
    echo "ERROR: CGoInvoke symbol is missing from the built framework (${FW_BIN})."
    echo "       The Go CGo bridge failed to export CGoInvoke."
    exit 1
  fi
  if ! nm -gU "${FW_BIN}" 2>/dev/null | grep -q "_CGoFree"; then
    echo "ERROR: CGoFree symbol is missing from the built framework (${FW_BIN})."
    echo "       The Go CGo bridge failed to export CGoFree."
    exit 1
  fi
  echo ">> [✓] Core symbols verified: CGoInvoke + CGoFree exported"
fi

# --- [2/4] Geo assets (geoip.dat / geosite.dat) --------------------------------

download_geo_asset() {
  local url="$1"
  local output="$2"
  local name
  name="$(basename "${output}")"

  if [ -s "${output}" ]; then
    echo ">> [Geo] ${name} already present ($(du -h "${output}" | cut -f1))"
    return 0
  fi

  echo ">> [Geo] Downloading ${name}..."
  curl -fSL --retry 3 --connect-timeout 30 -o "${output}.tmp" "${url}"
  mv "${output}.tmp" "${output}"

  if [ ! -s "${output}" ]; then
    echo "ERROR: Downloaded ${name} is empty."
    exit 1
  fi
  echo ">> [Geo] ${name} ready ($(du -h "${output}" | cut -f1))"
}

download_geo_asset "${GEOIP_URL}" "${GEO_DIR}/geoip.dat"
download_geo_asset "${GEOSITE_URL}" "${GEO_DIR}/geosite.dat"

# --- [3/4] Summary -------------------------------------------------------------

echo "=========================================================="
echo ">> LibXray core preparation finished"
echo ">> Framework: ${XCFRAMEWORK_PATH} ($(du -sh "${XCFRAMEWORK_PATH}" 2>/dev/null | cut -f1))"
echo ">> Tag:       $(cat "${TAG_MARKER}" 2>/dev/null || echo 'unknown')"
echo ">> Geo:       ${GEO_DIR}/geoip.dat, ${GEO_DIR}/geosite.dat"
echo "=========================================================="

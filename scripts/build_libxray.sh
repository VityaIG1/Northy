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
#
# Requirements (macOS): Go (`brew install go`) + Xcode with ios SDK.
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

  # --- [1c] Install gomobile + gobind ------------------------------------------

  echo ">> [Core] Installing gomobile toolchain..."
  go install golang.org/x/mobile/cmd/gomobile@latest
  go install golang.org/x/mobile/cmd/gobind@latest
  gomobile init

  # --- [1d] Bind the CGo bridge into a static xcframework -----------------------
  # Note: no -ldflags "-s -w" — stripping may remove exported CGo symbols from
  # the static archive, which the tunnel resolves via dlsym at runtime.

  echo ">> [Core] Binding LibXray.xcframework (ios arm64) — this takes ~10-15 min..."
  cd "${LIBXRAY_CHECKOUT}"
  gomobile bind \
    -o "${XCFRAMEWORK_PATH}" \
    -target=ios \
    -iosversion=15.0 \
    ./cgo_bridge

  echo "${LIBXRAY_TAG}" > "${TAG_MARKER}"

  # --- [1e] Symbol gate: CGoInvoke/CGoFree MUST be exported --------------------

  FW_SLICE_DIR="${XCFRAMEWORK_PATH}/ios-arm64"
  FW_BIN=""
  for fw_dir in "${FW_SLICE_DIR}"/*.framework; do
    candidate="${fw_dir}/$(basename "${fw_dir}")"
    if [ -f "${candidate}" ]; then FW_BIN="${candidate}"; break; fi
  done

  if [ -z "${FW_BIN}" ]; then
    echo "ERROR: Could not locate the framework binary under ${FW_SLICE_DIR}."
    exit 1
  fi

  if ! nm -gU "${FW_BIN}" 2>/dev/null | grep -q "_CGoInvoke"; then
    echo "ERROR: CGoInvoke symbol is missing from the built framework (${FW_BIN})."
    echo "       The Go CGo bridge was dead-stripped or the bind failed silently."
    exit 1
  fi
  if ! nm -gU "${FW_BIN}" 2>/dev/null | grep -q "_CGoFree"; then
    echo "ERROR: CGoFree symbol is missing from the built framework (${FW_BIN})."
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

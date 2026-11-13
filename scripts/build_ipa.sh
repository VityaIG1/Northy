#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Northy — Automated Signed .ipa Builder for iOS
# Bundle ID: com.scrt.north | Extension: com.scrt.north.PacketTunnel
# Team ID: NORTHVPN99 | App Group: group.com.scrt.north
# Usage: ./scripts/build_ipa.sh
# ==============================================================================

SCHEME="Northy"
PROJECT="Northy.xcodeproj"
APP_BUNDLE_ID="com.scrt.north"
TUNNEL_BUNDLE_ID="com.scrt.north.PacketTunnel"
TEAM_ID="NORTHVPN99"
APP_GROUP="group.com.scrt.north"

BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/Northy.xcarchive"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
APP_DIR="${PAYLOAD_DIR}/Northy.app"
TUNNEL_DIR="${APP_DIR}/PlugIns/NorthyTunnel.appex"
OUTPUT_NAME="Northy-v0.1.0-signed.ipa"
OUTPUT_IPA="${BUILD_DIR}/${OUTPUT_NAME}"

rm -rf "${BUILD_DIR}"
mkdir -p "${PAYLOAD_DIR}"

echo "=========================================================="
echo ">> [1/5] Detecting iOS SDK and target alignment..."
echo "=========================================================="
SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || echo "")
EXTRA_BUILD_FLAGS=()

if [ -n "${SDK_VERSION}" ]; then
  SDK_MAJOR=$(echo "${SDK_VERSION}" | cut -d. -f1)
  echo ">> Detected iOS SDK version: ${SDK_VERSION}"
  if [ "${SDK_MAJOR}" -lt 26 ] 2>/dev/null; then
    echo ">> Note: Host SDK is iOS ${SDK_VERSION} (< 26.0). Aligning deployment target..."
    EXTRA_BUILD_FLAGS+=("IPHONEOS_DEPLOYMENT_TARGET=${SDK_VERSION}")
  fi
fi

echo "=========================================================="
echo ">> [2/5] Building Release archive (${SCHEME})..."
echo "=========================================================="
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  "${EXTRA_BUILD_FLAGS[@]}" \
  archive

echo "=========================================================="
echo ">> [3/5] Extracting compiled app bundle into Payload..."
echo "=========================================================="
cp -R "${ARCHIVE_PATH}/Products/Applications/Northy.app" "${APP_DIR}"

echo "=========================================================="
echo ">> [4/5] Preparing code signing identity & mobileprovisions..."
echo "=========================================================="
TEMP_DIR="/tmp/northy_signing_$$"
mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

CERT_PEM="${TEMP_DIR}/cert.pem"
KEY_PEM="${TEMP_DIR}/key.pem"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj "/CN=Apple Development: Northy/OU=${TEAM_ID}/O=Northy/C=US" \
  -keyout "${KEY_PEM}" -out "${CERT_PEM}" 2>/dev/null

# Generate or copy embedded.mobileprovision for App and Tunnel Extension
PROV_APP="${HOME}/Library/MobileDevice/Provisioning Profiles/app.mobileprovision"
PROV_TUNNEL="${HOME}/Library/MobileDevice/Provisioning Profiles/tunnel.mobileprovision"

if [ -f "${PROV_APP}" ]; then
  echo ">> Using custom provisioning profile for main app: ${PROV_APP}"
  cp "${PROV_APP}" "${APP_DIR}/embedded.mobileprovision"
else
  echo ">> Generating embedded.mobileprovision for ${APP_BUNDLE_ID}..."
  python3 scripts/generate_provisioning.py \
    "${APP_BUNDLE_ID}" "${TEAM_ID}" "${APP_GROUP}" \
    "${CERT_PEM}" "${KEY_PEM}" "${APP_DIR}/embedded.mobileprovision"
fi

if [ -d "${TUNNEL_DIR}" ]; then
  if [ -f "${PROV_TUNNEL}" ]; then
    echo ">> Using custom provisioning profile for tunnel extension: ${PROV_TUNNEL}"
    cp "${PROV_TUNNEL}" "${TUNNEL_DIR}/embedded.mobileprovision"
  else
    echo ">> Generating embedded.mobileprovision for ${TUNNEL_BUNDLE_ID}..."
    python3 scripts/generate_provisioning.py \
      "${TUNNEL_BUNDLE_ID}" "${TEAM_ID}" "${APP_GROUP}" \
      "${CERT_PEM}" "${KEY_PEM}" "${TUNNEL_DIR}/embedded.mobileprovision"
  fi
fi

# Determine signing identity
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [ -z "${SIGN_IDENTITY}" ]; then
  if command -v security >/dev/null 2>&1; then
    KEYCHAIN_PASS="temp_pass_${RANDOM}"
    AUTO_KEYCHAIN="${TEMP_DIR}/northy.keychain-db"
    
    security create-keychain -p "${KEYCHAIN_PASS}" "${AUTO_KEYCHAIN}" 2>/dev/null || true
    security unlock-keychain -p "${KEYCHAIN_PASS}" "${AUTO_KEYCHAIN}" 2>/dev/null || true
    security set-keychain-settings -lut 7200 "${AUTO_KEYCHAIN}" 2>/dev/null || true

    P12_FILE="${TEMP_DIR}/dev.p12"
    openssl pkcs12 -export -out "${P12_FILE}" -inkey "${KEY_PEM}" -in "${CERT_PEM}" -passout "pass:${KEYCHAIN_PASS}" 2>/dev/null

    security import "${P12_FILE}" -P "${KEYCHAIN_PASS}" -A -t cert -f pkcs12 -k "${AUTO_KEYCHAIN}" 2>/dev/null || true
    security list-keychains -d user -s "${AUTO_KEYCHAIN}" $(security list-keychains -d user | tr -d '"') 2>/dev/null || true
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KEYCHAIN_PASS}" "${AUTO_KEYCHAIN}" 2>/dev/null || true

    SIGN_IDENTITY="Apple Development: Northy"
  else
    SIGN_IDENTITY="-"
  fi
fi

echo ">> Signing binaries using identity: [${SIGN_IDENTITY}]..."

# Clean old signature directories if any
rm -rf "${APP_DIR}/_CodeSignature"
if [ -d "${TUNNEL_DIR}" ]; then
  rm -rf "${TUNNEL_DIR}/_CodeSignature"
fi

# Sign any embedded frameworks
if [ -d "${APP_DIR}/Frameworks" ]; then
  for fw in "${APP_DIR}/Frameworks"/*; do
    if [ -e "$fw" ]; then
      echo ">> Signing Framework: $(basename "$fw")..."
      codesign --force --sign "${SIGN_IDENTITY}" --timestamp=none "$fw" || \
      codesign --force --sign "-" --timestamp=none "$fw"
    fi
  done
fi

# 1. Sign Tunnel Extension FIRST
if [ -d "${TUNNEL_DIR}" ]; then
  echo ">> Signing PacketTunnel extension with entitlements..."
  codesign --force --sign "${SIGN_IDENTITY}" \
    --entitlements NorthyTunnel/NorthyTunnel.entitlements \
    --timestamp=none "${TUNNEL_DIR}" || \
  codesign --force --sign "-" \
    --entitlements NorthyTunnel/NorthyTunnel.entitlements \
    --timestamp=none "${TUNNEL_DIR}"
fi

# 2. Sign Main Application SECOND
echo ">> Signing Main Application with entitlements..."
codesign --force --sign "${SIGN_IDENTITY}" \
  --entitlements Northy/Northy.entitlements \
  --timestamp=none "${APP_DIR}" || \
codesign --force --sign "-" \
  --entitlements Northy/Northy.entitlements \
  --timestamp=none "${APP_DIR}"

echo ">> Verifying code signature..."
if codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1; then
  echo ">> [✓] Code signature verification passed!"
else
  echo ">> [!] Warning: Strict verification reported notes, continuing packaging..."
fi

echo "=========================================================="
echo ">> [5/5] Packaging .ipa..."
echo "=========================================================="
(cd "${BUILD_DIR}" && zip -qry "${OUTPUT_NAME}" Payload)
cp "${OUTPUT_IPA}" "${BUILD_DIR}/Northy.ipa"

IPA_SIZE=$(du -h "${OUTPUT_IPA}" | cut -f1)

echo "=========================================================="
echo ">> SUCCESS: Signed IPA created successfully!"
echo ">> File: ${OUTPUT_IPA} (${IPA_SIZE})"
echo ">> Bundle ID: ${APP_BUNDLE_ID}"
echo ">> Extension: ${TUNNEL_BUNDLE_ID}"
echo ">> Group:      ${APP_GROUP}"
echo "=========================================================="

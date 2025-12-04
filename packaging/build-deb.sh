#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="testssl_package"
CONTROL_FILE="${PKG_DIR}/DEBIAN/control"

# --- Read version from control file ---
read_version_from_control() {
    grep -E '^Version:' "$CONTROL_FILE" | awk '{print $2}'
}

# --- Determine VERSION ---
if [[ $# -ge 1 ]]; then
    # User supplied version argument
    VERSION="$1"
else
    # No argument → read version from control
    VERSION="$(read_version_from_control)"
fi

# --- Fail if version still empty ---
if [[ -z "${VERSION}" ]]; then
    echo "ERROR: No version provided and no Version field in control." >&2
    exit 1
fi

# --- Update control with the version ---
if grep -qE '^Version:' "$CONTROL_FILE"; then
    sed -i -E "s/^Version:.*/Version: ${VERSION}/" "$CONTROL_FILE"
else
    echo "Version: ${VERSION}" >> "$CONTROL_FILE"
fi

OUTPUT="testssl_${VERSION}_amd64.deb"

echo "Building ${OUTPUT} from ${PKG_DIR} ..."
echo "Using version: ${VERSION}"

if [ ! -d "${PKG_DIR}" ]; then
  echo "ERROR: ${PKG_DIR} not found." >&2
  exit 1
fi

# Ensure maintainer scripts executable
chmod 755 "${PKG_DIR}/DEBIAN/"{postinst,prerm,postrm} 2>/dev/null || true

# 🎯 NEW: Ensure all testssl runtime directories/files have correct permissions
TESTSSL_ROOT="${PKG_DIR}/opt/venarisecurity/bin/testssl.sh"

if [ -d "${TESTSSL_ROOT}" ]; then
    echo "Fixing permissions under ${TESTSSL_ROOT} ..."
    # Directories = 755
    find "${TESTSSL_ROOT}" -type d -exec chmod 755 {} \;

    # Shell scripts = 755
    find "${TESTSSL_ROOT}" -type f -name "*.sh" -exec chmod 755 {} \;

    # All other files = 644 (safe defaults)
    find "${TESTSSL_ROOT}" -type f ! -name "*.sh" -exec chmod 644 {} \;
else
    echo "WARNING: Missing directory ${TESTSSL_ROOT}" >&2
fi

# Ensure main script is executable
TARGET="${TESTSSL_ROOT}/testssl.sh"
if [ -f "$TARGET" ]; then
  chmod 755 "$TARGET"
else
  echo "WARNING: missing $TARGET" >&2
fi

# Build the package
fakeroot dpkg-deb --build "${PKG_DIR}" "${OUTPUT}"
echo "Built ${OUTPUT}"

dpkg -I "${OUTPUT}" || true

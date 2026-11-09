#!/usr/bin/env bash
# ==============================================================================
# CarrierLab — Repeatable Read-Only Diagnostic Test for iPhone Duo (iPhone19,4)
# Target Firmware: iOS 27.2 (Build 24B91020) | Baseband 1.02.05
# Execution Host: macOS Workstation with libimobiledevice installed
# ==============================================================================

set -euo pipefail

TIMESTAMP=$(date -u +"%Y%m%d_%H%M%SZ")
AUDIT_LOG="${HOME}/CarrierLab_Verification_${TIMESTAMP}.log"

echo "================================================================="
echo "CarrierLab — Real-Device Diagnostic Interrogation"
echo "Target: iPhone Duo (iPhone19,4) | iOS 27.2 | Baseband 1.02.05"
echo "Timestamp: ${TIMESTAMP}"
echo "================================================================="

# 1. Verify Prerequisites
if ! command -v ideviceinfo &> /dev/null; then
    echo "[-] Error: 'ideviceinfo' not found in PATH."
    echo "    Please install libimobiledevice via Homebrew: brew install libimobiledevice"
    exit 1
fi

if ! command -v idevice_id &> /dev/null; then
    echo "[-] Error: 'idevice_id' not found in PATH."
    exit 1
fi

# 2. Check Device Connection
echo "[+] Step 1: Checking USB-connected iOS devices..."
CONNECTED_DEVICES=$(idevice_id -l || true)
if [ -z "${CONNECTED_DEVICES}" ]; then
    echo "[-] No connected iOS device detected via usbmuxd."
    echo "    1. Reconnect iPhone via Apple USB cable."
    echo "    2. Unlock iPhone and select 'Trust This Computer'."
    exit 2
fi

PRIMARY_UDID=$(echo "${CONNECTED_DEVICES}" | head -n 1)
SANITIZED_UDID="••••••••••••••••••••••••••••••••••••${PRIMARY_UDID: -4}"
echo "    Connected Device Detected (Sanitized UDID: ${SANITIZED_UDID})"

# 3. Read-Only Query of Target Parameters
echo ""
echo "[+] Step 2: Querying lockdownd attributes..."
PRODUCT_TYPE=$(ideviceinfo -u "${PRIMARY_UDID}" -k ProductType 2>/dev/null || echo "Unknown")
PRODUCT_VERSION=$(ideviceinfo -u "${PRIMARY_UDID}" -k ProductVersion 2>/dev/null || echo "Unknown")
BUILD_VERSION=$(ideviceinfo -u "${PRIMARY_UDID}" -k BuildVersion 2>/dev/null || echo "Unknown")
BASEBAND_VERSION=$(ideviceinfo -u "${PRIMARY_UDID}" -k BasebandVersion 2>/dev/null || echo "Unknown")
BASEBAND_STATUS=$(ideviceinfo -u "${PRIMARY_UDID}" -k BasebandStatus 2>/dev/null || echo "Unknown")
ACTIVATION_STATE=$(ideviceinfo -u "${PRIMARY_UDID}" -k ActivationState 2>/dev/null || echo "Unknown")
SIM_STATUS=$(ideviceinfo -u "${PRIMARY_UDID}" -k SIMStatus 2>/dev/null || echo "Unknown")

echo "-----------------------------------------------------------------"
echo "ProductType:      ${PRODUCT_TYPE}"
echo "ProductVersion:   ${PRODUCT_VERSION}"
echo "BuildVersion:     ${BUILD_VERSION}"
echo "BasebandVersion:  ${BASEBAND_VERSION}"
echo "BasebandStatus:   ${BASEBAND_STATUS}"
echo "ActivationState:  ${ACTIVATION_STATE}"
echo "SIMStatus:        ${SIM_STATUS}"
echo "-----------------------------------------------------------------"

# 4. Firmware Baseline Assertion
echo ""
echo "[+] Step 3: Comparing against verified baseline..."
PASS_COUNT=0
TOTAL_CHECKS=4

if [ "${PRODUCT_TYPE}" = "iPhone19,4" ]; then
    echo "  [PASS] ProductType matches target baseline (iPhone19,4 / iPhone Duo)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [WARN] ProductType mismatch: expected iPhone19,4, got ${PRODUCT_TYPE}"
fi

if [ "${PRODUCT_VERSION}" = "27.2" ]; then
    echo "  [PASS] ProductVersion matches target baseline (27.2)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [WARN] ProductVersion mismatch: expected 27.2, got ${PRODUCT_VERSION}"
fi

if [ "${BUILD_VERSION}" = "24B91020" ]; then
    echo "  [PASS] BuildVersion matches target baseline (24B91020)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [WARN] BuildVersion mismatch: expected 24B91020, got ${BUILD_VERSION}"
fi

if [ "${BASEBAND_VERSION}" = "1.02.05" ]; then
    echo "  [PASS] BasebandVersion matches target baseline (1.02.05)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  [WARN] BasebandVersion mismatch: expected 1.02.05, got ${BASEBAND_VERSION}"
fi

# 5. Save Timestamped Audit Log
cat <<EOF > "${AUDIT_LOG}"
# CarrierLab Hardware Interrogation Audit Log
Timestamp: ${TIMESTAMP}
Sanitized_UDID: ${SANITIZED_UDID}
ProductType: ${PRODUCT_TYPE}
ProductVersion: ${PRODUCT_VERSION}
BuildVersion: ${BUILD_VERSION}
BasebandVersion: ${BASEBAND_VERSION}
BasebandStatus: ${BASEBAND_STATUS}
ActivationState: ${ACTIVATION_STATE}
SIMStatus: ${SIM_STATUS}
Baseline_Checks_Passed: ${PASS_COUNT}/${TOTAL_CHECKS}
EOF

echo ""
echo "[+] Step 4: Audit log successfully written to: ${AUDIT_LOG}"
echo "================================================================="

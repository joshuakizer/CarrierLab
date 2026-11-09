# CarrierLab Diagnostic & Security Audit Report (Corrected)

- **Report ID:** `REP-20261109004911`
- **Timestamp:** `2026-11-09T00:49:11.242767+00:00`
- **Tool Version:** `CarrierLab v1.0.0 (Phase 1 Correction)`
- **Physical Connection Status:** `Disconnected`

---

## 1. Category A: Verified Through Executed Tests

### Host Build Environment
- **Operating System:** Linux (6.12.105+)
- **Architecture:** x86_64
- **Compilers:** clang=/usr/bin/clang, gcc=/usr/bin/gcc, swift=Not installed
- **libimobiledevice:** {"ideviceinfo": "Not installed", "idevice_id": "Not installed", "usbmuxd": "Not installed", "idevicepair": "Not installed"}
- **USB Subsystem Status:** {"sysfs_usb_exists": false, "sysfs_devices": [], "usbmuxd_socket_exists": false}

### Physical Device Telemetry (Observed Directly by Diagnostic Tool)
- **ProductType (Hardware Model):** `None / Disconnected`
- **ProductVersion (iOS Version):** `None / Disconnected`
- **BuildVersion (OS Build):** `None / Disconnected`
- **BasebandVersion (Modem Firmware):** `None / Disconnected`
- **BasebandStatus:** `None / Disconnected`
- **ActivationState:** `None / Disconnected`
- **Sanitized UDID:** `None / Disconnected`
- **Sanitized Serial:** `None / Disconnected`
- **Sanitized IMEI:** `None / Disconnected`

### Raw Diagnostic Errors & Probes
- `Mock socket absent`

---

## 2. Category B: Reported by Device Owner (Unverified by Direct Diagnostic)

The following claims were provided as user premises and have NOT been verified by real-time hardware telemetry:
- **Device Model Identity:** `iPhone Duo`
- **Operating System Version:** `iOS 27.2`
- **Carrier Affiliation:** `Verizon`
- **Financial Status:** `Unverified`
- **Carrier Lock Setting:** `Unverified`
- **Finder Recognition Status:** `Unverified`

---

## 3. Category C: Supported by Cited Public Research

### A. libimobiledevice / lockdownd
- **Capability:** Non-invasive protocol over `usbmuxd` (port 27015 or `/var/run/usbmuxd`) to query `lockdownd` (port 62078).
- **Evidence:** Source code analysis of `github.com/libimobiledevice/libimobiledevice`. Supports reading `ProductType`, `ProductVersion`, `BuildVersion`, `BasebandVersion`, `BasebandStatus`, and `ActivationState`.
- **Limitation:** Read-only diagnostics. Cannot modify or bypass carrier activation policies.

### B. seemoo-lab / BaseTrace
- **Capability:** Framework for inspecting AP-to-Baseband IPC over PCIe / MHI / USB.
- **Evidence:** Source code analysis of `github.com/seemoo-lab/BaseTrace` (SEEMOO Lab, TU Darmstadt). Qualcomm basebands communicate via Qualcomm MSM Interface (QMI); Apple/Intel basebands communicate via Apple Remote Invocation (ARI).
- **Limitation:** Packet injection (`qmi-inject`) requires root/kernel privileges (jailbreak). BaseTrace provides cellular protocol tracing, but cannot synthesize cryptographic activation tickets.

### C. userlandkernel / baseband-research
- **Capability:** Documents 32-bit Qualcomm basebands (iPhone 4/4S/5 era) running OKL4 microkernel.
- **Evidence:** Analysis of `github.com/userlandkernel/baseband-research`.
- **Limitation:** Obsolete for modern 64-bit devices. Modern basebands enforce hardware Secure Boot, Baseband TSS verification, memory tagging, and AP isolation.

### D. Apple Activation Architecture & Cryptographic Enforcement
- **Evidence:** Apple Platform Security Guide, GSX activation documentation, and cellular modem boot architecture.
- **Mechanism:** Carrier locking is enforced via cryptographically signed Activation Records (`WildcardTickets`) issued by Apple Activation Servers (`albert.apple.com`). The baseband verifies Apple's RSA/ECDSA signature against root keys in ROM before registering on cellular networks.

---

## 4. Category D: Hypotheses Requiring Confirmation

- **Hypothesis:** Model 'iPhone Duo' is unreleased / unverified

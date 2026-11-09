# CarrierLab Diagnostic & Security Audit Report (Corrected)

- **Report ID:** `REP-20261109012110`
- **Timestamp:** `2026-11-09T01:21:10.395306+00:00`
- **Tool Version:** `CarrierLab v1.0.0 (Phase 1 Correction)`
- **Physical Connection Status:** `Disconnected (Antigravity runs on remote Linux sandbox without physical USB access)`

---

## 1. Category A: Verified Through Executed Tests

### Host Build Environment
- **Operating System:** Linux (6.12.105+)
- **Architecture:** x86_64
- **Compilers:** clang=/usr/bin/clang, gcc=/usr/bin/gcc, swift=Not installed
- **libimobiledevice:** {"ideviceinfo": "Not installed", "idevice_id": "Not installed", "usbmuxd": "Not installed", "idevicepair": "Not installed"}
- **USB Subsystem Status:** {"sysfs_usb_exists": false, "sysfs_devices": [], "usbmuxd_socket_exists": false}

### Physical Device Telemetry (Observed Directly by Diagnostic Tool)
- **ProductType (Hardware Model):** `None`
- **ProductVersion (iOS Version):** `None`
- **BuildVersion (OS Build):** `None`
- **BasebandVersion (Modem Firmware):** `None`
- **BasebandStatus:** `None`
- **ActivationState:** `None`
- **Sanitized UDID:** `None`
- **Sanitized Serial:** `None`
- **Sanitized IMEI:** `None`

### Raw Diagnostic Errors & Probes
- `usbmuxd socket probe: UNIX socket not found at /var/run/usbmuxd. usbmuxd daemon is not running.`
- `libimobiledevice CLI probe: No device detected via libimobiledevice CLI tools.`

---

## 2. Category B: Physical-Device Evidence (Obtained on User's Mac)

The following parameters were obtained directly via libimobiledevice on the physical Mac and provided for the research baseline:
- **Acquisition Source:** `Verified Terminal output via libimobiledevice on user's physical Mac`
- **ProductType (Hardware Model):** `iPhone19,4` (iPhone Duo)
- **ProductVersion (iOS Version):** `27.2`
- **BuildVersion (OS Build):** `24B91020`
- **BasebandVersion (Modem Firmware):** `1.02.05`
- **Carrier Affiliation:** `Verizon`
- **Carrier Lock Setting:** `SIM locked`
- **Financial Status:** `Financed (Active installment agreement)`
- **Finder Status:** `Recognized in macOS Finder`

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

- **Hypothesis:** Modem Architecture for Baseband 1.02.05: The version string '1.02.05' indicates an early-cycle revision typical of a new modem generation (e.g. Apple in-house modem or next-generation baseband). Hypothesis requires confirmation via baseband chipset interrogation.
- **Hypothesis:** Carrier Lock Integrity on Build 24B91020: Enforced via cryptographically signed Activation Tickets verified by the baseband secure boot engine. The hypothesis that local carrier lock enforcement can be circumvented remains unverified and lacks demonstration.
- **Hypothesis:** AP-to-Baseband IPC Endpoint Analysis: Passive monitoring of lockdownd cache on macOS may reveal whether custom Verizon bundle policies or Carrier Prerogatives are applied.

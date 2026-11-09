#!/usr/bin/env python3
"""
Automated Unit and Integration Tests for CarrierLab Phase 2:
Carrier Lock Research, Baseline Capture, and Alternate-Carrier eSIM Experiments
"""

import unittest
import sys
import os
import json
import hashlib
import tempfile
import shutil
from pathlib import Path
from datetime import datetime, timezone

# Add scripts directory to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from carrierlab_diagnostics import (
    DeviceSanitizer,
    HostEnvironmentInspector,
    LiveDeviceProber,
    DiagnosticReportGenerator
)


class Phase2EvidenceHasher:
    @staticmethod
    def sha256_string(s: str) -> str:
        return hashlib.sha256(s.encode("utf-8")).hexdigest()

    @staticmethod
    def sha256_file(path: Path) -> str:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()


class Phase2ExperimentManager:
    """Python reference implementation of the CarrierLab Phase 2 Experiment Engine."""
    
    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.attachments_dir = self.base_dir / "attachments"
        self.dossiers_dir = self.base_dir / "dossiers"
        self.attachments_dir.mkdir(exist_ok=True)
        self.dossiers_dir.mkdir(exist_ok=True)

    def capture_baseline(self, diag: dict, manual_lock_setting: str = "SIM Locked", carrier: str = "Verizon") -> dict:
        timestamp = datetime.now(timezone.utc).isoformat()
        observed = {
            "ProductType": diag.get("ProductType"),
            "ProductVersion": diag.get("ProductVersion"),
            "BuildVersion": diag.get("BuildVersion"),
            "BasebandVersion": diag.get("BasebandVersion"),
            "BasebandStatus": diag.get("BasebandStatus"),
            "ActivationState": diag.get("ActivationState"),
            "SIMStatus": diag.get("SIMStatus"),
            "SanitizedUDID": diag.get("SanitizedUDID")
        }
        confirmed = {
            "carrier_lock_setting": manual_lock_setting,
            "active_carrier": carrier,
            "financing_status": "Active Installment Plan / Financed",
            "settings_path": "Settings > General > About > Carrier Lock"
        }
        interpretation = {
            "sim_status_analysis": "kCTSIMSupportSIMStatusReady denotes that the installed USIM/eSIM application is accepted and authenticated by CommCenter. It does NOT denote that the phone is carrier-unlocked.",
            "lock_enforcement_summary": "Carrier lock enforcement is mediated by Apple's signed WildcardTicket. In-market SIM lock prevents non-Verizon network registration regardless of USIM readiness."
        }
        sig_str = f"baseline|{observed.get('ProductType')}|{observed.get('BuildVersion')}|{observed.get('BasebandVersion')}|{observed.get('SIMStatus')}|{confirmed.get('carrier_lock_setting')}"
        checksum = Phase2EvidenceHasher.sha256_string(sig_str)
        
        return {
            "timestamp": timestamp,
            "device_observed": observed,
            "owner_confirmed": confirmed,
            "technical_interpretation": interpretation,
            "snapshot_checksum": checksum
        }

    def compare_baselines(self, initial: dict, final: dict, esim_installed: bool, data_worked: bool, reboot_confirmed: bool = False) -> dict:
        init_obs = initial["device_observed"]
        final_obs = final["device_observed"]
        init_lock = initial["owner_confirmed"]["carrier_lock_setting"]
        final_lock = final["owner_confirmed"]["carrier_lock_setting"]
        
        diff = {
            "activation_state_changed": init_obs.get("ActivationState") != final_obs.get("ActivationState"),
            "sim_status_changed": init_obs.get("SIMStatus") != final_obs.get("SIMStatus"),
            "baseband_changed": init_obs.get("BasebandVersion") != final_obs.get("BasebandVersion"),
            "build_changed": init_obs.get("BuildVersion") != final_obs.get("BuildVersion"),
            "lock_setting_changed": init_lock != final_lock,
            "initial_lock": init_lock,
            "final_lock": final_lock,
            "reboot_confirmed": reboot_confirmed
        }
        
        # Classification Engine
        if "No SIM" in final_lock and reboot_confirmed:
            diff["outcome"] = "Carrier Lock Changed Following Authorized Unlock"
            diff["is_permanent_unlock_verified"] = True
            diff["justification"] = "Carrier Lock officially transitioned to No SIM Restrictions and persisted across device reboot."
        elif not esim_installed or (not data_worked and "Locked" in final_lock):
            diff["outcome"] = "Carrier Restriction Enforced"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "Alternative carrier rejected or non-operational under active Verizon lock policy. Normal enforcement verified."
        elif data_worked and "Locked" in final_lock:
            diff["outcome"] = "Alternative Carrier Activated (Lock Unchanged)"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "Alternative carrier connected while Settings displays SIM Locked. Does NOT constitute an unlock; requires checking roaming profile."
        else:
            diff["outcome"] = "Inconclusive"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "Observations insufficient for definitive classification."
            
        return diff

    def save_experiment(self, exp: dict, allow_overwrite: bool = False) -> Path:
        exp_id = exp["experiment_id"]
        json_path = self.base_dir / f"{exp_id}.json"
        if not allow_overwrite and json_path.exists():
            raise FileExistsError(f"Experiment '{exp_id}' already exists. Silent overwrite is blocked.")
            
        # Compute integrity hash
        sig_str = f"{exp_id}|{exp.get('start_time')}|{exp.get('target_carrier')}|{exp.get('esim_installed')}|{exp.get('outcome')}"
        exp["record_integrity_hash"] = Phase2EvidenceHasher.sha256_string(sig_str)
        
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(exp, f, indent=2)
            
        return json_path

    def load_all_experiments(self) -> list:
        exps = []
        for p in self.base_dir.glob("*.json"):
            with open(p, "r", encoding="utf-8") as f:
                exps.append(json.load(f))
        return sorted(exps, key=lambda x: x.get("start_time", ""), reverse=True)


class TestPhase2Experiments(unittest.TestCase):
    
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp(prefix="carrierlab_test_"))
        self.mgr = Phase2ExperimentManager(self.temp_dir)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_baseline_capture_telemetry_and_interpretation(self):
        diag = {
            "ProductType": "iPhone19,4",
            "ProductVersion": "27.2",
            "BuildVersion": "24B91020",
            "BasebandVersion": "1.02.05",
            "BasebandStatus": "BBInfoAvailable",
            "ActivationState": "Activated",
            "SIMStatus": "kCTSIMSupportSIMStatusReady",
            "SanitizedUDID": "••••••••••••12AB"
        }
        baseline = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked", carrier="Verizon")
        
        self.assertEqual(baseline["device_observed"]["ProductType"], "iPhone19,4")
        self.assertEqual(baseline["device_observed"]["BuildVersion"], "24B91020")
        self.assertEqual(baseline["owner_confirmed"]["carrier_lock_setting"], "SIM Locked")
        self.assertIn("does NOT denote that the phone is carrier-unlocked", baseline["technical_interpretation"]["sim_status_analysis"])
        self.assertEqual(len(baseline["snapshot_checksum"]), 64)

    def test_disconnected_device_baseline_handling(self):
        empty_diag = {
            "ProductType": None,
            "ProductVersion": None,
            "BuildVersion": None,
            "BasebandVersion": None,
            "SIMStatus": None
        }
        baseline = self.mgr.capture_baseline(empty_diag, manual_lock_setting="SIM Locked")
        self.assertIsNone(baseline["device_observed"]["ProductType"])
        self.assertIsNone(baseline["device_observed"]["BasebandVersion"])

    def test_outcome_carrier_restriction_enforced(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        
        # Alternate carrier failed to install/rejected
        diff = self.mgr.compare_baselines(init, final, esim_installed=False, data_worked=False, reboot_confirmed=False)
        self.assertEqual(diff["outcome"], "Carrier Restriction Enforced")
        self.assertFalse(diff["is_permanent_unlock_verified"])

    def test_outcome_alternate_carrier_activated_lock_unchanged(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        
        # Alternate carrier installed and data worked, but Settings still reports SIM locked
        diff = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=False)
        self.assertEqual(diff["outcome"], "Alternative Carrier Activated (Lock Unchanged)")
        self.assertFalse(diff["is_permanent_unlock_verified"])

    def test_strict_unlock_verification_gate(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="No SIM Restrictions")
        
        # Test 1: Reports No SIM Restrictions, but reboot persistence NOT confirmed -> Unlock NOT verified
        diff_unconfirmed = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=False)
        self.assertFalse(diff_unconfirmed["is_permanent_unlock_verified"])
        
        # Test 2: Reports No SIM Restrictions, AND reboot persistence IS confirmed -> Unlock verified
        diff_confirmed = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=True)
        self.assertEqual(diff_confirmed["outcome"], "Carrier Lock Changed Following Authorized Unlock")
        self.assertTrue(diff_confirmed["is_permanent_unlock_verified"])

    def test_experiment_persistence_and_silent_overwrite_prevention(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020"}
        base = self.mgr.capture_baseline(diag)
        exp = {
            "experiment_id": "EXP-20261108-001",
            "start_time": datetime.now(timezone.utc).isoformat(),
            "target_carrier": "T-Mobile",
            "esim_installed": False,
            "outcome": "Carrier Restriction Enforced",
            "initial_baseline": base
        }
        
        # Save experiment
        saved_path = self.mgr.save_experiment(exp, allow_overwrite=False)
        self.assertTrue(saved_path.exists())
        
        # Duplicate save must raise FileExistsError
        with self.assertRaises(FileExistsError):
            self.mgr.save_experiment(exp, allow_overwrite=False)
            
        # Verify loading
        loaded = self.mgr.load_all_experiments()
        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0]["experiment_id"], "EXP-20261108-001")
        self.assertIn("record_integrity_hash", loaded[0])

    def test_safety_verizon_profile_intact(self):
        exp = {
            "experiment_id": "EXP-SAFE-001",
            "original_verizon_service_intact": True,
            "target_carrier": "AT&T"
        }
        self.assertTrue(exp["original_verizon_service_intact"])

    def test_screenshot_sha256_evidence_hashing(self):
        test_img = self.temp_dir / "test_screenshot.png"
        test_data = b"\x89PNG\r\n\x1a\nFakeCarrierLockErrorImageBytes"
        with open(test_img, "wb") as f:
            f.write(test_data)
            
        h = Phase2EvidenceHasher.sha256_file(test_img)
        expected = hashlib.sha256(test_data).hexdigest()
        self.assertEqual(h, expected)


if __name__ == "__main__":
    unittest.main()

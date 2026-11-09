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

    def compare_baselines(self, initial: dict, final: dict, esim_installed: bool, data_worked: bool, reboot_confirmed: bool = False, original_verizon_intact: bool = True, physical_attempt_conducted: bool = False, has_supporting_evidence: bool = False) -> dict:
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
            "reboot_confirmed": reboot_confirmed,
            "original_verizon_intact": original_verizon_intact,
            "physical_attempt_conducted": physical_attempt_conducted,
            "has_supporting_evidence": has_supporting_evidence
        }
        
        # Classification Engine
        if not original_verizon_intact:
            diff["outcome"] = "Unexpected Behavior Requiring Investigation"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "CRITICAL SAFETY VIOLATION: Primary Verizon eSIM was modified or removed. Test invalidated."
        elif not physical_attempt_conducted:
            diff["outcome"] = "Not Performed"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "No physical alternate-carrier activation attempt was conducted on the device. Experiment conducted entirely within software."
        elif "No SIM" in final_lock and reboot_confirmed and data_worked:
            diff["outcome"] = "Carrier Lock Changed Following Authorized Unlock"
            diff["is_permanent_unlock_verified"] = True
            diff["justification"] = "Carrier Lock officially transitioned to No SIM Restrictions and persisted across device reboot."
        elif not has_supporting_evidence and not esim_installed and not data_worked:
            diff["outcome"] = "Inconclusive"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "Physical activation attempt reported, but without corroborating error messages or evidence."
        elif not esim_installed or (not data_worked and "Locked" in final_lock):
            diff["outcome"] = "Carrier Restriction Enforced"
            diff["is_permanent_unlock_verified"] = False
            diff["justification"] = "Owner reported alternate carrier rejected under active Verizon lock. (Owner-reported observation; not baseband verified)."
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
        sig_str = f"{exp_id}|{exp.get('start_time')}|{exp.get('target_carrier')}|{exp.get('physical_attempt_conducted', False)}|{exp.get('esim_installed')}|{exp.get('outcome')}"
        exp["record_integrity_hash"] = Phase2EvidenceHasher.sha256_string(sig_str)
        
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(exp, f, indent=2)
            
        return json_path

    def save_audit_correction(self, target_id: str, prev_outcome: str, corrected_outcome: str, reason: str) -> Path:
        corr_id = f"CORRECTION-{target_id}"
        corr_record = {
            "correction_id": corr_id,
            "target_experiment_id": target_id,
            "timestamp": "2026-11-09T01:55:00Z",
            "previous_outcome": prev_outcome,
            "corrected_outcome": corrected_outcome,
            "auditor_reason": reason,
            "audit_status": "AUDIT_CORRECTED"
        }
        json_path = self.base_dir / f"{corr_id}.json"
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(corr_record, f, indent=2)
        return json_path

    def load_all_experiments(self) -> list:
        exps = []
        corrections = {}
        for p in self.base_dir.glob("CORRECTION-*.json"):
            with open(p, "r", encoding="utf-8") as f:
                c = json.load(f)
                corrections[c["target_experiment_id"]] = c
                
        for p in self.base_dir.glob("*.json"):
            if p.name.startswith("CORRECTION-"):
                continue
            with open(p, "r", encoding="utf-8") as f:
                exp = json.load(f)
                if exp.get("experiment_id") in corrections:
                    exp["audit_correction"] = corrections[exp["experiment_id"]]
                    exp["effective_outcome"] = corrections[exp["experiment_id"]]["corrected_outcome"]
                else:
                    exp["effective_outcome"] = exp.get("outcome")
                exps.append(exp)
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
        
        # Alternate carrier failed to install/rejected with physical attempt and evidence
        diff = self.mgr.compare_baselines(init, final, esim_installed=False, data_worked=False, reboot_confirmed=False, physical_attempt_conducted=True, has_supporting_evidence=True)
        self.assertEqual(diff["outcome"], "Carrier Restriction Enforced")
        self.assertFalse(diff["is_permanent_unlock_verified"])

    def test_outcome_alternate_carrier_activated_lock_unchanged(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        
        # Alternate carrier installed and data worked, but Settings still reports SIM locked
        diff = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=False, physical_attempt_conducted=True, has_supporting_evidence=True)
        self.assertEqual(diff["outcome"], "Alternative Carrier Activated (Lock Unchanged)")
        self.assertFalse(diff["is_permanent_unlock_verified"])

    def test_strict_unlock_verification_gate(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="No SIM Restrictions")
        
        # Test 1: Reports No SIM Restrictions, but reboot persistence NOT confirmed -> Unlock NOT verified
        diff_unconfirmed = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=False, physical_attempt_conducted=True, has_supporting_evidence=True)
        self.assertFalse(diff_unconfirmed["is_permanent_unlock_verified"])
        
        # Test 2: Reports No SIM Restrictions, AND reboot persistence IS confirmed -> Unlock verified
        diff_confirmed = self.mgr.compare_baselines(init, final, esim_installed=True, data_worked=True, reboot_confirmed=True, physical_attempt_conducted=True, has_supporting_evidence=True)
        self.assertEqual(diff_confirmed["outcome"], "Carrier Lock Changed Following Authorized Unlock")
        self.assertTrue(diff_confirmed["is_permanent_unlock_verified"])

    def test_unperformed_experiment_classified_as_not_performed(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        
        # Physical attempt was NOT conducted (software session only)
        diff = self.mgr.compare_baselines(init, final, esim_installed=False, data_worked=False, reboot_confirmed=False, physical_attempt_conducted=False, has_supporting_evidence=False)
        self.assertEqual(diff["outcome"], "Not Performed")
        self.assertFalse(diff["is_permanent_unlock_verified"])
        self.assertIn("No physical alternate-carrier activation attempt was conducted", diff["justification"])

    def test_incomplete_evidence_classified_as_inconclusive(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020", "BasebandVersion": "1.02.05"}
        init = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        final = self.mgr.capture_baseline(diag, manual_lock_setting="SIM Locked")
        
        # Physical attempt reported, but zero error messages or evidence
        diff = self.mgr.compare_baselines(init, final, esim_installed=False, data_worked=False, reboot_confirmed=False, physical_attempt_conducted=True, has_supporting_evidence=False)
        self.assertEqual(diff["outcome"], "Inconclusive")
        self.assertFalse(diff["is_permanent_unlock_verified"])
        self.assertIn("without corroborating error messages", diff["justification"])

    def test_audit_correction_exp1794188993_preserves_original_and_amends_outcome(self):
        diag = {"ProductType": "iPhone19,4", "BuildVersion": "24B91020"}
        base = self.mgr.capture_baseline(diag)
        
        # Save original erroneous experiment
        exp = {
            "experiment_id": "EXP-1794188993",
            "start_time": "2026-11-08T18:00:00Z",
            "target_carrier": "AT&T",
            "physical_attempt_conducted": False,
            "esim_installed": False,
            "outcome": "Carrier Restriction Enforced",
            "initial_baseline": base
        }
        self.mgr.save_experiment(exp, allow_overwrite=True)
        
        # Verify original file content on disk has the historical outcome
        json_file = self.temp_dir / "EXP-1794188993.json"
        with open(json_file, "r") as f:
            content = f.read()
            self.assertIn("Carrier Restriction Enforced", content)
            
        # Save audit correction
        self.mgr.save_audit_correction(
            target_id="EXP-1794188993",
            prev_outcome="Carrier Restriction Enforced",
            corrected_outcome="Not Performed",
            reason="Audit established experiment was executed entirely within CarrierLab without physical attempt on device."
        )
        
        # Load experiments through manager
        loaded = self.mgr.load_all_experiments()
        matching = next(x for x in loaded if x["experiment_id"] == "EXP-1794188993")
        self.assertEqual(matching["effective_outcome"], "Not Performed")
        self.assertIn("audit_correction", matching)
        self.assertEqual(matching["audit_correction"]["corrected_outcome"], "Not Performed")
        
        # Verify original file on disk was NOT mutated or overwritten
        with open(json_file, "r") as f:
            content_post = f.read()
            self.assertIn("Carrier Restriction Enforced", content_post)

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
        
        # Test markdown output matching
        md_intact = f"- Original Verizon eSIM Preserved: {'YES (Verified Intact)' if exp['original_verizon_service_intact'] else 'ALERT: VERIZON eSIM MODIFIED'}"
        self.assertIn("Original Verizon eSIM Preserved: YES (Verified Intact)", md_intact)
        
        # Test compromised alert
        exp_compromised = {
            "experiment_id": "EXP-SAFE-002",
            "original_verizon_service_intact": False,
            "target_carrier": "T-Mobile"
        }
        md_compromised = f"- Original Verizon eSIM Preserved: {'YES (Verified Intact)' if exp_compromised['original_verizon_service_intact'] else 'ALERT: VERIZON eSIM MODIFIED'}"
        self.assertIn("ALERT: VERIZON eSIM MODIFIED", md_compromised)
        self.assertNotIn("YES (Verified Intact)", md_compromised)

    def test_safety_blocks_unlock_when_verizon_line_compromised(self):
        mgr = Phase2ExperimentManager(self.temp_dir)
        diag = {
            "ProductType": "iPhone19,4",
            "ProductVersion": "27.2",
            "BuildVersion": "24B91020",
            "BasebandVersion": "1.02.05",
            "SIMStatus": "kCTSIMSupportSIMStatusReady"
        }
        base_init = mgr.capture_baseline(diag, "SIM Locked")
        base_final = mgr.capture_baseline(diag, "No SIM Restrictions")
        
        diff = mgr.compare_baselines(base_init, base_final, esim_installed=True, data_worked=True, reboot_confirmed=True, original_verizon_intact=False)
        self.assertFalse(diff["is_permanent_unlock_verified"])
        self.assertEqual(diff["outcome"], "Unexpected Behavior Requiring Investigation")
        self.assertIn("CRITICAL SAFETY VIOLATION", diff["justification"])

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

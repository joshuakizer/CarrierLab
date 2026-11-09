#!/usr/bin/env python3
"""
Automated Unit and Integration Tests for CarrierLab Diagnostic Engine (Corrected)
"""

import unittest
import sys
import os
import json
from pathlib import Path

# Add scripts directory to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from carrierlab_diagnostics import (
    DeviceSanitizer,
    HostEnvironmentInspector,
    LiveDeviceProber,
    DiagnosticReportGenerator,
    REPORTS_DIR
)


class TestDeviceSanitizer(unittest.TestCase):
    
    def test_legacy_udid_sanitization(self):
        udid = "1234567890abcdef1234567890abcdef12345678"
        sanitized = DeviceSanitizer.sanitize_udid(udid)
        self.assertIsNotNone(sanitized)
        self.assertTrue(sanitized.endswith("5678"))
        self.assertNotIn("1234567890abcdef", sanitized)
        self.assertEqual(len(sanitized), len(udid))
        self.assertEqual(sanitized, "••••••••••••••••••••••••••••••••••••5678")

    def test_modern_udid_sanitization(self):
        udid = "00008110-00192837465012AB"
        sanitized = DeviceSanitizer.sanitize_udid(udid)
        self.assertIsNotNone(sanitized)
        self.assertTrue(sanitized.endswith("12AB"))
        self.assertNotIn("00008110", sanitized)

    def test_imei_sanitization(self):
        imei = "353014109876543"
        sanitized = DeviceSanitizer.sanitize_imei(imei)
        self.assertIsNotNone(sanitized)
        self.assertEqual(sanitized, "•••••••••••6543")
        self.assertNotIn("35301410", sanitized)

    def test_serial_number_sanitization(self):
        serial = "F2LZA1B2C3D4"
        sanitized = DeviceSanitizer.sanitize_serial(serial)
        self.assertIsNotNone(sanitized)
        self.assertEqual(sanitized, "•••••••••3D4")

    def test_empty_and_none_sanitization(self):
        self.assertIsNone(DeviceSanitizer.sanitize_udid(None))
        self.assertIsNone(DeviceSanitizer.sanitize_udid(""))
        self.assertIsNone(DeviceSanitizer.sanitize_imei(None))
        self.assertIsNone(DeviceSanitizer.sanitize_imei("   "))
        self.assertIsNone(DeviceSanitizer.sanitize_serial(None))

    def test_log_message_scrubbing(self):
        raw_log = "Error connecting to device 1234567890abcdef1234567890abcdef12345678 with IMEI 353014109876543 on port 62078"
        scrubbed = DeviceSanitizer.sanitize_log_message(raw_log)
        self.assertNotIn("1234567890abcdef1234567890abcdef", scrubbed)
        self.assertNotIn("35301410987", scrubbed)
        self.assertIn("••••••••••••••••••••••••••••••••••••5678", scrubbed)
        self.assertIn("•••••••••••6543", scrubbed)


class TestUnavailableFieldsHandling(unittest.TestCase):
    
    def test_missing_fields_not_fabricated(self):
        raw_payload = {
            "ProductType": "iPhone15,2",
            # BasebandVersion and ProductVersion omitted
        }
        
        # Generator must use "None / Disconnected" or None, never invent fake values
        report = DiagnosticReportGenerator.build_report(
            host_info={"system": "Linux"},
            connection_status="Disconnected",
            device_observed_telemetry=raw_payload,
            owner_reported_claims={"model_name": "iPhone Duo"},
            cited_public_research={},
            unverified_hypotheses=[],
            raw_errors=[]
        )
        
        md = DiagnosticReportGenerator.format_markdown(report)
        self.assertIn("`iPhone15,2`", md)
        self.assertIn("- **ProductVersion (iOS Version):** `None / Disconnected`", md)
        self.assertIn("- **BasebandVersion (Modem Firmware):** `None / Disconnected`", md)


class TestFourCategoryReportStructure(unittest.TestCase):
    
    def test_report_categorization(self):
        host_info = HostEnvironmentInspector.inspect()
        report = DiagnosticReportGenerator.build_report(
            host_info=host_info,
            connection_status="Disconnected",
            device_observed_telemetry=None,
            owner_reported_claims={
                "acquisition_source": "Verified Terminal output via libimobiledevice on user's physical Mac",
                "product_type": "iPhone19,4",
                "marketing_name": "iPhone Duo",
                "product_version": "27.2",
                "build_version": "24B91020",
                "baseband_version": "1.02.05",
                "carrier_name": "Verizon"
            },
            cited_public_research={
                "libimobiledevice": "Protocol library"
            },
            unverified_hypotheses=[
                "Modem Architecture for Baseband 1.02.05 requires chipset confirmation"
            ],
            raw_errors=["Mock socket absent"]
        )
        
        json_path, md_path = DiagnosticReportGenerator.save_report(report)
        self.assertTrue(json_path.exists())
        self.assertTrue(md_path.exists())
        
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            self.assertEqual(data["tool_version"], "CarrierLab v1.0.0 (Phase 1 Correction)")
            self.assertIn("category_a_verified_test_telemetry", data)
            self.assertIn("category_b_owner_reported_claims", data)
            self.assertEqual(data["category_b_owner_reported_claims"]["product_type"], "iPhone19,4")
            
        with open(md_path, "r", encoding="utf-8") as f:
            content = f.read()
            self.assertIn("## 1. Category A: Verified Through Executed Tests", content)
            self.assertIn("## 2. Category B: Physical-Device Evidence", content)
            self.assertIn("iPhone19,4", content)
            self.assertIn("24B91020", content)
            self.assertIn("1.02.05", content)
            self.assertIn("## 3. Category C: Supported by Cited Public Research", content)
            self.assertIn("## 4. Category D: Hypotheses Requiring Confirmation", content)


if __name__ == "__main__":
    unittest.main()

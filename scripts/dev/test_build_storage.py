#!/usr/bin/env python3
"""Checks that external build routing fails before creating internal output."""

import json
import contextlib
import io
from pathlib import Path
import plistlib
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import build_storage as storage


class BuildStorageTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.volume = self.base / "Samsung T7"
        self.volume.mkdir()
        self.config = self.base / "config.json"
        self.config.write_text(json.dumps({"volume": str(self.volume), "volume_uuid": "expected",
                                           "artifact_directory": "SF Build Artifacts"}))
        self.root = self.base / "SF/project"
        for name, value in [("CONFIG", self.config), ("ROOT", self.root)]:
            patcher = patch.object(storage, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def drive(self, uuid="expected", free=10 * 1024 ** 3):
        for patcher in [patch.object(storage.os.path, "ismount", return_value=True),
                        patch.object(storage.subprocess, "run", return_value=SimpleNamespace(
                            returncode=0, stdout=plistlib.dumps({"VolumeUUID": uuid, "Writable": True}))),
                        patch.object(storage.shutil, "disk_usage", return_value=SimpleNamespace(free=free))]:
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_disconnected_drive_does_not_create_output(self):
        with patch.object(storage.os.path, "ismount", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "Connect and unlock Samsung T7"):
                storage.output_path(None, "project/artifacts/android/new.aab")
        self.assertEqual(list(self.volume.iterdir()), [])

    def test_wrong_volume_is_rejected(self):
        self.drive(uuid="different")
        with self.assertRaisesRegex(RuntimeError, "wrong drive"):
            storage.storage_root()

    def test_full_volume_is_rejected(self):
        self.drive(free=100)
        with self.assertRaisesRegex(RuntimeError, "insufficient free space"):
            storage.storage_root()

    def test_original_workspace_output_routes_to_external_tree(self):
        self.drive()
        original = self.root.parent / "artifacts/releases/version/android/swarmfront.aab"
        self.assertEqual(storage.output_path(original, "unused"),
                         self.volume / "SF Build Artifacts/artifacts/releases/version/android/swarmfront.aab")

    def test_source_and_escaped_destinations_are_rejected(self):
        self.drive()
        for requested in [self.root / "assets/game.pck", self.base / "internal.aab"]:
            with self.assertRaises(RuntimeError):
                storage.output_path(requested, "unused")
        with self.assertRaises(RuntimeError):
            storage.output_path(None, "../../escaped.aab")

    def test_symlink_escape_is_rejected(self):
        self.drive()
        artifact_root = self.volume / "SF Build Artifacts"
        artifact_root.mkdir()
        (artifact_root / "escape").symlink_to(self.base, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            storage.output_path(None, "escape/new.aab")

    def test_unconfigured_checkout_keeps_existing_explicit_path_behavior(self):
        self.config.unlink()
        requested = self.base / "existing-release-location/new.aab"
        self.assertEqual(storage.output_path(requested, "unused"), requested)
        with self.assertRaises(RuntimeError):
            storage.storage_root(required=True)

    def test_path_command_accepts_required_flag_before_relative_path(self):
        self.drive()
        output = io.StringIO()
        with patch.object(storage.sys, "argv", ["build_storage.py", "path", "--required", "project/artifacts/new"]):
            with contextlib.redirect_stdout(output):
                storage.main()
        self.assertEqual(output.getvalue().strip(), str(self.volume / "SF Build Artifacts/project/artifacts/new"))


if __name__ == "__main__":
    unittest.main()

"""Synthetic, stdlib-only admission checks; no installed profiles or CBM I/O.

Run with: python -B patches/pi-cbm-011/tests/test_admission.py -v
"""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


PATCHER = Path(__file__).resolve().parents[1] / "apply.py"

# Exercise the real argument parser, commands, file reads/writes and process exit.
# Substitute only external CBM version/help responses, never admission or results.
CHILD = """
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cbm_patch", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
version, has_format = sys.argv[4:6]
def metadata(args):
    if args == ["--version"]:
        return "codebase-memory-mcp " + version
    if args == ["cli", "search_graph", "--help"]:
        return "--format <tree|json>" if has_format == "yes" else ""
    raise AssertionError("unexpected external CBM request: " + repr(args))
module.run_cbm = metadata
sys.argv = [sys.argv[1], "--agent-dir", sys.argv[2], sys.argv[3]]
raise SystemExit(module.main())
"""


def mixed_eol(body: bytes, alternating: bool = False) -> bytes:
    """Derive distinct EOL layouts only from the public canonical/store body."""
    lines = body.replace(b"\r\n", b"\n").splitlines(keepends=True)
    return b"".join(
        line[:-1] + b"\r\n"
        if line.endswith(b"\n") and (i % 2 == 0 if alternating else i < 107)
        else line
        for i, line in enumerate(lines)
    )


class AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("cbm_patch_fixture", PATCHER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls.pristine = module.pristine_path("1.2.1").read_bytes()
        canonical, problems = module.build_patched(cls.pristine.decode("utf-8"))
        if problems:
            raise AssertionError(problems)
        cls.canonical = canonical.encode("utf-8")
        cls.previous = module.previous_patched(canonical).encode("utf-8")
        crlf_stock = cls.pristine.decode("utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
        crlf_stock_canonical, problems = module.build_patched(crlf_stock)
        if problems:
            raise AssertionError(problems)
        cls.crlf_stock_canonical = crlf_stock_canonical.encode("utf-8")

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="cbm-admission-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.agent = self.root / "profile"
        self.pkg = self.agent / "npm" / "node_modules" / "pi-cbm"
        self.target = self.pkg / "src" / "cbm" / "client.ts"
        self.target.parent.mkdir(parents=True)
        self.package_version("1.2.1")
        self.backups = self.agent / ".pi-agent-build-backups" / "pi-cbm-011"

    def package_version(self, version):
        (self.pkg / "package.json").write_text(
            json.dumps({"name": "pi-cbm", "version": version}), encoding="utf-8"
        )

    def snapshot(self):
        return (
            self.target.read_bytes(),
            self.target.stat().st_mtime_ns,
            {p.name: p.read_bytes() for p in self.backups.glob("*")},
        )

    def invoke(self, operation, version="0.11.0", has_format=True):
        env = os.environ.copy()
        env["PI_CODING_AGENT_DIR"] = str(self.agent)
        result = subprocess.run(
            [sys.executable, "-B", "-c", CHILD, str(PATCHER), str(self.agent),
             operation, version, "yes" if has_format else "no"],
            cwd=self.root, env=env, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual("", result.stderr, result.stderr)
        return result

    def preserved(self, operation, expected, **kwargs):
        before = self.snapshot()
        backup_root_existed = self.backups.exists()
        result = self.invoke(operation, **kwargs)
        # Preservation assertions execute even when the expected status fails.
        self.assertEqual(before, self.snapshot(), result.stdout)
        self.assertEqual(backup_root_existed, self.backups.exists(), result.stdout)
        self.assertEqual(expected, result.returncode, result.stdout)
        return result.stdout

    def test_current_mixed_eol_check_and_apply_are_noops(self):
        for alternating in (False, True):
            with self.subTest(alternating=alternating):
                body = mixed_eol(self.canonical, alternating)
                self.assertIn(b"\r\n", body)
                self.assertIn(b"\n", body.replace(b"\r\n", b""))
                self.assertNotIn(body, (self.canonical, self.canonical.replace(b"\r\n", b"\n")))
                self.assertEqual(self.canonical.replace(b"\r\n", b"\n"), body.replace(b"\r\n", b"\n"))
                self.target.write_bytes(body)
                for operation, marker in (
                    ("--check", "ALREADY PATCHED"),
                    ("--apply", "idempotent"),
                    ("--apply", "idempotent"),
                ):
                    with self.subTest(operation=operation):
                        self.assertIn(marker, self.preserved(operation, 0))

    def test_public_crlf_stock_build_is_current_noop(self):
        # Recreate the original patcher's mixed output, not an installed fixture.
        body = self.crlf_stock_canonical
        self.assertIn(b"\r\n", body)
        self.assertIn(b"\n", body.replace(b"\r\n", b""))
        self.assertEqual(self.canonical.replace(b"\r\n", b"\n"), body.replace(b"\r\n", b"\n"))
        self.target.write_bytes(body)
        for operation in ("--check", "--apply"):
            with self.subTest(operation=operation):
                self.preserved(operation, 0)

    def test_exact_lf_and_crlf_current_are_noops(self):
        lf = self.canonical.replace(b"\r\n", b"\n")
        for body in dict.fromkeys((self.canonical, lf, lf.replace(b"\n", b"\r\n"))):
            with self.subTest(crlf=body.count(b"\r\n")):
                self.target.write_bytes(body)
                self.preserved("--check", 0)
                self.preserved("--apply", 0)

    def test_semantic_and_unknown_drift_is_refused_without_writes(self):
        mixed = mixed_eol(self.canonical)
        semantic = mixed.replace(b'format: "json"', b'format: "tree"', 1)
        self.assertNotEqual(mixed, semantic)
        self.assertIn(b"// [local-compat-patch]", semantic)
        bodies = {
            "semantic-edit": semantic,
            "previous-semantic-edit": mixed_eol(self.previous).replace(b'format: "json"', b'format: "tree"', 1),
            "extra-whitespace": mixed.replace(b"export class", b"export  class", 1),
            "bare-cr": mixed.replace(b"\r\n", b"\r", 1),
            "unknown-marker": b"// [local-compat-patch]\nunknown source\n",
            "eol-only-stock": mixed_eol(self.pristine, alternating=True),
        }
        self.assertNotEqual(self.pristine, bodies["eol-only-stock"])
        for name, body in bodies.items():
            for operation in ("--check", "--apply", "--restore"):
                with self.subTest(body=name, operation=operation):
                    self.target.write_bytes(body)
                    output = self.preserved(operation, 2)
                    self.assertRegex(output, "UNKNOWN STATE|REFUSING")

    def test_version_and_format_guards_preserve_mixed_current(self):
        self.target.write_bytes(mixed_eol(self.canonical))
        cases = (
            ("1.2.2", "0.11.0", True),
            ("1.2.1", "0.12.0", True),
            ("1.2.1", "", True),
            ("1.2.1", "0.11.0", False),
        )
        for package, cbm, has_format in cases:
            self.package_version(package)
            for operation in ("--check", "--apply"):
                with self.subTest(package=package, cbm=cbm, has_format=has_format, operation=operation):
                    self.preserved(operation, 2, version=cbm, has_format=has_format)
        self.package_version("1.2.2")
        self.preserved("--restore", 2)

    def test_mixed_current_restore_keeps_exact_backup_and_pristine(self):
        for alternating in (False, True):
            with self.subTest(alternating=alternating):
                body = mixed_eol(self.canonical, alternating)
                self.target.write_bytes(body)
                existing = set(self.backups.glob("*"))
                result = self.invoke("--restore")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertEqual(self.pristine, self.target.read_bytes())
                added = set(self.backups.glob("*")) - existing
                self.assertEqual(1, len(added))
                self.assertEqual(body, added.pop().read_bytes())
                self.preserved("--restore", 0)
                self.preserved("--check", 1)

    def test_stock_and_known_previous_transitions_backup_and_restore(self):
        previous_lf = self.previous.replace(b"\r\n", b"\n")
        bodies = {
            "stock": self.pristine,
            "previous": self.previous,
            "previous-lf": previous_lf,
            "previous-mixed": mixed_eol(self.previous),
        }
        for name, body in bodies.items():
            with self.subTest(source=name):
                self.target.write_bytes(body)
                self.preserved("--check", 1)
                existing = set(self.backups.glob("*"))
                result = self.invoke("--apply")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertEqual(self.canonical, self.target.read_bytes())
                added = set(self.backups.glob("*")) - existing
                self.assertEqual(1, len(added))
                self.assertEqual(body, added.pop().read_bytes())
                self.preserved("--check", 0)
                self.preserved("--apply", 0)
                existing = set(self.backups.glob("*"))
                result = self.invoke("--restore")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertEqual(self.pristine, self.target.read_bytes())
                added = set(self.backups.glob("*")) - existing
                self.assertEqual(1, len(added))
                self.assertEqual(self.canonical, added.pop().read_bytes())

    def test_previous_restore_remains_byte_exact(self):
        lf = self.previous.replace(b"\r\n", b"\n")
        for body in (self.previous, lf, mixed_eol(self.previous)):
            with self.subTest(crlf=body.count(b"\r\n")):
                self.target.write_bytes(body)
                existing = set(self.backups.glob("*"))
                result = self.invoke("--restore")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertEqual(self.pristine, self.target.read_bytes())
                added = set(self.backups.glob("*")) - existing
                self.assertEqual(1, len(added))
                self.assertEqual(body, added.pop().read_bytes())

    def test_pre011_stock_needs_no_patch(self):
        self.target.write_bytes(self.pristine)
        for operation in ("--check", "--apply"):
            self.preserved(operation, 0, version="0.8.1", has_format=False)


if __name__ == "__main__":
    unittest.main()

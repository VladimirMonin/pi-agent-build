#!/usr/bin/env python3
"""Apply the verified Pi Trace 0.1.16 localization/Windows/profile patch.

Modes:
  python apply.py --agent-dir <profile> --check
  python apply.py --agent-dir <profile> --apply
  python apply.py --agent-dir <profile> --restore

The patch is fail-closed: it only accepts exact Pi Trace 0.1.16 and known stock,
patched, or previously observed transitional file hashes. Runtime backups are
kept under the selected Pi profile, never inside this Git repository.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

VERSION = "0.1.16"
HERE = Path(__file__).resolve().parent
PAYLOAD = HERE / "payload"
FILES = {
    "index.ts": {
        "stock": "ac370c5fd06d3ae6fbb62a1fe807b49eef74c5e6d6bc71d81b1f4c2fd8bbb12b",
        "patched": "822fa2a21e87a99b09940f1c9f59773b1558b761cd584d9dcf6c6a11f56b98a4",
        "transitional": [],
    },
    "trace_to_html.py": {
        "stock": "3684c5a787d416eb08d7cb6eae942e6a550b53a608086712e013fe093f09c2ba",
        "patched": "1d464dcc269c3a2d3244416a0cbe11c7f5264f5bd53aea40c7ee1c7aed9ab290",
        "transitional": ["23e035325641186c3df9fe358da283beb4081fdd62946940a57e8c5571d85bd5"],
    },
    "viewer/viewer.html": {
        "stock": "243accc49e55b1f34a31d7022170e37f8eb058d567670d5db610ee06bd3e71e1",
        "patched": "c5d3555f40478ce0236a4d67a55d393dc49fb3b883665050c91c0e0b06d1217b",
        "transitional": [],
    },
    "viewer/viewer.js": {
        "stock": "363877fa05f6d7236e645ffaae7353d6d415282cea246d61a52f840ceef8ed19",
        "patched": "079024ea369a772876ac3960d0834635c1a7c652951a5f905a86378b825fe2b1",
        "transitional": ["7c3937222fb1358edc92aa8ceb5787f837c848069467874267cba1d09e30441c"],
    },
    "viewer/dashboard.html": {
        "stock": "144b110fc59352af02d9cea8a56b401800e054681339081ab0daaa80a30d90fa",
        "patched": "03d3683628d5cd39dbade35de973852d71fbad7101760bedba9ad71a84d2d6a2",
        "transitional": [],
    },
    "viewer/dashboard.js": {
        "stock": "52ba28818a7c3f90e9309629aee9eafc9be1c3965eb5d46e03ab99b1d8c45cdd",
        "patched": "5177eb2f49b58fc72ac7ac9b862147db94908f6cbb30e3ae3c3a438cff40a5e0",
        "transitional": [],
    },
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_agent_dir(value: str | None) -> Path:
    return Path(
        value
        or os.environ.get("PI_CODING_AGENT_DIR", "")
        or Path.home() / ".pi" / "agent"
    ).expanduser().resolve()


def package_root(agent_dir: Path) -> Path:
    return agent_dir / "npm" / "node_modules" / "pi-trace-extension" / "extensions" / "trace"


def assert_package(root: Path) -> None:
    package_json = root.parents[1] / "package.json"
    if not package_json.exists():
        raise RuntimeError(f"package.json not found: {package_json}")
    actual = json.loads(package_json.read_text(encoding="utf-8")).get("version")
    if actual != VERSION:
        raise RuntimeError(f"unsupported pi-trace-extension {actual}; expected exactly {VERSION}")
    for rel, meta in FILES.items():
        payload = PAYLOAD / rel
        if not payload.exists():
            raise RuntimeError(f"payload missing: {payload}")
        if digest(payload) != meta["patched"]:
            raise RuntimeError(f"payload checksum mismatch: {rel}")
        if not (root / rel).exists():
            raise RuntimeError(f"installed file missing: {root / rel}")


def states(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for rel, meta in FILES.items():
        current = digest(root / rel)
        if current == meta["patched"]:
            state = "patched"
        elif current == meta["stock"]:
            state = "stock"
        elif current in meta["transitional"]:
            state = "known-transitional"
        else:
            state = "unknown"
        result[rel] = state
    return result


def rebuild_assets(root: Path) -> None:
    build = root / "viewer" / "build.py"
    if not build.exists():
        raise RuntimeError(f"viewer builder missing: {build}")
    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    result = subprocess.run(
        [sys.executable, str(build)],
        cwd=str(build.parent),
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "unknown error").strip()
        raise RuntimeError(f"viewer build failed: {detail}")
    assets = root / "viewer" / "assets.json"
    if not assets.exists():
        raise RuntimeError("viewer build reported success but assets.json is missing")


def create_backup(root: Path, backup_root: Path) -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    target = backup_root / stamp
    target.mkdir(parents=True, exist_ok=False)
    manifest = {"package": "pi-trace-extension", "version": VERSION, "files": []}
    for rel in FILES:
        src = root / rel
        dst = target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        manifest["files"].append({"path": rel, "sha256": digest(src)})
    assets = root / "viewer" / "assets.json"
    if assets.exists():
        dst = target / "viewer" / "assets.json"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(assets, dst)
        manifest["assetsSha256"] = digest(assets)
    (target / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return target


def latest_backup(backup_root: Path) -> Path:
    candidates = sorted(
        p for p in backup_root.iterdir() if p.is_dir() and (p / "manifest.json").exists()
    ) if backup_root.exists() else []
    if not candidates:
        raise RuntimeError(f"no runtime backup found under {backup_root}")
    return candidates[-1]


def check(root: Path) -> int:
    current = states(root)
    for rel, state in current.items():
        print(f"{state:20} {rel}")
    if all(state == "patched" for state in current.values()):
        print("ALREADY PATCHED")
        return 0
    if any(state == "unknown" for state in current.values()):
        print("UNKNOWN STATE — refusing automatic apply")
        return 2
    print("PATCH REQUIRED")
    return 1


def apply(root: Path, backup_root: Path) -> int:
    current = states(root)
    if all(state == "patched" for state in current.values()):
        print("ALREADY PATCHED")
        return 0
    unknown = [rel for rel, state in current.items() if state == "unknown"]
    if unknown:
        raise RuntimeError(f"unknown installed files; refusing overwrite: {unknown}")
    backup = create_backup(root, backup_root)
    print(f"runtime backup: {backup}")
    for rel in FILES:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PAYLOAD / rel, dst)
    rebuild_assets(root)
    after = states(root)
    if not all(state == "patched" for state in after.values()):
        raise RuntimeError(f"post-write verification failed: {after}")
    print("PATCHED — run /reload, then /trace and /trace all")
    return 0


def restore(root: Path, backup_root: Path) -> int:
    unknown = [rel for rel, state in states(root).items() if state == "unknown"]
    if unknown:
        raise RuntimeError(f"unknown installed files; refusing restore overwrite: {unknown}")
    source = latest_backup(backup_root)
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or set(manifest) - {"package", "version", "files", "assetsSha256"}:
        raise RuntimeError("unknown backup manifest structure")
    if manifest.get("package") != "pi-trace-extension" or manifest.get("version") != VERSION:
        raise RuntimeError("backup package/version mismatch")
    items = manifest.get("files")
    if not isinstance(items, list) or len(items) != len(FILES):
        raise RuntimeError("backup must contain the exact patch file inventory")
    seen = set()
    # Validate the entire backup before the first write; a late corrupt entry
    # must not leave an earlier file restored or escape the selected package.
    for item in items:
        if not isinstance(item, dict) or set(item) != {"path", "sha256"}:
            raise RuntimeError("unknown backup file entry")
        rel = item["path"]
        if not isinstance(rel, str) or rel not in FILES or rel in seen:
            raise RuntimeError("unknown or duplicate backup path")
        seen.add(rel)
        src = source / rel
        allowed = {FILES[rel]["stock"], FILES[rel]["patched"], *FILES[rel]["transitional"]}
        if item["sha256"] not in allowed or not src.is_file() or digest(src) != item["sha256"]:
            raise RuntimeError(f"backup checksum/state mismatch: {rel}")
    assets = source / "viewer" / "assets.json"
    if "assetsSha256" in manifest:
        if not assets.is_file() or digest(assets) != manifest["assetsSha256"]:
            raise RuntimeError("backup assets checksum mismatch")
    elif assets.exists():
        raise RuntimeError("unrecorded backup assets refused")
    for item in items:
        rel = item["path"]
        shutil.copy2(source / rel, root / rel)
    if "assetsSha256" in manifest:
        shutil.copy2(assets, root / "viewer" / "assets.json")
    else:
        rebuild_assets(root)
    print(f"RESTORED from {source}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--agent-dir",
        help="Pi profile directory; default: PI_CODING_AGENT_DIR or ~/.pi/agent",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--restore", action="store_true")
    args = parser.parse_args()
    agent_dir = resolve_agent_dir(args.agent_dir)
    root = package_root(agent_dir)
    backup_root = agent_dir / ".pi-agent-build-backups" / "trace-ru-windows-profile"
    try:
        assert_package(root)
        if args.check:
            return check(root)
        if args.apply:
            return apply(root, backup_root)
        return restore(root, backup_root)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

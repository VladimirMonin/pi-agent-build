#!/usr/bin/env python3
"""Exact pi-memory1.6 runtime, ordered turns and scoped automatic hybrid recall."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path: sys.path.insert(0, str(HERE))
from injection import apply_injection, is_injection_safe
VERSION = "1.6.1"
BACKUP = HERE / "stock-index.js"
EXPECTED_STOCK_SHA256 = "9517f79582b2ff71e510289c0e6d912744b3dc8a867aaa52758df371bd41891f"
PREVIOUS_161_SHA256 = "d05d1b54a59a69da08458d6a896be36fbc19286360642d1a0672169211c7d5a9"
# Published build source 248b6cb (last 1.5.0 canonical), not arbitrary old versions.
PREVIOUS_150_HASHES = {
    "b8d68f90bcdf4fa40b9a573c67f8ed19853d90e889e8c9ed2cf4021f50c6ce58": "previous-stock-1.5.0",
    "e3cf2b202f12c8053a769d23dd8f6e21e6088937d4bcbe83f44328401ee66ad2": "previous-patched-1.5.0",
}


WIN_MARKER = "// win32: `pi` — это .cmd-шим"

FIXED_SCOPE_MARKER = "// pi-memory ordered turns: session-local lexical state"

PROFILE_SETTINGS_MARKER = "// pi-memory profile settings: PI_CODING_AGENT_DIR"

SESSIONID_MARKER = "// ExtensionContext has no sessionId/session field"

LEGACY_GLOBAL = "globalThis.__piMemoryTurns"

SESSIONID_FROM = "      sessionId = ctx.sessionId ?? ctx.session?.id;"

SESSIONID_TO = '''      // ExtensionContext has no sessionId/session field; read the real id from
      // the read-only session manager so consolidation labels facts correctly.
      sessionId = ctx.sessionManager?.getSessionId?.() ?? ctx.sessionId ?? ctx.session?.id;'''

SETTINGS_FROM = 'var GLOBAL_SETTINGS_PATH = join(homedir(), ".pi", "agent", "settings.json");'

SETTINGS_TO = '''// pi-memory profile settings: PI_CODING_AGENT_DIR
var GLOBAL_SETTINGS_PATH = join(
  process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent"),
  "settings.json"
);'''

P1_FROM = """      const execPromise = pi.exec("pi", [
        "-p",
        prompt,
        "--print","""

P1_TO = """      const execPromise = pi.exec(...(() => {
        const args = [
          "-p",
          prompt,
          "--print","""

P1_TAIL_FROM = """        injectorConfig.consolidationModel ?? DEFAULT_CONSOLIDATION_MODEL
      ], {
        timeout: EXEC_TIMEOUT_MS,
        cwd: sessionCwd
      });"""

P1_TAIL_TO = """          injectorConfig.consolidationModel ?? DEFAULT_CONSOLIDATION_MODEL
        ];
        // win32: `pi` — это .cmd-шим, spawn(shell:false) его не находит (ENOENT).
        // Запускаем тот же CLI напрямую через node: shell не нужен, а prompt
        // передаётся аргументом массива — без кавычек и экранирования.
        if (process.platform === "win32") {
          const root = process.env.PI_AGENT_BUILD_NPM_PREFIX?.trim() || join(process.env.APPDATA || homedir(), "npm");
          const cli = join(root, "node_modules", "@earendil-works", "pi-coding-agent", "dist", "bundle", "cli.js");
          if (!existsSync(cli)) throw new Error("Pi CLI not found under selected npm prefix");
          return [process.execPath, [cli, ...args], { timeout: EXEC_TIMEOUT_MS, cwd: sessionCwd }];
        }
        return ["pi", args, { timeout: EXEC_TIMEOUT_MS, cwd: sessionCwd }];
      })());"""

P2_STATE_FROM = """function index_default(pi) {
  let store = null;
  let pendingUserMessages = [];
  let pendingAssistantMessages = [];"""

P2_STATE_TO = """function index_default(pi) {
  let store = null;
  let pendingUserMessages = [];
  let pendingAssistantMessages = [];
  // pi-memory ordered turns: session-local lexical state
  let pendingTurns = [];
  function pushTurn(role, text) {
    const cap = 60;
    if (role === "user") {
      pendingUserMessages.push(text);
      if (pendingUserMessages.length > cap) pendingUserMessages.shift();
    } else {
      pendingAssistantMessages.push(text);
      if (pendingAssistantMessages.length > cap) pendingAssistantMessages.shift();
    }
    pendingTurns.push({ role, text });
    if (pendingTurns.length > cap * 4) pendingTurns.shift();
  }"""

P2_REPLAY_FROM = """        const branch = ctx.sessionManager.getBranch();
        for (const entry of branch) {
          if (entry.type !== "message") continue;
          const msg = entry.message;
          if (!msg) continue;
          if (msg.role === "user") {
            const text = extractText(msg.content);
            if (text) pendingUserMessages.push(text);
          } else if (msg.role === "assistant") {
            const text = extractText(msg.content);
            if (text) pendingAssistantMessages.push(text);
          }
        }"""

P2_REPLAY_TO = """        const branch = ctx.sessionManager.getBranch();
        for (const entry of branch) {
          if (entry.type !== "message") continue;
          const msg = entry.message;
          if (!msg) continue;
          if (msg.role !== "user" && msg.role !== "assistant") continue;
          const text = extractText(msg.content);
          if (text) pushTurn(msg.role, text);
        }"""

P2_AGENT_END_FROM = """  pi.on("agent_end", async (event, _ctx) => {
    for (const msg of event.messages) {
      if (msg.role === "user" && "content" in msg) {
        const text = extractText(msg.content);
        if (text) {
          pendingUserMessages.push(text);
          if (pendingUserMessages.length > 60) pendingUserMessages.shift();
        }
      } else if (msg.role === "assistant" && "content" in msg) {
        const text = extractText(msg.content);
        if (text) {
          pendingAssistantMessages.push(text);
          if (pendingAssistantMessages.length > 60) pendingAssistantMessages.shift();
        }
      }
    }
  });"""

P2_AGENT_END_TO = """  pi.on("agent_end", async (event, _ctx) => {
    for (const msg of event.messages) {
      if (msg.role !== "user" && msg.role !== "assistant") continue;
      if (!("content" in msg)) continue;
      const text = extractText(msg.content);
      if (text) pushTurn(msg.role, text);
    }
  });"""

P2_RESET_START_FROM = """      pendingUserMessages = [];
      pendingAssistantMessages = [];
      try {
        const branch = ctx.sessionManager.getBranch();"""

P2_RESET_START_TO = """      pendingUserMessages = [];
      pendingAssistantMessages = [];
      pendingTurns = [];
      try {
        const branch = ctx.sessionManager.getBranch();"""

P2_RESET_SWITCH_FROM = """    }
    pendingUserMessages = [];
    pendingAssistantMessages = [];
  });"""

P2_RESET_SWITCH_TO = """    }
    pendingUserMessages = [];
    pendingAssistantMessages = [];
    pendingTurns = [];
  });"""

P2_PAIRS_FROM = """  const maxPairs = 30;
  const len = Math.min(input.userMessages.length, maxPairs);
  for (let i = 0; i < len; i++) {
    const userMsg = input.userMessages[i];
    if (userMsg) messages.push(`User: ${truncate2(userMsg, 1e3)}`);
    const assistantMsg = input.assistantMessages[i];
    if (assistantMsg) messages.push(`Assistant: ${truncate2(assistantMsg, 500)}`);
  }"""

P2_PAIRS_TO = """  const maxPairs = 30;
  // Build each pair from the ordered stream: a user message plus the nearest
  // subsequent textual assistant reply before the next user message.
  const turns = input.turns;
  if (Array.isArray(turns) && turns.length) {
    const userIdx = [];
    for (let i = 0; i < turns.length; i++) {
      if (turns[i].role === "user" && turns[i].text) userIdx.push(i);
    }
    for (const u of userIdx.slice(-maxPairs)) {
      messages.push(`User: ${truncate2(turns[u].text, 1e3)}`);
      for (let j = u + 1; j < turns.length; j++) {
        if (turns[j].role === "user") break;
        if (turns[j].role === "assistant" && turns[j].text) {
          messages.push(`Assistant: ${truncate2(turns[j].text, 500)}`);
          break;
        }
      }
    }
  } else {
    // Compatibility for external callers that do not provide ordered turns.
    const len = Math.min(input.userMessages.length, maxPairs);
    for (let i = 0; i < len; i++) {
      const userMsg = input.userMessages[i];
      if (userMsg) messages.push(`User: ${truncate2(userMsg, 1e3)}`);
      const assistantMsg = input.assistantMessages[i];
      if (assistantMsg) messages.push(`Assistant: ${truncate2(assistantMsg, 500)}`);
    }
  }"""

P2_INPUT_FROM = """      userMessages: pendingUserMessages,
      assistantMessages: pendingAssistantMessages,"""

P2_INPUT_TO = """      userMessages: pendingUserMessages,
      assistantMessages: pendingAssistantMessages,
      turns: pendingTurns.slice(),"""

CANONICAL_REPLACEMENTS = [
    (SETTINGS_FROM, SETTINGS_TO),
    (P1_FROM, P1_TO),
    (P1_TAIL_FROM, P1_TAIL_TO),
    (P2_STATE_FROM, P2_STATE_TO),
    (P2_REPLAY_FROM, P2_REPLAY_TO),
    (P2_AGENT_END_FROM, P2_AGENT_END_TO),
    (P2_RESET_START_FROM, P2_RESET_START_TO),
    (P2_RESET_SWITCH_FROM, P2_RESET_SWITCH_TO),
    (P2_PAIRS_FROM, P2_PAIRS_TO),
    (P2_INPUT_FROM, P2_INPUT_TO),
    (SESSIONID_FROM, SESSIONID_TO),
    ('  pi.on("session_start", async (_event, ctx) => {\n    try {',
     '  pi.on("session_start", async (_event, ctx) => {\n    pendingContextBlock = null;\n    try {'),
    ('  pi.on("session_before_switch", async (_event, ctx) => {\n    if (!store) return;',
     '  pi.on("session_before_switch", async (_event, ctx) => {\n    pendingContextBlock = null;\n    if (!store) return;'),
    ('  pi.on("before_agent_start", async (event, ctx) => {\n    if (!store) return;',
     '''  pi.on("before_agent_start", async (event, ctx) => {
    // pi-memory run lifecycle: never reuse recall across user/custom runs.
    // Keep the block across context/tool continuations within this user run only.
    pendingContextBlock = null;
    if (event.messageType !== "user" || typeof event.prompt !== "string" || !event.prompt.trim()) return;
    if (!store) return;'''),
]

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def short(data: bytes) -> str:
    return digest(data)[:12]

def build_canonical(stock: bytes, replacements=CANONICAL_REPLACEMENTS, *, injector=True, project_writes=True) -> bytes:
    text = stock.decode("utf-8")
    for old, new in replacements:
        count = text.count(old)
        if count != 1:
            anchor = old.strip().splitlines()[0][:70]
            raise RuntimeError(f"stock anchor count {count}, expected 1: {anchor}")
        text = text.replace(old, new, 1)
    if replacements is CANONICAL_REPLACEMENTS and injector:
        text = apply_injection(text, project_writes=project_writes)
    if replacements is CANONICAL_REPLACEMENTS:
        old = "    const { text } = await buildContextBlock(store, ctx.cwd, event.prompt, injectorConfig);"
        new = "    // pi-memory automatic hybrid recall: reuse upstream provider/RRF\n    const recall = await searchMemory(event.prompt, SEARCH_LIMIT, ctx);\n    const { text } = await buildContextBlock(store, ctx.cwd, event.prompt, injectorConfig, recall);"
        if text.count(old) != 1:
            raise RuntimeError("automatic recall anchor mismatch")
        text = text.replace(old, new, 1)
    result = text.encode("utf-8")
    if replacements is CANONICAL_REPLACEMENTS and injector and not is_runtime_safe(text):
        raise RuntimeError("internal error: generated patch is not runtime-safe")
    return result

def is_runtime_safe(text: str) -> bool:
    index_pos = text.find("function index_default(pi) {")
    helper_pos = text.find("  function pushTurn(role, text) {", index_pos)
    first_handler = text.find('  pi.on("session_start"', index_pos)
    return (
        WIN_MARKER in text
        and FIXED_SCOPE_MARKER in text
        and PROFILE_SETTINGS_MARKER in text
        and "// pi-memory run lifecycle" in text
        and 'event.messageType !== "user"' in text
        and "// pi-memory automatic hybrid recall" in text
        and "searchMemory(event.prompt, SEARCH_LIMIT, ctx)" in text
        and SESSIONID_MARKER in text
        and "ctx.sessionManager?.getSessionId?.()" in text
        and "process.env.PI_CODING_AGENT_DIR?.trim()" in text
        and index_pos >= 0
        and index_pos < helper_pos < first_handler
        and "let pendingTurns = [];" in text
        and "turns: pendingTurns.slice()," in text
        and text.count("pendingTurns = [];") >= 3
        and LEGACY_GLOBAL not in text
        and is_injection_safe(text)
    )

def runtime_backup(agent_dir: pathlib.Path, target: pathlib.Path, label: str) -> pathlib.Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    root = agent_dir / ".pi-agent-build-backups" / "memory-windows-runtime"
    root.mkdir(parents=True, exist_ok=True)
    destination = root / f"index.js.{label}-{stamp}"
    shutil.copy2(target, destination)
    if destination.read_bytes() != target.read_bytes(): raise RuntimeError("backup verification failed")
    metadata = (target.parent.parent / "package.json").read_bytes()
    destination.with_suffix(destination.suffix + ".package.json").write_bytes(metadata)
    destination.with_suffix(destination.suffix + ".receipt.json").write_text(json.dumps({
        "packageVersion": json.loads(metadata)["version"], "file": "dist/index.js",
        "sha256": digest(destination.read_bytes()), "packageJsonSha256": digest(metadata),
        "restore": "Reinstall the exact recorded package version, then restore this index.js backup after verifying its SHA256.",
    }, indent=2), encoding="utf-8")
    return destination

def classify(target, stock, canonical):
    if target == stock: return "stock-pristine"
    if target == canonical: return "runtime-safe"
    if digest(target) == PREVIOUS_161_SHA256: return "previous-patched-1.6.1"
    return "noncanonical-drift" if is_runtime_safe(target.decode("utf-8")) else "unknown"


def installed_state(version, current, stock, canonical):
    if version == VERSION: return classify(current, stock, canonical)
    if version == "1.5.0": return PREVIOUS_150_HASHES.get(digest(current), "unknown")
    return "unknown"


def main():
    ap = argparse.ArgumentParser()
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--restore", action="store_true")
    modes.add_argument("--inspect-installed", action="store_true", help="read-only exact known pre-replacement state")
    modes.add_argument("--prepare-replace", action="store_true", help="recognize and back up before package replacement; never patches old versions")
    ap.add_argument("--agent-dir")
    args = ap.parse_args()
    agent = pathlib.Path(args.agent_dir or os.environ.get("PI_CODING_AGENT_DIR", "") or pathlib.Path.home() / ".pi" / "agent").expanduser().resolve()
    target = agent / "npm/node_modules/@samfp/pi-memory/dist/index.js"
    try:
        version = json.loads((target.parent.parent / "package.json").read_text(encoding="utf-8")).get("version")
        stock = BACKUP.read_bytes()
        if digest(stock) != EXPECTED_STOCK_SHA256: raise RuntimeError("immutable stock hash mismatch")
        canonical = build_canonical(stock)
        current = target.read_bytes()
        state = installed_state(version, current, stock, canonical)
        print(f"version={version} target={VERSION} state={state}")
        known = state in {"stock-pristine", "runtime-safe", "previous-patched-1.6.1", *PREVIOUS_150_HASHES.values()}
        if args.inspect_installed or args.prepare_replace:
            if not known: raise RuntimeError("unknown installed bytes/version; preserve the package and compare with backups before replacement")
            if args.prepare_replace:
                print(f"pre-replacement backup: {runtime_backup(agent, target, state)}")
            return 0
        if version != VERSION: raise RuntimeError(f"target patch requires exactly {VERSION}, found {version}; use --prepare-replace before reinstall")
        if args.check: return 0 if state == "runtime-safe" else 1 if state in {"stock-pristine", "previous-patched-1.6.1"} else 2
        if not known: raise RuntimeError("unknown/noncanonical installed state; restore from the verified runtime backup, not marker-based repair")
        desired = stock if args.restore else canonical
        if current == desired:
            print("ALREADY STOCK" if args.restore else "ALREADY PATCHED")
            return 0
        backup = runtime_backup(agent, target, "before-restore" if args.restore else "before-apply")
        print(f"runtime backup: {backup}")
        target.write_bytes(desired)
        subprocess.run(["node", "--check", str(target)], check=True)
        if target.read_bytes() != desired: raise RuntimeError("post-write byte mismatch")
        print("RESTORED BYTE-EXACT" if args.restore else "RUNTIME-SAFE")
        return 0
    except Exception as error:
        print(f"REFUSING: {error}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Patch @samfp/pi-memory 1.5.0 for runtime safety and scoped injection.

Rebuild from verified pristine bytes. Only exact known states may be upgraded;
noncanonical or unknown bundles are never overwritten by a marker-only match.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from injection import apply_injection, is_injection_safe

BACKUP = HERE / "stock-index.js"
EXPECTED_STOCK_SHA256 = "b8d68f90bcdf4fa40b9a573c67f8ed19853d90e889e8c9ed2cf4021f50c6ce58"
# Exact private v1 bundle identity, accepted solely for one-time, backed-up migration.
# Its hard-coded local aliases are NOT part of this public source.
KNOWN_LOCAL_INJECTOR_V1_SHA256 = "15ca149cb8968f32735fe4ed1647c2bc81c19b3b7993507ec7bb31c6da4236bb"
# Initial scoped v2 canonical, superseded by profile-only (not project-local) aliases.
KNOWN_SCOPED_V2_INITIAL_SHA256 = "6ee8966d85382a088cf56af8ab98b40b33ee41bd2d22b4f21afaf69681c5881e"

WIN_MARKER = "// win32: `pi` — это .cmd-шим"
FIXED_SCOPE_MARKER = "// pi-memory ordered turns: session-local lexical state"
PROFILE_SETTINGS_MARKER = "// pi-memory profile settings: PI_CODING_AGENT_DIR"
EMBEDDER_MARKER = "// pi-memory multilingual embedder: Russian-capable, 384d"
SESSIONID_MARKER = "// ExtensionContext has no sessionId/session field"
LEGACY_GLOBAL = "globalThis.__piMemoryTurns"

# Multilingual embedder: stock ships the English-only all-MiniLM-L6-v2, which
# separates Russian paraphrases from unrelated text poorly. The multilingual
# MiniLM keeps the same 384 dimensions and mean pooling, so no reindex or
# threshold change is required.
MODEL_FROM = 'var MODEL = "Xenova/all-MiniLM-L6-v2";'
MODEL_TO = '''// pi-memory multilingual embedder: Russian-capable, 384d
var MODEL = "Xenova/paraphrase-multilingual-MiniLM-L12-v2";'''

# Session id: ExtensionContext exposes no sessionId/session field (only the
# read-only sessionManager), so stock's `ctx.sessionId ?? ctx.session?.id` is
# always undefined and consolidation labels every fact `session:unknown`.
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

# Windows spawn: npm's pi.cmd shim cannot be spawned with shell:false.
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
          if (existsSync(cli)) return [process.execPath, [cli, ...args], { timeout: EXEC_TIMEOUT_MS, cwd: sessionCwd }];
          return [join(root, "pi.cmd"), args, { timeout: EXEC_TIMEOUT_MS, cwd: sessionCwd }];
        }
        return ["pi", args, { timeout: EXEC_TIMEOUT_MS, cwd: sessionCwd }];
      })());"""

# Canonical body shipped before profile-local settings/custom npm-prefix support.
P1_TAIL_TO_PREVIOUS = P1_TAIL_TO.replace(
    'const root = process.env.PI_AGENT_BUILD_NPM_PREFIX?.trim() || join(process.env.APPDATA || homedir(), "npm");',
    'const root = join(process.env.APPDATA || homedir(), "npm");',
)

# Ordered turns: state and helper must share index_default's lexical scope.
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
    if (userMsg) messages.push(`User: ${truncate(userMsg, 1e3)}`);
    const assistantMsg = input.assistantMessages[i];
    if (assistantMsg) messages.push(`Assistant: ${truncate(assistantMsg, 500)}`);
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
      messages.push(`User: ${truncate(turns[u].text, 1e3)}`);
      for (let j = u + 1; j < turns.length; j++) {
        if (turns[j].role === "user") break;
        if (turns[j].role === "assistant" && turns[j].text) {
          messages.push(`Assistant: ${truncate(turns[j].text, 500)}`);
          break;
        }
      }
    }
  } else {
    // Compatibility for external callers that do not provide ordered turns.
    const len = Math.min(input.userMessages.length, maxPairs);
    for (let i = 0; i < len; i++) {
      const userMsg = input.userMessages[i];
      if (userMsg) messages.push(`User: ${truncate(userMsg, 1e3)}`);
      const assistantMsg = input.assistantMessages[i];
      if (assistantMsg) messages.push(`Assistant: ${truncate(assistantMsg, 500)}`);
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
    (MODEL_FROM, MODEL_TO),
    (SESSIONID_FROM, SESSIONID_TO),
]

# Canonical body shipped before the session-id fix (settings + turns + embedder).
PREVIOUS_CANONICAL_REPLACEMENTS = [
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
    (MODEL_FROM, MODEL_TO),
]

# Canonical body shipped before the multilingual embedder fix (settings + turns).
PREVIOUS_CANONICAL_NO_EMBEDDER_REPLACEMENTS = [
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
]

# Older canonical body that also lacked profile-local settings.
LEGACY_CANONICAL_REPLACEMENTS = [
    (P1_FROM, P1_TO),
    (P1_TAIL_FROM, P1_TAIL_TO_PREVIOUS),
    (P2_STATE_FROM, P2_STATE_TO),
    (P2_REPLAY_FROM, P2_REPLAY_TO),
    (P2_AGENT_END_FROM, P2_AGENT_END_TO),
    (P2_RESET_START_FROM, P2_RESET_START_TO),
    (P2_RESET_SWITCH_FROM, P2_RESET_SWITCH_TO),
    (P2_PAIRS_FROM, P2_PAIRS_TO),
    (P2_INPUT_FROM, P2_INPUT_TO),
]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def short(data: bytes) -> str:
    return digest(data)[:12]


def build_canonical(stock: bytes, replacements=CANONICAL_REPLACEMENTS, *, injector=True) -> bytes:
    text = stock.decode("utf-8")
    for old, new in replacements:
        count = text.count(old)
        if count != 1:
            anchor = old.strip().splitlines()[0][:70]
            raise RuntimeError(f"stock anchor count {count}, expected 1: {anchor}")
        text = text.replace(old, new, 1)
    if replacements is CANONICAL_REPLACEMENTS and injector:
        text = apply_injection(text)
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
        and EMBEDDER_MARKER in text
        and 'var MODEL = "Xenova/paraphrase-multilingual-MiniLM-L12-v2";' in text
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


def classify(target: bytes, stock: bytes, canonical: bytes, previous_states: tuple[bytes, ...]) -> str:
    if target == stock:
        return "stock-pristine"
    text = target.decode("utf-8")
    if target == canonical:
        return "runtime-safe"
    if digest(target) == KNOWN_LOCAL_INJECTOR_V1_SHA256:
        return "legacy-local-injector"
    if digest(target) == KNOWN_SCOPED_V2_INITIAL_SHA256:
        return "legacy-canonical"
    if target in previous_states:
        return "legacy-canonical"
    if is_runtime_safe(text):
        return "noncanonical-drift"
    return "unknown"


def private_aliases_ready(agent_dir: pathlib.Path) -> bool:
    """Migration from the old hard-coded local injector needs private replacement aliases."""
    try:
        settings = json.loads((agent_dir / "settings.json").read_text(encoding="utf-8"))
        aliases = settings.get("memory", {}).get("factProjectAliases")
        return isinstance(aliases, list) and bool(aliases) and all(
            isinstance(a, dict) and isinstance(a.get("path"), str) and a["path"].strip()
            and (a["path"].startswith("/") or re.match(r"^[A-Za-z]:[/\\]", a["path"]))
            and isinstance(a.get("scope"), str) and re.fullmatch(r"[a-z0-9_-]+", a["scope"].lower())
            and ("includeChildren" not in a or isinstance(a["includeChildren"], bool))
            for a in aliases
        )
    except (OSError, ValueError, TypeError, AttributeError):
        return False


def runtime_backup(agent_dir: pathlib.Path, target: pathlib.Path, label: str) -> pathlib.Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    root = agent_dir / ".pi-agent-build-backups" / "memory-windows-runtime"
    root.mkdir(parents=True, exist_ok=True)
    destination = root / f"index.js.{label}-{stamp}"
    shutil.copy2(target, destination)
    return destination


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="show state only")
    ap.add_argument("--restore", action="store_true", help="restore pristine 1.5.0")
    ap.add_argument("--agent-dir", help="Pi agent directory; default: PI_CODING_AGENT_DIR or ~/.pi/agent")
    args = ap.parse_args()

    agent_dir = pathlib.Path(
        args.agent_dir
        or os.environ.get("PI_CODING_AGENT_DIR", "")
        or pathlib.Path.home() / ".pi" / "agent"
    ).expanduser().resolve()
    target = agent_dir / "npm" / "node_modules" / "@samfp" / "pi-memory" / "dist" / "index.js"

    if not target.exists():
        print(f"НЕ НАЙДЕН: {target}")
        return 2
    try:
        metadata = json.loads((target.parent.parent / "package.json").read_text(encoding="utf-8"))
        if metadata.get("version") != "1.5.0":
            print(f"ОТКАЗ: expected @samfp/pi-memory 1.5.0, found {metadata.get('version')}")
            return 2
    except (OSError, ValueError, AttributeError) as exc:
        print(f"ОТКАЗ: package metadata unavailable: {exc}")
        return 2
    if not BACKUP.exists():
        print(f"НЕ НАЙДЕН pristine backup: {BACKUP}")
        return 2

    stock = BACKUP.read_bytes()
    if digest(stock) != EXPECTED_STOCK_SHA256:
        print(f"ОТКАЗ: pristine backup изменён: {digest(stock)}")
        return 2
    try:
        canonical = build_canonical(stock)
        previous_injector = build_canonical(stock, injector=False)
        previous = build_canonical(stock, PREVIOUS_CANONICAL_REPLACEMENTS)
        previous_no_embedder = build_canonical(stock, PREVIOUS_CANONICAL_NO_EMBEDDER_REPLACEMENTS)
        legacy = build_canonical(stock, LEGACY_CANONICAL_REPLACEMENTS)
    except RuntimeError as exc:
        print(f"ОТКАЗ: {exc}")
        return 2

    current = target.read_bytes()
    try:
        state = classify(current, stock, canonical, (previous_injector, previous, previous_no_embedder, legacy))
    except UnicodeDecodeError:
        state = "unknown"

    print(f"agent: {agent_dir}")
    print(f"файл:  {target}")
    print(f"sha:   {short(current)}")
    print(f"backup: {BACKUP} (sha {short(stock)})")
    print(f"состояние: {state}")
    if state == "runtime-safe":
        print("verdict: RUNTIME-SAFE — pushTurn shares lexical scope with pending arrays.")
    elif state == "legacy-canonical":
        print("verdict: PATCH REQUIRED — previous canonical patch lacks scoped whole-record injection.")
    elif state == "legacy-local-injector":
        print("verdict: PATCH REQUIRED — exact local v1 injector requires private alias config before migration.")
        if not private_aliases_ready(agent_dir):
            print("ОТКАЗ: add memory.factProjectAliases to the private profile settings.json first.")
    elif state == "stock-pristine":
        print("verdict: PATCH REQUIRED — pristine 1.5.0.")
    elif state == "noncanonical-drift":
        print("verdict: UNKNOWN — markers match, but bytes differ from canonical patch.")
    else:
        print("verdict: UNKNOWN — refusing to overwrite an unrecognized dist.")

    if args.check:
        if state == "runtime-safe":
            return 0
        if state in {"stock-pristine", "legacy-canonical"}:
            return 1
        if state == "legacy-local-injector":
            return 1 if private_aliases_ready(agent_dir) else 2
        return 2

    if args.restore:
        if state in {"unknown", "noncanonical-drift"}:
            print("ОТКАЗ: unknown/noncanonical state не перезаписан; восстановите пакет штатным reinstall.")
            return 2
        if state == "stock-pristine":
            print("изменений нет: pristine stock уже установлен.")
            return 0
        backup = runtime_backup(agent_dir, target, "before-restore")
        print(f"runtime backup: {backup}")
        target.write_bytes(stock)
        print(f"восстановлено из pristine backup -> {target}")
        print(f"sha: {short(target.read_bytes())}")
        return 0

    if state == "runtime-safe":
        if current == canonical:
            print("изменений нет: canonical patch уже применён.")
            return 0
        print("ОТКАЗ: runtime-safe, но не canonical; ручные изменения не перезаписаны.")
        return 2
    if state not in {"stock-pristine", "legacy-canonical", "legacy-local-injector"}:
        print("ОТКАЗ: применим только к pristine stock или точному known previous patch.")
        return 2
    if state == "legacy-local-injector" and not private_aliases_ready(agent_dir):
        print("ОТКАЗ: private memory.factProjectAliases required to preserve local project mapping.")
        return 2

    backup = runtime_backup(agent_dir, target, "before-apply")
    print(f"runtime backup: {backup}")
    target.write_bytes(canonical)
    written = target.read_bytes()
    if written != canonical or not is_runtime_safe(written.decode("utf-8")):
        print("ОШИБКА: post-write verification failed.")
        return 2
    action = "обновлён previous canonical patch" if state == "legacy-canonical" else "применён patch к stock"
    print(f"{action} -> {target}")
    print(f"sha: {short(written)}")
    print("verdict: RUNTIME-SAFE")
    return 0


if __name__ == "__main__":
    sys.exit(main())

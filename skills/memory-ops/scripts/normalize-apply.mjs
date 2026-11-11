// normalize-apply.mjs — plan-file surgery before apply:
// 1) strip backticks in ПРОЕКТ values (apply-lessons would store them literally);
// 2) MOVE blocks whose title says ЖДЁТ/⚠️ out of applied sections into "## Ждёт подтверждения";
// 3) (не здесь) user-ключи отсекают validate-apply и защита в самих применителях.
// Usage: node normalize-apply.mjs <file...>
import { readFileSync, writeFileSync } from "node:fs";

for (const path of process.argv.slice(2)) {
  let raw = readFileSync(path, "utf8").replace(/\r\n/g, "\n");

  // 1) ПРОЕКТ backticks: "ПРОЕКТ: `x` · " -> "ПРОЕКТ: x · "
  raw = raw.replace(/^(ПРОЕКТ:\s*)`([^`]+)`/gm, "$1$2");

  // 2) split into heading chunks: [header, "Группы...", blocks..., "Слияние уроков", ..., "Ждёт подтверждения", ...]
  const parts = raw.split(/(?=^## )/m);
  const held = [];
  const moved = [];
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i];
    if (/^## (Группы слияния фактов|Слияние уроков)/.test(p)) {
      const segs = p.split(/(?=^### )/m);
      const keepSegs = [];
      for (const s of segs) {
        if (/^### /.test(s) && /ЖДЁТ|⚠️/.test(s.split("\n")[0])) { held.push(s.trimEnd()); moved.push(s.split("\n")[0].trim()); }
        else keepSegs.push(s);
      }
      parts[i] = keepSegs.join("");
    }
  }
  // append moved blocks to the held section (create if missing)
  if (held.length) {
    let idx = parts.findIndex((p) => /^## Ждёт подтверждения/.test(p));
    const block = "\n## Ждёт подтверждения\n\n(Перенесено нормализатором из применяемых секций — скрипты эти блоки НЕ применяют.)\n\n" + held.join("\n\n") + "\n";
    if (idx >= 0) parts[idx] = parts[idx].replace(/\s*$/, "\n") + "\n" + held.join("\n\n") + "\n";
    else parts.push(block);
  }
  writeFileSync(path, parts.join(""), "utf8");
  console.log(path.split("/").pop(), "| перенесено блоков:", moved.length, moved.join(" "));
}

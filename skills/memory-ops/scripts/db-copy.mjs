// db-copy.mjs — consistent copy of a SQLite store via VACUUM INTO.
// Portable backup/probe base: works without a sqlite3 CLI (often missing on
// Windows). Use before every probe or apply — never measure or mutate the
// only copy.
//   node db-copy.mjs <src.db> <dst.db> [--force]
import { DatabaseSync } from "node:sqlite";
import { existsSync, rmSync } from "node:fs";

const [src, dst, ...rest] = process.argv.slice(2);
const force = rest.includes("--force");
if (!src || !dst) { console.error("usage: node db-copy.mjs <src.db> <dst.db> [--force]"); process.exit(2); }
if (!existsSync(src)) { console.error("source store not found:", src); process.exit(2); }
if (existsSync(dst)) {
  if (!force) { console.error("target exists (pass --force to replace):", dst); process.exit(2); }
  rmSync(dst);
}
const db = new DatabaseSync(src);
db.exec("VACUUM INTO '" + dst.replaceAll("'", "''") + "'");
db.close();
console.log("copied:", src, "->", dst);

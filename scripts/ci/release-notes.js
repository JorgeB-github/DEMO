#!/usr/bin/env node
/**
 * Appends release-notes rows to a cumulative CSV (one row per deployed component).
 *
 * Columns: PR, Fecha, Hora, Tipo, Componente
 *
 * Usage:
 *   node release-notes.js <package.xml | -> <pr> <date> <time> <csvPath> [agentName ...]
 *
 *   - <package.xml>  delta package with classic metadata (Apex/Flows/Permsets...).
 *                    Pass "-" if there is none.
 *   - <date>         e.g. 2026-06-23
 *   - <time>         e.g. 14:35:07 (HH:MM:SS)
 *   - [agentName...] AiAuthoringBundle api-names handled via Agentforce DX.
 *
 * If the CSV already exists with the old 4-column header (PR,Fecha,Tipo,Componente),
 * it is migrated in place: the Hora column is inserted and existing rows padded.
 */
const fs = require("fs");
const path = require("path");

const [, , pkgPath, pr, date, time, csvPath, ...agents] = process.argv;
if (!csvPath) {
  console.error("usage: release-notes.js <package.xml|-> <pr> <date> <time> <csv> [agents...]");
  process.exit(2);
}

const HEADER = "PR,Fecha,Hora,Tipo,Componente";
const OLD_HEADER = "PR,Fecha,Tipo,Componente";

const rows = [];

// classic metadata from package.xml
if (pkgPath && pkgPath !== "-" && fs.existsSync(pkgPath)) {
  const xml = fs.readFileSync(pkgPath, "utf8");
  const types = xml.match(/<types>[\s\S]*?<\/types>/g) || [];
  for (const block of types) {
    const name = (block.match(/<name>([^<]+)<\/name>/) || [])[1];
    if (!name) continue;
    const members = block.match(/<members>([^<]+)<\/members>/g) || [];
    for (const m of members) {
      const v = m.replace(/<\/?members>/g, "").trim();
      if (v) rows.push([name.trim(), v]);
    }
  }
}

// agents (handled by Agentforce DX, not present in package.xml)
for (const a of agents) {
  if (a && a.trim()) rows.push(["AiAuthoringBundle", a.trim()]);
}

if (rows.length === 0) {
  console.log("release-notes: no components to record");
  process.exit(0);
}

const esc = (s) => `"${String(s).replace(/"/g, '""')}"`;
fs.mkdirSync(path.dirname(csvPath), { recursive: true });

// --- migrate existing CSV to the new header if needed ---
if (fs.existsSync(csvPath)) {
  const lines = fs.readFileSync(csvPath, "utf8").split(/\r?\n/);
  const currentHeader = (lines[0] || "").trim();
  if (currentHeader === OLD_HEADER) {
    const migrated = [HEADER];
    for (const line of lines.slice(1)) {
      if (!line.trim()) continue;
      // insert an empty Hora field after the 2nd field (Fecha)
      migrated.push(line.replace(/^("[^"]*","[^"]*"),(.*)$/, '$1,"",$2'));
    }
    fs.writeFileSync(csvPath, migrated.join("\n") + "\n");
    console.log("release-notes: CSV migrado al header con columna Hora");
  }
}

let out = "";
if (!fs.existsSync(csvPath)) out += HEADER + "\n";
for (const [tipo, comp] of rows) {
  out += [esc(pr || ""), esc(date || ""), esc(time || ""), esc(tipo), esc(comp)].join(",") + "\n";
}
fs.appendFileSync(csvPath, out);
console.log(`release-notes: appended ${rows.length} row(s) to ${csvPath}`);

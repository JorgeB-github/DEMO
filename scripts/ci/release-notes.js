#!/usr/bin/env node
/**
 * Appends release-notes rows to a cumulative CSV (one row per deployed component).
 *
 * Columns: PR, Fecha, Tipo, Componente
 *
 * Usage:
 *   node release-notes.js <package.xml | -> <pr> <date> <csvPath> [agentName ...]
 *
 *   - <package.xml>  delta package with classic metadata (Apex/Flows/Permsets...).
 *                    Pass "-" if there is none.
 *   - [agentName...] AiAuthoringBundle api-names handled via Agentforce DX.
 */
const fs = require("fs");
const path = require("path");

const [, , pkgPath, pr, date, csvPath, ...agents] = process.argv;
if (!csvPath) {
  console.error("usage: release-notes.js <package.xml|-> <pr> <date> <csv> [agents...]");
  process.exit(2);
}

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

let out = "";
if (!fs.existsSync(csvPath)) out += "PR,Fecha,Tipo,Componente\n";
for (const [tipo, comp] of rows) {
  out += [esc(pr || ""), esc(date || ""), esc(tipo), esc(comp)].join(",") + "\n";
}
fs.appendFileSync(csvPath, out);
console.log(`release-notes: appended ${rows.length} row(s) to ${csvPath}`);

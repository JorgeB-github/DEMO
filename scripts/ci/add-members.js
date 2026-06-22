#!/usr/bin/env node
/**
 * Ensures the given members exist under a metadata <type> in a package.xml.
 * Creates the <types> block if it doesn't exist yet. Deduplicates members.
 *
 * Usage: node add-members.js <package.xml> <TypeName> <member> [<member> ...]
 */
const fs = require("fs");

const [, , pkgPath, typeName, ...members] = process.argv;
if (!pkgPath || !typeName) {
  console.error("usage: add-members.js <package.xml> <Type> <member...>");
  process.exit(2);
}
const wanted = members.map((m) => (m || "").trim()).filter(Boolean);
if (wanted.length === 0) process.exit(0);

let xml = fs.readFileSync(pkgPath, "utf8");
const typesRe = /<types>[\s\S]*?<\/types>/g;
let found = false;

xml = xml.replace(typesRe, (block) => {
  const name = (block.match(/<name>([^<]+)<\/name>/) || [])[1];
  if (!name || name.trim() !== typeName) return block;
  found = true;
  const existing = new Set(
    (block.match(/<members>([^<]+)<\/members>/g) || []).map((m) =>
      m.replace(/<\/?members>/g, "").trim()
    )
  );
  const toAdd = wanted.filter((m) => !existing.has(m));
  if (toAdd.length === 0) return block;
  const inserts = toAdd.map((m) => `        <members>${m}</members>`).join("\n");
  return block.replace(/(\s*)<name>/, `\n${inserts}$1<name>`);
});

if (!found) {
  const inserts = wanted.map((m) => `        <members>${m}</members>`).join("\n");
  const typesBlock = `    <types>\n${inserts}\n        <name>${typeName}</name>\n    </types>\n`;
  if (/<version>/.test(xml)) {
    xml = xml.replace(/(\s*)<version>/, `\n${typesBlock}$1<version>`);
  } else {
    xml = xml.replace(/<\/Package>/, `${typesBlock}</Package>`);
  }
}

fs.writeFileSync(pkgPath, xml);
console.log(`add-members: ensured [${wanted.join(", ")}] in ${typeName}`);

#!/usr/bin/env node
/*
 * check-agent-desc-length.js
 *
 * Guardrail de PR: mide la longitud de las `description` de un .agent y avisa
 * ANTES del merge cuando superan el limite del campo REAL donde Salesforce las
 * guarda al compilar el agente. Asi el problema se detecta en el PR y no recien
 * en `sf agent publish` (o, peor, truncado en silencio al editar por UI).
 *
 * Campos y limites (duros de plataforma):
 *   * config.description                 -> BotDefinition.Description        (<= 1000)
 *   * subagent/start_agent .description  -> GenAiPluginDefinition.Description (<= 2000)
 *
 * Politica por defecto (el pipeline NO recorta nada; si excede, el publish falla):
 *   * subagent/start_agent > 2000  -> ERROR (rompe el publish; NADIE la recorta).
 *   * config.description   > 1000  -> ERROR (rompe el publish; el desarrollador
 *                                     debe resumir la descripcion en la fuente).
 *
 * Nota <br>: al compilar, los saltos de linea de un block scalar (|) pueden
 * expandirse a "<br>" y sumar caracteres. Se mide la longitud CRUDA (\n = 1) para
 * el corte duro y, si la version con <br> superaria el limite, se emite un WARN
 * de borde para que se revise.
 *
 * Uso:
 *   node check-agent-desc-length.js <file1.agent> [file2.agent ...]
 *
 * Env:
 *   CONFIG_DESC_LIMIT    default 1000
 *   SUBAGENT_DESC_LIMIT  default 2000
 */
'use strict';

const fs = require('fs');

const CONFIG_LIMIT = parseInt(process.env.CONFIG_DESC_LIMIT || '1000', 10);
const SUB_LIMIT = parseInt(process.env.SUBAGENT_DESC_LIMIT || '2000', 10);

const files = process.argv.slice(2).filter(Boolean);
if (files.length === 0) {
  console.log('>> [desc-length] no hay archivos .agent para validar. OK.');
  process.exit(0);
}

// Extrae el valor de la `description` que empieza en la linea descIdx, soportando
// cadena entrecomillada de una linea, block scalar (| / > / ->) y escalar plano.
function extractValue(lines, descIdx) {
  const line = lines[descIdx];
  const indent = (line.match(/^(\s*)/) || ['', ''])[1].length;
  const after = line
    .slice(line.indexOf('description:') + 'description:'.length)
    .replace(/^\s*/, '');

  // Cadena entrecomillada en una sola linea: description: "..."
  const q = after.match(/^"([\s\S]*)"\s*$/);
  if (q) return q[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');

  // Block scalar (| , > , ->) o clave sin valor en la misma linea -> multi-linea.
  if (after === '' || /^(\|[-+]?|>[-+]?|->)\s*$/.test(after)) {
    const content = [];
    for (let i = descIdx + 1; i < lines.length; i++) {
      const l = lines[i];
      if (l.trim() === '') { content.push(''); continue; }
      const ind = (l.match(/^(\s*)/) || ['', ''])[1].length;
      if (ind <= indent) break; // dedent => fin del bloque
      content.push(l);
    }
    while (content.length && content[content.length - 1] === '') content.pop();
    const indents = content
      .filter((s) => s !== '')
      .map((s) => (s.match(/^(\s*)/) || ['', ''])[1].length);
    const min = indents.length ? Math.min(...indents) : 0;
    return content.map((s) => (s.length >= min ? s.slice(min) : s)).join('\n');
  }

  // Escalar plano de una linea.
  return after.trim();
}

// Encuentra la PRIMERA `description:` hija dentro del bloque que arranca en
// blockIdx (clave de nivel 0). Devuelve el indice de linea o -1.
function findChildDescription(lines, blockIdx) {
  for (let j = blockIdx + 1; j < lines.length; j++) {
    if (/^\S/.test(lines[j])) break; // proxima clave de nivel 0 => fin del bloque
    if (/^\s+description:\s*/.test(lines[j])) return j;
  }
  return -1;
}

let errors = 0;
let warns = 0;

for (const file of files) {
  if (!fs.existsSync(file)) continue;
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  console.log(`-- ${file}`);

  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (!/^\S/.test(l)) continue; // solo claves de nivel 0

    let name = null;
    let limit = null;

    let m;
    if (/^config:\s*$/.test(l)) {
      name = 'config.description';
      limit = CONFIG_LIMIT;
    } else if ((m = l.match(/^subagent\s+(\S+):\s*$/))) {
      name = `subagent ${m[1]}`;
      limit = SUB_LIMIT;
    } else if ((m = l.match(/^start_agent\s+(\S+):\s*$/))) {
      name = `start_agent ${m[1]}`;
      limit = SUB_LIMIT;
    } else {
      continue;
    }

    const descIdx = findChildDescription(lines, i);
    if (descIdx === -1) continue;

    const value = extractValue(lines, descIdx);
    const raw = value.length;
    const br = value.replace(/\n/g, '<br>').length;
    const where = `${name} (linea ${descIdx + 1})`;

    const hardOver = raw > limit;
    const borderOver = !hardOver && br > limit;

    if (hardOver) {
      errors++;
      console.log(
        `   !! ERROR ${where}: ${raw} chars (> ${limit}). Excede el limite duro ` +
          `del campo; el publish fallara. Reestructurar (mover comportamiento a instructions).`
      );
    } else if (borderOver) {
      warns++;
      console.log(
        `   ~~ WARN ${where}: ${raw} chars (<= ${limit}) pero ${br} con <br> al ` +
          `compilar (> ${limit}). Borde: dejar margen.`
      );
    } else {
      console.log(`   ok ${where}: ${raw} chars (<= ${limit}).`);
    }
  }
}

console.log(`>> Descripciones fuera de limite: ${errors} error(es), ${warns} aviso(s).`);

if (errors > 0) {
  console.error(
    '>> ERROR: hay descripciones que exceden el limite duro del campo en Salesforce.\n' +
      '   Recordá: `description` es para RUTEO (corto); el comportamiento y los\n' +
      '   guardrails van en `instructions` (limite alto). Reestructurá el/los\n' +
      '   subagente(s) señalados arriba.'
  );
  process.exit(1);
}

process.exit(0);

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Limpia un package.xml de Salesforce sin CLI args y genera sfi-package.yaml.
Configuración editable en la sección CONFIG.

- EXCLUDE_TYPES: elimina tipos completos (p.ej., "CustomLabels", "Profile").
- EXCLUDE_MEMBERS: elimina miembros por patrón "Tipo:Patrón" (fnmatch).
- INPUT_PATH / OUTPUT_PATH: archivos de entrada/salida para package.xml.
- GENERATE_SFI_YAML: habilita/deshabilita la escritura de package/sfi-package.yaml.
- SFI_YAML_PATH: ruta del YAML a generar.
- SFI_YAML_TEMPLATE: contenido de sfi-package.yaml (se escribe tal cual).
- IN_PLACE: si True, reescribe el INPUT_PATH.
- SORT_OUTPUT: si True, ordena tipos y miembros al guardar.

Al final imprime un resumen de miembros removidos por tipo.
"""

import sys
import fnmatch
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict

# =========================
# ======== CONFIG =========
# =========================
CONFIG = {
    "INPUT_PATH": "package/package.xml",
    "OUTPUT_PATH": "package/package.xml",
    "EXCLUDE_TYPES": [
        "CustomLabels",
        "CustomMetadata",
        "DecisionMatrixDefinition",
        "DecisionMatrixDefinitionVersion",
        "EntitlementProcess",
        "ExpressionSetDefinition",
        "ExpressionSetDefinitionVersion",
        "ExternalCredential",
        "NamedCredential",
    ],
    "EXCLUDE_MEMBERS": [
        # "ApexClass:Test_*",
        # "Profile:*ReadOnly*",
        # "Profile:*"   # equivale a excluir el tipo completo
    ],
    "IN_PLACE": False,
    "SORT_OUTPUT": True,

    # ---- Generación del YAML de SFI ----
    "GENERATE_SFI_YAML": True,
    "SFI_YAML_PATH": "package/sfi-package.yaml",
    # Se respeta exactamente el formato e indentación provistos
    "SFI_YAML_TEMPLATE": """projectPath: .
expansionPath: dataPack
continueAfterError: true
autoUpdateSettings: true
maxDepth: 0
compileOnBuild: true
npmAuthKey: Y3VzdG9tZXJfdGVsbWV4X2IyYzo3eF9Wa1ZpQU82SWppTjJY
activate: true
manifest:

OverrideSettings:
  DataPacks:
    Product2:
      MaxDeploy: 1
  SObjects:
    vlocity_namespace__PromotionItem__c:
      SourceKeyDefinition:
        - vlocity_namespace__OfferId__c
        - vlocity_namespace__ProductId__c
        - vlocity_namespace__PromotionId__c
""",
}
# =========================
# ===== FIN CONFIG ========
# =========================

NS = "http://soap.sforce.com/2006/04/metadata"
ET.register_namespace("", NS)

def _q(tag: str) -> str:
    return f"{{{NS}}}{tag}"

def _normalize_types(types):
    out = set()
    for t in types:
        t = (t or "").strip()
        if not t:
            continue
        if t == "CustomLabel":
            out.add("CustomLabels")
        elif t == "ReportTypes":
            out.add("ReportType")
        else:
            out.add(t)
    return out

def _parse_member_rules(rules):
    """
    Convierte ['Tipo:patrón', 'Otro:pat*'] en dict {'Tipo': ['patrón', ...]}
    Si viene 'Tipo' sin ':', se interpreta como '*'.
    """
    out = defaultdict(list)
    for r in rules:
        r = (r or "").strip()
        if not r:
            continue
        if ":" not in r:
            t, pat = r, "*"
        else:
            t, pat = r.split(":", 1)
        t = t.strip()
        pat = (pat or "*").strip()
        if t == "CustomLabel":
            t = "CustomLabels"
        if t == "ReportTypes":
            t = "ReportType"
        out[t].append(pat)
    return dict(out)

def _member_matches(name, patterns):
    return any(fnmatch.fnmatchcase(name, p) for p in patterns)

def _snapshot_members(types_el):
    """Devuelve lista de miembros (texto) tal como están en el bloque."""
    out = []
    for m in types_el.findall(_q("members")):
        txt = (m.text or "").strip()
        if txt:
            out.append(txt)
    return out

def _sort_package(root):
    # Ordena <types> por <name> y miembros por texto
    types_nodes = root.findall(_q("types"))
    types_nodes.sort(key=lambda el: (el.find(_q("name")).text if el.find(_q("name")) is not None else ""))

    for t in types_nodes:
        members = t.findall(_q("members"))
        members.sort(key=lambda m: (m.text or ""))
        # reinsertar ordenados
        for m in members:
            t.remove(m)
        for m in members:
            # colocamos antes de <name> para lectura natural
            name_el = t.find(_q("name"))
            if name_el is None:
                t.append(m)
            else:
                idx = list(t).index(name_el)
                t.insert(idx, m)

    # Reconstruir en el root, dejando <version> al final
    version = root.find(_q("version"))
    for t in root.findall(_q("types")):
        root.remove(t)
    for t in types_nodes:
        if version is not None:
            idx = list(root).index(version)
            root.insert(idx, t)
        else:
            root.append(t)

def _write_sfi_yaml():
    cfg = CONFIG
    if not cfg.get("GENERATE_SFI_YAML", True):
        return
    yaml_path = Path(cfg.get("SFI_YAML_PATH", "package/sfi-package.yaml"))
    yaml_path.parent.mkdir(parents=True, exist_ok=True)
    content = cfg.get("SFI_YAML_TEMPLATE", "")
    # Escribir exactamente el template provisto
    with yaml_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"   sfi-package.yaml     : {yaml_path} (generado)")

def clean_package_xml():
    cfg = CONFIG
    in_path = Path(cfg["INPUT_PATH"])
    out_path = in_path if cfg.get("IN_PLACE") else Path(cfg["OUTPUT_PATH"])

    if not in_path.exists():
        print(f"❌ No se encuentra el archivo de entrada: {in_path}", file=sys.stderr)
        sys.exit(1)

    tree = ET.parse(in_path)
    root = tree.getroot()

    exclude_types = _normalize_types(cfg.get("EXCLUDE_TYPES", []))
    exclude_member_rules = _parse_member_rules(cfg.get("EXCLUDE_MEMBERS", []))

    # Nuevas estructuras de tracking
    removed_by_type = defaultdict(set)   # tipo -> set(miembros removidos); '*' si todos
    types_removed_completely = set()     # tipos eliminados enteros

    to_remove_types = []

    for types_el in root.findall(_q("types")):
        name_el = types_el.find(_q("name"))
        mtype = (name_el.text.strip() if name_el is not None and name_el.text else "")

        # Snapshot de miembros antes de modificar
        initial_members = _snapshot_members(types_el)  # puede incluir "*"

        # 1) excluir tipo completo por lista de tipos
        if mtype in exclude_types:
            to_remove_types.append(types_el)
            types_removed_completely.add(mtype)
            if "*" in initial_members or not initial_members:
                removed_by_type[mtype].add("*")
            else:
                removed_by_type[mtype].update(initial_members)
            continue

        # 2) excluir por patrones
        patterns = exclude_member_rules.get(mtype, [])
        if patterns:
            # Si hay un '*', eliminar el tipo completo
            if any(p.strip() == "*" for p in patterns):
                to_remove_types.append(types_el)
                types_removed_completely.add(mtype)
                if "*" in initial_members or not initial_members:
                    removed_by_type[mtype].add("*")
                else:
                    removed_by_type[mtype].update(initial_members)
                continue

            # Eliminar solo los miembros que matchean
            removed_here = set()
            for mem_el in list(types_el.findall(_q("members"))):
                name = (mem_el.text or "").strip()
                if not name:
                    types_el.remove(mem_el)
                    continue
                if _member_matches(name, patterns):
                    types_el.remove(mem_el)
                    removed_here.add(name)

            if removed_here:
                removed_by_type[mtype].update(removed_here)

        # 3) si quedó sin miembros, eliminar el bloque
        if not types_el.findall(_q("members")):
            to_remove_types.append(types_el)
            types_removed_completely.add(mtype)
            if mtype not in removed_by_type or not removed_by_type[mtype]:
                if "*" in initial_members or not initial_members:
                    removed_by_type[mtype].add("*")
                else:
                    removed_by_type[mtype].update(initial_members)

    for t in to_remove_types:
        root.remove(t)

    if CONFIG.get("SORT_OUTPUT", True):
        _sort_package(root)

    # Indentado (Py 3.9+)
    try:
        ET.indent(tree, space="  ", level=0)
    except Exception:
        pass

    out_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(out_path, encoding="utf-8", xml_declaration=True)

    # ===== Generar sfi-package.yaml =====
    _write_sfi_yaml()

    # ===== Resumen claro =====
    print("✅ Limpieza completada.")
    print(f"   Archivo de entrada   : {in_path}")
    print(f"   Archivo de salida    : {out_path}")

    if types_removed_completely:
        print(f"   Tipos removidos completamente ({len(types_removed_completely)}):")
        for t in sorted(types_removed_completely):
            marker = " (todos)" if removed_by_type.get(t) == {"*"} else ""
            print(f"     - {t}{marker}")

    # Miembros removidos por tipo (excluye el caso '*' ya reflejado arriba)
    detailed = []
    for t, members in removed_by_type.items():
        if members == {"*"}:
            continue
        if members:
            detailed.append((t, sorted(members)))

    if detailed:
        print("   Miembros removidos por tipo:")
        for t, members in sorted(detailed, key=lambda x: x[0]):
            print(f"     - {t} ({len(members)}):")
            for m in members:
                print(f"         · {m}")

if __name__ == "__main__":
    clean_package_xml()

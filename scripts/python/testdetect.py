#!/usr/bin/env python3
# add_test_classes_to_package.py
# - Agrega clases de test al package.xml si contiene ApexClass

import argparse, re, subprocess, sys
from pathlib import Path
import xml.etree.ElementTree as ET

# Defaults
DEFAULT_PACKAGE = "package/package.xml"              # 👈 ahora busca acá por defecto
DEFAULT_CLASSES_DIR = "force-app/main/default/classes"

# Namespace Salesforce
SF_NS = "http://soap.sforce.com/2006/04/metadata"
ET.register_namespace("", SF_NS)

# Patrones para detectar tests (case-insensitive)
TEST_PATTERNS = [
    r".*(?:^|[_-])(test|tests|tst)(?:$|[_-]).*",  # _test, -tests, tst-, etc.
    r".*(Test|Tests|Tst)$",                       # sufijo
    r".*Spec$",                                   # estilo Spec
]
TEST_REGEX = re.compile("|".join(f"(?:{p})" for p in TEST_PATTERNS), re.IGNORECASE)

def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()

def parse_package(package_path: Path) -> ET.ElementTree:
    try:
        return ET.parse(package_path)
    except ET.ParseError as e:
        print(f"[ERROR] package.xml mal formado: {e}", file=sys.stderr)
        sys.exit(2)

def _local(tag: str) -> str:
    return tag.split('}', 1)[-1] if '}' in tag else tag

def find_or_create_apex_types(root: ET.Element) -> ET.Element:
    apex_types = None
    for t in root.findall(f".//{{{SF_NS}}}types") + root.findall(".//types"):
        name_el = t.find(f"{{{SF_NS}}}name") or t.find("name")
        if name_el is not None and (name_el.text or "").strip() == "ApexClass":
            apex_types = t
            break
    if apex_types is None:
        apex_types = ET.Element(f"{{{SF_NS}}}types")
        name_el = ET.SubElement(apex_types, f"{{{SF_NS}}}name")
        name_el.text = "ApexClass"
        root.append(apex_types)
    return apex_types

def apex_types_exists(root: ET.Element) -> bool:
    for t in root.findall(f".//{{{SF_NS}}}types") + root.findall(".//types"):
        name_el = t.find(f"{{{SF_NS}}}name") or t.find("name")
        if name_el is not None and (name_el.text or "").strip() == "ApexClass":
            return True
    return False

def get_existing_members(apex_types: ET.Element) -> set[str]:
    members = set()
    for m in apex_types.findall(f"{{{SF_NS}}}members") + apex_types.findall("members"):
        if m.text and m.text.strip():
            members.add(m.text.strip())
    return members

def list_cls_files(classes_dir: Path, use_git: bool) -> list[Path]:
    if use_git:
        out = run(["git", "ls-files", "--", str(classes_dir)])
        return [Path(p) for p in out.splitlines() if p.endswith(".cls")]
    return list(classes_dir.rglob("*.cls"))

def is_test_class_name(name: str) -> bool:
    return bool(TEST_REGEX.fullmatch(name) or TEST_REGEX.search(name))

def add_members(apex_types: ET.Element, new_members: list[str]) -> int:
    existing = get_existing_members(apex_types)
    added = 0
    for cls in sorted(set(new_members)):
        if cls not in existing:
            ET.SubElement(apex_types, f"{{{SF_NS}}}members").text = cls
            added += 1
    return added

def main():
    ap = argparse.ArgumentParser(description="Agregar clases de test al package.xml si hay ApexClass.")
    ap.add_argument("--package", default=DEFAULT_PACKAGE,
                    help=f"Ruta a package.xml (default: {DEFAULT_PACKAGE})")
    ap.add_argument("--classes-dir", default=DEFAULT_CLASSES_DIR,
                    help=f"Carpeta de clases .cls (default: {DEFAULT_CLASSES_DIR})")
    ap.add_argument("--use-git", action="store_true", help="Usar 'git ls-files' para listar clases versionadas")
    ap.add_argument("--dry-run", action="store_true", help="No escribe cambios; solo reporta")
    args = ap.parse_args()

    package_path = Path(args.package)
    classes_dir = Path(args.classes_dir)

    if not package_path.exists():
        print(f"[ERROR] No existe {package_path}", file=sys.stderr)
        sys.exit(1)

    tree = parse_package(package_path)
    root = tree.getroot()

    if not apex_types_exists(root):
        print("[INFO] package.xml no contiene ApexClass; no se agregan tests.")
        sys.exit(0)

    apex_types = find_or_create_apex_types(root)

    cls_files = list_cls_files(classes_dir, args.use_git)
    test_names = [f.stem for f in cls_files if is_test_class_name(f.stem)]

    if not test_names:
        print("[INFO] No se encontraron clases de test para agregar.")
        sys.exit(0)

    added = add_members(apex_types, test_names)

    if added == 0:
        print("[OK] No había tests nuevos para agregar (ya estaban).")
        sys.exit(0)

    if args.dry_run:
        print(f"[DRY-RUN] Se agregarían {added} clases de test.")
        sys.exit(0)

    tree.write(package_path, encoding="utf-8", xml_declaration=True)
    print(f"[OK] Agregadas {added} clases de test a {package_path}")

if __name__ == "__main__":
    main()

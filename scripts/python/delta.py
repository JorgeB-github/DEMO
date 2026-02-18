#!/usr/bin/env python3
import os
import shutil
import re
import subprocess
import sys
import argparse
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom
from pathlib import Path

# ---- Config ----
DATA_PACK_ROOTS = ["dataPack", "dataPacks", "datapack", "datapacks", "vlocity"]
# ----------------

def print_modified_files(content_file):
    print("ARCHIVOS MODIFICADOS:")
    for line in content_file:
        print(f"\t---{line.strip()}")
    print("\n")

def copy_bundle_dir(origin_path, target_path, component_folder, copied_dirs, label):
    print(f"\t({label}) {component_folder}")
    component_path = os.path.join(origin_path, component_folder.replace('/', os.sep))
    destination_component_path = os.path.join(target_path, component_folder.replace('/', os.sep))
    destination_parent = os.path.dirname(destination_component_path)
    if component_folder not in copied_dirs and os.path.exists(component_path):
        if not os.path.exists(destination_parent):
            os.makedirs(destination_parent)
        shutil.copytree(component_path, destination_parent, dirs_exist_ok=True)
        copied_dirs.add(component_folder)
        print(f"Copiada ruta: {component_folder}")
        return 1
    return 0

def copy_same_basename_files(origin_dir, dest_dir, basename):
    count = 0
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)
    if os.path.isdir(origin_dir):
        for f in os.listdir(origin_dir):
            if f.startswith(basename + '.'):
                src_file = os.path.join(origin_dir, f)
                if os.path.isfile(src_file):
                    shutil.copy2(src_file, dest_dir)
                    count += 1
    return 1 if count > 0 else 0

def _build_datapack_regex():
    roots_union = "|".join([re.escape(r) for r in DATA_PACK_ROOTS])
    return re.compile(rf'^(?:{roots_union})/[^/]+/[^/]+/')

def filter_and_copy_files(lines_file, origin_path, target_path):
    print('******** Funcion FilterAndCopyFiles ***********')
    files_count = 0
    copied_dirs = set()
    dp_re = _build_datapack_regex()

    for raw_line in lines_file:
        line = raw_line.strip()

        # Acepta D/M/A/Rxxx para force-app y datapacks/vlocity
        if not (
            re.match(r'^[DMAR]\d{0,4}\tforce-app/.*$', line) or
            re.match(r'^[DMA]\tforce-app/.*$', line) or
            re.match(r'^[DMAR]\d{0,4}\t(?:' + "|".join(DATA_PACK_ROOTS) + r')/.*$', line) or
            re.match(r'^[DMA]\t(?:' + "|".join(DATA_PACK_ROOTS) + r')/.*$', line)
        ):
            continue

        # Renames: usar última columna
        if re.match(r'^R\d{0,4}\t', line):
            parts = line.split('\t')
            status_line = parts[0]
            path_file = parts[-1]
        else:
            parts = line.split('\t')
            status_line = parts[0]
            path_file = parts[1]

        # datapacks/vlocity -> copiar bundle <root>/<Type>/<Name>/
        if dp_re.match(path_file):
            m = re.match(r'^((?:' + "|".join(DATA_PACK_ROOTS) + r')/[^/]+/[^/]+/)', path_file)
            if m:
                component_folder = m.group(1)
                files_count += copy_bundle_dir(origin_path, target_path, component_folder, copied_dirs, 'datapack')
            continue

        # classes/triggers -> basename.*
        if re.match(r'force-app/[^/]+/[^/]+/(classes|triggers)/', path_file) and status_line != "D":
            m = re.match(r'^(force-app/[^/]+/[^/]+/(?:classes|triggers)/)([^/]+)$', path_file)
            if m:
                component_folder = m.group(1)
                file_name = m.group(2)
                base = file_name.split('.')[0]
                src_dir = os.path.join(origin_path, component_folder.replace('/', os.sep))
                dst_dir = os.path.join(target_path, component_folder.replace('/', os.sep))
                files_count += copy_same_basename_files(src_dir, dst_dir, base)
            continue

        # LWC / Aura bundles
        if re.match(r'force-app/[^/]+/[^/]+/lwc/[^/]+/', path_file):
            component_folder = re.match(r'^(force-app/.*/lwc/[^/]+/)', path_file).group(1)
            files_count += copy_bundle_dir(origin_path, target_path, component_folder, copied_dirs, 'lwc')
            continue

        if re.match(r'force-app/[^/]+/[^/]+/aura/[^/]+/', path_file):
            component_folder = re.match(r'^(force-app/.*/aura/[^/]+/)', path_file).group(1)
            files_count += copy_bundle_dir(origin_path, target_path, component_folder, copied_dirs, 'aura')
            continue

        # Objects: copiar carpeta del objeto
        if re.match(r'force-app/[^/]+/[^/]+/objects/[^/]+/', path_file) and status_line != "D":
            component_folder = re.match(r'^(force-app/[^/]+/[^/]+/objects/[^/]+/)', path_file).group(1)
            files_count += copy_bundle_dir(origin_path, target_path, component_folder, copied_dirs, 'objects')
            continue

        # flows/layouts/flexipages/workflows -> basename.*
        if re.match(r'force-app/[^/]+/[^/]+/(flows|layouts|flexipages|workflows)/', path_file) and status_line != "D":
            m = re.match(r'^(force-app/[^/]+/[^/]+/(?:flows|layouts|flexipages|workflows)/)(.+)$', path_file)
            if m:
                component_folder = m.group(1)
                remainder = m.group(2)
                base = os.path.basename(remainder).split('.')[0]
                src_dir = os.path.join(origin_path, component_folder.replace('/', os.sep))
                dst_dir = os.path.join(target_path, component_folder.replace('/', os.sep))
                files_count += copy_same_basename_files(src_dir, dst_dir, base)
            continue

        # Otros force-app: copiar tal cual
        if path_file.startswith("force-app/") and status_line != "D":
            component_path = os.path.join(origin_path, path_file.replace('/', os.sep))
            dest_dir = os.path.join(target_path, os.path.dirname(path_file).replace('/', os.sep))
            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir)
            if os.path.exists(component_path) and os.path.isfile(component_path):
                shutil.copy2(component_path, dest_dir)
                files_count += 1

    return files_count

# ---- MDAPI Map ----
FOLDER_TO_MDAPI = {
    "classes": "ApexClass",
    "triggers": "ApexTrigger",
    "lwc": "LightningComponentBundle",
    "aura": "AuraDefinitionBundle",
    "flows": "Flow",
    "layouts": "Layout",
    "flexipages": "FlexiPage",
    "workflows": "Workflow",
    "staticresources": "StaticResource",
    "permissionsets": "PermissionSet",
    "profiles": "Profile",
    "tabs": "CustomTab",
    "applications": "CustomApplication",
    "labels": "CustomLabels",
    "quickActions": "QuickAction",
    "objectTranslations": "CustomObjectTranslation",
    "reportTypes": "ReportType",
    "contentassets": "ContentAsset",
    "email": "EmailTemplate",
}

def add_member(members_dict, md_type, name):
    if not name:
        return
    members_dict.setdefault(md_type, set()).add(name)

# ---- Parsers ----
def parse_layout_member(filename): return Path(filename).name.split(".")[0]
def parse_flow_member(filename): return Path(filename).name.split(".")[0]
def parse_flexipage_member(filename): return Path(filename).name.split(".")[0]
def parse_class_trigger_member(filename): return Path(filename).name.split(".")[0]
def parse_lwc_aura_member(path_folder): return Path(path_folder).name
def parse_tab_member(filename): return Path(filename).name.split(".")[0]
def parse_application_member(filename): return Path(filename).name.split(".")[0]
def parse_reporttype_member(filename): return Path(filename).name.split(".")[0]
def parse_contentasset_member(filename): return Path(filename).name.split(".")[0]
def parse_quickaction_member(filename): return Path(filename).name.split(".")[0]
def parse_objecttranslation_member(filename): return Path(filename).name.split(".")[0]
def parse_customobject_member(object_folder_path): return Path(object_folder_path.rstrip('/')).name
def parse_emailtemplate_member(path_from_email_dir):
    p = Path(path_from_email_dir)
    name = p.stem.split(".")[0]
    folder = p.parent.as_posix()
    return f"{folder}/{name}" if folder != "." else name

# ---- Scanners (post-scan Archivos_Modificados) ----
def scan_force_app_for_members(staging_root):
    members = {}
    default_root = Path(staging_root) / "force-app" / "main" / "default"
    if not default_root.exists():
        return members

    # CustomLabels
    labels_meta = default_root / "labels" / "CustomLabels.labels-meta.xml"
    if labels_meta.exists():
        add_member(members, "CustomLabels", "CustomLabels")

    # CustomObject
    objects_dir = default_root / "objects"
    if objects_dir.exists():
        for obj in objects_dir.iterdir():
            if obj.is_dir():
                has_content = any(True for _ in obj.rglob("*") if _.is_file())
                if has_content:
                    add_member(members, "CustomObject", parse_customobject_member(obj.as_posix()))

    # LWC/Aura
    for bundle_dir, md in [(default_root / "lwc", "LightningComponentBundle"),
                           (default_root / "aura", "AuraDefinitionBundle")]:
        if bundle_dir.exists():
            for bundle in bundle_dir.iterdir():
                if bundle.is_dir():
                    add_member(members, md, bundle.name)

    # Classes/Triggers
    for folder, mdtype, ext in [("classes","ApexClass",".cls"), ("triggers","ApexTrigger",".trigger")]:
        fdir = default_root / folder
        if fdir.exists():
            for f in fdir.glob(f"*{ext}"):
                add_member(members, mdtype, f.stem)

    # Flows / Layouts / FlexiPages / Workflows
    scans = [
        ("flows", "Flow", "*.flow-meta.xml", parse_flow_member),
        ("layouts", "Layout", "*.layout-meta.xml", parse_layout_member),
        ("flexipages", "FlexiPage", "*.flexipage-meta.xml", parse_flexipage_member),
        ("workflows", "Workflow", "*.workflow-meta.xml", lambda n: Path(n).stem.split(".")[0]), # object name
    ]
    for folder, mdtype, pattern, parser in scans:
        d = default_root / folder
        if d.exists():
            for f in d.glob(pattern):
                add_member(members, mdtype, parser(f.name))

    # Otros por patrón
    patterns = [
        ("permissionsets", "PermissionSet", "*.permissionset-meta.xml"),
        ("profiles", "Profile", "*.profile-meta.xml"),
        ("staticresources", "StaticResource", "*.resource-meta.xml"),
        ("tabs", "CustomTab", "*.tab-meta.xml"),
        ("applications", "CustomApplication", "*.app-meta.xml"),
        ("reportTypes", "ReportType", "*.reportType-meta.xml"),
        ("contentassets", "ContentAsset", "*.asset-meta.xml"),
        ("quickActions", "QuickAction", "*.quickAction-meta.xml"),
        ("objectTranslations", "CustomObjectTranslation", "*.objectTranslation"),
    ]
    for folder, mdtype, pattern in patterns:
        fdir = default_root / folder
        if fdir.exists():
            for f in fdir.glob(pattern):
                name = f.name.split(".")[0]
                add_member(members, mdtype, name)

    # Email templates
    email_dir = default_root / "email"
    if email_dir.exists():
        for folder in email_dir.glob("*"):
            if folder.is_dir():
                for f in folder.glob("*.email-meta.xml"):
                    member = parse_emailtemplate_member(Path(folder.name) / f.name)
                    add_member(members, "EmailTemplate", member)

    return members

def scan_datapack_for_entries(staging_root):
    entries = set()
    root_path = Path(staging_root)
    for root in DATA_PACK_ROOTS:
        dp_root = root_path / root
        if not dp_root.exists():
            continue
        for type_dir in dp_root.iterdir():
            if type_dir.is_dir():
                for name_dir in type_dir.iterdir():
                    if name_dir.is_dir():
                        entries.add(f"{type_dir.name}/{name_dir.name}")
    return entries

# ---- Writers ----
def prettify_xml(elem):
    rough = tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough)
    return reparsed.toprettyxml(indent="  ", encoding="UTF-8").decode("utf-8")

def write_package_xml(manifest_dir, members_dict, api_version="64.0"):
    pkg = Element('Package')
    pkg.set('xmlns', 'http://soap.sforce.com/2006/04/metadata')

    for md_type in sorted(members_dict.keys()):
        types_el = SubElement(pkg, 'types')
        for member in sorted(members_dict[md_type]):
            SubElement(types_el, 'members').text = member
        SubElement(types_el, 'name').text = md_type

    SubElement(pkg, 'version').text = api_version

    xml_str = prettify_xml(pkg)
    out_path = os.path.join(manifest_dir, "package.xml")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml_str)
    print(f"Generado: {out_path}")

def write_vbt_manifest(manifest_dir, datapack_entries):
    out_path = os.path.join(manifest_dir, "package-sfi.yaml")
    lines = []
    lines.append("projectPath: ./dataPack")
    lines.append("continueAfterError: true")
    lines.append("autoRetryErrors: true")
    lines.append("maxDepth: -1")
    lines.append("npmAuthKey: Y3VzdG9tZXJfdGVsbWV4X2IyYzo3eF9Wa1ZpQU82SWppTjJY")
    lines.append("\nmanifest:")
    for entry in sorted(datapack_entries):
        lines.append(f"  - {entry}")
    lines.append("\nOverrideSettings:")
    lines.append("  DataPacks:")
    lines.append("      Product2:")
    lines.append("          MaxDeploy: 1")
    lines.append("  SObjects:")
    lines.append("      vlocity_namespace__PromotionItem__c:")
    lines.append("          SourceKeyDefinition:")
    lines.append("              - vlocity_namespace__ProductId__c")
    lines.append("              - vlocity_namespace__PromotionId__c")
    lines.append("              - vlocity_namespace__OfferId__c")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Generado: {out_path}")

# ---- Main ----
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Copia cambios y genera manifiestos desde Archivos_Modificados")
    parser.add_argument("-sourcePath", type=str, default="./", help="Ruta origen del repo")
    args = parser.parse_args()

    source_path = args.sourcePath
    folder_name = 'Archivos_Modificados'
    target_path = os.path.join(source_path, folder_name)

    print(f'Directorio raiz origen: {source_path}')
    print(f'Directorio raiz destino: {target_path}')

    # 1) GIT DIFF
    try:
        print("Ejecutando: git diff --name-status origin/delta-target")
        result = subprocess.run(
            ["git", "diff", "--name-status", "origin/delta-target"],
            cwd=source_path,
            text=True,
            capture_output=True,
            check=True
        )
        source_path_changed_files = os.path.join(source_path, 'ArchivosCambiados.txt')
        with open(source_path_changed_files, 'w', encoding='utf-8') as out:
            out.write(result.stdout)
    except FileNotFoundError:
        print("Error: No se encontró 'git' en el PATH.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print("Error al ejecutar 'git diff --name-status origin/delta-target'. ¿Repo/branch válidos?")
        if e.stderr:
            print(e.stderr)
        sys.exit(1)

    # 2) Limpiar destino y copiar por diff
    if os.path.exists(target_path):
        shutil.rmtree(target_path)
    os.makedirs(target_path)

    if not os.path.exists(source_path_changed_files):
        print("No existe el archivo ArchivosCambiados.txt")
        sys.exit(1)

    with open(source_path_changed_files, 'r', encoding='utf-8') as f:
        content_modified_files = f.readlines()

    print_modified_files(content_modified_files)

    files_copied = 0
    if content_modified_files:
        files_copied = filter_and_copy_files(
            content_modified_files,
            origin_path=source_path,
            target_path=target_path,
        )
        if files_copied <= 0:
            print("No se encontraron archivos para desplegar")
    else:
        print("No existe diferencias de archivos")

    # 3) GENERAR MANIFIESTOS A PARTIR DE Archivos_Modificados
    manifest_dir = os.path.join(target_path, "manifest")
    os.makedirs(manifest_dir, exist_ok=True)

    package_members = scan_force_app_for_members(target_path)
    datapack_entries = scan_datapack_for_entries(target_path)

    if package_members:
        write_package_xml(manifest_dir, package_members, api_version="64.0")
    else:
        # package.xml vacío válido
        pkg = Element('Package'); pkg.set('xmlns', 'http://soap.sforce.com/2006/04/metadata')
        SubElement(pkg, 'version').text = "64.0"
        xml_str = minidom.parseString(tostring(pkg, 'utf-8')).toprettyxml(indent="  ", encoding="UTF-8").decode("utf-8")
        out_path = os.path.join(manifest_dir, "package.xml")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(xml_str)
        print(f"Generado: {out_path} (vacío)")

    write_vbt_manifest(manifest_dir, datapack_entries)

    # Resumen
    resumen = {k: len(v) for k, v in package_members.items()}
    print(f"Total archivos copiados a {folder_name}: {files_copied}")
    print("Miembros por tipo en package.xml:", resumen)
    print(f"Entradas VBT (datapack/vlocity): {len(datapack_entries)}")
    print(f"- Carpeta staging: {target_path}/")
    print(f"- Manifiestos en: {manifest_dir}/")

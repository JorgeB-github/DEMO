#!/usr/bin/env python3
# scripts/datapack.py

import argparse
import subprocess
import sys
from pathlib import Path


def sh(cmd: list[str]) -> str:
    return subprocess.check_output(cmd).decode("utf-8", errors="replace")


def git_diff_names(base: str, head: str, datapack: str) -> list[str]:
    cmd = ["git", "diff", "--name-only", f"{base}...{head}", "--", f"{datapack}/"]
    out = sh(cmd)
    return [ln.strip() for ln in out.splitlines() if ln.strip()]


def to_components(paths: list[str], datapack: str) -> list[str]:
    comps: set[str] = set()
    prefix = f"{datapack.strip('/')}/"
    for p in paths:
        if not p.startswith(prefix):
            continue
        parts = p.split("/")
        if len(parts) >= 3:
            comps.add(f"{parts[1]}/{parts[2]}")
    return sorted(comps)


def build_yaml(datapack: str, components: list[str]) -> str:
    """Construye el YAML como string sin usar PyYAML."""
    header = f"""projectPath: .
expansionPath: {datapack}
continueAfterError: true
autoUpdateSettings: true
compileOnBuild: true
npmAuthKey: Y3VzdG9tZXJfdGVsbWV4X2IyYzo3eF9Wa1ZpQU82SWppTjJY
activate: true
maxDepth: -1
manifest:
"""
    manifest_lines = "".join([f"    - {c}\n" for c in components])
    overrides = """OverrideSettings:
    DataPacks:
        Product2:
            MaxDeploy: 1
    SObjects:
        vlocity_namespace__PromotionItem__c:
            SourceKeyDefinition:
                - vlocity_namespace__OfferId__c
                - vlocity_namespace__ProductId__c
                - vlocity_namespace__PromotionId__c
"""
    return header + manifest_lines + overrides


def main() -> int:
    ap = argparse.ArgumentParser(description="Generar manifest SFI sin PyYAML")
    ap.add_argument("base", help="Rama o ref base (ej.: main)")
    ap.add_argument("head", help="Rama o ref head (ej.: HEAD o feature/x)")
    args = ap.parse_args()

    datapack = "dataPack"
    manifest_path = Path("package/sfi-package.yaml")

    changed = git_diff_names(args.base, args.head, datapack)
    if not changed:
        print(f"No hay cambios en '{datapack}' entre {args.base}...{args.head}.")
        return 0

    components = to_components(changed, datapack)
    if not components:
        print("No se encontraron componentes válidos.")
        return 0

    yaml_str = build_yaml(datapack, components)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(yaml_str, encoding="utf-8")

    print(f"Manifest generado en {manifest_path} con {len(components)} componentes:")
    print(yaml_str)
    return 0


if __name__ == "__main__":
    sys.exit(main())

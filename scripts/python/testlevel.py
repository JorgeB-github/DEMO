#!/usr/bin/env python3
# testlevel.py
# - Podar builds (metadata/datapack) según cambios en Git
# - Si hay nodo metadata, setear testLevel según ApexClass en package.xml
# - Insertar pre/postDestructiveChanges debajo de "manifestFile" si hubo cambios en sus XML
# - Insertar anonymousApex de scripts/apex/pre antes de dataPack y de scripts/apex/post después de dataPack

import argparse, json, subprocess, sys
from pathlib import Path
from typing import Iterable, Tuple, Optional, List
import xml.etree.ElementTree as ET

DEF_FILE  = "package/buildfile.json"     # tu buildfile
DEF_RANGE = "origin/develop...HEAD"      # rango Git por defecto
META_DIR  = "force-app"                  # carpeta con metadata
DATA_DIR  = "dataPack"                   # carpeta con datapacks (solo para detectar cambios)

POST_PATH = "manifest/postDestructive/destructiveChanges.xml"
PRE_PATH  = "manifest/preDestructive/destructiveChanges.xml"

PRE_APEX_DIR  = "scripts/apex/pre"
POST_APEX_DIR = "scripts/apex/post"

# ---------- Utilidades ----------
def run(cmd: List[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT).strip()

def git_diff_names_smart(base: str, head: str, path_filter: Optional[str] = None) -> List[str]:
    cmds = [
        ["git", "diff", "--name-only", f"{base}...{head}"],
        ["git", "diff", "--name-only", base, head],
    ]
    last_err = None
    for cmd in cmds:
        try:
            out = run(cmd)
            return [p for p in out.splitlines() if p]
        except subprocess.CalledProcessError as e:
            last_err = e
    if last_err:
        raise last_err
    return []

def changed_paths_from_range(git_range: str) -> List[str]:
    try:
        if "..." in git_range:
            base, head = git_range.split("...", 1)
            return git_diff_names_smart(base.strip(), head.strip())
        if " " in git_range:
            base, head = git_range.split(" ", 1)
            return git_diff_names_smart(base.strip(), head.strip())
        out = run(["git", "diff", "--name-only", git_range])
        return [p for p in out.splitlines() if p]
    except subprocess.CalledProcessError as e:
        if "..." not in git_range and " " not in git_range:
            try:
                return git_diff_names_smart(git_range.strip(), "HEAD")
            except subprocess.CalledProcessError:
                pass
        raise e

def any_under(paths: Iterable[str], folder: str) -> bool:
    prefix = folder.rstrip("/") + "/"
    return any(p.startswith(prefix) for p in paths)

def decide(meta_changed: bool, data_changed: bool) -> str:
    if meta_changed and not data_changed: return "meta_only"
    if data_changed and not meta_changed: return "data_only"
    if meta_changed and data_changed:     return "both"
    return "none"

def _local(tag: str) -> str:
    return tag.split('}', 1)[-1] if '}' in tag else tag

def has_apex_class(pkg_path: Path) -> bool:
    if not pkg_path or not pkg_path.exists():
        return False
    try:
        root = ET.parse(pkg_path).getroot()
        for t in root.iter():
            if _local(t.tag) != "types":
                continue
            for c in t:
                if _local(c.tag) == "name" and (c.text or "").strip() == "ApexClass":
                    return True
        return False
    except ET.ParseError:
        txt = pkg_path.read_text(encoding="utf-8", errors="ignore")
        return "<name>ApexClass</name>" in txt

# ---------- Helpers de buildfile ----------
def is_meta(b: dict) -> bool:
    return isinstance(b, dict) and b.get("type", "").lower() == "metadata"

def is_datapack(b: dict) -> bool:
    # Soporta "datapack" o "dataPack"
    return isinstance(b, dict) and b.get("type", "").lower() == "datapack"

def is_anonymous_apex(b: dict) -> bool:
    return isinstance(b, dict) and b.get("type", "").lower() == "anonymousapex"

def prune_builds(build_cfg: dict, decision: str) -> Tuple[dict, bool]:
    """
    Mantiene/borra bloques según cambios detectados:

      - 'meta_only'  -> quedan solo 'metadata'
      - 'data_only'  -> quedan solo 'dataPack'
      - 'both'       -> quedan ambos
      - 'none'       -> se eliminan 'metadata' y 'dataPack'
    """
    builds = build_cfg.get("builds", [])
    if not isinstance(builds, list):
        return build_cfg, False

    if decision == "meta_only":
        new_builds = [b for b in builds if is_meta(b)]
    elif decision == "data_only":
        new_builds = [b for b in builds if is_datapack(b)]
    elif decision == "both":
        new_builds = [b for b in builds if is_meta(b) or is_datapack(b)]
    else:  # "none" -> quitar ambos
        new_builds = [b for b in builds if not (is_meta(b) or is_datapack(b))]

    if new_builds == builds:
        return build_cfg, False

    build_cfg["builds"] = new_builds
    return build_cfg, True

def set_test_level_if_metadata(build_cfg: dict, repo_root: Path) -> Tuple[dict, bool, Optional[str]]:
    changed = False
    test_level: Optional[str] = None
    builds = build_cfg.get("builds", [])
    meta = next((b for b in builds if is_meta(b)), None)
    if not meta:
        return build_cfg, False, test_level

    manifest_rel = meta.get("manifestFile") or "manifest/package.xml"
    pkg_path = (repo_root / manifest_rel).resolve()

    apex = has_apex_class(pkg_path)
    desired = "RunSpecifiedTests" if apex else "NoTestRun"
    if meta.get("testLevel") != desired:
        meta["testLevel"] = desired
        changed = True
    return build_cfg, changed, desired

# ---- pre/postDestructive debajo de 'manifestFile' si hubo cambios ----
def _insert_after_key(d: dict, after_key: str, items: List[Tuple[str, object]]) -> bool:
    if not isinstance(d, dict):
        return False
    changed = False

    for k, v in items:
        if k in d and d[k] != v:
            d[k] = v
            changed = True

    need_reorder = any(k not in d for k, _ in items)
    if not need_reorder:
        return changed

    new_d = {}
    inserted = False
    for k, v in d.items():
        new_d[k] = v
        if k == after_key and not inserted:
            for nk, nv in items:
                if nk not in d:
                    new_d[nk] = nv
                    changed = True
            inserted = True

    if not inserted:
        for nk, nv in items:
            if nk not in new_d:
                new_d[nk] = nv
                changed = True

    d.clear()
    d.update(new_d)
    return changed

def add_destructive_changes_if_needed(build_cfg: dict, changed_files: List[str]) -> Tuple[dict, bool]:
    builds = build_cfg.get("builds", [])
    meta = next((b for b in builds if is_meta(b)), None)
    if not meta:
        return build_cfg, False

    post_changed = any(p == POST_PATH for p in changed_files)
    pre_changed  = any(p == PRE_PATH  for p in changed_files)

    items: List[Tuple[str, object]] = []
    if post_changed:
        items.append(("postDestructiveChanges", POST_PATH))
    if pre_changed:
        items.append(("preDestructiveChanges",  PRE_PATH))

    if not items:
        return build_cfg, False

    changed = _insert_after_key(meta, "manifestFile", items)
    return build_cfg, changed

# ---- anonymousApex antes/después de dataPack según scripts modificados ----
def _collect_changed_apex(changed_files: List[str], base_dir: str) -> List[str]:
    base = base_dir.rstrip("/") + "/"
    return sorted([p for p in changed_files if p.startswith(base) and p.endswith(".apex")])

def _first_datapack_index(builds: List[dict]) -> Optional[int]:
    for i, b in enumerate(builds):
        if is_datapack(b):
            return i
    return None

def _last_datapack_index(builds: List[dict]) -> Optional[int]:
    for i in range(len(builds) - 1, -1, -1):
        if is_datapack(builds[i]):
            return i
    return None

def _existing_anonymous_apex(builds: List[dict]) -> set:
    ex = set()
    for b in builds:
        if is_anonymous_apex(b) and "apexScript" in b:
            ex.add(str(b["apexScript"]))
    return ex

def insert_anonymous_apex_around_datapack(build_cfg: dict, changed_files: List[str]) -> Tuple[dict, bool, int, int]:
    """
    Inserta:
      - scripts en scripts/apex/pre/*.apex ANTES del primer dataPack
      - scripts en scripts/apex/post/*.apex DESPUÉS del último dataPack
    Evita duplicados por apexScript exacto.
    Devuelve (cfg, changed, count_pre, count_post)
    """
    builds: List[dict] = build_cfg.get("builds", [])
    if not isinstance(builds, list):
        return build_cfg, False, 0, 0

    pre_scripts  = _collect_changed_apex(changed_files, PRE_APEX_DIR)
    post_scripts = _collect_changed_apex(changed_files, POST_APEX_DIR)

    if not pre_scripts and not post_scripts:
        return build_cfg, False, 0, 0

    changed = False
    existing = _existing_anonymous_apex(builds)

    # --- Insert PRE antes del PRIMER dataPack ---
    pre_nodes = [{"type": "anonymousApex", "apexScript": p} for p in pre_scripts if p not in existing]
    if pre_nodes:
        idx = _first_datapack_index(builds)
        if idx is None:
            builds.extend(pre_nodes)
        else:
            builds[idx:idx] = pre_nodes
        changed = True
        existing.update([n["apexScript"] for n in pre_nodes])

    # --- Insert POST después del ÚLTIMO dataPack ---
    post_nodes = [{"type": "anonymousApex", "apexScript": p} for p in post_scripts if p not in existing]
    if post_nodes:
        idx = _last_datapack_index(builds)
        if idx is None:
            builds.extend(post_nodes)
        else:
            insert_pos = idx + 1
            builds[insert_pos:insert_pos] = post_nodes
        changed = True

    build_cfg["builds"] = builds
    return build_cfg, changed, len(pre_nodes), len(post_nodes)

# ---------- Main ----------
def main():
    ap = argparse.ArgumentParser(description="Podar builds por cambios en Git y ajustar testLevel por ApexClass.")
    ap.add_argument("--file", default=DEF_FILE, help="Ruta del buildfile JSON (default: %(default)s)")
    ap.add_argument("--range", help="Rango Git para diff (por ejemplo 'A...B' o 'A B').")
    ap.add_argument("--base", help="Base ref/SHA para diff (se combina con --head como 'base...head').")
    ap.add_argument("--head", help="Head ref/SHA para diff (se combina con --base como 'base...head').")
    ap.add_argument("--meta-dir", default=META_DIR, help="Carpeta metadata (default: %(default)s)")
    ap.add_argument("--data-dir", default=DATA_DIR, help="Carpeta datapack (default: %(default)s)")
    args = ap.parse_args()

    # Resolver rango efectivo
    if args.range:
        eff_range = args.range
    elif args.base and args.head:
        eff_range = f"{args.base}...{args.head}"
    else:
        eff_range = DEF_RANGE

    buildfile = Path(args.file)
    if not buildfile.exists():
        print(f"[ERROR] No existe el archivo: {buildfile}", file=sys.stderr)
        sys.exit(1)

    repo_root = Path.cwd()

    # 1) Detectar cambios en Git
    try:
        paths = changed_paths_from_range(eff_range)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] git diff falló para rango '{eff_range}':\n{e.output if hasattr(e, 'output') else e}", file=sys.stderr)
        sys.exit(2)

    meta_changed = any_under(paths, args.meta_dir)
    data_changed = any_under(paths, args.data_dir)
    decision = decide(meta_changed, data_changed)

    print(f"[INFO] Rango: {eff_range}")
    print(f"[INFO] Cambios: meta={meta_changed} ({args.meta_dir}/), data={data_changed} ({args.data_dir}/)")
    print(f"[INFO] Resultado: {decision}")

    # 2) Cargar buildfile y podar (incluye quitar metadata/datapack cuando no hay cambios)
    cfg = json.loads(buildfile.read_text(encoding="utf-8"))
    cfg, pruned = prune_builds(cfg, decision)

    # 3) metadata -> ajustar testLevel según ApexClass en package.xml (si sigue existiendo)
    cfg, tl_changed, tl_value = set_test_level_if_metadata(cfg, repo_root)

    # 4) pre/postDestructive debajo de "manifestFile" si hubo cambios
    cfg, destr_changed = add_destructive_changes_if_needed(cfg, paths)

    # 5) anonymousApex antes/después de dataPack según scripts modificados
    cfg, aa_changed, pre_count, post_count = insert_anonymous_apex_around_datapack(cfg, paths)

    # 6) Guardar si cambió algo
    if pruned or tl_changed or destr_changed or aa_changed:
        Path(DEF_FILE).write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("[OK] Buildfile actualizado.")
    else:
        print("[OK] Sin cambios en el buildfile.")

    # Logs informativos
    if tl_value:
        print(f"[INFO] testLevel(metadata) => {tl_value}")
    if destr_changed:
        print("[INFO] Se añadieron claves de destructiveChanges en metadata (debajo de 'manifestFile').")
    if aa_changed:
        print(f"[INFO] Se insertaron anonymousApex (pre: {pre_count}, post: {post_count}).")
    if decision == "none":
        print("[INFO] Sin cambios en force-app/ ni dataPack/: se quitaron nodos 'metadata' y 'dataPack' (si existían).")

if __name__ == "__main__":
    main()

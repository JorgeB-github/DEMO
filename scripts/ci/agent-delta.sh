#!/usr/bin/env bash
#
# Delta-based deploy/validate for Agentforce agents (proyecto dataprev).
#
# Reads the git diff between FROM_REF and TO_REF, builds a delta package.xml
# with sfdx-git-delta, then:
#   - metadata (flows, permission sets, apex, etc.) -> sf project deploy start
#   - agents (aiAuthoringBundle):
#       * USE_AGENTFORCE_DX=false (default / actual) -> sf project deploy start
#         (mismo path CLI que el core; draft bundles via metadata)
#       * USE_AGENTFORCE_DX=true  (legado)          -> sf agent publish + activate
#
# Antes de validar/desplegar agentes, si RENDER_ENV esta definido se renderizan
# los tokens por-ambiente (@@AGENT_USER@@ / @@RAG_CONFIG_ID@@) en los .agent
# cambiados usando scripts/ci/render-agents.sh + agentPipeline/<Agente>.env.
#
# If the delta includes Apex test classes (@isTest / testMethod), the metadata
# deploy/validate runs with --test-level RunSpecifiedTests for those classes;
# otherwise it uses NoTestRun.
#
# En orgs productivas / prod-like (p.ej. HOM) NoTestRun no esta permitido.
# Con REQUIRE_SPECIFIED_TESTS=true, si el delta no trae Apex ni tests, se suma
# FALLBACK_TEST_CLASS al package y se corre RunSpecifiedTests.
#
# Env vars:
#   FROM_REF           base git ref/sha   (fallback: <TO_REF>~1)
#   TO_REF             head git ref/sha   (default: HEAD)
#   MODE               validate | deploy  (default: validate)
#   TARGET_ORG         org alias/username (required)
#   SOURCE_DIR         package dir        (default: force-app)
#   RENDER_ENV         (opcional) ambiente para render-agents.sh (p.ej. qa)
#   USE_AGENTFORCE_DX  true|false         (default: false) — path legado sf agent
#   REQUIRE_SPECIFIED_TESTS  true|false   (default: false) — fuerza RunSpecifiedTests
#   FALLBACK_TEST_CLASS      (default: CiDeploySmokeTest) — dummy si no hay tests
#   RELEASE_NOTES      (deploy only) path to a cumulative CSV to append component rows
#   PR_NUMBER          (deploy only) PR number recorded in the release notes
#   TZ_RN              (opcional) zona horaria para fecha/hora de release notes
#
set -euo pipefail

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
MODE="${MODE:-validate}"
TARGET_ORG="${TARGET_ORG:?TARGET_ORG is required}"
SOURCE_DIR="${SOURCE_DIR:-force-app}"
RENDER_ENV="${RENDER_ENV:-}"
USE_AGENTFORCE_DX="${USE_AGENTFORCE_DX:-false}"
REQUIRE_SPECIFIED_TESTS="${REQUIRE_SPECIFIED_TESTS:-false}"
FALLBACK_TEST_CLASS="${FALLBACK_TEST_CLASS:-CiDeploySmokeTest}"
DELTA_DIR="delta"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Super agente (concierge) que orquesta a los subagentes. Solo aplica cuando
# USE_AGENTFORCE_DX=true (publish/activate). Configurable via CONCIERGE_AGENT.
CONCIERGE_AGENT="${CONCIERGE_AGENT:-GovBRConciergeAgent}"

# NOTA: config.description -> BotDefinition.Description tiene un limite duro de
# plataforma (1000). Con Agentforce DX, `sf agent publish` falla (STRING_TOO_LONG).
# Con path Salesforce CLI (metadata deploy) el guardrail de PR quedo desactivado
# en el workflow; reactivar check-agent-desc-length si se vuelve a DX.

# Resuelve la ultima version (BotVersion) de un agente y la activa de forma
# no interactiva (sin TTY en CI). Solo usado si USE_AGENTFORCE_DX=true.
activate_agent() {
  local a="$1" ver
  echo ">> Resolving latest version of ${a}..."
  ver="$(sf data query --target-org "$TARGET_ORG" --json \
    --query "SELECT VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName='${a}' ORDER BY VersionNumber DESC LIMIT 1" \
    2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const r=j.result&&j.result.records&&j.result.records[0];console.log(r?r.VersionNumber:"");}catch(e){console.log("");}})')"
  if [ -n "$ver" ]; then
    echo ">> Activating agent ${a} (version ${ver})"
    sf agent activate --api-name "$a" --version "$ver" --target-org "$TARGET_ORG"
  else
    echo ">> Could not resolve version number; trying activate (non-interactive)"
    sf agent activate --api-name "$a" --target-org "$TARGET_ORG" < /dev/null
  fi
}

# Devuelve exit 0 si el agente existe en la org (tiene al menos una BotVersion).
# Se usa para decidir si hay que (re)activar el super agente al final, con
# independencia de si el deactivate inicial tuvo exito (p.ej. ya estaba inactivo).
agent_exists() {
  local a="$1" cnt
  cnt="$(sf data query --target-org "$TARGET_ORG" --json \
    --query "SELECT Id FROM BotVersion WHERE BotDefinition.DeveloperName='${a}' LIMIT 1" \
    2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const n=j.result&&Array.isArray(j.result.records)?j.result.records.length:0;console.log(n);}catch(e){console.log(0);}})')"
  [ -n "$cnt" ] && [ "$cnt" != "0" ]
}

# Asegura un package.xml base y suma AiAuthoringBundle members (path CLI).
ensure_agents_in_meta_package() {
  if [ -z "$AGENTS" ]; then
    return 0
  fi
  if [ ! -f "$NOAGENT" ]; then
    API_VER="$(node -e 'try{process.stdout.write(String(require("./sfdx-project.json").sourceApiVersion||""))}catch(e){}' 2>/dev/null || true)"
    [ -z "$API_VER" ] && API_VER="66.0"
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
      echo "    <version>${API_VER}</version>"
      echo '</Package>'
    } > "$NOAGENT"
  fi
  # shellcheck disable=SC2086
  node "${SCRIPT_DIR}/add-members.js" "$NOAGENT" AiAuthoringBundle $AGENTS
  HAS_META="true"
}

# --- resolve FROM_REF (handle first push / shallow / invalid refs) ---
if [ -z "$FROM_REF" ] || ! git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
  echo ">> FROM_REF '${FROM_REF}' not usable; falling back to ${TO_REF}~1"
  FROM_REF="${TO_REF}~1"
fi

echo ">> MODE=${MODE}  FROM=${FROM_REF}  TO=${TO_REF}  ORG=${TARGET_ORG}  USE_AGENTFORCE_DX=${USE_AGENTFORCE_DX}"

# --- generate delta ---
rm -rf "$DELTA_DIR"; mkdir -p "$DELTA_DIR"
sf sgd source delta \
  --from "$FROM_REF" \
  --to "$TO_REF" \
  --output-dir "$DELTA_DIR" \
  --source-dir "$SOURCE_DIR"

PKG="${DELTA_DIR}/package/package.xml"
NOAGENT="${DELTA_DIR}/package-noagent.xml"

# --- detect changed agent bundles directly from git ---
# sfdx-git-delta may not recognize the (newer) AiAuthoringBundle metadata type,
# so we resolve changed agents from the git diff to be version-proof.
AGENTS_GIT="$(git diff --name-only "$FROM_REF" "$TO_REF" 2>/dev/null \
  | grep '/aiAuthoringBundles/' \
  | sed -E 's#.*/aiAuthoringBundles/([^/]+)/.*#\1#' \
  | sort -u || true)"

# --- split agents out of the sgd metadata package (if any) ---
# Con USE_AGENTFORCE_DX=true los agentes salen del package (publish aparte).
# Con false se vuelven a sumar al package mas abajo (sf project deploy).
AGENTS_PKG=""
if [ -f "$PKG" ]; then
  echo ">> Delta package.xml (sfdx-git-delta):"; cat "$PKG"; echo
  AGENTS_PKG="$(node "${SCRIPT_DIR}/split-package.js" "$PKG" "$NOAGENT")"
else
  echo ">> No package.xml produced by sfdx-git-delta (no classic metadata changed)."
fi

# union of agents detected via git diff and via sgd package
AGENTS="$(printf '%s\n%s\n' "$AGENTS_GIT" "$AGENTS_PKG" | sed '/^[[:space:]]*$/d' | sort -u)"

HAS_META="false"
if [ -f "$NOAGENT" ] && grep -q "<types>" "$NOAGENT"; then HAS_META="true"; fi

echo ">> Non-agent metadata to process: ${HAS_META}"
echo ">> Agents changed: ${AGENTS:-<none>}"

# --- (optional) render per-env tokens in the changed agents ---
# Reescribe los .agent en el workspace efimero del runner. Como el delta se
# calcula con git diff (commits), el render no afecta la deteccion de cambios.
if [ -n "$RENDER_ENV" ] && [ -n "$AGENTS" ] && [ -f "${SCRIPT_DIR}/render-agents.sh" ]; then
  echo ">> Rendering changed agents for env '${RENDER_ENV}'"
  TARGET_ENV="$RENDER_ENV" ONLY_AGENTS="$AGENTS" bash "${SCRIPT_DIR}/render-agents.sh"
fi

# --- detect Apex classes & resolve their tests -> RunSpecifiedTests ---
# Rules:
#   * A changed test class (@isTest / testMethod) is run as-is.
#   * A changed NON-test class whose test is NOT in the delta: we find its test
#     by naming convention, ADD it to the package (so it deploys) and run it.
CHANGED_CLS="$(git diff --name-only "$FROM_REF" "$TO_REF" 2>/dev/null | grep -E '\.cls$' || true)"
TEST_CLASSES=""        # all tests to run
EXTRA_TEST_MEMBERS=""  # tests to ADD to the package (their class wasn't in the delta as a test)

# Echo the test class name for a given class (by convention), or nothing.
find_test_for() {
  local cls="$1" cand f
  for cand in "${cls}Test" "${cls}_Test" "Test${cls}" "${cls}Tests"; do
    f="$(find "$SOURCE_DIR" -name "${cand}.cls" -print -quit 2>/dev/null || true)"
    if [ -n "$f" ]; then echo "$cand"; return 0; fi
  done
}

if [ -n "$CHANGED_CLS" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue   # skip deleted files
    base="$(basename "$f" .cls)"
    if grep -qiE '@istest|testmethod' "$f"; then
      TEST_CLASSES="${TEST_CLASSES}${base}"$'\n'
    else
      t="$(find_test_for "$base")"
      if [ -n "$t" ]; then
        echo ">> ${base} no trae su test en el cambio; sumando ${t}"
        TEST_CLASSES="${TEST_CLASSES}${t}"$'\n'
        EXTRA_TEST_MEMBERS="${EXTRA_TEST_MEMBERS}${t}"$'\n'
      else
        echo ">> WARN: no se encontro clase de test para ${base}"
      fi
    fi
  done <<< "$CHANGED_CLS"
fi
TEST_CLASSES="$(printf '%s' "$TEST_CLASSES" | sed '/^[[:space:]]*$/d' | sort -u)"
EXTRA_TEST_MEMBERS="$(printf '%s' "$EXTRA_TEST_MEMBERS" | sed '/^[[:space:]]*$/d' | sort -u)"

# Add the discovered tests to the package so they deploy alongside the change.
if [ -n "$EXTRA_TEST_MEMBERS" ] && [ -f "$NOAGENT" ]; then
  # shellcheck disable=SC2086
  node "${SCRIPT_DIR}/add-members.js" "$NOAGENT" ApexClass $EXTRA_TEST_MEMBERS
  HAS_META="true"
fi

# Prod-like orgs (HOM): NoTestRun is forbidden. If the delta has no Apex/tests
# but there is metadata or agents to process, inject FALLBACK_TEST_CLASS.
ensure_empty_package() {
  if [ -f "$NOAGENT" ]; then
    return 0
  fi
  API_VER="$(node -e 'try{process.stdout.write(String(require("./sfdx-project.json").sourceApiVersion||""))}catch(e){}' 2>/dev/null || true)"
  [ -z "$API_VER" ] && API_VER="66.0"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
    echo "    <version>${API_VER}</version>"
    echo '</Package>'
  } > "$NOAGENT"
}

if [ "$REQUIRE_SPECIFIED_TESTS" = "true" ] && [ -z "$TEST_CLASSES" ]; then
  if [ -n "$CHANGED_CLS" ]; then
    echo "ERROR: REQUIRE_SPECIFIED_TESTS=true but Apex changed without resolvable tests."
    echo "       Add/name a test class (*Test) for the Apex in the delta, then retry."
    exit 1
  fi
  will_deploy="false"
  if [ "$HAS_META" = "true" ] || [ -n "$AGENTS" ]; then
    will_deploy="true"
  fi
  if [ "$will_deploy" = "true" ]; then
    fallback_file="$(find "$SOURCE_DIR" -name "${FALLBACK_TEST_CLASS}.cls" -print -quit 2>/dev/null || true)"
    if [ -z "$fallback_file" ]; then
      echo "ERROR: fallback test class ${FALLBACK_TEST_CLASS}.cls not found under ${SOURCE_DIR}"
      exit 1
    fi
    echo ">> REQUIRE_SPECIFIED_TESTS: no Apex in delta; adding fallback ${FALLBACK_TEST_CLASS}"
    ensure_empty_package
    node "${SCRIPT_DIR}/add-members.js" "$NOAGENT" ApexClass "$FALLBACK_TEST_CLASS"
    HAS_META="true"
    TEST_CLASSES="$FALLBACK_TEST_CLASS"
  fi
fi

TEST_FLAGS="--test-level NoTestRun"
if [ -n "$TEST_CLASSES" ]; then
  TEST_FLAGS="--test-level RunSpecifiedTests"
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    TEST_FLAGS="${TEST_FLAGS} --tests ${t}"
  done <<< "$TEST_CLASSES"
fi
echo ">> Test classes detected: ${TEST_CLASSES:-<none>}"
echo ">> Test flags: ${TEST_FLAGS}"

deploy_meta() {
  # $1 = extra flags (e.g. --dry-run)
  sf project deploy start \
    --manifest "$NOAGENT" \
    --target-org "$TARGET_ORG" \
    $TEST_FLAGS \
    --ignore-warnings \
    --wait 33 $1
}

case "$MODE" in
  validate)
    # --- Agentforce DX (legado): compile-check server-side. Desactivado por default. ---
    if [ "$USE_AGENTFORCE_DX" = "true" ] && [ -n "$AGENTS" ]; then
      while IFS= read -r a; do
        [ -z "$a" ] && continue
        echo ">> Validating agent bundle (compile / Agentforce DX): ${a}"
        sf agent validate authoring-bundle --api-name "$a" --target-org "$TARGET_ORG"
      done <<< "$AGENTS"
    fi

    # Path Salesforce CLI: incluir AiAuthoringBundle en el manifiesto y dry-run.
    # (Con DX=true tambien se suman para check-only real contra la org.)
    ensure_agents_in_meta_package

    if [ "$HAS_META" = "true" ]; then
      echo ">> Validating metadata + agents (check-only / dry-run) against ${TARGET_ORG}..."
      deploy_meta "--dry-run"
    else
      echo ">> No metadata or agents to validate."
    fi
    ;;

  deploy)
    if [ "$USE_AGENTFORCE_DX" = "true" ]; then
      # --- Path legado Agentforce DX: metadata sin agentes + publish/activate ---
      if [ "$HAS_META" = "true" ]; then
        echo ">> Deploying metadata (non-agent)..."
        deploy_meta ""
      else
        echo ">> No non-agent metadata to deploy."
      fi
      if [ -n "$AGENTS" ]; then
        # Subagentes = todos los agentes cambiados excepto el super agente (concierge).
        SUBAGENTS="$(printf '%s\n' "$AGENTS" | grep -vx "$CONCIERGE_AGENT" || true)"
        CONCIERGE_CHANGED="false"
        if printf '%s\n' "$AGENTS" | grep -qx "$CONCIERGE_AGENT"; then CONCIERGE_CHANGED="true"; fi

        # 0) Determinar si el super agente ya existe en la org. Esta es la unica
        #    condicion para (re)activarlo al final: si existe, debe quedar ACTIVO
        #    al terminar el deploy, sin importar si estaba activo o inactivo al
        #    empezar. Asi evitamos que un concierge ya desactivado (por cualquier
        #    motivo) quede inactivo tras el deploy y rechace sesiones (412).
        CONCIERGE_EXISTS="false"
        if [ -n "$SUBAGENTS" ] || [ "$CONCIERGE_CHANGED" = "true" ]; then
          if agent_exists "$CONCIERGE_AGENT"; then
            CONCIERGE_EXISTS="true"
          else
            echo ">> Super agent ${CONCIERGE_AGENT} not found in org yet (will be created only if its bundle changed)."
          fi
        fi

        # 1) Antes de desplegar cualquier subagente, desactivar el super agente.
        #    Solo se intenta si hay subagentes a desplegar y el concierge ya existe.
        #    Si ya estaba inactivo (o el deactivate falla por cualquier motivo), NO
        #    se aborta el pipeline: se registra un WARN y se continua, porque de
        #    todos modos se reactivara al final.
        if [ -n "$SUBAGENTS" ] && [ "$CONCIERGE_EXISTS" = "true" ]; then
          echo ">> Deactivating super agent ${CONCIERGE_AGENT} before deploying subagents..."
          if sf agent deactivate --api-name "$CONCIERGE_AGENT" --target-org "$TARGET_ORG" < /dev/null; then
            echo ">> ${CONCIERGE_AGENT} deactivated."
          else
            echo ">> WARN: could not deactivate ${CONCIERGE_AGENT} (probably already inactive). Continuing; it will be reactivated at the end."
          fi
        fi

        # 2) Publicar + activar cada subagente.
        while IFS= read -r a; do
          [ -z "$a" ] && continue
          echo ">> Publishing agent bundle: ${a}"
          # --skip-retrieve evita un bug del CLI (@salesforce/agents) que crashea en
          # retrieveAgentMetadata con "Cannot read properties of undefined (reading 'map')"
          # cuando el agente tiene subagents sin acciones (n.tools undefined). El publish
          # y el deploy del bundle se realizan igual; en CI no necesitamos el retrieve-back.
          sf agent publish authoring-bundle --api-name "$a" --target-org "$TARGET_ORG" --concise --skip-retrieve
          activate_agent "$a"
        done <<< "$SUBAGENTS"

        # 3) Apenas termina el deploy de los subagentes, reactivar el super agente
        #    (antes del commit de release notes). Si el propio concierge cambio, se
        #    (re)publica primero y luego se activa.
        if [ "$CONCIERGE_CHANGED" = "true" ]; then
          echo ">> Publishing super agent bundle: ${CONCIERGE_AGENT}"
          # --skip-retrieve: ver nota arriba (bug del CLI en retrieveAgentMetadata).
          sf agent publish authoring-bundle --api-name "$CONCIERGE_AGENT" --target-org "$TARGET_ORG" --concise --skip-retrieve
          activate_agent "$CONCIERGE_AGENT"
        elif [ "$CONCIERGE_EXISTS" = "true" ]; then
          # Reactivar SIEMPRE que el super agente exista en la org, aunque el
          # deactivate inicial haya sido no-op (ya estaba inactivo). Asi el
          # concierge queda ACTIVO al terminar el deploy.
          echo ">> Reactivating super agent ${CONCIERGE_AGENT} after subagents deploy..."
          activate_agent "$CONCIERGE_AGENT"
        fi
      fi
    else
      # --- Path actual: Salesforce CLI para agentes + core ---
      ensure_agents_in_meta_package
      if [ "$HAS_META" = "true" ]; then
        echo ">> Deploying metadata + agents via Salesforce CLI (sf project deploy)..."
        deploy_meta ""
      else
        echo ">> No metadata or agents to deploy."
      fi
    fi
    # --- release notes (one CSV row per deployed component) ---
    if [ -n "${RELEASE_NOTES:-}" ]; then
      pkg_for_notes="$NOAGENT"; [ -f "$pkg_for_notes" ] || pkg_for_notes="-"
      echo ">> Recording release notes in ${RELEASE_NOTES}"
      # GitHub runners are UTC; use a local TZ (override with TZ_RN) for date/time.
      rn_tz="${TZ_RN:-America/Sao_Paulo}"
      rn_date="$(TZ="$rn_tz" date +%Y-%m-%d)"
      rn_time="$(TZ="$rn_tz" date +%H:%M:%S)"
      # shellcheck disable=SC2086
      node "${SCRIPT_DIR}/release-notes.js" "$pkg_for_notes" "${PR_NUMBER:-}" "$rn_date" "$rn_time" "$RELEASE_NOTES" $AGENTS
    fi
    ;;

  *)
    echo "Unknown MODE: ${MODE} (use validate|deploy)"; exit 2;;
esac

echo ">> Done."

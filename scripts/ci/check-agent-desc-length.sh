#!/usr/bin/env bash
#
# check-agent-desc-length.sh
#
# Guardrail de PR: mide la longitud de las `description` de los .agent CAMBIADOS
# y falla ANTES del merge si superan el limite del campo real donde Salesforce las
# guarda al compilar. Complementa a `sf agent validate` (no necesita org: corre en
# local/CI en segundos) y detecta el caso que hoy rompe el `publish`:
#   * subagent/start_agent .description > 2000 (GenAiPluginDefinition.Description).
#
# El chequeo real (parseo + limites) lo hace check-agent-desc-length.js.
#
# Uso (CI):
#   FROM_REF=<base.sha> TO_REF=<head.sha> bash scripts/ci/check-agent-desc-length.sh
#
# Uso (local, revisa TODOS los .agent):
#   CHECK_ALL=true bash scripts/ci/check-agent-desc-length.sh
#
# Env vars:
#   FROM_REF             base git ref/sha   (si no es usable, cae a <TO_REF>~1)
#   TO_REF               head git ref/sha   (default: HEAD)
#   CHECK_ALL            "true" para revisar todos los .agent (ignora el git diff)
#   BUNDLES_DIR          carpeta de bundles (default: force-app/main/default/aiAuthoringBundles)
#   CONFIG_DESC_LIMIT    default 1000 (config.description)   -> se pasa al node
#   SUBAGENT_DESC_LIMIT  default 2000 (subagent.description) -> se pasa al node
#
set -euo pipefail

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
CHECK_ALL="${CHECK_ALL:-false}"
BUNDLES_DIR="${BUNDLES_DIR:-force-app/main/default/aiAuthoringBundles}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- resolver lista de .agent a revisar ---
AGENT_FILES=""
if [ "$CHECK_ALL" = "true" ]; then
  echo ">> CHECK_ALL=true: revisando todos los .agent bajo ${BUNDLES_DIR}"
  AGENT_FILES="$(find "$BUNDLES_DIR" -name '*.agent' 2>/dev/null | sort -u || true)"
else
  # Fallback de FROM_REF (primer push / ref invalido / shallow).
  if [ -z "$FROM_REF" ] || ! git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
    echo ">> FROM_REF '${FROM_REF}' no usable; usando ${TO_REF}~1"
    FROM_REF="${TO_REF}~1"
  fi
  echo ">> Revisando .agent cambiados entre ${FROM_REF} y ${TO_REF}"
  AGENT_FILES="$(git diff --name-only --diff-filter=d "$FROM_REF" "$TO_REF" 2>/dev/null \
    | grep -E '/aiAuthoringBundles/.*\.agent$' \
    | sort -u || true)"
fi

if [ -z "$AGENT_FILES" ]; then
  echo ">> No hay archivos .agent para validar. OK."
  exit 0
fi

# Node ejecuta el parseo + limites y define el exit code.
# shellcheck disable=SC2086
node "${SCRIPT_DIR}/check-agent-desc-length.js" $AGENT_FILES

#!/usr/bin/env bash
#
# check-agent-tokens.sh
#
# Guardrail de PR: evita que un .agent se committee con los VALORES REALES del
# ambiente (dev/qa/...) en lugar de los TOKENS que el pipeline sustituye en el
# runner. Si esto pasara, el commit "pisaria" la config ambientable y el deploy
# quedaria clavado al ambiente donde se edito el agente.
#
# Reglas (por cada .agent CAMBIADO en el PR):
#   * Si la clave 'default_agent_user:'   existe -> su valor DEBE ser "@@AGENT_USER@@"
#   * Si la clave 'rag_feature_config_id:' existe -> su valor DEBE ser "@@RAG_CONFIG_ID@@"
#
# No exige que las claves existan: un agente sin RAG puede no tener
# 'rag_feature_config_id'. Solo valida que, si estan, tengan el token.
#
# Uso (CI):
#   FROM_REF=<base.sha> TO_REF=<head.sha> bash scripts/ci/check-agent-tokens.sh
#
# Uso (local, revisa TODOS los .agent):
#   CHECK_ALL=true bash scripts/ci/check-agent-tokens.sh
#
# Env vars:
#   FROM_REF     base git ref/sha   (si no es usable, cae a <TO_REF>~1)
#   TO_REF       head git ref/sha   (default: HEAD)
#   CHECK_ALL    "true" para revisar todos los .agent (ignora el git diff)
#   BUNDLES_DIR  carpeta de bundles (default: force-app/main/default/aiAuthoringBundles)
#
set -euo pipefail

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
CHECK_ALL="${CHECK_ALL:-false}"
BUNDLES_DIR="${BUNDLES_DIR:-force-app/main/default/aiAuthoringBundles}"

# key <-> token esperado
USER_KEY="default_agent_user"
USER_TOKEN="@@AGENT_USER@@"
RAG_KEY="rag_feature_config_id"
RAG_TOKEN="@@RAG_CONFIG_ID@@"

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

# Extrae el valor de una clave YAML-ish 'key: valor' (primera ocurrencia),
# recortando espacios y comillas. Devuelve vacio si la clave no esta.
read_agent_value() {
  local file="$1" key="$2"
  sed -nE "s/^[[:space:]]*${key}:[[:space:]]*(.*)$/\1/p" "$file" \
    | head -n1 \
    | sed -E 's/^["'\'']?//; s/["'\'']?[[:space:]]*$//'
}

errors=0
checked=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  checked=$((checked + 1))
  echo "-- ${f}"

  # default_agent_user
  if grep -qE "^[[:space:]]*${USER_KEY}:" "$f"; then
    val="$(read_agent_value "$f" "$USER_KEY")"
    if [ "$val" != "$USER_TOKEN" ]; then
      echo "   !! ${USER_KEY} = '${val}' (se esperaba el token '${USER_TOKEN}')"
      errors=$((errors + 1))
    fi
  fi

  # rag_feature_config_id
  if grep -qE "^[[:space:]]*${RAG_KEY}:" "$f"; then
    val="$(read_agent_value "$f" "$RAG_KEY")"
    if [ "$val" != "$RAG_TOKEN" ]; then
      echo "   !! ${RAG_KEY} = '${val}' (se esperaba el token '${RAG_TOKEN}')"
      errors=$((errors + 1))
    fi
  fi
done <<< "$AGENT_FILES"

echo ">> Agentes revisados: ${checked}  | Violaciones: ${errors}"

if [ "$errors" -gt 0 ]; then
  cat >&2 <<EOF
>> ERROR: hay .agent con valores reales de ambiente en lugar de tokens.
   Reemplazar en el/los archivo(s) .agent:
     ${USER_KEY}: "${USER_TOKEN}"
     ${RAG_KEY}: "${RAG_TOKEN}"
   Los valores por-ambiente los inyecta el pipeline (render-agents.sh) desde
   agentPipeline/<Agente>.env; NO deben commitearse en el .agent.
EOF
  exit 1
fi

echo ">> OK: todos los .agent cambiados usan los tokens."

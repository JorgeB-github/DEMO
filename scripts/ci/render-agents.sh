#!/usr/bin/env bash
#
# render-agents.sh  (EJEMPLO / referencia de diseño)
#
# Inyecta los valores por-ambiente (userId del bot + Data Library / RAG config id)
# dentro de cada archivo .agent, ANTES del deploy. Pensado para correr SOLO en CI:
# reescribe los archivos en el workspace efímero del runner; nada se commitea.
#
# Fuente de verdad: govbr-dataprev-sf/agentPipeline/<Agente>.env
#   name=GovBRMDSAgent
#   username.<env>=...
#   adl.config.id.<env>=...
#   adl.config.faq.id.<env>=...
#
# Tokens esperados en los .agent (tras tokenizar):
#   @@AGENT_USER@@       -> username.<env>
#   @@RAG_CONFIG_ID@@    -> adl.config.faq.id.<env>  (o adl.config.id.<env> segun el agente)
#
# Cada token se exige/sustituye SOLO si el .agent lo contiene. Un agente que no
# usa RAG/FAQ puede dejar 'adl.config.*.id.<env>' vacio sin romper el render
# (mientras su .agent no tenga @@RAG_CONFIG_ID@@).
#
# Uso:
#   TARGET_ENV=hom2 bash scripts/ci/render-agents.sh
#
# Env vars:
#   TARGET_ENV   ambiente destino: dev | qa | hom | hom2 ... hom7   (requerido)
#   PIPELINE_DIR carpeta de .env       (default: agentPipeline)
#   BUNDLES_DIR  carpeta de bundles     (default: force-app/main/default/aiAuthoringBundles)
#   DRY_RUN      si "true", solo muestra lo que haría
#   ONLY_AGENTS  (opcional) lista de api-names (separados por espacio/salto de linea)
#                a renderizar. Si se define, el resto de agentes se omite y NO
#                cuentan para el chequeo de valores faltantes. Util en CI delta:
#                renderiza solo los agentes incluidos en el cambio.
#
set -euo pipefail

TARGET_ENV="${TARGET_ENV:?TARGET_ENV is required (dev|qa|hom|hom2..hom7)}"
PIPELINE_DIR="${PIPELINE_DIR:-agentPipeline}"
BUNDLES_DIR="${BUNDLES_DIR:-force-app/main/default/aiAuthoringBundles}"
DRY_RUN="${DRY_RUN:-false}"
ONLY_AGENTS="${ONLY_AGENTS:-}"

# Normaliza el filtro a tokens separados por espacio (acepta saltos de linea).
ONLY_AGENTS="$(printf '%s' "$ONLY_AGENTS" | tr '\n' ' ')"
in_filter() {
  # true si no hay filtro, o si "$1" esta en la lista ONLY_AGENTS.
  [ -z "$ONLY_AGENTS" ] && return 0
  local needle="$1" a
  for a in $ONLY_AGENTS; do [ "$a" = "$needle" ] && return 0; done
  return 1
}

echo ">> Render agents for TARGET_ENV=${TARGET_ENV}"

# Lee una clave 'key=value' de un archivo .env (ignora comentarios y espacios).
read_env_key() {
  local file="$1" key="$2"
  # Escapa los puntos del nombre de la clave para el regex.
  local key_re="${key//./\\.}"
  sed -nE "s/^[[:space:]]*${key_re}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$file" \
    | tail -n1
}

# Sustituye un token por su valor en un archivo (idempotente).
replace_token() {
  local file="$1" token="$2" value="$3"
  # Usa '|' como delimitador para no chocar con '/' de emails/paths.
  local esc_value="${value//|/\\|}"
  sed -i.bak "s|${token}|${esc_value}|g" "$file" && rm -f "${file}.bak"
}

shopt -s nullglob
missing=0
processed=0

for env_file in "${PIPELINE_DIR}"/*.env; do
  agent_name="$(read_env_key "$env_file" "name")"
  if [ -z "$agent_name" ]; then
    echo ">> WARN: ${env_file} sin clave 'name'; se omite."
    continue
  fi

  if ! in_filter "$agent_name"; then
    echo ">> (filtro) ${agent_name} no esta en ONLY_AGENTS; se omite."
    continue
  fi

  agent_file="${BUNDLES_DIR}/${agent_name}/${agent_name}.agent"
  if [ ! -f "$agent_file" ]; then
    echo ">> WARN: no existe ${agent_file}; se omite ${agent_name}."
    continue
  fi

  user_value="$(read_env_key "$env_file" "username.${TARGET_ENV}")"
  rag_value="$(read_env_key "$env_file" "adl.config.faq.id.${TARGET_ENV}")"
  # Fallback: si no hay faq id, usar la data library "plana".
  [ -z "$rag_value" ] && rag_value="$(read_env_key "$env_file" "adl.config.id.${TARGET_ENV}")"

  # Detecta que tokens usa realmente el .agent: solo exigimos/sustituimos lo
  # que el bundle necesita. Asi un agente que NO usa RAG/FAQ puede tener
  # 'adl.config.*.id.<env>' vacio sin romper el render.
  needs_user=false
  if grep -q "@@AGENT_USER@@" "$agent_file"; then needs_user=true; fi
  needs_rag=false
  if grep -q "@@RAG_CONFIG_ID@@" "$agent_file"; then needs_rag=true; fi

  echo "   - ${agent_name}: user='${user_value:-<vacio>}' rag='${rag_value:-<vacio>}' (needs_user=${needs_user} needs_rag=${needs_rag})"

  # Solo es error si el .agent contiene el token pero falta su valor.
  if [ "$needs_user" = "true" ] && [ -z "$user_value" ]; then
    echo "     !! Falta 'username.${TARGET_ENV}' en ${env_file} (requerido por @@AGENT_USER@@)"
    missing=$((missing + 1))
    continue
  fi
  if [ "$needs_rag" = "true" ] && [ -z "$rag_value" ]; then
    echo "     !! Falta 'adl.config.[faq.]id.${TARGET_ENV}' en ${env_file} (requerido por @@RAG_CONFIG_ID@@)"
    missing=$((missing + 1))
    continue
  fi

  if [ "$needs_user" = "false" ] && [ "$needs_rag" = "false" ]; then
    echo "     (sin tokens @@...@@ en el .agent; nada que sustituir)"
    processed=$((processed + 1))
    continue
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "     (dry-run) no se escribe ${agent_file}"
  else
    [ "$needs_user" = "true" ] && replace_token "$agent_file" "@@AGENT_USER@@" "$user_value"
    [ "$needs_rag" = "true" ]  && replace_token "$agent_file" "@@RAG_CONFIG_ID@@" "$rag_value"
  fi
  processed=$((processed + 1))
done

echo ">> Procesados: ${processed}  | Con valores faltantes: ${missing}"

if [ "$missing" -gt 0 ]; then
  echo ">> ERROR: hay agentes sin valores para '${TARGET_ENV}'. Completar los .env." >&2
  exit 1
fi

echo ">> Done."

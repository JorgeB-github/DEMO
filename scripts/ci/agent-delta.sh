#!/usr/bin/env bash
#
# Delta-based deploy/validate for Agentforce agents.
#
# Reads the git diff between FROM_REF and TO_REF, builds a delta package.xml
# with sfdx-git-delta, then:
#   - metadata (flows, permission sets, apex, etc.) -> sf project deploy start
#   - agents (aiAuthoringBundle)                    -> sf agent publish + activate
#
# Env vars:
#   FROM_REF     base git ref/sha   (fallback: <TO_REF>~1)
#   TO_REF       head git ref/sha   (default: HEAD)
#   MODE         validate | deploy  (default: validate)
#   TARGET_ORG   org alias/username (required)
#   SOURCE_DIR   package dir        (default: force-app)
#
set -euo pipefail

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
MODE="${MODE:-validate}"
TARGET_ORG="${TARGET_ORG:?TARGET_ORG is required}"
SOURCE_DIR="${SOURCE_DIR:-force-app}"
DELTA_DIR="delta"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- resolve FROM_REF (handle first push / shallow / invalid refs) ---
if [ -z "$FROM_REF" ] || ! git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
  echo ">> FROM_REF '${FROM_REF}' not usable; falling back to ${TO_REF}~1"
  FROM_REF="${TO_REF}~1"
fi

echo ">> MODE=${MODE}  FROM=${FROM_REF}  TO=${TO_REF}  ORG=${TARGET_ORG}"

# --- generate delta ---
rm -rf "$DELTA_DIR"; mkdir -p "$DELTA_DIR"
sf sgd source delta \
  --from "$FROM_REF" \
  --to "$TO_REF" \
  --output-dir "$DELTA_DIR" \
  --source-dir "$SOURCE_DIR"

PKG="${DELTA_DIR}/package/package.xml"
NOAGENT="${DELTA_DIR}/package-noagent.xml"

if [ ! -f "$PKG" ]; then
  echo ">> No package.xml produced by delta. Nothing changed."
  exit 0
fi

echo ">> Delta package.xml:"; cat "$PKG"; echo

# --- split agents out of the metadata package ---
AGENTS="$(node "${SCRIPT_DIR}/split-package.js" "$PKG" "$NOAGENT")"

HAS_META="false"
if [ -f "$NOAGENT" ] && grep -q "<types>" "$NOAGENT"; then HAS_META="true"; fi

echo ">> Non-agent metadata to process: ${HAS_META}"
echo ">> Agents changed: ${AGENTS:-<none>}"

deploy_meta() {
  # $1 = extra flags (e.g. --dry-run)
  sf project deploy start \
    --manifest "$NOAGENT" \
    --target-org "$TARGET_ORG" \
    --test-level NoTestRun \
    --ignore-warnings \
    --wait 33 $1
}

case "$MODE" in
  validate)
    if [ "$HAS_META" = "true" ]; then
      echo ">> Validating metadata (check-only / dry-run)..."
      deploy_meta "--dry-run"
    else
      echo ">> No non-agent metadata to validate."
    fi
    if [ -n "$AGENTS" ]; then
      while IFS= read -r a; do
        [ -z "$a" ] && continue
        echo ">> Validating agent bundle: ${a}"
        sf agent validate authoring-bundle --api-name "$a" --target-org "$TARGET_ORG"
      done <<< "$AGENTS"
    fi
    ;;

  deploy)
    if [ "$HAS_META" = "true" ]; then
      echo ">> Deploying metadata..."
      deploy_meta ""
    else
      echo ">> No non-agent metadata to deploy."
    fi
    if [ -n "$AGENTS" ]; then
      while IFS= read -r a; do
        [ -z "$a" ] && continue
        echo ">> Publishing agent bundle: ${a}"
        sf agent publish authoring-bundle --api-name "$a" --target-org "$TARGET_ORG" --concise
        echo ">> Activating agent: ${a}"
        sf agent activate --api-name "$a" --target-org "$TARGET_ORG"
      done <<< "$AGENTS"
    fi
    ;;

  *)
    echo "Unknown MODE: ${MODE} (use validate|deploy)"; exit 2;;
esac

echo ">> Done."

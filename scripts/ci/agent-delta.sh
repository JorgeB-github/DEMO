#!/usr/bin/env bash
#
# Delta-based deploy/validate for Agentforce agents.
#
# Reads the git diff between FROM_REF and TO_REF, builds a delta package.xml
# with sfdx-git-delta, then:
#   - metadata (flows, permission sets, apex, etc.) -> sf project deploy start
#   - agents (aiAuthoringBundle)                    -> sf agent publish + activate
#
# If the delta includes Apex test classes (@isTest / testMethod), the metadata
# deploy/validate runs with --test-level RunSpecifiedTests for those classes;
# otherwise it uses NoTestRun.
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

# --- detect changed agent bundles directly from git ---
# sfdx-git-delta may not recognize the (newer) AiAuthoringBundle metadata type,
# so we resolve changed agents from the git diff to be version-proof.
AGENTS_GIT="$(git diff --name-only "$FROM_REF" "$TO_REF" 2>/dev/null \
  | grep '/aiAuthoringBundles/' \
  | sed -E 's#.*/aiAuthoringBundles/([^/]+)/.*#\1#' \
  | sort -u || true)"

# --- split agents out of the sgd metadata package (if any) ---
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

# --- detect changed Apex test classes -> RunSpecifiedTests ---
# If the delta includes one or more Apex test classes (@isTest / testMethod),
# run those specific tests during validate (check-only) and deploy.
CHANGED_CLS="$(git diff --name-only "$FROM_REF" "$TO_REF" 2>/dev/null | grep -E '\.cls$' || true)"
TEST_CLASSES=""
if [ -n "$CHANGED_CLS" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue   # skip deleted files
    if grep -qiE '@istest|testmethod' "$f"; then
      TEST_CLASSES="${TEST_CLASSES}$(basename "$f" .cls)"$'\n'
    fi
  done <<< "$CHANGED_CLS"
fi
TEST_CLASSES="$(printf '%s' "$TEST_CLASSES" | sed '/^[[:space:]]*$/d' | sort -u)"

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
        # Resolve the newest BotVersion so activate runs non-interactively (no TTY in CI).
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
      done <<< "$AGENTS"
    fi
    ;;

  *)
    echo "Unknown MODE: ${MODE} (use validate|deploy)"; exit 2;;
esac

echo ">> Done."

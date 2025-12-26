#!/usr/bin/env bash
set -euo pipefail

# Setup script for /speckit.document intake generator
# Usage: ./setup-document.sh --json

JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json|-j)
            JSON_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions if available
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
fi

# Determine repo root
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    HAS_GIT=true
else
    REPO_ROOT="$(pwd)"
    CURRENT_BRANCH="main"
    HAS_GIT=false
fi

# Check for existing constitution
CONSTITUTION_FILE="$REPO_ROOT/.specify/memory/constitution.md"
HAS_CONSTITUTION=false
if [[ -f "$CONSTITUTION_FILE" ]]; then
    HAS_CONSTITUTION=true
fi

# Determine next feature ID by scanning existing specs
SPECS_DIR="$REPO_ROOT/specs"
NEXT_ID="001"
EXISTING_FEATURES="[]"

if [[ -d "$SPECS_DIR" ]]; then
    HIGHEST=$(find "$SPECS_DIR" -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' 2>/dev/null | \
        sed 's/.*\/\([0-9]\{3\}\)-.*/\1/' | sort -rn | head -1 || echo "000")
    
    if [[ -n "$HIGHEST" && "$HIGHEST" != "000" ]]; then
        NEXT_NUM=$((10#$HIGHEST + 1))
        NEXT_ID=$(printf "%03d" "$NEXT_NUM")
    fi
    
    FEATURES_LIST=""
    for dir in "$SPECS_DIR"/[0-9][0-9][0-9]-*/; do
        if [[ -d "$dir" ]]; then
            FEATURE_NAME=$(basename "$dir")
            if [[ -n "$FEATURES_LIST" ]]; then
                FEATURES_LIST="$FEATURES_LIST,\"$FEATURE_NAME\""
            else
                FEATURES_LIST="\"$FEATURE_NAME\""
            fi
        fi
    done
    EXISTING_FEATURES="[$FEATURES_LIST]"
fi

INTAKE_BASE="$REPO_ROOT/.specify/intake"
mkdir -p "$INTAKE_BASE"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if $JSON_MODE; then
    cat << EOF
{
  "repo_root": "$REPO_ROOT",
  "intake_base": "$INTAKE_BASE",
  "suggested_feature_id": "$NEXT_ID",
  "has_git": $HAS_GIT,
  "current_branch": "$CURRENT_BRANCH",
  "has_constitution": $HAS_CONSTITUTION,
  "constitution_path": "$CONSTITUTION_FILE",
  "specs_dir": "$SPECS_DIR",
  "existing_features": $EXISTING_FEATURES,
  "timestamp": "$TIMESTAMP"
}
EOF
else
    echo "REPO_ROOT: $REPO_ROOT"
    echo "INTAKE_BASE: $INTAKE_BASE"
    echo "SUGGESTED_FEATURE_ID: $NEXT_ID"
    echo "HAS_GIT: $HAS_GIT"
    echo "HAS_CONSTITUTION: $HAS_CONSTITUTION"
fi

echo "" >&2
echo "✓ Intake generator ready" >&2
echo "  Next feature ID: $NEXT_ID" >&2
echo "  Constitution: $( $HAS_CONSTITUTION && echo "exists" || echo "not found" )" >&2
echo "" >&2

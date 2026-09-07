#!/usr/bin/env bash
# Local producer gate. CI and merger use the same policy with live PR bindings.
set -uo pipefail
BASE="${1:?usage: check-machinery-gate.sh <base-ref>}"
exec node "$(dirname "$0")/effect-policy-cli.mjs" --base="$BASE" --head=HEAD

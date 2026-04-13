#!/bin/sh

set -eu

exec sh scripts/ci/check-codebase-guardrails.sh "$@"
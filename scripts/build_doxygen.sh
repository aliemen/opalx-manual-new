#!/usr/bin/env bash
set -euo pipefail

manual_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export OPALX_SOURCE_DIR="${OPALX_SOURCE_DIR:-${manual_root}/../opalx}"

if [[ ! -d "${OPALX_SOURCE_DIR}/src" ]]; then
  echo "OPALX source directory not found: ${OPALX_SOURCE_DIR}" >&2
  exit 1
fi

api_output="${manual_root}/_site/api"
if [[ "${api_output}" != "${manual_root}/_site/api" ]]; then
  echo "Refusing to clean unexpected API output path: ${api_output}" >&2
  exit 1
fi

rm -rf "${api_output}"
mkdir -p "${api_output}"
cd "${manual_root}"
doxygen Doxyfile

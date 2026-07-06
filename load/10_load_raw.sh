#!/usr/bin/env bash
# Load NDJSON from ./data into the raw tables (full replace each run).
# Swap these files for a real source export (same shapes) to load production data.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BQ_PROJECT:?set BQ_PROJECT}"
: "${BQ_LOCATION:=australia-southeast1}"

for tbl in clubs players tournaments registrations payments matches; do
  echo "Loading padel_raw.$tbl ..."
  bq load \
    --project_id="$BQ_PROJECT" --location="$BQ_LOCATION" \
    --source_format=NEWLINE_DELIMITED_JSON \
    --replace \
    "padel_raw.${tbl}" "data/${tbl}.ndjson"
done
echo "Raw load complete."

#!/usr/bin/env bash
# Run the transform layer in dependency order: staging -> dimensions -> facts -> marts.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BQ_PROJECT:?set BQ_PROJECT}"
: "${BQ_LOCATION:=australia-southeast1}"

for f in \
  warehouse/transform/10_staging.sql \
  warehouse/transform/20_dimensions.sql \
  warehouse/transform/30_facts.sql \
  warehouse/marts/40_marts.sql
do
  echo ">> $f"
  bq query --project_id="$BQ_PROJECT" --location="$BQ_LOCATION" --use_legacy_sql=false \
    " $(cat "$f")"
done
echo "Transforms complete. Try:  bq query --use_legacy_sql=false 'SELECT * FROM padel_mart.v_monthly_revenue ORDER BY year_month LIMIT 20'"

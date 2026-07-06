#!/usr/bin/env bash
# Create datasets + typed raw tables. Run once per project.
# Requires: gcloud + bq CLI authenticated, and:
#   export BQ_PROJECT=your-gcp-project-id
#   export BQ_LOCATION=australia-southeast1   # or your region
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BQ_PROJECT:?set BQ_PROJECT to your GCP project id}"
: "${BQ_LOCATION:=australia-southeast1}"

echo "Project=$BQ_PROJECT  Location=$BQ_LOCATION"
# NOTE: leading space in the query string keeps bq's flag parser from treating a
# leading SQL "--" comment as a command-line flag.
bq query --project_id="$BQ_PROJECT" --location="$BQ_LOCATION" --use_legacy_sql=false \
  " $(cat warehouse/ddl/00_datasets.sql)"
bq query --project_id="$BQ_PROJECT" --location="$BQ_LOCATION" --use_legacy_sql=false \
  " $(cat warehouse/ddl/01_raw_tables.sql)"
echo "Datasets + raw tables created."

#!/usr/bin/env bash
# Post-deploy verification: run the headline marts in BigQuery and print them next
# to the local reconciliation oracle, so warehouse output can be eyeballed against
# an independent recompute from source.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BQ_PROJECT:?set BQ_PROJECT}"
: "${BQ_LOCATION:=australia-southeast1}"
Q() { bq query --project_id="$BQ_PROJECT" --location="$BQ_LOCATION" --use_legacy_sql=false --format=pretty "$1"; }

echo "############ BigQuery: total net revenue ############"
Q "SELECT ROUND(SUM(net_revenue_aud),2) AS total_net_revenue_aud,
          COUNTIF(is_paid) AS paid_registrations,
          COUNT(*) AS registrations
   FROM padel_core.fct_registration"

echo "############ BigQuery: top players by win rate ############"
Q "SELECT full_name, wins, matches_played, win_rate
   FROM padel_mart.v_player_leaderboard
   ORDER BY win_rate DESC, matches_played DESC LIMIT 5"

echo "############ BigQuery: refund rate by provider ############"
Q "SELECT * FROM padel_mart.v_refund_rate ORDER BY provider"

echo
echo "############ LOCAL oracle (should reconcile to the above) ############"
node tools/expected_metrics.mjs

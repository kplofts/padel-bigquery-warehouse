-- ============================================================================
-- BUSINESS-FACING MARTS (views over the star schema).
-- These are the questions the warehouse exists to answer. Views, not tables,
-- so they always reflect the latest facts; promote any of them to a scheduled
-- materialised table if query cost ever matters.
-- ============================================================================

-- 1) Monthly net revenue by club and category (the headline finance view).
CREATE OR REPLACE VIEW padel_mart.v_monthly_revenue AS
SELECT
  d.year_month,
  t.club_name,
  f.category,
  COUNT(*)                        AS registrations,
  COUNTIF(f.is_paid)              AS paid_registrations,
  ROUND(SUM(f.net_revenue_aud), 2) AS net_revenue_aud
FROM padel_core.fct_registration f
JOIN padel_core.dim_date       d ON f.registered_date = d.date_key
JOIN padel_core.dim_tournament t ON f.tournament_key  = t.tournament_key
GROUP BY d.year_month, t.club_name, f.category;

-- 2) Tournament fill rate: teams entered vs capacity.
CREATE OR REPLACE VIEW padel_mart.v_tournament_fill AS
SELECT
  t.tournament_key,
  t.tournament_name,
  t.club_name,
  t.category,
  t.max_teams,
  COUNT(f.registration_id)                                   AS teams_entered,
  ROUND(COUNT(f.registration_id) / t.max_teams, 3)           AS fill_rate,
  ROUND(SUM(f.net_revenue_aud), 2)                           AS net_revenue_aud
FROM padel_core.dim_tournament t
LEFT JOIN padel_core.fct_registration f ON t.tournament_key = f.tournament_key
WHERE t.status != 'cancelled'
GROUP BY t.tournament_key, t.tournament_name, t.club_name, t.category, t.max_teams;

-- 3) Player win-rate leaderboard (min 5 completed matches).
CREATE OR REPLACE VIEW padel_mart.v_player_leaderboard AS
SELECT
  p.player_key,
  p.full_name,
  p.country,
  p.age_band,
  COUNT(*)                                   AS matches_played,
  SUM(f.win_flag)                            AS wins,
  ROUND(SAFE_DIVIDE(SUM(f.win_flag), COUNT(*)), 3) AS win_rate
FROM padel_core.fct_match_participation f
JOIN padel_core.dim_player p ON f.player_key = p.player_key
GROUP BY p.player_key, p.full_name, p.country, p.age_band
HAVING matches_played >= 5;

-- 4) New-player acquisition by month (cohort sizing).
CREATE OR REPLACE VIEW padel_mart.v_player_acquisition AS
SELECT
  FORMAT_DATE('%Y-%m', joined_date) AS join_month,
  COUNT(*)                          AS new_players
FROM padel_core.dim_player
GROUP BY join_month;

-- 5) Refund rate by payment provider (finance/ops health check).
CREATE OR REPLACE VIEW padel_mart.v_refund_rate AS
SELECT
  provider,
  COUNT(*)                                              AS payments,
  COUNTIF(is_refunded)                                  AS refunds,
  ROUND(SAFE_DIVIDE(COUNTIF(is_refunded), COUNT(*)), 3) AS refund_rate,
  ROUND(SUM(IF(is_refunded, amount_aud, 0)), 2)         AS refunded_aud
FROM padel_stg.stg_payments
GROUP BY provider;

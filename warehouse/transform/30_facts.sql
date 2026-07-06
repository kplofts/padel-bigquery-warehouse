-- ============================================================================
-- FACT TABLES.
-- Partitioned by the event date and clustered by the highest-cardinality filter
-- key, so the common "revenue in month X for tournament/club Y" scans stay cheap.
-- ============================================================================

-- fct_registration: grain = one row per registration (a team entering a tournament).
CREATE OR REPLACE TABLE padel_core.fct_registration
PARTITION BY registered_date
CLUSTER BY tournament_key, club_key AS
SELECT
  r.registration_id,
  DATE(r.registered_at)                              AS registered_date,
  r.tournament_id                                    AS tournament_key,
  t.club_key,
  r.player_id                                        AS player_key,
  r.partner_player_id                                AS partner_player_key,
  t.category,
  t.surface,
  r.payment_status,
  r.is_paid,
  r.amount_paid_cents,
  r.amount_paid_aud,
  -- net revenue recognises refunds as zero
  IF(r.payment_status = 'refunded', 0, r.amount_paid_cents) AS net_revenue_cents,
  IF(r.payment_status = 'refunded', 0, r.amount_paid_aud)   AS net_revenue_aud
FROM padel_stg.stg_registrations r
JOIN padel_core.dim_tournament t
  ON r.tournament_id = t.tournament_key;

-- fct_match_participation: grain = one row per PLAYER per match (4 per doubles match).
-- Built by unpivoting the four player slots so player-level win rates are a simple GROUP BY.
CREATE OR REPLACE TABLE padel_core.fct_match_participation
PARTITION BY match_date
CLUSTER BY tournament_key, player_key AS
WITH slots AS (
  SELECT match_id, tournament_id, round, match_date, status, winner_team,
         team1_player1 AS player_id, 1 AS team FROM padel_stg.stg_matches
  UNION ALL
  SELECT match_id, tournament_id, round, match_date, status, winner_team,
         team1_player2, 1 FROM padel_stg.stg_matches
  UNION ALL
  SELECT match_id, tournament_id, round, match_date, status, winner_team,
         team2_player1, 2 FROM padel_stg.stg_matches
  UNION ALL
  SELECT match_id, tournament_id, round, match_date, status, winner_team,
         team2_player2, 2 FROM padel_stg.stg_matches
)
SELECT
  s.match_id,
  s.match_date,
  s.tournament_id           AS tournament_key,
  s.player_id               AS player_key,
  s.round,
  s.team,
  s.status,
  (s.team = s.winner_team)  AS is_winner,
  CAST(s.team = s.winner_team AS INT64) AS win_flag
FROM slots s
WHERE s.player_id IS NOT NULL       -- singles slots / missing partners drop out
  AND s.status = 'played';

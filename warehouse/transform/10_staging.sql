-- ============================================================================
-- STAGING: type-safe, cleaned, deduplicated. One staging table per source table.
-- This is where the "data cleansing" happens: trimming, normalising country/
-- gender, dropping duplicates, and deriving a few convenience columns.
-- ============================================================================

CREATE OR REPLACE TABLE padel_stg.stg_clubs AS
SELECT
  club_id,
  TRIM(name)            AS club_name,
  TRIM(city)            AS city,
  UPPER(TRIM(country))  AS country,
  created_at
FROM padel_raw.clubs;

CREATE OR REPLACE TABLE padel_stg.stg_players AS
SELECT
  player_id,
  TRIM(full_name)                                   AS full_name,
  LOWER(TRIM(email))                                AS email,
  UPPER(TRIM(country))                              AS country,        -- fix lower-case dirt
  CASE UPPER(COALESCE(gender, ''))
    WHEN 'M' THEN 'Male'
    WHEN 'F' THEN 'Female'
    ELSE 'Unknown'                                                     -- fold NULLs to a real member
  END                                               AS gender,
  date_of_birth,
  DATE_DIFF(DATE '2026-01-01', date_of_birth, YEAR) AS age_2026,
  created_at
FROM padel_raw.players;

CREATE OR REPLACE TABLE padel_stg.stg_tournaments AS
SELECT
  tournament_id,
  club_id,
  TRIM(name)                                  AS tournament_name,
  category,
  surface,
  entry_fee_cents,
  entry_fee_cents / 100.0                      AS entry_fee_aud,
  currency,
  max_teams,
  start_date,
  end_date,
  DATE_DIFF(end_date, start_date, DAY) + 1     AS duration_days,
  status,
  created_at
FROM padel_raw.tournaments;

-- Registrations can arrive more than once (retries/replays). Keep the latest per id.
CREATE OR REPLACE TABLE padel_stg.stg_registrations AS
SELECT * EXCEPT(rn) FROM (
  SELECT
    registration_id,
    tournament_id,
    player_id,
    partner_player_id,
    seed,
    amount_paid_cents,
    amount_paid_cents / 100.0                       AS amount_paid_aud,
    payment_status,
    (payment_status = 'paid')                       AS is_paid,
    registered_at,
    ROW_NUMBER() OVER (
      PARTITION BY registration_id ORDER BY registered_at DESC
    ) AS rn
  FROM padel_raw.registrations
)
WHERE rn = 1;

CREATE OR REPLACE TABLE padel_stg.stg_payments AS
SELECT
  payment_id,
  registration_id,
  provider,
  amount_cents,
  amount_cents / 100.0            AS amount_aud,
  currency,
  status,
  (status = 'refunded')          AS is_refunded,
  created_at
FROM padel_raw.payments;

CREATE OR REPLACE TABLE padel_stg.stg_matches AS
SELECT
  match_id,
  tournament_id,
  round,
  court,
  scheduled_at,
  DATE(scheduled_at)             AS match_date,
  team1_player1,
  team1_player2,
  team2_player1,
  team2_player2,
  winner_team,
  score,
  status
FROM padel_raw.matches;

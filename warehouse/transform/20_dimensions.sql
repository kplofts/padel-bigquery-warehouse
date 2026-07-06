-- ============================================================================
-- CONFORMED DIMENSIONS (star schema).
-- Design choice: business keys double as dimension keys (player_id, club_id,
-- tournament_id, date). At this scale that is cleaner and just as correct as
-- synthetic surrogate keys; the swap to surrogate keys is a documented next step.
-- ============================================================================

-- dim_date: one row per calendar day across the data's range (plus headroom).
CREATE OR REPLACE TABLE padel_core.dim_date AS
SELECT
  d                                            AS date_key,
  EXTRACT(YEAR    FROM d)                       AS year,
  EXTRACT(QUARTER FROM d)                       AS quarter,
  EXTRACT(MONTH   FROM d)                       AS month,
  FORMAT_DATE('%Y-%m', d)                       AS year_month,
  FORMAT_DATE('%B', d)                          AS month_name,
  EXTRACT(DAY     FROM d)                        AS day_of_month,
  EXTRACT(DAYOFWEEK FROM d)                      AS day_of_week,     -- 1=Sun
  FORMAT_DATE('%A', d)                          AS day_name,
  EXTRACT(DAYOFWEEK FROM d) IN (1, 7)           AS is_weekend
FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2023-01-01', DATE '2026-12-31')) AS d;

CREATE OR REPLACE TABLE padel_core.dim_player AS
SELECT
  player_id       AS player_key,
  full_name,
  email,
  country,
  gender,
  date_of_birth,
  age_2026,
  CASE
    WHEN age_2026 < 18 THEN 'Under 18'
    WHEN age_2026 < 30 THEN '18-29'
    WHEN age_2026 < 45 THEN '30-44'
    WHEN age_2026 < 60 THEN '45-59'
    ELSE '60+'
  END             AS age_band,
  DATE(created_at) AS joined_date
FROM padel_stg.stg_players;

CREATE OR REPLACE TABLE padel_core.dim_club AS
SELECT
  club_id    AS club_key,
  club_name,
  city,
  country,
  DATE(created_at) AS opened_date
FROM padel_stg.stg_clubs;

CREATE OR REPLACE TABLE padel_core.dim_tournament AS
SELECT
  t.tournament_id AS tournament_key,
  t.tournament_name,
  t.category,
  t.surface,
  t.currency,
  t.entry_fee_aud,
  t.max_teams,
  t.start_date,
  t.end_date,
  t.duration_days,
  t.status,
  t.club_id       AS club_key,               -- role of club within tournament grain
  c.club_name,
  c.city          AS club_city,
  c.country       AS club_country
FROM padel_stg.stg_tournaments t
LEFT JOIN padel_stg.stg_clubs c USING (club_id);

-- Raw landing tables. Typed to match source/schema.sql exactly (no cleaning here).
-- Loaded by `bq load --source_format=NEWLINE_DELIMITED_JSON --replace` from ./data.
-- Keeping raw as an immutable-ish 1:1 copy means transforms are always re-runnable.

CREATE OR REPLACE TABLE padel_raw.clubs (
  club_id     INT64,
  name        STRING,
  city        STRING,
  country     STRING,
  created_at  TIMESTAMP
);

CREATE OR REPLACE TABLE padel_raw.players (
  player_id     INT64,
  full_name     STRING,
  email         STRING,
  country       STRING,
  gender        STRING,
  date_of_birth DATE,
  created_at    TIMESTAMP
);

CREATE OR REPLACE TABLE padel_raw.tournaments (
  tournament_id   INT64,
  club_id         INT64,
  name            STRING,
  category        STRING,
  surface         STRING,
  entry_fee_cents INT64,
  currency        STRING,
  max_teams       INT64,
  start_date      DATE,
  end_date        DATE,
  status          STRING,
  created_at      TIMESTAMP
);

CREATE OR REPLACE TABLE padel_raw.registrations (
  registration_id   INT64,
  tournament_id     INT64,
  player_id         INT64,
  partner_player_id INT64,
  seed              INT64,
  amount_paid_cents INT64,
  payment_status    STRING,
  registered_at     TIMESTAMP
);

CREATE OR REPLACE TABLE padel_raw.matches (
  match_id      INT64,
  tournament_id INT64,
  round         STRING,
  court         STRING,
  scheduled_at  TIMESTAMP,
  team1_player1 INT64,
  team1_player2 INT64,
  team2_player1 INT64,
  team2_player2 INT64,
  winner_team   INT64,
  score         STRING,
  status        STRING
);

CREATE OR REPLACE TABLE padel_raw.payments (
  payment_id      INT64,
  registration_id INT64,
  provider        STRING,
  amount_cents    INT64,
  currency        STRING,
  status          STRING,
  created_at      TIMESTAMP
);

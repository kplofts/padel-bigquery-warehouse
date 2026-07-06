-- ============================================================================
-- SOURCE OLTP SCHEMA  (the "existing relational database")
-- PostgreSQL dialect. This mirrors a normalised transactional app database
-- (padel-tournament management, Tournly-style). The warehouse maps FROM this.
--
-- In production this schema lives in the app's Postgres. For this project the
-- same shapes are generated as NDJSON by tools/generate.mjs so the pipeline
-- runs end-to-end without a live database. To use a real source instead,
-- export these tables to NDJSON/CSV and drop them into ./data.
-- ============================================================================

CREATE TABLE clubs (
    club_id      BIGINT PRIMARY KEY,
    name         TEXT        NOT NULL,
    city         TEXT        NOT NULL,
    country      CHAR(2)     NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE players (
    player_id    BIGINT PRIMARY KEY,
    full_name    TEXT        NOT NULL,
    email        TEXT        NOT NULL,
    country      CHAR(2)     NOT NULL,
    gender       CHAR(1),                       -- 'M' | 'F' | NULL (dirty on purpose)
    date_of_birth DATE,
    created_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE tournaments (
    tournament_id   BIGINT PRIMARY KEY,
    club_id         BIGINT      NOT NULL REFERENCES clubs(club_id),
    name            TEXT        NOT NULL,
    category        TEXT        NOT NULL,       -- 'Open' | 'Mens' | 'Womens' | 'Mixed' | 'Junior'
    surface         TEXT        NOT NULL,       -- 'Indoor' | 'Outdoor'
    entry_fee_cents INTEGER     NOT NULL,
    currency        CHAR(3)     NOT NULL,
    max_teams       INTEGER     NOT NULL,
    start_date      DATE        NOT NULL,
    end_date        DATE        NOT NULL,
    status          TEXT        NOT NULL,       -- 'completed' | 'cancelled' | 'scheduled'
    created_at      TIMESTAMPTZ NOT NULL
);

CREATE TABLE registrations (
    registration_id   BIGINT PRIMARY KEY,
    tournament_id     BIGINT      NOT NULL REFERENCES tournaments(tournament_id),
    player_id         BIGINT      NOT NULL REFERENCES players(player_id),
    partner_player_id BIGINT      REFERENCES players(player_id),
    seed              INTEGER,
    amount_paid_cents INTEGER     NOT NULL DEFAULT 0,
    payment_status    TEXT        NOT NULL,     -- 'paid' | 'pending' | 'refunded' | 'waived'
    registered_at     TIMESTAMPTZ NOT NULL
);

CREATE TABLE matches (
    match_id        BIGINT PRIMARY KEY,
    tournament_id   BIGINT      NOT NULL REFERENCES tournaments(tournament_id),
    round           TEXT        NOT NULL,       -- 'R32' | 'R16' | 'QF' | 'SF' | 'F'
    court           TEXT,
    scheduled_at    TIMESTAMPTZ,
    team1_player1   BIGINT      REFERENCES players(player_id),
    team1_player2   BIGINT      REFERENCES players(player_id),
    team2_player1   BIGINT      REFERENCES players(player_id),
    team2_player2   BIGINT      REFERENCES players(player_id),
    winner_team     INTEGER,                    -- 1 | 2 | NULL (unplayed)
    score           TEXT,                       -- e.g. '6-3 6-4'
    status          TEXT        NOT NULL        -- 'played' | 'walkover' | 'scheduled'
);

CREATE TABLE payments (
    payment_id      BIGINT PRIMARY KEY,
    registration_id BIGINT      NOT NULL REFERENCES registrations(registration_id),
    provider        TEXT        NOT NULL,       -- 'stripe' | 'paypal'
    amount_cents    INTEGER     NOT NULL,
    currency        CHAR(3)     NOT NULL,
    status          TEXT        NOT NULL,       -- 'succeeded' | 'refunded' | 'failed'
    created_at      TIMESTAMPTZ NOT NULL
);

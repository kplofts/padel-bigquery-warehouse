#!/usr/bin/env node
// ============================================================================
// Local data-quality gate over the generated NDJSON. No cloud needed.
// Asserts primary-key uniqueness, referential integrity, and value domains,
// the same checks you'd otherwise run as post-load tests in the warehouse.
// Exits non-zero on any failure so it can gate a pipeline / CI step.
// ============================================================================

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA = path.join(__dirname, "..", "data");
const load = (n) =>
  fs.readFileSync(path.join(DATA, `${n}.ndjson`), "utf8")
    .trim().split("\n").map((l) => JSON.parse(l));

const t = {
  clubs: load("clubs"), players: load("players"), tournaments: load("tournaments"),
  registrations: load("registrations"), payments: load("payments"), matches: load("matches"),
};

let failures = 0;
const check = (name, ok, detail = "") => {
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${detail && !ok ? ` -> ${detail}` : ""}`);
  if (!ok) failures++;
};
const ids = (rows, k) => new Set(rows.map((r) => r[k]));
const uniquePK = (rows, k) => ids(rows, k).size === rows.length;
const fkOk = (rows, k, parentIds, allowNull = false) =>
  rows.filter((r) => !(allowNull && r[k] == null) && !parentIds.has(r[k]));

console.log("Data-quality checks:");

// Primary-key uniqueness
check("clubs.club_id unique",                 uniquePK(t.clubs, "club_id"));
check("players.player_id unique",             uniquePK(t.players, "player_id"));
check("tournaments.tournament_id unique",     uniquePK(t.tournaments, "tournament_id"));
check("registrations.registration_id unique", uniquePK(t.registrations, "registration_id"));
check("payments.payment_id unique",           uniquePK(t.payments, "payment_id"));
check("matches.match_id unique",              uniquePK(t.matches, "match_id"));

// Referential integrity
const playerIds = ids(t.players, "player_id");
const tourIds   = ids(t.tournaments, "tournament_id");
const clubIds   = ids(t.clubs, "club_id");
const regIds    = ids(t.registrations, "registration_id");

check("tournaments.club_id -> clubs",             fkOk(t.tournaments, "club_id", clubIds).length === 0);
check("registrations.tournament_id -> tournaments", fkOk(t.registrations, "tournament_id", tourIds).length === 0);
check("registrations.player_id -> players",       fkOk(t.registrations, "player_id", playerIds).length === 0);
check("registrations.partner_player_id -> players (nullable)", fkOk(t.registrations, "partner_player_id", playerIds, true).length === 0);
check("payments.registration_id -> registrations", fkOk(t.payments, "registration_id", regIds).length === 0);
check("matches.tournament_id -> tournaments",     fkOk(t.matches, "tournament_id", tourIds).length === 0);

// Value domains
const PAY = new Set(["paid", "pending", "refunded", "waived"]);
check("registrations.payment_status in domain",
  t.registrations.every((r) => PAY.has(r.payment_status)));
check("matches.winner_team in {1,2,null}",
  t.matches.every((m) => [1, 2, null].includes(m.winner_team)));
check("registrations.amount_paid_cents >= 0",
  t.registrations.every((r) => r.amount_paid_cents >= 0));

// Business sanity: paid registrations should carry a positive amount
const paidZero = t.registrations.filter((r) => r.payment_status === "paid" && r.amount_paid_cents <= 0);
check("paid registrations have amount > 0", paidZero.length === 0, `${paidZero.length} offending rows`);

console.log(`\n${failures === 0 ? "ALL CHECKS PASSED" : failures + " CHECK(S) FAILED"}`);
process.exit(failures === 0 ? 0 : 1);

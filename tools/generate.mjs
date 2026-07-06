#!/usr/bin/env node
// ============================================================================
// Synthetic source-data generator.
// Emits one NDJSON file per source table into ../data, matching source/schema.sql.
// Deterministic (seeded PRNG) so every run produces identical data -> the whole
// pipeline is reproducible and testable. Intentionally seeds some dirty values
// (null gender, whitespace, mixed-case country) so the staging layer has real
// cleaning to do.
//
//   node tools/generate.mjs            # default volumes
//   node tools/generate.mjs --scale 3  # 3x the rows
// ============================================================================

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(__dirname, "..", "data");
fs.mkdirSync(DATA_DIR, { recursive: true });

const scaleArg = process.argv.indexOf("--scale");
const SCALE = scaleArg > -1 ? Math.max(1, Number(process.argv[scaleArg + 1]) || 1) : 1;

// ---- deterministic PRNG (mulberry32) ----
let _s = 0x9e3779b9;
function rnd() {
  _s |= 0; _s = (_s + 0x6d2b79f5) | 0;
  let t = Math.imul(_s ^ (_s >>> 15), 1 | _s);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const int  = (lo, hi) => lo + Math.floor(rnd() * (hi - lo + 1));
const chance = (p) => rnd() < p;
const pad = (n, w) => String(n).padStart(w, "0");

// Fixed epoch base so output never depends on the wall clock (reproducible).
const DAY = 86400000;
const BASE = Date.UTC(2024, 0, 1);                       // 2024-01-01
const dateISO = (ms) => new Date(ms).toISOString().slice(0, 10);
const tsISO   = (ms) => new Date(ms).toISOString().replace(".000Z", "Z");

const COUNTRIES = ["AU", "ES", "AR", "IT", "FR", "US", "GB", "BR", "SE", "MX"];
const CITIES = {
  AU: ["Melbourne", "Sydney", "Brisbane"], ES: ["Madrid", "Barcelona"],
  AR: ["Buenos Aires"], IT: ["Rome", "Milan"], FR: ["Paris"], US: ["Austin"],
  GB: ["London"], BR: ["Sao Paulo"], SE: ["Stockholm"], MX: ["Mexico City"],
};
const FIRST = ["Alex","Maria","Juan","Sofia","Luca","Emma","Diego","Chloe","Marco","Lucia","Sam","Nadia","Pablo","Ines","Tom","Ana","Leo","Mia","Hugo","Vera"];
const LAST  = ["Garcia","Smith","Rossi","Martin","Silva","Lopez","Nguyen","Muller","Costa","Ferrari","Dubois","Jones","Sanchez","Bianchi","Andersson","Torres","Romero","Klein","Moreau","Reyes"];
const CATEGORIES = ["Open", "Mens", "Womens", "Mixed", "Junior"];
const ROUNDS = ["R32", "R16", "QF", "SF", "F"];

function writeNDJSON(name, rows) {
  const file = path.join(DATA_DIR, `${name}.ndjson`);
  fs.writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log(`  ${name.padEnd(14)} ${String(rows.length).padStart(6)} rows -> data/${name}.ndjson`);
}

console.log(`Generating synthetic source data (scale ${SCALE})...`);

// ---- clubs ----
const N_CLUBS = 8 * SCALE;
const clubs = [];
for (let i = 1; i <= N_CLUBS; i++) {
  const country = pick(COUNTRIES);
  clubs.push({
    club_id: i,
    name: `${pick(CITIES[country])} Padel Club ${pad(i, 2)}`,
    city: pick(CITIES[country]),
    country,
    created_at: tsISO(BASE - int(200, 900) * DAY),
  });
}

// ---- players ----
const N_PLAYERS = 500 * SCALE;
const players = [];
for (let i = 1; i <= N_PLAYERS; i++) {
  const country = pick(COUNTRIES);
  // deliberately dirty: ~4% null gender, some names with stray whitespace,
  // country occasionally lower-case so staging has to normalise.
  const dirtyCountry = chance(0.05) ? country.toLowerCase() : country;
  const name = `${pick(FIRST)} ${pick(LAST)}`;
  players.push({
    player_id: i,
    full_name: chance(0.03) ? `  ${name}  ` : name,
    email: `player${i}@example.com`,
    country: dirtyCountry,
    gender: chance(0.04) ? null : pick(["M", "F"]),
    date_of_birth: dateISO(Date.UTC(int(1975, 2010), int(0, 11), int(1, 28))),
    created_at: tsISO(BASE - int(0, 700) * DAY),
  });
}

// ---- tournaments ----
const N_TOURN = 60 * SCALE;
const tournaments = [];
for (let i = 1; i <= N_TOURN; i++) {
  const start = BASE + int(0, 540) * DAY;                 // spread across ~18 months
  const days = int(1, 3);
  const status = chance(0.08) ? "cancelled" : (start < BASE + 480 * DAY ? "completed" : "scheduled");
  tournaments.push({
    tournament_id: i,
    club_id: int(1, N_CLUBS),
    name: `${pick(CATEGORIES)} Cup ${pad(i, 3)}`,
    category: pick(CATEGORIES),
    surface: pick(["Indoor", "Outdoor"]),
    entry_fee_cents: pick([4000, 6000, 8000, 10000, 12000]),
    currency: "AUD",
    max_teams: pick([8, 16, 32]),
    start_date: dateISO(start),
    end_date: dateISO(start + days * DAY),
    status,
    created_at: tsISO(start - int(20, 90) * DAY),
  });
}

// ---- registrations + payments ----
const registrations = [];
const payments = [];
let regId = 0, payId = 0;
for (const t of tournaments) {
  if (t.status === "cancelled") continue;
  const teams = int(Math.floor(t.max_teams / 2), t.max_teams);   // fill rate 50-100%
  const startMs = Date.parse(t.start_date + "T00:00:00Z");
  for (let k = 0; k < teams; k++) {
    const p1 = int(1, N_PLAYERS);
    let p2 = int(1, N_PLAYERS);
    if (p2 === p1) p2 = (p2 % N_PLAYERS) + 1;
    const roll = rnd();
    const payment_status = roll < 0.80 ? "paid" : roll < 0.90 ? "pending" : roll < 0.96 ? "refunded" : "waived";
    const amount = (payment_status === "paid" || payment_status === "refunded") ? t.entry_fee_cents : 0;
    const registered_at = tsISO(startMs - int(1, 45) * DAY);
    regId++;
    registrations.push({
      registration_id: regId,
      tournament_id: t.tournament_id,
      player_id: p1,
      partner_player_id: p2,
      seed: k < 8 ? k + 1 : null,
      amount_paid_cents: amount,
      payment_status,
      registered_at,
    });
    if (payment_status === "paid" || payment_status === "refunded") {
      payId++;
      payments.push({
        payment_id: payId,
        registration_id: regId,
        provider: chance(0.85) ? "stripe" : "paypal",
        amount_cents: t.entry_fee_cents,
        currency: t.currency,
        status: payment_status === "refunded" ? "refunded" : "succeeded",
        created_at: registered_at,
      });
    }
  }
}

// ---- matches ----
const matches = [];
let matchId = 0;
const regsByTournament = {};
for (const r of registrations) (regsByTournament[r.tournament_id] ??= []).push(r);
for (const t of tournaments) {
  if (t.status !== "completed") continue;
  const regs = regsByTournament[t.tournament_id] || [];
  if (regs.length < 4) continue;
  const startMs = Date.parse(t.start_date + "T09:00:00Z");
  const nMatches = Math.max(3, Math.floor(regs.length / 2));
  for (let m = 0; m < nMatches; m++) {
    const a = pick(regs), b = pick(regs);
    if (a.registration_id === b.registration_id) continue;
    const status = chance(0.04) ? "walkover" : "played";
    const winner_team = status === "walkover" ? pick([1, 2]) : pick([1, 2]);
    matchId++;
    matches.push({
      match_id: matchId,
      tournament_id: t.tournament_id,
      round: pick(ROUNDS),
      court: `Court ${int(1, 6)}`,
      scheduled_at: tsISO(startMs + m * 3600000),
      team1_player1: a.player_id,
      team1_player2: a.partner_player_id,
      team2_player1: b.player_id,
      team2_player2: b.partner_player_id,
      winner_team,
      score: status === "walkover" ? null : `${pick(["6-3","6-4","7-5","6-2"])} ${pick(["6-4","6-2","7-6","6-3"])}`,
      status,
    });
  }
}

writeNDJSON("clubs", clubs);
writeNDJSON("players", players);
writeNDJSON("tournaments", tournaments);
writeNDJSON("registrations", registrations);
writeNDJSON("payments", payments);
writeNDJSON("matches", matches);
console.log("Done.");

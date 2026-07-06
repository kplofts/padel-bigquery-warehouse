#!/usr/bin/env node
// ============================================================================
// Reconciliation oracle. Recomputes the headline mart metrics straight from the
// source NDJSON, independently of the BigQuery SQL. After deploying, the marts in
// padel_mart must match these numbers -- the same source-vs-warehouse reconciliation
// you'd run to sign off a migration.
// ============================================================================

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA = path.join(__dirname, "..", "data");
const load = (n) =>
  fs.readFileSync(path.join(DATA, `${n}.ndjson`), "utf8")
    .trim().split("\n").map((l) => JSON.parse(l));

const tournaments = load("tournaments");
const registrations = load("registrations");
const payments = load("payments");
const matches = load("matches");
const aud = (cents) => cents / 100;
const r2 = (n) => Math.round(n * 100) / 100;

// --- Net revenue (mirrors fct_registration.net_revenue) ---
const netCents = (r) => (r.payment_status === "refunded" ? 0 : r.amount_paid_cents);
const totalNet = registrations.reduce((s, r) => s + netCents(r), 0);
const paidCount = registrations.filter((r) => r.payment_status === "paid").length;

// --- Net revenue by month ---
const byMonth = {};
for (const r of registrations) {
  const ym = r.registered_at.slice(0, 7);
  byMonth[ym] = (byMonth[ym] || 0) + netCents(r);
}
const topMonths = Object.entries(byMonth).sort((a, b) => b[0].localeCompare(a[0])).slice(0, 6);

// --- Average fill rate (mirrors v_tournament_fill) ---
const tById = Object.fromEntries(tournaments.map((t) => [t.tournament_id, t]));
const regsByT = {};
for (const r of registrations) (regsByT[r.tournament_id] ??= []).push(r);
const fills = tournaments
  .filter((t) => t.status !== "cancelled")
  .map((t) => (regsByT[t.tournament_id]?.length || 0) / t.max_teams);
const avgFill = fills.reduce((s, x) => s + x, 0) / fills.length;

// --- Player win rates (mirrors fct_match_participation + v_player_leaderboard) ---
const played = matches.filter((m) => m.status === "played");
const stat = {}; // player_id -> {p, w}
for (const m of played) {
  const slots = [
    [m.team1_player1, 1], [m.team1_player2, 1],
    [m.team2_player1, 2], [m.team2_player2, 2],
  ];
  for (const [pid, team] of slots) {
    if (pid == null) continue;
    (stat[pid] ??= { p: 0, w: 0 });
    stat[pid].p++;
    if (team === m.winner_team) stat[pid].w++;
  }
}
const leaderboard = Object.entries(stat)
  .filter(([, s]) => s.p >= 5)
  .map(([pid, s]) => ({ pid: +pid, played: s.p, wins: s.w, rate: r2(s.w / s.p) }))
  .sort((a, b) => b.rate - a.rate)
  .slice(0, 5);

// --- Refund rate by provider (mirrors v_refund_rate) ---
const prov = {};
for (const p of payments) {
  (prov[p.provider] ??= { n: 0, refunds: 0 });
  prov[p.provider].n++;
  if (p.status === "refunded") prov[p.provider].refunds++;
}

console.log("=== Expected mart metrics (reconciliation baseline) ===\n");
console.log(`Registrations: ${registrations.length}  |  paid: ${paidCount}`);
console.log(`Total net revenue: A$${r2(aud(totalNet)).toLocaleString()}\n`);

console.log("Net revenue by month (latest 6):");
for (const [ym, c] of topMonths) console.log(`  ${ym}   A$${r2(aud(c)).toLocaleString()}`);

console.log(`\nAverage tournament fill rate: ${(avgFill * 100).toFixed(1)}%`);

console.log("\nTop 5 players by win rate (min 5 matches):");
for (const p of leaderboard) console.log(`  player ${String(p.pid).padStart(3)}   ${p.wins}/${p.played}   ${(p.rate * 100).toFixed(0)}%`);

console.log("\nRefund rate by provider:");
for (const [name, s] of Object.entries(prov))
  console.log(`  ${name.padEnd(7)} ${s.refunds}/${s.n}   ${((s.refunds / s.n) * 100).toFixed(1)}%`);

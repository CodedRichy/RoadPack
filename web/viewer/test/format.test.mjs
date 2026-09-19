/* Tests for the honesty layer.
 *
 *   node --test web/viewer/test/
 *
 * No dependencies, no browser, no build step. These are the rules that make
 * the viewer safe to look at while deciding whether to turn around for someone,
 * so they are tested rather than trusted.
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  ageSeconds,
  deriveMember,
  deriveSnapshot,
  formatAge,
  formatDistance,
  formatDuration,
  freshnessState,
  statusMeta,
} from '../js/format.js';
import { decodePolyline, decodeRoute, looksPlausible } from '../js/polyline.js';
import { hydrateFixture } from '../js/devfixtures.js';

const NOW = Date.parse('2026-08-10T09:14:05Z');
const iso = (secondsAgo) => new Date(NOW - secondsAgo * 1000).toISOString();

const base = {
  member_key: 'Rk3Zq7Xa2Lmp',
  display_name: 'Ravi',
  chainage_m: 41200,
  position: [10.0231, 76.341],
  precision_m: 50,
  gap_from_leader_m: -4200,
  gap_from_leader_s: 420,
  status: 'riding',
  status_auto: false,
  stale: false,
  off_route: false,
  updated_at: iso(3),
};

const derive = (patch) =>
  deriveMember({ ...base, ...patch }, { nowMs: NOW, staleThresholdS: 90 });

/* --- Formatting ---------------------------------------------------------- */

test('formatAge speaks in units a rider reads at a glance', () => {
  assert.equal(formatAge(2), 'just now');
  assert.equal(formatAge(45), '45s ago');
  assert.equal(formatAge(300), '5m ago');
  assert.equal(formatAge(4500), '1h 15m ago');
  assert.equal(formatAge(null), 'time unknown');
});

test('formatDistance rounds coarsely below a kilometre', () => {
  assert.equal(formatDistance(432), '430 m');
  assert.equal(formatDistance(-4200), '4.2 km');
  assert.equal(formatDistance(38400), '38 km');
  assert.equal(formatDistance(undefined), null);
});

test('formatDuration', () => {
  assert.equal(formatDuration(42), '42s');
  assert.equal(formatDuration(420), '7 min');
  assert.equal(formatDuration(4500), '1h 15m');
});

test('ageSeconds refuses to guess at an unreadable timestamp', () => {
  assert.equal(ageSeconds('not a date', NOW), null);
  assert.equal(ageSeconds(undefined, NOW), null);
  assert.equal(ageSeconds(iso(30), NOW), 30);
});

/* --- Honesty rule 1: never show a stale position as live ----------------- */

test('a fresh member is live and shows a numeric gap', () => {
  const m = derive({});
  assert.equal(m.stale, false);
  assert.equal(m.gap.suppressed, false);
  assert.equal(m.gap.text, '4.2 km');
  assert.equal(m.gap.sub, '7 min behind');
  assert.equal(m.tone, 'protected');
});

test('past the stale threshold the gap is replaced by an age', () => {
  const m = derive({ updated_at: iso(400) });
  assert.equal(m.stale, true);
  assert.equal(m.gap.suppressed, true);
  assert.equal(m.gap.text, '6m ago');
  assert.match(m.stateLabel, /^Last seen 6m ago/);
  assert.equal(m.tone, 'muted');
});

test('the server stale flag is honoured even when the timestamp looks fresh', () => {
  const m = derive({ stale: true, updated_at: iso(2) });
  assert.equal(m.stale, true);
  assert.equal(m.gap.suppressed, true);
});

test('an unreadable timestamp counts as stale, never as live', () => {
  const m = derive({ updated_at: null });
  assert.equal(m.stale, true);
  assert.equal(m.gap.suppressed, true);
});

test('a stale member keeps its last reported position and gains no other', () => {
  const m = derive({ updated_at: iso(600) });
  assert.deepEqual(m.position, base.position);
  assert.equal(m.located, true);
});

/* --- Honesty rule 2: unreachable is not stopped -------------------------- */

test('unreachable and stopped are visually distinct in shape and in words', () => {
  const unreachable = statusMeta('unreachable');
  const stopped = statusMeta('stopped');
  assert.notEqual(unreachable.shape, stopped.shape);
  assert.notEqual(unreachable.label, stopped.label);
  assert.equal(unreachable.shape, 'ring');
  assert.equal(stopped.shape, 'square');
});

test('every status distinguishes by shape as well as tone (CVD safety)', () => {
  for (const code of ['riding', 'stopped', 'unreachable', 'possible_incident']) {
    const meta = statusMeta(code);
    assert.ok(meta.shape, `${code} has a shape`);
    assert.ok(meta.label, `${code} has a label`);
  }
});

/* --- Honesty rule 3: suppress the gap ------------------------------------ */

test('off route shows distance from the route and no route gap', () => {
  const m = derive({ off_route: true, display_state: 'off_route', off_route_m: 2300 });
  assert.equal(m.gap.suppressed, true);
  assert.equal(m.gap.text, 'Off route');
  assert.match(m.gap.sub, /2\.3 km from the route/);
  assert.ok(!m.gap.sub.includes('4.2'));
});

test('off route with no distance says so rather than inventing one', () => {
  const m = derive({ off_route: true, off_route_m: undefined });
  assert.equal(m.gap.sub, 'distance unavailable');
});

test('off route outranks stale in the gap slot, matching the producer', () => {
  const m = derive({
    off_route: true,
    display_state: 'off_route',
    off_route_m: 800,
    updated_at: iso(600),
  });
  assert.equal(m.displayState, 'off_route');
  assert.equal(m.gap.text, 'Off route');
  /* ...but staleness is still stated, and the marker still greys. */
  assert.equal(m.stale, true);
  assert.equal(m.tone, 'muted');
  assert.match(m.stateLabel, /Last seen 10m ago/);
});

test("the producer's display_state is honoured when present", () => {
  const m = derive({ display_state: 'locating' });
  assert.equal(m.displayState, 'locating');
  assert.equal(m.gap.text, 'Locating');
});

test('a locally aged-out member is promoted to stale however fresh the payload claims to be', () => {
  const m = derive({ display_state: 'ok', stale: false, updated_at: iso(400) });
  assert.equal(m.displayState, 'stale');
  assert.equal(m.gap.suppressed, true);
});

test('display_state "estimated" marks the number as estimated', () => {
  const m = derive({ display_state: 'estimated', gap_estimated: false });
  assert.equal(m.gap.suppressed, false);
  assert.equal(m.gap.estimated, true);
});

test('the leader is identified in the state line', () => {
  assert.match(derive({ role: 'leader' }).stateLabel, /leads/);
});

test('a member with no position is locating, not at the start line', () => {
  const m = derive({ position: null, chainage_m: null });
  assert.equal(m.located, false);
  assert.equal(m.gap.text, 'Locating');
});

test('a malformed position is not treated as a position', () => {
  assert.equal(derive({ position: [999, 999] }).located, false);
  assert.equal(derive({ position: ['a', 'b'] }).located, false);
});

/* --- Honesty rule 4: mark estimates -------------------------------------- */

test('an estimated gap is flagged as estimated', () => {
  assert.equal(derive({ gap_estimated: true }).gap.estimated, true);
  assert.equal(derive({}).gap.estimated, false);
});

/* --- Precedence and tiering ---------------------------------------------- */

test('a possible incident keeps the emergency tier even when stale', () => {
  const m = derive({ status: 'possible_incident', status_auto: true, updated_at: iso(900) });
  assert.equal(m.tone, 'emergency');
  assert.equal(m.stale, true);
  assert.match(m.stateLabel, /Last seen/);
});

test('off route does not reach the reserved emergency tier', () => {
  assert.equal(derive({ off_route: true }).tone, 'attention');
});

test('automatic statuses are labelled as automatic', () => {
  const m = derive({ status: 'unexplained_stop', status_auto: true });
  assert.match(m.stateLabel, /detected automatically/);
});

/* --- Identity: member_key, and nothing else ------------------------------ */

test('identity is keyed on member_key, not on the name or the array position', () => {
  const a = derive({ member_key: 'Bt9Ye1Cv8Qsd', display_name: 'Ravi' });
  const b = derive({ member_key: 'Hn4Uw6Gk0Jrz', display_name: 'Ravi' });
  assert.equal(a.key, 'Bt9Ye1Cv8Qsd');
  assert.notEqual(a.key, b.key, 'two riders sharing a first name are distinct');
});

test('a member_key survives the array reordering, which an index key would not', () => {
  const raw = (names) => ({
    status: 'active',
    generated_at: iso(2),
    members: names.map(([key, name, chainage]) => ({
      ...base,
      member_key: key,
      display_name: name,
      chainage_m: chainage,
    })),
  });
  const first = deriveSnapshot(
    raw([
      ['k-front', 'Ravi', 40000],
      ['k-back', 'Ravi', 100],
    ]),
    { nowMs: NOW },
  );
  /* Same two people, emitted in the opposite order and having swapped places
   * on the road. The key that follows each person must not change. */
  const second = deriveSnapshot(
    raw([
      ['k-back', 'Ravi', 40000],
      ['k-front', 'Ravi', 100],
    ]),
    { nowMs: NOW },
  );
  assert.equal(first.members[0].key, 'k-front');
  assert.equal(second.members[0].key, 'k-back');
});

test('a member with no member_key gets no identity rather than a guessed one', () => {
  const m = deriveMember(
    { ...base, member_key: undefined },
    { nowMs: NOW, staleThresholdS: 90 },
  );
  assert.equal(m.key, null, 'no name#index fallback exists');
  assert.equal(m.name, 'Ravi', 'the roster can still list them');
});

/* --- Off-route distance -------------------------------------------------- */

test('off_route_m is the only field read for the off-route distance', () => {
  const m = derive({
    off_route: true,
    display_state: 'off_route',
    off_route_m: undefined,
    straight_m: 2300,
  });
  assert.equal(m.gap.sub, 'distance unavailable');
});

/* --- Snapshot ------------------------------------------------------------ */

test('members sort front of pack first, unlocated last', () => {
  const snap = deriveSnapshot(
    {
      status: 'active',
      generated_at: iso(2),
      route: { polyline: '', length_m: 50000 },
      members: [
        { ...base, display_name: 'Back', chainage_m: 100 },
        { ...base, display_name: 'Nowhere', chainage_m: null, position: null },
        { ...base, display_name: 'Front', chainage_m: 40000 },
      ],
    },
    { nowMs: NOW },
  );
  assert.deepEqual(
    snap.members.map((m) => m.name),
    ['Front', 'Back', 'Nowhere'],
  );
});

test('a per-ride stale threshold in the payload overrides the client default', () => {
  const raw = {
    status: 'active',
    generated_at: iso(2),
    stale_threshold_s: 600,
    members: [{ ...base, updated_at: iso(300) }],
  };
  assert.equal(deriveSnapshot(raw, { nowMs: NOW }).members[0].stale, false);
  const strict = deriveSnapshot({ ...raw, stale_threshold_s: 90 }, { nowMs: NOW });
  assert.equal(strict.members[0].stale, true);
});

test('the payload stale threshold overrides the caller default outright', () => {
  const raw = {
    status: 'active',
    generated_at: iso(2),
    stale_threshold_s: 300,
    members: [{ ...base, updated_at: iso(200) }],
  };
  /* The caller passes config.STALE_THRESHOLD_S; the ride's own column wins,
   * in both directions, so this page and the app never disagree about who is
   * stale. */
  const loose = deriveSnapshot(raw, { nowMs: NOW, staleThresholdS: 90 });
  assert.equal(loose.staleThresholdS, 300);
  assert.equal(loose.members[0].stale, false);

  const tight = deriveSnapshot(
    { ...raw, stale_threshold_s: 60 },
    { nowMs: NOW, staleThresholdS: 3600 },
  );
  assert.equal(tight.staleThresholdS, 60);
  assert.equal(tight.members[0].stale, true);
});

test('a payload with no stale threshold falls back to the caller, then to 90', () => {
  const raw = { status: 'active', generated_at: iso(2), members: [base] };
  assert.equal(deriveSnapshot(raw, { nowMs: NOW, staleThresholdS: 45 }).staleThresholdS, 45);
  assert.equal(deriveSnapshot(raw, { nowMs: NOW }).staleThresholdS, 90);
});

/* --- Visible audience (PM-55) -------------------------------------------- */

test('an absent viewer_count renders nothing, never a fabricated zero', () => {
  const raw = { status: 'active', generated_at: iso(2), members: [base] };
  assert.equal(deriveSnapshot(raw, { nowMs: NOW }).viewerCount, null);
  assert.equal(
    deriveSnapshot({ ...raw, viewer_count: null }, { nowMs: NOW }).viewerCount,
    null,
  );
});

test('a real viewer_count is passed through, including a true zero', () => {
  const raw = { status: 'active', generated_at: iso(2), members: [base] };
  assert.equal(deriveSnapshot({ ...raw, viewer_count: 7 }, { nowMs: NOW }).viewerCount, 7);
  /* A ride that HAS been beaconed and currently has nobody watching is a fact,
   * and differs from never having been beaconed at all. */
  assert.equal(deriveSnapshot({ ...raw, viewer_count: 0 }, { nowMs: NOW }).viewerCount, 0);
  assert.equal(
    deriveSnapshot({ ...raw, viewer_count: 'lots' }, { nowMs: NOW }).viewerCount,
    null,
  );
});

test('an incident anywhere in the pack surfaces on the snapshot', () => {
  const snap = deriveSnapshot(
    {
      status: 'active',
      generated_at: iso(2),
      members: [base, { ...base, display_name: 'Faisal', status: 'possible_incident' }],
    },
    { nowMs: NOW },
  );
  assert.equal(snap.incident.name, 'Faisal');
});

test('a garbage snapshot degrades to empty rather than throwing', () => {
  const snap = deriveSnapshot(null, { nowMs: NOW });
  assert.deepEqual(snap.members, []);
  assert.equal(snap.status, 'unknown');
});

/* --- Freshness ----------------------------------------------------------- */

test('freshness is live, lagging, then frozen', () => {
  const opts = { warnS: 12, frozenS: 30 };
  assert.equal(freshnessState(3, opts), 'live');
  assert.equal(freshnessState(20, opts), 'lagging');
  assert.equal(freshnessState(90, opts), 'frozen');
  assert.equal(freshnessState(null, opts), 'frozen');
});

/* --- Polyline ------------------------------------------------------------ */

test('decodes a known precision-5 polyline', () => {
  const coords = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  assert.equal(coords.length, 3);
  assert.deepEqual(
    coords[0].map((n) => Number(n.toFixed(5))),
    [-120.2, 38.5],
  );
});

test('decodeRoute rejects garbage instead of drawing it', () => {
  assert.deepEqual(decodeRoute(''), []);
  assert.deepEqual(decodeRoute('!!!!'), []);
  assert.equal(looksPlausible([[0, 0]]), false);
});

test('decodeRoute decodes at precision 5 only and never retries at 6', () => {
  const encoded = '_p|{@kiupMffAcbDn|CohCwcAowHgbC_dIgY_kHnF_gEbB_gEcBooB';
  assert.deepEqual(decodeRoute(encoded), decodePolyline(encoded));
  /* Precision 5 is the confirmed contract, so decodePolyline takes no
   * precision argument at all -- a stray one must not change the result. */
  assert.deepEqual(decodePolyline(encoded, 6), decodePolyline(encoded));
});

test('the sample route decodes to plausible coordinates in Kerala', () => {
  const coords = decodeRoute(
    '_p|{@kiupMffAcbDn|CohCwcAowHgbC_dIgY_kHnF_gEbB_gEcBooB',
  );
  assert.ok(coords.length > 2);
  for (const [lng, lat] of coords) {
    assert.ok(lat > 9 && lat < 11, `lat ${lat} in Kerala`);
    assert.ok(lng > 75 && lng < 78, `lng ${lng} in Kerala`);
  }
});

/* --- Dev fixtures -------------------------------------------------------- */

test('fixture timestamps resolve relative to now', () => {
  const out = hydrateFixture(
    {
      generated_at: 'REPLACED_AT_LOAD',
      members: [{ updated_at: 'STALE_6M' }, { updated_at: 'STALE_30S' }],
    },
    NOW,
  );
  assert.equal(Date.parse(out.generated_at), NOW);
  assert.equal(ageSeconds(out.members[0].updated_at, NOW), 360);
  assert.equal(ageSeconds(out.members[1].updated_at, NOW), 30);
});

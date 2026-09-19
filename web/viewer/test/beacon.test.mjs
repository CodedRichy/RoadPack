/* Tests for the viewer beacon (PM-55 / PM-73).
 *
 *   node --test web/viewer/test/
 *
 * The beacon exists so the riders' visible audience count is a true number.
 * Two things are being protected here, and neither is the count itself:
 *
 *  1. The beacon can never break the page. Every failure -- unconfigured,
 *     refused, offline, storage disabled -- has to be silent and harmless.
 *  2. The session id must not identify anyone or persist across visits.
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import { beaconUrl, sendBeacon, startBeacon, viewerSessionId } from '../js/beacon.js';
import { deriveSnapshot } from '../js/format.js';

const CFG = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon-publishable-key',
  BEACON_MS: 30000,
};

/** Minimal in-memory Storage stand-in. */
function memoryStorage() {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
    removeItem: (k) => map.delete(k),
  };
}

/* --- Session id ---------------------------------------------------------- */

test('the session id is per tab, opaque, and inside the shape the server accepts', () => {
  const store = memoryStorage();
  const id = viewerSessionId(store);
  assert.match(id, /^[A-Za-z0-9_-]{8,64}$/, 'matches the server validation regex');
  assert.equal(viewerSessionId(store), id, 'stable within the tab');

  /* A second tab is a second viewer, not the same one returning. */
  const other = viewerSessionId(memoryStorage());
  assert.notEqual(other, id);
});

test('a session id survives storage being unavailable', () => {
  const id = viewerSessionId(null);
  assert.match(id, /^[A-Za-z0-9_-]{8,64}$/);
});

test('a corrupted stored id is replaced rather than sent', () => {
  const store = memoryStorage();
  store.setItem('roadpack.viewer.session', 'not a valid id!!');
  assert.match(viewerSessionId(store), /^[A-Za-z0-9_-]{8,64}$/);
});

test('the beacon never touches localStorage', async () => {
  const src = await import('node:fs/promises').then((fs) =>
    fs.readFile(new URL('../js/beacon.js', import.meta.url), 'utf8'),
  );
  /* Comments are allowed to name it -- the prohibition is what the code does.
   * A stable, cross-visit id would make this page a visit tracker, which is
   * the posture the whole feature is built against. */
  const code = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  assert.ok(!code.includes('localStorage'), 'sessionStorage only, by construction');
  assert.ok(code.includes('sessionStorage'));
});

/* --- Endpoint ------------------------------------------------------------ */

test('the beacon posts the share token in the body, never in the URL', async () => {
  const url = beaconUrl(CFG);
  assert.equal(url, 'https://example.supabase.co/rest/v1/rpc/fn_pack_viewer_beacon');

  let seen = null;
  const ok = await sendBeacon('tok_abcdefghijklmnop', 'sess1234', {
    config: CFG,
    fetch: async (u, init) => {
      seen = { u, init };
      return { ok: true, status: 200 };
    },
  });
  assert.equal(ok, true);
  assert.ok(!seen.u.includes('tok_abcdefghijklmnop'), 'token is not in the URL');
  assert.equal(seen.init.method, 'POST');
  assert.equal(seen.init.referrerPolicy, 'no-referrer');
  assert.equal(seen.init.credentials, 'omit');
  assert.deepEqual(JSON.parse(seen.init.body), {
    p_share_token: 'tok_abcdefghijklmnop',
    p_session_id: 'sess1234',
  });
  assert.equal(seen.init.headers.apikey, 'anon-publishable-key');
});

test('no configured backend means no beacon and no error', async () => {
  assert.equal(beaconUrl({ SUPABASE_URL: null }), null);
  let called = false;
  const ok = await sendBeacon('tok', 'sess1234', {
    config: { SUPABASE_URL: null },
    fetch: async () => {
      called = true;
      return { ok: true };
    },
  });
  assert.equal(ok, false);
  assert.equal(called, false);
});

/* --- Failure is silent --------------------------------------------------- */

test('a refused beacon resolves false and throws nothing', async () => {
  for (const res of [{ ok: false, status: 400 }, { ok: false, status: 401 }, null]) {
    const ok = await sendBeacon('tok', 'sess1234', {
      config: CFG,
      fetch: async () => res,
    });
    assert.equal(ok, false);
  }
});

test('a network failure resolves false and throws nothing', async () => {
  const ok = await sendBeacon('tok', 'sess1234', {
    config: CFG,
    fetch: async () => {
      throw new TypeError('Failed to fetch');
    },
  });
  assert.equal(ok, false);
});

test('a beacon that fails does not disturb the snapshot the page renders', async () => {
  const raw = {
    status: 'active',
    generated_at: new Date().toISOString(),
    stale_threshold_s: 90,
    members: [
      {
        member_key: 'Rk3Zq7Xa2Lmp',
        display_name: 'Ravi',
        chainage_m: 100,
        position: [10.0, 76.3],
        gap_from_leader_m: 0,
        status: 'riding',
        display_state: 'ok',
        updated_at: new Date().toISOString(),
      },
    ],
  };

  const before = deriveSnapshot(raw);
  const beacon = startBeacon('tok', {
    config: { ...CFG, BEACON_MS: 5 },
    sessionId: 'sess1234',
    fetch: async () => {
      throw new Error('refused');
    },
  });
  await new Promise((r) => setTimeout(r, 20));
  const after = deriveSnapshot(raw);
  beacon.stop();

  assert.deepEqual(after.members[0].key, before.members[0].key);
  assert.equal(after.members[0].gap.suppressed, false);
  /* And above all: a failing beacon produces no audience number. */
  assert.equal(after.viewerCount, null);
});

test('stop() ends the beacon loop', async () => {
  let calls = 0;
  const beacon = startBeacon('tok', {
    config: { ...CFG, BEACON_MS: 5 },
    sessionId: 'sess1234',
    fetch: async () => {
      calls += 1;
      return { ok: true };
    },
  });
  await new Promise((r) => setTimeout(r, 30));
  beacon.stop();
  const atStop = calls;
  await new Promise((r) => setTimeout(r, 30));
  assert.ok(atStop >= 1, 'it beacons immediately rather than after the first interval');
  assert.equal(calls, atStop, 'nothing fires after stop');
});

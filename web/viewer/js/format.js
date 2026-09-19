/* The honesty layer.
 *
 * Every rule in CONTRACT.md "Honesty rules" and TRD 4.5 / 9 is implemented
 * here as a pure function, so it can be tested without a browser, a map, or a
 * live snapshot endpoint (see test/format.test.mjs).
 *
 * The rules, restated because they are correctness requirements and not copy:
 *  1. Never show a stale position as live, and never interpolate one forward.
 *  2. `unreachable` (dead zone) and `stopped` (rider halted) are different
 *     situations and must render differently.
 *  3. Suppress the numeric gap entirely when off route, stale, or not yet
 *     located. Say why instead.
 *  4. Estimated values are marked as estimated.
 *  5. Nothing here may imply the product dispatches help.
 *
 * Nothing in this file invents a value. If the payload does not contain it,
 * the UI says so.
 */

/** Last-resort staleness threshold, used only when neither the payload nor
 * the caller supplies one. The server default is 90s (TRD 4.5). */
export const DEFAULT_STALE_THRESHOLD_S = 90;

/** ISO-8601 -> epoch ms, or null if unusable. */
export function parseTime(iso) {
  if (typeof iso !== 'string') return null;
  const ms = Date.parse(iso);
  return Number.isFinite(ms) ? ms : null;
}

/** Whole seconds since `iso`. null when the timestamp is missing or unusable. */
export function ageSeconds(iso, nowMs = Date.now()) {
  const ms = parseTime(iso);
  if (ms === null) return null;
  return Math.max(0, Math.round((nowMs - ms) / 1000));
}

/** "just now" / "40s ago" / "6m ago" / "1h 12m ago". */
export function formatAge(seconds) {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds)) {
    return 'time unknown';
  }
  if (seconds < 5) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;
  const m = Math.floor(seconds / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  const rem = m % 60;
  return rem ? `${h}h ${rem}m ago` : `${h}h ago`;
}

/** Distance in the unit a rider reads on a milestone. */
export function formatDistance(metres) {
  if (!Number.isFinite(metres)) return null;
  const m = Math.abs(metres);
  if (m < 950) return `${Math.round(m / 10) * 10} m`;
  if (m < 10000) return `${(m / 1000).toFixed(1)} km`;
  return `${Math.round(m / 1000)} km`;
}

/** Elapsed-time gap. */
export function formatDuration(seconds) {
  if (!Number.isFinite(seconds)) return null;
  const s = Math.abs(Math.round(seconds));
  if (s < 60) return `${s}s`;
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const rem = m % 60;
  return rem ? `${h}h ${rem}m` : `${h}h`;
}

/* --- Status vocabulary ---------------------------------------------------
 * `tone` picks a colour tier. `shape` picks a silhouette. Both are always set,
 * because ~8% of Indian men have red-green CVD and colour alone must never
 * carry a distinction. `label` is the third channel: words.
 *
 * Note `unreachable` (ring, muted -- no fix is arriving) versus `stopped`
 * (square, attention -- fixes are arriving and the rider is not moving). Same
 * dot for both would be the exact failure TRD 9 exists to prevent.
 */
const STATUS = {
  riding: { label: 'Riding', tone: 'protected', shape: 'pin' },
  refueling: { label: 'Refuelling', tone: 'attention', shape: 'pin' },
  break: { label: 'On a break', tone: 'attention', shape: 'pin' },
  wrong_turn: { label: 'Wrong turn', tone: 'attention', shape: 'pin' },
  waiting: { label: 'Waiting', tone: 'attention', shape: 'pin' },
  stopped: { label: 'Stopped', tone: 'attention', shape: 'square' },
  done: { label: 'Finished', tone: 'muted', shape: 'pin' },
  unexplained_stop: {
    label: 'Stopped, no reason given',
    tone: 'attention',
    shape: 'square',
  },
  unreachable: { label: 'No signal', tone: 'muted', shape: 'ring' },
  possible_incident: {
    label: 'Possible incident',
    tone: 'emergency',
    shape: 'pin',
  },
};

const UNKNOWN_STATUS = { label: 'Unknown status', tone: 'muted', shape: 'pin' };

export function statusMeta(code) {
  return STATUS[code] || UNKNOWN_STATUS;
}

/** Statuses written by the system, not the rider (TRD 5.2). */
const AUTO_ONLY = new Set([
  'unexplained_stop',
  'possible_incident',
  'unreachable',
]);

export function isAutoStatus(member) {
  return member.status_auto === true || AUTO_ONLY.has(member.status);
}

/** First grapheme of the name, for the marker glyph. Never a user id. */
export function initial(name) {
  const trimmed = (name || '').trim();
  if (!trimmed) return '?';
  return Array.from(trimmed)[0].toUpperCase();
}

/* The producer's five display states (migration 00017), in its precedence
 * order: off_route > locating > stale > estimated > ok. */
const SUPPRESSION_STATES = new Set([
  'off_route',
  'locating',
  'stale',
  'estimated',
  'ok',
]);

function validPosition(pos) {
  return (
    Array.isArray(pos) &&
    pos.length >= 2 &&
    Number.isFinite(pos[0]) &&
    Number.isFinite(pos[1]) &&
    Math.abs(pos[0]) <= 90 &&
    Math.abs(pos[1]) <= 180
  );
}

/**
 * Normalise one raw member into everything the UI needs to draw it honestly.
 *
 * @param {object} raw   a member object exactly as it appears in TRD 7.2
 * @param {object} opts  { nowMs, staleThresholdS }
 */
export function deriveMember(raw, opts = {}) {
  const nowMs = opts.nowMs ?? Date.now();
  const threshold = opts.staleThresholdS ?? DEFAULT_STALE_THRESHOLD_S;

  const name = typeof raw.display_name === 'string' ? raw.display_name : '';
  const age = ageSeconds(raw.updated_at, nowMs);

  /* Staleness is decided by whichever source says "old" first. The server flag
   * is authoritative when set, but the client also ages the timestamp itself,
   * because a snapshot that stops being regenerated freezes `stale: false`
   * forever. A timestamp we cannot read at all counts as stale: unverifiable
   * freshness must never render as live. */
  const stale =
    raw.stale === true || age === null || (age !== null && age > threshold);

  const located = validPosition(raw.position) && Number.isFinite(raw.chainage_m);
  const serverState = SUPPRESSION_STATES.has(raw.display_state)
    ? raw.display_state
    : null;
  const offRoute = raw.off_route === true || serverState === 'off_route';
  const meta = statusMeta(raw.status);

  /* A crash flag that has gone stale is still the most important thing on the
   * screen, so it keeps the emergency tier. Everything else greys out when
   * stale -- an old "riding" must not read as a rider currently riding. */
  const tone =
    meta.tone === 'emergency'
      ? 'emergency'
      : stale
        ? 'muted'
        : offRoute
          ? 'attention'
          : meta.tone;

  const shape = stale && meta.shape === 'pin' ? 'ring' : meta.shape;

  /* --- Which of the five display states applies -----------------------
   * The producer already decides this (`display_state`, migration 00017:
   * off_route > locating > stale > estimated > ok) and nulls the gap for
   * anything outside ok/estimated, so the app and this page cannot disagree
   * about when a number is trustworthy. It is honoured when present.
   *
   * The one thing the client overrides is staleness, and only in the
   * direction of MORE caution: a snapshot the producer stopped regenerating
   * keeps saying `ok` forever, so a locally aged-out member is promoted to
   * `stale` no matter what the payload claims. Never the reverse. */
  let displayState =
    serverState ??
    (offRoute ? 'off_route' : !located ? 'locating' : stale ? 'stale' : 'ok');
  if (stale && displayState !== 'off_route' && displayState !== 'locating') {
    displayState = 'stale';
  }

  /* --- Gap, and the reasons not to show one --------------------------- */
  const gap = { suppressed: true, text: '', sub: '', estimated: false };

  if (displayState === 'locating') {
    gap.text = 'Locating';
    gap.sub = 'no position yet';
  } else if (displayState === 'off_route') {
    /* TRD 4.5: off route shows distance from the route only, never a gap
     * measured along a route the rider is not on. `off_route_m` (ST_Distance
     * to the route line) is the field, confirmed. No aliases are accepted --
     * a viewer that quietly reads some other key would keep rendering a
     * number after the producer stopped sending this one. */
    const away = Number.isFinite(raw.off_route_m) ? raw.off_route_m : null;
    gap.text = 'Off route';
    gap.sub =
      away === null
        ? 'distance unavailable'
        : `${formatDistance(away)} from the route`;
  } else if (displayState === 'stale') {
    gap.text = formatAge(age);
    gap.sub = 'last known position';
  } else {
    const dist = Number.isFinite(raw.gap_from_leader_m)
      ? raw.gap_from_leader_m
      : null;
    const secs = Number.isFinite(raw.gap_from_leader_s)
      ? raw.gap_from_leader_s
      : null;

    if (dist === null) {
      gap.text = 'No gap yet';
      gap.sub = 'not enough data';
    } else if (Math.abs(dist) < 60) {
      gap.suppressed = false;
      gap.text = 'With leader';
      gap.sub = '';
    } else {
      /* Sign convention, TRD 4.4: the gap is signed relative to the leader,
       * negative meaning behind. Direction is spelled out in words rather
       * than left as a minus sign a rider has to interpret at a glance. */
      /* Sign convention (migration 00017): gap_m is `chainage - leader
       * chainage`, so negative means behind the front of the pack. The
       * direction is spelled out in words rather than left as a minus sign a
       * viewer has to decode at a glance in the sun. */
      gap.suppressed = false;
      gap.text = formatDistance(dist);
      const direction = dist < 0 ? 'behind' : 'ahead';
      const t = formatDuration(secs);
      gap.sub = t ? `${t} ${direction}` : direction;
      gap.estimated = raw.gap_estimated === true || displayState === 'estimated';
    }
  }

  /* --- The words under the name --------------------------------------- */
  let stateLabel;
  if (stale) {
    /* Staleness leads. What the rider was doing is secondary to the fact that
     * we have not heard from them. */
    stateLabel = `Last seen ${formatAge(age)}`;
    if (raw.status && raw.status !== 'riding') {
      stateLabel += ` · was ${meta.label.toLowerCase()}`;
    }
  } else {
    stateLabel = meta.label;
    if (offRoute && meta.tone !== 'emergency') stateLabel += ' · off route';
    if (isAutoStatus(raw) && meta.tone !== 'muted') {
      stateLabel += ' · detected automatically';
    }
  }
  if (raw.role === 'leader') stateLabel += ' · leads';

  return {
    displayState,
    role: typeof raw.role === 'string' ? raw.role : null,
    /* Identity is `member_key` and nothing else: opaque, stable for the life
     * of the ride, and unique within it (migration 00019). There is
     * deliberately no name-or-index fallback. Two riders called Ravi would
     * share a name key, and an index key changes whenever the array reorders
     * -- either way a marker silently becomes a different person, which is
     * the one thing a map people make wait/continue decisions on may not do.
     * No key means no marker; the roster still lists them. */
    key: typeof raw.member_key === 'string' && raw.member_key ? raw.member_key : null,
    name: name || 'Unnamed rider',
    initial: initial(name),
    status: raw.status ?? null,
    statusLabel: meta.label,
    statusAuto: isAutoStatus(raw),
    tone,
    shape,
    stale,
    ageSeconds: age,
    located,
    offRoute,
    position: located ? raw.position : null,
    chainageM: Number.isFinite(raw.chainage_m) ? raw.chainage_m : null,
    precisionM: Number.isFinite(raw.precision_m) ? raw.precision_m : null,
    stateLabel,
    gap,
  };
}

/* --- Snapshot ----------------------------------------------------------- */

/** How live the page may honestly claim to be. */
export function freshnessState(generatedAgeS, opts = {}) {
  const warn = opts.warnS ?? 12;
  const frozen = opts.frozenS ?? 30;
  if (generatedAgeS === null || generatedAgeS === undefined) return 'frozen';
  if (generatedAgeS >= frozen) return 'frozen';
  if (generatedAgeS >= warn) return 'lagging';
  return 'live';
}

export function freshnessLabel(state, ageS) {
  if (state === 'live') return 'Live';
  if (state === 'lagging') return `Updated ${formatAge(ageS)}`;
  return ageS === null ? 'Not live' : `Frozen · ${formatAge(ageS)}`;
}

/**
 * Normalise a whole snapshot. Members come back sorted front-of-pack first;
 * anyone without a position sorts last, because an unlocated rider has no
 * place in an ordering.
 */
export function deriveSnapshot(raw, opts = {}) {
  const nowMs = opts.nowMs ?? Date.now();
  /* The per-ride threshold in the payload wins outright. It is a column on
   * the ride, so a local constant would make this page disagree with the app
   * about who is stale -- and disagreement about staleness is exactly the
   * failure the honesty rules exist to prevent. The config value is only the
   * floor for a payload that predates the field. */
  const staleThresholdS =
    Number.isFinite(raw?.stale_threshold_s) && raw.stale_threshold_s > 0
      ? raw.stale_threshold_s
      : (opts.staleThresholdS ?? DEFAULT_STALE_THRESHOLD_S);

  const generatedAge = ageSeconds(raw?.generated_at, nowMs);
  const rawMembers = Array.isArray(raw?.members) ? raw.members : [];

  const members = rawMembers.map((m) =>
    deriveMember(m, { nowMs, staleThresholdS }),
  );

  members.sort((a, b) => {
    if (a.located !== b.located) return a.located ? -1 : 1;
    return (b.chainageM ?? -Infinity) - (a.chainageM ?? -Infinity);
  });

  const routeLength = Number.isFinite(raw?.route?.length_m)
    ? raw.route.length_m
    : null;

  return {
    rideId: raw?.ride_id ?? null,
    rideName: typeof raw?.name === 'string' && raw.name ? raw.name : 'Pack ride',
    status: raw?.status ?? 'unknown',
    generatedAt: raw?.generated_at ?? null,
    generatedAgeSeconds: generatedAge,
    staleThresholdS,
    routePolyline: typeof raw?.route?.polyline === 'string'
      ? raw.route.polyline
      : null,
    routeLengthM: routeLength,
    /* PM-55/PM-73: present only once the ride has actually received a viewer
     * beacon. Absent stays null and renders nothing. Substituting 0 would be a
     * fabricated audience number, and the entire anti-abuse value of showing
     * riders the count is that the number is true. */
    viewerCount:
      Number.isInteger(raw?.viewer_count) && raw.viewer_count >= 0
        ? raw.viewer_count
        : null,
    members,
    /* Any member flagged possible_incident lifts the whole page into the
     * emergency tier. It is the one thing that outranks the map. */
    incident: members.find((m) => m.status === 'possible_incident') ?? null,
    anyStale: members.some((m) => m.stale),
  };
}

/** Coarsening notice, worded from the payload rather than assumed. */
export function precisionNote(members) {
  const values = members
    .map((m) => m.precisionM)
    .filter((v) => Number.isFinite(v));
  if (values.length === 0) return 'Positions shown to link viewers are coarsened.';
  const worst = Math.max(...values);
  return `Positions are coarsened to about ${Math.round(worst)} m for link viewers.`;
}

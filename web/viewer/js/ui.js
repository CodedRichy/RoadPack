/* DOM rendering.
 *
 * Deliberately not a framework. Everything here is textContent and dataset
 * flips against markup that already exists in index.html, which means the
 * first paint costs one HTML file and one CSS file, and the first *data* paint
 * costs one 5 KB JSON fetch -- no bundle, no hydration, no build step. On a
 * 3G phone that is the entire argument.
 *
 * Two rules run through all of it:
 *  - Nothing is ever written with innerHTML from payload data.
 *  - No state is drawn without also drawing how old it is.
 */

import { formatAge, formatDistance, freshnessLabel, precisionNote } from './format.js';

const $ = (id) => document.getElementById(id);

/* --- Full-page states --------------------------------------------------- */

export function showState(kind, { title, body, spinner = false } = {}) {
  const el = $('state');
  $('state-title').textContent = title;
  $('state-body').textContent = body;
  $('state-spinner').hidden = !spinner;
  el.dataset.kind = kind;
  el.hidden = false;
}

export function hideState() {
  $('state').hidden = true;
}

/* --- Banner -------------------------------------------------------------
 * One slot. Tier is one of notice | attention | emergency. The emergency tier
 * is reachable only from a member flagged possible_incident -- it is reserved
 * and it means someone may be hurt. */

export function showBanner(tier, title, body) {
  const el = $('banner');
  $('banner-title').textContent = title;
  $('banner-body').textContent = body || '';
  $('banner-body').hidden = !body;
  el.dataset.tier = tier;
  el.hidden = false;
}

export function hideBanner() {
  $('banner').hidden = true;
}

/* --- Freshness ---------------------------------------------------------- */

export function renderFreshness(state, ageSeconds) {
  const el = $('freshness');
  el.dataset.state = state;
  $('freshness-text').textContent = freshnessLabel(state, ageSeconds);
  el.setAttribute(
    'aria-label',
    state === 'live'
      ? 'Live. Updating every five seconds.'
      : `Not live. Data last updated ${formatAge(ageSeconds)}.`,
  );
  document.getElementById('mapwrap').dataset.frozen = String(state === 'frozen');
}

/* --- Header ------------------------------------------------------------- */

export function renderHeader(snapshot) {
  $('ride-name').textContent = snapshot.rideName;
  const parts = [];
  if (snapshot.routeLengthM) {
    parts.push(`${formatDistance(snapshot.routeLengthM)} route`);
  }
  parts.push(
    `${snapshot.members.length} rider${snapshot.members.length === 1 ? '' : 's'}`,
  );
  /* PM-55: only when the payload actually carries a count. Absent means no
   * beacon has been received for this ride yet, and the honest rendering of
   * "we do not know" is nothing at all -- never "0 watching". */
  if (snapshot.viewerCount !== null) {
    parts.push(
      `${snapshot.viewerCount} watching`,
    );
  }
  $('ride-sub').textContent = parts.join(' · ');
}

/* --- Chainage strip -----------------------------------------------------
 * The route flattened to a rail, each rider ticked at their chainage. It needs
 * no tiles and no WebGL, so it answers "who is where, in what order" even when
 * the basemap never arrives. Riders with no position are absent from the rail
 * rather than parked at zero -- a tick at the start line would be a claim. */

export function renderStrip(snapshot) {
  const rail = $('strip-rail');
  rail.textContent = '';

  const length = snapshot.routeLengthM;
  const located = snapshot.members.filter((m) => m.chainageM !== null);

  $('strip-length').textContent = length ? formatDistance(length) : '';
  $('strip-note').textContent =
    located.length === snapshot.members.length
      ? ''
      : `${snapshot.members.length - located.length} not located`;

  if (!length || located.length === 0) {
    $('strip').hidden = !length;
    return;
  }
  $('strip').hidden = false;

  for (const m of located) {
    const tick = document.createElement('div');
    tick.className = 'strip__tick';
    tick.dataset.tone = m.tone;
    tick.dataset.stale = String(m.stale);
    const pct = Math.min(100, Math.max(0, (m.chainageM / length) * 100));
    tick.style.left = `${pct}%`;
    tick.title = `${m.name} · ${formatDistance(m.chainageM)} along`;
    rail.appendChild(tick);
  }
}

/* --- Roster ------------------------------------------------------------- */

function memberRow(member, onSelect) {
  const li = document.createElement('li');
  li.className = 'member';
  li.dataset.tone = member.tone;
  li.dataset.shape = member.shape;
  li.dataset.stale = String(member.stale);

  const glyph = document.createElement('div');
  glyph.className = 'member__glyph';
  glyph.setAttribute('aria-hidden', 'true');
  glyph.textContent = member.initial;

  const body = document.createElement('div');
  const name = document.createElement('div');
  name.className = 'member__name';
  name.textContent = member.name;
  const state = document.createElement('div');
  state.className = 'member__state';
  state.textContent = member.stateLabel;
  body.append(name, state);

  const gap = document.createElement('div');
  gap.className = 'member__gap';
  gap.dataset.suppressed = String(member.gap.suppressed);
  gap.append(document.createTextNode(member.gap.text));

  /* An estimated number is never shown bare. TRD 4.4's fallback derives the
   * time gap from average speed before enough breadcrumbs exist, and a viewer
   * deciding whether to wait deserves to know which kind of number they are
   * looking at. */
  if (member.gap.estimated) {
    const chip = document.createElement('span');
    chip.className = 'est';
    chip.textContent = 'est';
    chip.title = 'Estimated from average speed, not measured from the route';
    gap.appendChild(chip);
  }
  if (member.gap.sub) {
    const sub = document.createElement('span');
    sub.className = 'member__gapsub';
    sub.textContent = member.gap.sub;
    gap.appendChild(sub);
  }

  li.append(glyph, body, gap);

  /* Focusable only when the map can actually find it: a located member with
   * an identity key. */
  if (member.located && member.key && onSelect) {
    li.tabIndex = 0;
    li.setAttribute('role', 'button');
    li.addEventListener('click', () => onSelect(member.key));
    li.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onSelect(member.key);
      }
    });
  }
  return li;
}

export function renderRoster(snapshot, onSelect) {
  const list = $('roster-list');
  list.textContent = '';
  if (snapshot.members.length === 0) {
    const li = document.createElement('li');
    li.className = 'member';
    li.textContent = 'No riders are sharing a position in this pack right now.';
    list.appendChild(li);
    return;
  }
  for (const m of snapshot.members) list.appendChild(memberRow(m, onSelect));
  $('precision-note').textContent = precisionNote(snapshot.members);
}

/* --- Install prompt -----------------------------------------------------
 * TRD 7.3: value first, ask second. This is called only after the map has
 * rendered and become interactive. It is a sheet, never a modal, never a
 * gate, and once dismissed it does not come back in this session. */

export function showInstall({ onInstall, onDismiss }) {
  const el = $('install');
  if (el.dataset.dismissed === 'true' || !el.hidden) return false;
  el.hidden = false;
  $('install-cta').onclick = onInstall;
  $('install-dismiss').onclick = () => {
    el.hidden = true;
    el.dataset.dismissed = 'true';
    onDismiss?.();
  };
  return true;
}

export function renderMapHint(text) {
  const el = $('maphint');
  el.textContent = text || '';
  el.hidden = !text;
}

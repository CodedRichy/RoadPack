/* MapLibre GL JS + OpenFreeMap.
 *
 * Why not Google or Mapbox: a viral ride link is the intended outcome of this
 * feature, and both bill per map load. The same 500k-view moment costs
 * ~$3,430 on Google and ~$2,250 on Mapbox; here it costs nothing. The tile
 * source is one swappable style URL so moving to a Protomaps PMTiles extract
 * on Cloudflare R2 stays a one-line change (TRD 7.1).
 *
 * The map is loaded LAZILY and is treated as optional throughout. The roster
 * and the chainage strip render from the snapshot JSON alone, so a phone that
 * never finishes downloading a WebGL bundle over 3G still gets the answer it
 * came for. If the map never arrives, the page says so instead of showing an
 * empty grey rectangle.
 *
 * Coordinate order: the snapshot carries [lat, lng] (TRD 7.2). MapLibre and
 * GeoJSON want [lng, lat]. Everything crossing this boundary flips exactly
 * once, in `toLngLat`.
 */

import { config } from './config.js';
import { decodeRoute, bounds } from './polyline.js';

const INDIA_CENTER = [76.3, 10.0]; // Ernakulam -- the pilot corridor.

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.async = true;
    s.crossOrigin = 'anonymous';
    s.onload = resolve;
    s.onerror = () => reject(new Error(`failed to load ${src}`));
    document.head.appendChild(s);
  });
}

function loadStyleSheet(href) {
  return new Promise((resolve) => {
    const l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = href;
    l.crossOrigin = 'anonymous';
    l.onload = resolve;
    l.onerror = resolve; // cosmetic only; never block the map on its CSS
    document.head.appendChild(l);
  });
}

/** [lat, lng] from the payload -> [lng, lat] for MapLibre. */
export function toLngLat(position) {
  return [position[1], position[0]];
}

export class PackMap {
  constructor(container) {
    this.container = container;
    this.map = null;
    this.markers = new Map();
    this.routeDrawn = false;
    this.fitted = false;
    this.ready = false;
    this.failed = false;
    this._pending = null;
    this._onInteractive = null;
  }

  /** Resolves when the map is usable, rejects if the stack cannot load. */
  async init({ onInteractive } = {}) {
    this._onInteractive = onInteractive;
    try {
      await Promise.all([
        loadScript(config.MAPLIBRE_JS),
        loadStyleSheet(config.MAPLIBRE_CSS),
      ]);
      if (!window.maplibregl) throw new Error('maplibregl missing after load');

      let style = config.MAP_STYLE;
      if (config.PMTILES_URL) {
        await loadScript(config.PMTILES_JS);
        const protocol = new window.pmtiles.Protocol();
        window.maplibregl.addProtocol('pmtiles', protocol.tile);
        style = config.MAP_STYLE; // a style JSON whose sources use pmtiles://
      }

      this.map = new window.maplibregl.Map({
        container: this.container,
        style,
        center: INDIA_CENTER,
        zoom: 5,
        attributionControl: { compact: true },
        /* A viewer reading a map outdoors does not want a pitched 3D view they
         * have to fight; keep it flat and cheap to render on a Snapdragon 680. */
        pitchWithRotate: false,
        dragRotate: false,
        maxPitch: 0,
        fadeDuration: 0,
      });

      this.map.addControl(
        new window.maplibregl.NavigationControl({ showCompass: false }),
        'top-right',
      );

      await new Promise((resolve, reject) => {
        this.map.once('load', resolve);
        this.map.once('error', (e) => {
          /* Style/tile errors after load are survivable; a failure before load
           * is not. */
          if (!this.ready) reject(e?.error || new Error('map style failed'));
        });
      });

      this.ready = true;
      this.map.once('idle', () => {
        if (this._onInteractive) this._onInteractive();
      });

      if (this._pending) {
        this.render(this._pending.snapshot, this._pending.opts);
        this._pending = null;
      }
      return true;
    } catch (err) {
      this.failed = true;
      console.warn('[map] unavailable:', err?.message || err);
      return false;
    }
  }

  /** Draw a snapshot. Safe to call before the map has loaded. */
  render(snapshot, opts = {}) {
    if (!this.ready) {
      this._pending = { snapshot, opts };
      return;
    }
    this._drawRoute(snapshot);
    this._drawMembers(snapshot, opts);
  }

  _drawRoute(snapshot) {
    if (this.routeDrawn || !snapshot.routePolyline) return;
    const coords = decodeRoute(snapshot.routePolyline);
    if (coords.length < 2) {
      console.warn('[map] route polyline did not decode; drawing no route');
      return;
    }

    this.map.addSource('route', {
      type: 'geojson',
      data: {
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: coords },
      },
    });

    /* Casing first so the route stays readable over both light and dark
     * cartography without depending on the basemap's palette. */
    this.map.addLayer({
      id: 'route-casing',
      type: 'line',
      source: 'route',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': routeColors().casing,
        'line-width': 9,
        'line-opacity': 0.9,
      },
    });
    this.map.addLayer({
      id: 'route-line',
      type: 'line',
      source: 'route',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': routeColors().line,
        'line-width': 4,
      },
    });

    this.routeDrawn = true;

    const bb = bounds(coords);
    if (bb && !this.fitted) {
      this.map.fitBounds(bb, { padding: 48, duration: 0 });
      this.fitted = true;
    }
  }

  _drawMembers(snapshot, opts) {
    const live = new Set();

    for (const member of snapshot.members) {
      if (!member.located) continue; // no position -> no marker, ever
      /* Marker identity is `member_key` and there is no fallback. Without one
       * two riders could share a key, and a marker would silently become a
       * different person on the next reorder -- worse than a missing marker,
       * because nobody can see it happen. The roster still lists them. */
      if (!member.key) continue;
      live.add(member.key);

      let entry = this.markers.get(member.key);
      if (!entry) {
        const el = document.createElement('div');
        el.className = 'marker';
        el.innerHTML =
          '<div class="marker__pin"></div><div class="marker__label"></div>';
        el.addEventListener('click', () => opts.onSelect?.(member.key));
        const marker = new window.maplibregl.Marker({
          element: el,
          anchor: 'bottom',
        })
          .setLngLat(toLngLat(member.position))
          .addTo(this.map);
        entry = { el, marker };
        this.markers.set(member.key, entry);
      }

      /* setLngLat, not a tween. A marker that glides between polls is a
       * marker inventing positions the payload never contained -- and the
       * pack makes wait/continue decisions on exactly those positions. It
       * jumps to the reported fix, or it does not move at all. */
      entry.marker.setLngLat(toLngLat(member.position));

      const el = entry.el;
      el.dataset.tone = member.tone;
      el.dataset.shape = member.shape;
      el.dataset.stale = String(member.stale);
      el.querySelector('.marker__pin').textContent = member.initial;
      el.querySelector('.marker__label').textContent = member.stale
        ? `${member.name} · ${member.stateLabel.replace('Last seen ', '')}`
        : member.name;
      el.setAttribute(
        'aria-label',
        `${member.name}. ${member.stateLabel}. ${member.gap.text} ${member.gap.sub}`.trim(),
      );
      el.title = el.getAttribute('aria-label');
    }

    /* A member who left the ride disappears from the next snapshot (PM-72),
     * so their marker must disappear with it. */
    for (const [key, entry] of this.markers) {
      if (!live.has(key)) {
        entry.marker.remove();
        this.markers.delete(key);
      }
    }
  }

  focus(key) {
    const entry = this.markers.get(key);
    if (!entry || !this.map) return;
    this.map.easeTo({ center: entry.marker.getLngLat(), zoom: 12, duration: 400 });
  }

  /** Re-tint the route after a theme change. */
  applyTheme() {
    if (!this.ready || !this.routeDrawn) return;
    const c = routeColors();
    this.map.setPaintProperty('route-casing', 'line-color', c.casing);
    this.map.setPaintProperty('route-line', 'line-color', c.line);
  }

  resize() {
    if (this.ready) this.map.resize();
  }
}

/* sRGB equivalents of --route-line / --route-casing, per theme. Kept as hex
 * because of the oklch() note on cssVar below; they are derived from the same
 * OKLCH values as css/tokens.css and must be changed together. */
function routeColors() {
  const sunlight = isSunlight();
  return sunlight
    ? { line: cssVar('--route-line', '#4c7800'), casing: cssVar('--route-casing', '#fbfaf8') }
    : { line: cssVar('--route-line', '#83af3e'), casing: cssVar('--route-casing', '#101411') };
}

function isSunlight() {
  const attr = document.documentElement.getAttribute('data-theme');
  if (attr === 'sunlight') return true;
  if (attr === 'night') return false;
  return (
    typeof matchMedia === 'function' &&
    matchMedia('(prefers-color-scheme: light)').matches
  );
}

/* MapLibre parses paint colours with its own CSS colour parser, which does not
 * understand oklch(). Our tokens resolve to oklch() on any modern browser, so
 * a raw var() read would hand the style engine a string it throws on. Take the
 * computed value only when it is a form MapLibre can parse, otherwise use the
 * sRGB fallback -- which is the same colour, derived from the same OKLCH. */
function cssVar(name, fallback) {
  try {
    const v = getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim();
    if (/^(#|rgb|hsl)/i.test(v)) return v;
    return fallback;
  } catch {
    return fallback;
  }
}

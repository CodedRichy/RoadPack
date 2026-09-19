/* Encoded-polyline decoder (Google/OSRM algorithm).
 *
 * `route.polyline` is precision 5, standard Google encoding. Confirmed by the
 * producer -- it is not a guess, so there is no precision-6 retry here and no
 * "does this look plausible, try the other one" fallback. A decoder that
 * guesses its own input format turns a producer bug into a subtly wrong map
 * instead of a visible one.
 *
 * The range check that remains is an assertion, not a fallback: coordinates
 * off the planet mean the payload is wrong, and the caller draws no route
 * rather than a wrong one.
 */

/** Precision 5 is the contract. It is not a parameter, because it is not a
 * choice the caller gets to make.
 *
 * @param {string} str encoded polyline
 * @returns {Array<[number, number]>} [lng, lat] pairs, GeoJSON order
 */
export function decodePolyline(str) {
  if (typeof str !== 'string' || str.length === 0) return [];

  const factor = 1e5;
  const coords = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < str.length) {
    let result = 1;
    let shift = 0;
    let b;
    do {
      b = str.charCodeAt(index++) - 63 - 1;
      if (Number.isNaN(b) || b < 0) return coords;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lat += result & 1 ? ~(result >> 1) : result >> 1;

    result = 1;
    shift = 0;
    do {
      b = str.charCodeAt(index++) - 63 - 1;
      if (Number.isNaN(b) || b < 0) return coords;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lng += result & 1 ? ~(result >> 1) : result >> 1;

    coords.push([lng / factor, lat / factor]);
  }

  return coords;
}

/** Every coordinate is on Earth and not at null island. */
export function looksPlausible(coords) {
  if (!Array.isArray(coords) || coords.length < 2) return false;
  return coords.every(
    ([lng, lat]) =>
      Number.isFinite(lng) &&
      Number.isFinite(lat) &&
      lng >= -180 &&
      lng <= 180 &&
      lat >= -90 &&
      lat <= 90 &&
      (Math.abs(lng) > 0.0001 || Math.abs(lat) > 0.0001),
  );
}

/**
 * Decode the route. Returns [] when the result is not a usable line on Earth
 * -- the caller then draws no route rather than drawing a wrong one. There is
 * no second attempt at another precision: a payload that fails this is a bug
 * to fix at the producer, not a shape to guess at here.
 */
export function decodeRoute(str) {
  const coords = decodePolyline(str);
  return looksPlausible(coords) ? coords : [];
}

/** Bounding box as [[minLng, minLat], [maxLng, maxLat]], or null. */
export function bounds(coords) {
  if (!coords || coords.length === 0) return null;
  let minLng = Infinity;
  let minLat = Infinity;
  let maxLng = -Infinity;
  let maxLat = -Infinity;
  for (const [lng, lat] of coords) {
    if (lng < minLng) minLng = lng;
    if (lat < minLat) minLat = lat;
    if (lng > maxLng) maxLng = lng;
    if (lat > maxLat) maxLat = lat;
  }
  return [
    [minLng, minLat],
    [maxLng, maxLat],
  ];
}

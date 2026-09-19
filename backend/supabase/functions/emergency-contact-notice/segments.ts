// SMS segmentation maths, used to enforce FR-104: a feature-phone SMS must fit
// in 2 segments or fewer in every language we ship.
//
// GSM 03.38 7-bit:  160 chars single, 153 per segment when concatenated.
// UCS-2 (any char outside GSM 03.38): 70 units single, 67 per segment.
// Malayalam and Devanagari force UCS-2, so a 2-segment budget there is only
// 134 UTF-16 code units — the tightest constraint in the product.

const GSM_BASIC =
  '@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?' +
  '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà'

// These cost two septets each (escape + char).
const GSM_EXTENDED = '^{}\\[~]|€'

const GSM_BASIC_SET = new Set(GSM_BASIC.split(''))
const GSM_EXTENDED_SET = new Set(GSM_EXTENDED.split(''))

export type SmsEncoding = 'GSM-7' | 'UCS-2'

export interface SegmentInfo {
  encoding: SmsEncoding
  /** Septets for GSM-7, UTF-16 code units for UCS-2. */
  units: number
  segments: number
}

export function detectEncoding(text: string): SmsEncoding {
  for (const ch of text) {
    if (!GSM_BASIC_SET.has(ch) && !GSM_EXTENDED_SET.has(ch)) return 'UCS-2'
  }
  return 'GSM-7'
}

export function measure(text: string): SegmentInfo {
  const encoding = detectEncoding(text)

  if (encoding === 'GSM-7') {
    let units = 0
    for (const ch of text) units += GSM_EXTENDED_SET.has(ch) ? 2 : 1
    const segments = units <= 160 ? (units === 0 ? 0 : 1) : Math.ceil(units / 153)
    return { encoding, units, segments }
  }

  // UCS-2 is billed in UTF-16 code units, so an astral character (an emoji)
  // costs 2. `text.length` is already the code-unit count.
  const units = text.length
  // A surrogate pair must not be split across a segment boundary; we never
  // emit astral characters in these templates, so the simple ceiling holds.
  const segments = units <= 70 ? (units === 0 ? 0 : 1) : Math.ceil(units / 67)
  return { encoding, units, segments }
}

export function segmentCount(text: string): number {
  return measure(text).segments
}

/** Longest body that still fits `n` segments in the encoding `text` uses. */
export function budgetFor(encoding: SmsEncoding, segments: number): number {
  if (encoding === 'GSM-7') return segments === 1 ? 160 : 153 * segments
  return segments === 1 ? 70 : 67 * segments
}

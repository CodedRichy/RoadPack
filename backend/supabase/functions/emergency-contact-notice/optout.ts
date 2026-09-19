// Opt-out keyword recognition for inbound SMS.
//
// Lives beside the notice that advertises the keyword so the vocabulary we
// print and the vocabulary we accept cannot drift apart. `sms-webhook` imports
// from here; it is deliberately a plain module with no top-level side effects
// so it can be unit-tested without starting a server.
//
// Indian carriers / TRAI conventions accept STOP and UNSUBSCRIBE. The notice
// templates print the Latin word STOP in every language (a feature phone
// cannot reliably compose Malayalam or Devanagari), but we also accept the
// native-script and transliterated words people actually type back.

const OPT_OUT_KEYWORDS = new Set([
  // English / carrier standard
  'STOP',
  'STOPALL',
  'UNSUBSCRIBE',
  'UNSUB',
  'CANCEL',
  'QUIT',
  'END',
  'OPTOUT',
  'OPT OUT',
  // Hindi — native and transliterated
  'बंद',
  'बंद करो',
  'रोको',
  'BAND',
  'BAND KARO',
  'ROKO',
  // Malayalam — native and transliterated
  'നിർത്തുക',
  'വേണ്ട',
  'NIRTHUKA',
  'VENDA',
])

/**
 * True when an inbound SMS body is an opt-out request.
 *
 * Deliberately strict: only the keyword itself (optionally with surrounding
 * whitespace or a trailing full stop) counts. A sentence that merely contains
 * "stop" — "did he stop?" — must keep flowing to the acknowledgement path.
 */
export function isOptOut(message: unknown): boolean {
  if (typeof message !== 'string') return false
  const normalized = message
    .trim()
    .replace(/[.!।॥]+$/u, '')
    .replace(/\s+/gu, ' ')
    .trim()
    .toUpperCase()
  if (normalized.length === 0) return false
  return OPT_OUT_KEYWORDS.has(normalized)
}

export function optOutKeywords(): string[] {
  return [...OPT_OUT_KEYWORDS]
}

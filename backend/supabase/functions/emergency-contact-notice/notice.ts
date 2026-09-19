// FR-024 "you have been listed as an emergency contact" notice.
//
// The copy is bound by FR-104: <= 2 SMS segments in every language we ship.
// Hindi and Malayalam are native-script here, which forces UCS-2, which means a
// 2-segment budget of 134 UTF-16 code units *including the sender's name*. That
// is why the copy is this terse and why `NAME_MAX_CHARS` is enforced rather
// than hoped for.
//
// Honesty (project rule 5): the notice says what being listed means and says
// plainly that RoadPack does not dispatch help and does not replace 112.

import { measure, type SegmentInfo } from './segments.ts'

export type NoticeLang = 'en' | 'hi' | 'ml'

export const NOTICE_LANGS: NoticeLang[] = ['en', 'hi', 'ml']

/** Max segments any notice may occupy, in any language. FR-104. */
export const MAX_SEGMENTS = 2

/**
 * The name is the only variable part, so it is the only thing that can push a
 * template over budget. Truncate rather than overflow: a clipped name is a
 * cosmetic loss, a third segment is a billing and deliverability loss.
 */
export const NAME_MAX_CHARS = 12

export interface NoticeTemplate {
  template: string
  /**
   * Filled in once DLT registration completes. Read from the environment so a
   * registered id can be supplied without a code change; the literal here is
   * only the "not yet registered" marker.
   */
  dlt_template_id: string
  /** Env var that overrides `dlt_template_id` at runtime. */
  dlt_template_id_env: string
}

/**
 * Runtime source of truth. Mirrored verbatim into
 * `shared/templates/alert_templates.json` under `emergency_contact_listed`
 * (that file is the DLT registration record); a test asserts the two match.
 */
export const CONTACT_LISTED_TEMPLATES: Record<NoticeLang, NoticeTemplate> = {
  en: {
    template:
      'RoadPack: {name} listed you as their emergency contact. If they have a road accident you may get an SMS with their location. RoadPack does not send help - call 112. Reply STOP to opt out.',
    dlt_template_id: 'PENDING_REGISTRATION',
    dlt_template_id_env: 'DLT_TEMPLATE_ID_CONTACT_LISTED_EN',
  },
  hi: {
    template:
      'RoadPack: {name} ने आपको आपातकालीन संपर्क बनाया। दुर्घटना पर SMS आ सकता है। मदद नहीं भेजते, 112 पर कॉल करें। बंद करने को STOP।',
    dlt_template_id: 'PENDING_REGISTRATION',
    dlt_template_id_env: 'DLT_TEMPLATE_ID_CONTACT_LISTED_HI',
  },
  ml: {
    template:
      'RoadPack: {name} നിങ്ങളെ അടിയന്തര ബന്ധുവാക്കി. അപകടത്തിൽ SMS വരാം. ഞങ്ങൾ സഹായം അയക്കില്ല. 112 വിളിക്കുക. വേണ്ടെങ്കിൽ STOP.',
    dlt_template_id: 'PENDING_REGISTRATION',
    dlt_template_id_env: 'DLT_TEMPLATE_ID_CONTACT_LISTED_ML',
  },
}

export function normalizeLang(value: unknown): NoticeLang {
  const v = String(value ?? '').toLowerCase().slice(0, 2)
  return (NOTICE_LANGS as string[]).includes(v) ? (v as NoticeLang) : 'en'
}

/** Hard-truncate so a long name can never buy a third segment. */
export function clampName(name: unknown): string {
  const s = String(name ?? '')
    // Non-BMP characters (emoji) cost two UTF-16 units each under UCS-2, so a
    // 12-character name could spend 24 of a 134-unit budget. Drop them; they
    // carry no information in this message.
    .replace(/[\u{10000}-\u{10FFFF}]/gu, '')
    .trim()
    .replace(/\s+/gu, ' ')
  if (s.length === 0) return 'Someone'
  return s.slice(0, NAME_MAX_CHARS).trim()
}

export function renderNotice(lang: NoticeLang, listedBy: unknown): string {
  return CONTACT_LISTED_TEMPLATES[lang].template.replace(
    '{name}',
    clampName(listedBy),
  )
}

export function measureNotice(lang: NoticeLang, listedBy: string): SegmentInfo {
  return measure(renderNotice(lang, listedBy))
}

export function dltTemplateId(lang: NoticeLang): string {
  const t = CONTACT_LISTED_TEMPLATES[lang]
  return Deno.env.get(t.dlt_template_id_env) ?? t.dlt_template_id
}

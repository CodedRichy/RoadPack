// FR-104: a feature-phone SMS must fit in 2 segments or fewer, in every
// language we ship. Hindi and Malayalam are native script here, so they encode
// as UCS-2 and a 2-segment message is only 134 UTF-16 code units.
//
//   deno test backend/supabase/tests/contact_notice_segments.test.ts

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  budgetFor,
  detectEncoding,
  measure,
} from '../functions/emergency-contact-notice/segments.ts'
import {
  CONTACT_LISTED_TEMPLATES,
  clampName,
  MAX_SEGMENTS,
  measureNotice,
  NAME_MAX_CHARS,
  NOTICE_LANGS,
  normalizeLang,
  renderNotice,
} from '../functions/emergency-contact-notice/notice.ts'

// A name at exactly the enforced maximum: the worst case the sender can emit.
const WORST_NAME = 'Sreekumar VP'

Deno.test('segments: GSM-7 boundaries', () => {
  assertEquals(measure('a'.repeat(160)).segments, 1)
  assertEquals(measure('a'.repeat(161)).segments, 2)
  assertEquals(measure('a'.repeat(306)).segments, 2)
  assertEquals(measure('a'.repeat(307)).segments, 3)
})

Deno.test('segments: GSM-7 extended characters cost two septets', () => {
  assertEquals(measure('a'.repeat(159) + '€').units, 161)
  assertEquals(measure('a'.repeat(159) + '€').segments, 2)
})

Deno.test('segments: UCS-2 boundaries', () => {
  const dev = 'क'
  assertEquals(detectEncoding(dev), 'UCS-2')
  assertEquals(measure(dev.repeat(70)).segments, 1)
  assertEquals(measure(dev.repeat(71)).segments, 2)
  assertEquals(measure(dev.repeat(134)).segments, 2)
  assertEquals(measure(dev.repeat(135)).segments, 3)
  assertEquals(budgetFor('UCS-2', 2), 134)
  assertEquals(budgetFor('GSM-7', 2), 306)
})

Deno.test('FR-104: every contact-listed notice fits 2 segments', () => {
  const measured: Record<string, string> = {}
  for (const lang of NOTICE_LANGS) {
    const info = measureNotice(lang, WORST_NAME)
    measured[lang] =
      `${info.encoding} ${info.units} units, ${info.segments} segment(s), ` +
      `${budgetFor(info.encoding, MAX_SEGMENTS) - info.units} spare`
    assert(
      info.segments <= MAX_SEGMENTS,
      `${lang} needs ${info.segments} segments (${info.units} ${info.encoding} units): ` +
        `${renderNotice(lang, WORST_NAME)}`,
    )
  }
  console.log('[FR-104 measured]', JSON.stringify(measured, null, 2))
})

Deno.test('FR-104: hi and ml are native script, hence UCS-2', () => {
  // If someone silently swaps these back to transliteration the budget gets 2x
  // looser and the constraint stops being tested at all — assert the hard case.
  assertEquals(measureNotice('hi', WORST_NAME).encoding, 'UCS-2')
  assertEquals(measureNotice('ml', WORST_NAME).encoding, 'UCS-2')
  assertEquals(measureNotice('en', WORST_NAME).encoding, 'GSM-7')
})

Deno.test('FR-104: a hostile name cannot buy a third segment', () => {
  const hostile = 'A'.repeat(400)
  const emoji = '🚑'.repeat(40)
  for (const lang of NOTICE_LANGS) {
    assert(measureNotice(lang, hostile).segments <= MAX_SEGMENTS, `${lang} long name`)
    assert(measureNotice(lang, emoji).segments <= MAX_SEGMENTS, `${lang} emoji name`)
  }
})

Deno.test('clampName: truncates, collapses whitespace, drops astral chars', () => {
  assertEquals(clampName('  Anu   Raj  '), 'Anu Raj')
  assertEquals(clampName('A'.repeat(50)).length, NAME_MAX_CHARS)
  assertEquals(clampName('Anu🚑'), 'Anu')
  assertEquals(clampName(''), 'Someone')
  assertEquals(clampName(null), 'Someone')
})

Deno.test('notice copy is honest: no dispatch claim, 112 present, opt-out present', () => {
  for (const lang of NOTICE_LANGS) {
    const text = renderNotice(lang, WORST_NAME)
    assert(text.includes('112'), `${lang} must point at 112`)
    assert(text.includes('STOP'), `${lang} must print the opt-out keyword`)
    for (const banned of ['ambulance', 'dispatch', 'we will send help', 'rescue']) {
      assert(
        !text.toLowerCase().includes(banned),
        `${lang} must not imply RoadPack dispatches help ("${banned}")`,
      )
    }
  }
})

Deno.test('normalizeLang falls back to en', () => {
  assertEquals(normalizeLang('ml'), 'ml')
  assertEquals(normalizeLang('ml-IN'), 'ml')
  assertEquals(normalizeLang('HI'), 'hi')
  assertEquals(normalizeLang('ta'), 'en')
  assertEquals(normalizeLang(undefined), 'en')
})

Deno.test('alert_templates.json mirrors the runtime templates', async () => {
  const raw = await Deno.readTextFile(
    new URL('../../../shared/templates/alert_templates.json', import.meta.url),
  )
  const json = JSON.parse(raw)
  const block = json.emergency_contact_listed
  assert(block, 'emergency_contact_listed missing from alert_templates.json')

  for (const lang of NOTICE_LANGS) {
    assertEquals(
      block[lang].template,
      CONTACT_LISTED_TEMPLATES[lang].template,
      `${lang} copy has drifted between the JSON record and the runtime`,
    )
    assertEquals(
      block[lang].dlt_template_id_env,
      CONTACT_LISTED_TEMPLATES[lang].dlt_template_id_env,
    )
  }

  // Existing templates must be untouched by this addition.
  assert(json.emergency_sms?.template?.startsWith('ROADPACK ALERT:'))
  assert(json.lost_contact?.title)
})

Deno.test('DLT template id comes from the environment, no code change needed', async () => {
  const { dltTemplateId } = await import(
    '../functions/emergency-contact-notice/notice.ts'
  )
  assertEquals(dltTemplateId('ml'), 'PENDING_REGISTRATION')
  Deno.env.set('DLT_TEMPLATE_ID_CONTACT_LISTED_ML', '1707100000000000000')
  try {
    assertEquals(dltTemplateId('ml'), '1707100000000000000')
  } finally {
    Deno.env.delete('DLT_TEMPLATE_ID_CONTACT_LISTED_ML')
  }
})

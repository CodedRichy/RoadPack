// Plain-text SMS sending for the FR-024 notice.
//
// The alert cascade's `AlertChannel` in `_shared/channels.ts` is shaped around
// an incident (victim, coordinates, maps link) and builds its own body, so it
// cannot carry this message. This module reuses that file's `ChannelResult`
// contract and, critically, the same `SMS_PROVIDER` switch — it does NOT open a
// second vendor path. When a real provider lands in `_shared/channels.ts` it
// must expose a `sendText(phone, message, dltTemplateId)` entry point and this
// module becomes a one-line delegate. See the report note on DLT registration:
// nothing here can be delivered in India until DLT entity/header/template
// registration completes.

import { type ChannelResult } from '../_shared/channels.ts'

export interface TextSmsSender {
  sendText(
    phone: string,
    message: string,
    dltTemplateId: string,
  ): Promise<ChannelResult>
}

export class MockTextSmsSender implements TextSmsSender {
  async sendText(
    phone: string,
    message: string,
    dltTemplateId: string,
  ): Promise<ChannelResult> {
    console.log(`[MockSMS] To: ${phone} | dlt=${dltTemplateId} | ${message}`)
    return await Promise.resolve({
      success: true,
      provider_id: `sms_mock_${Date.now()}`,
    })
  }
}

export function getTextSmsSender(): TextSmsSender {
  const provider = Deno.env.get('SMS_PROVIDER') ?? 'mock'
  if (provider === 'mock') return new MockTextSmsSender()
  // Same failure shape as `_shared/channels.ts#getChannel`, deliberately: a
  // provider is either wired in both places or in neither.
  throw new Error(`SMS provider '${provider}' not yet implemented`)
}

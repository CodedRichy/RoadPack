export interface AlertPayload {
  recipient_phone: string
  recipient_name: string
  victim_name: string
  victim_phone: string
  location: { lat: number; lng: number; address?: string }
  maps_link: string
  incident_id: string
}

export interface ChannelResult {
  success: boolean
  provider_id?: string
  error?: string
}

export interface AlertChannel {
  send(payload: AlertPayload): Promise<ChannelResult>
}

export class FcmChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    // FCM implementation — requires GOOGLE_SERVICE_ACCOUNT_KEY env var
    // For Phase 1, this is a structured mock that logs the payload
    console.log('[FCM] Would send push:', JSON.stringify({
      title: 'EMERGENCY ALERT - RoadPack',
      body: `${payload.victim_name} may have been in an accident.`,
      data: {
        incident_id: payload.incident_id,
        lat: payload.location.lat,
        lng: payload.location.lng,
        victim_name: payload.victim_name,
        victim_phone: payload.victim_phone,
      },
    }))
    return { success: true, provider_id: `fcm_mock_${Date.now()}` }
  }
}

export class MockSmsChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const message = `ROADPACK ALERT: ${payload.victim_name} accident at ${payload.location.lat},${payload.location.lng}. Map: ${payload.maps_link}. Call 112. Call ${payload.victim_name}: ${payload.victim_phone}. Reply OK.`
    console.log(`[MockSMS] To: ${payload.recipient_phone} | ${message}`)
    return { success: true, provider_id: `sms_mock_${Date.now()}` }
  }
}

export class MockVoiceChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const script = `This is an emergency alert from RoadPack. ${payload.victim_name} may have been in an accident at ${payload.location.lat},${payload.location.lng}. Press 1 to acknowledge. Press 2 to call 112.`
    console.log(`[MockVoice] To: ${payload.recipient_phone} | ${script}`)
    return { success: true, provider_id: `voice_mock_${Date.now()}` }
  }
}

export function getChannel(type: 'push' | 'sms' | 'call'): AlertChannel {
  switch (type) {
    case 'push': return new FcmChannel()
    case 'sms': {
      const provider = Deno.env.get('SMS_PROVIDER') ?? 'mock'
      if (provider === 'mock') return new MockSmsChannel()
      throw new Error(`SMS provider '${provider}' not yet implemented`)
    }
    case 'call': {
      const provider = Deno.env.get('VOICE_PROVIDER') ?? 'mock'
      if (provider === 'mock') return new MockVoiceChannel()
      throw new Error(`Voice provider '${provider}' not yet implemented`)
    }
  }
}

export function buildAlertPayload(
  contact: { name: string; phone: string },
  userProfile: { name: string; phone: string },
  location: { lat: number; lng: number },
  incidentId: string,
): AlertPayload {
  return {
    recipient_phone: contact.phone,
    recipient_name: contact.name,
    victim_name: userProfile.name,
    victim_phone: userProfile.phone,
    location,
    maps_link: `https://maps.google.com/?q=${location.lat},${location.lng}`,
    incident_id: incidentId,
  }
}

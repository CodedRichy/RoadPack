export interface AlertPayload {
  recipient_phone: string
  recipient_name: string
  victim_name: string
  victim_phone: string
  location: { lat: number; lng: number; address?: string }
  maps_link: string
  incident_id: string
  incident_type: string
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
    const isCrash = payload.incident_type === 'crash_detected'
    const title = isCrash
      ? 'CRASH DETECTED - RoadPack'
      : 'EMERGENCY ALERT - RoadPack'
    const body = isCrash
      ? `${payload.victim_name} may have been in a crash. Impact detected.`
      : `${payload.victim_name} triggered an emergency SOS alert.`

    console.log('[FCM] Would send push:', JSON.stringify({
      title,
      body,
      data: {
        incident_id: payload.incident_id,
        lat: payload.location.lat,
        lng: payload.location.lng,
        victim_name: payload.victim_name,
        victim_phone: payload.victim_phone,
        incident_type: payload.incident_type,
      },
    }))
    return { success: true, provider_id: `fcm_mock_${Date.now()}` }
  }
}

export class MockSmsChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const isCrash = payload.incident_type === 'crash_detected'
    const alertType = isCrash ? 'CRASH DETECTED' : 'SOS ALERT'
    const detail = isCrash
      ? `${payload.victim_name} may have crashed`
      : `${payload.victim_name} triggered SOS`
    const message = `ROADPACK ${alertType}: ${detail} at ${payload.location.lat},${payload.location.lng}. Map: ${payload.maps_link}. Call 112. Call ${payload.victim_name}: ${payload.victim_phone}. Reply OK.`
    console.log(`[MockSMS] To: ${payload.recipient_phone} | ${message}`)
    return { success: true, provider_id: `sms_mock_${Date.now()}` }
  }
}

export class MockVoiceChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const isCrash = payload.incident_type === 'crash_detected'
    const detail = isCrash
      ? `${payload.victim_name} may have been in a crash`
      : `${payload.victim_name} has triggered an emergency SOS alert`
    const script = `This is an emergency alert from RoadPack. ${detail} at ${payload.location.lat},${payload.location.lng}. Press 1 to acknowledge. Press 2 to call 112.`
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
  incidentType: string = 'sos',
): AlertPayload {
  return {
    recipient_phone: contact.phone,
    recipient_name: contact.name,
    victim_name: userProfile.name,
    victim_phone: userProfile.phone,
    location,
    maps_link: `https://maps.google.com/?q=${location.lat},${location.lng}`,
    incident_id: incidentId,
    incident_type: incidentType,
  }
}

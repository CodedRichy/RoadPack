import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyClerkJwt } from '../_shared/jwt.ts'
import { type ContactRow, type ContactStore, handleNotice } from './handler.ts'
import { getTextSmsSender } from './sms.ts'

function supabaseStore(): ContactStore {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  return {
    async getContact(id: string): Promise<ContactRow | null> {
      const { data, error } = await supabase
        .from('emergency_contacts')
        .select('id, user_id, name, phone, opted_out, notified_at')
        .eq('id', id)
        .maybeSingle()
      if (error) throw new Error(error.message)
      return (data as ContactRow | null) ?? null
    },

    async releaseClaim(id: string): Promise<void> {
      const { error } = await supabase
        .from('emergency_contacts')
        .update({ notified_at: null })
        .eq('id', id)
      if (error) throw new Error(error.message)
    },
  }
}

serve(async (req) => {
  try {
    return await handleNotice(req, {
      store: supabaseStore(),
      sender: getTextSmsSender(),
      verifyJwt: verifyClerkJwt,
    })
  } catch (err) {
    console.error('emergency-contact-notice: unhandled error', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})

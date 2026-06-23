// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const payload = await req.json()
    console.log('Webhook Chap Chap Pay:', JSON.stringify(payload))

    const status = payload.status?.code || payload.status
    const orderId = payload.order_id

    if ((status === 'success' || status === 'completed') && orderId) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') || '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
      )

      // Trouver le provider via paiements_log
      const { data: log } = await supabase
        .from('paiements_log')
        .select('provider_id')
        .eq('order_id', orderId)
        .single()

      if (log?.provider_id) {
        const fin = new Date()
        fin.setDate(fin.getDate() + 30)

        await supabase.from('providers').update({
          abonnement_actif: true,
          abonnement_fin: fin.toISOString(),
          essai_actif: false
        }).eq('id', log.provider_id)

        await supabase.from('paiements_log').update({
          statut: 'success',
          updated_at: new Date().toISOString()
        }).eq('order_id', orderId)

        console.log('Abonnement activé pour:', log.provider_id)
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch(e) {
    console.log('Erreur webhook:', e)
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    })
  }
})

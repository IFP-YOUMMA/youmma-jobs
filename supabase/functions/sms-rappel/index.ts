// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') || '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
  )

  const maintenant = new Date()
  const dans3jours = new Date()
  dans3jours.setDate(dans3jours.getDate() + 3)

  // ── Rappel 3 jours avant expiration ──
  const { data: expireBientot } = await supabase
    .from('providers')
    .select('id, prenom, telephone, abonnement_fin')
    .eq('statut', 'valide')
    .eq('abonnement_actif', true)
    .gte('abonnement_fin', maintenant.toISOString())
    .lte('abonnement_fin', dans3jours.toISOString())

  let rappelsEnvoyes = 0
  for (const p of expireBientot || []) {
    const fin   = new Date(p.abonnement_fin)
    const jours = Math.ceil((fin.getTime() - maintenant.getTime()) / (1000 * 60 * 60 * 24))
    try {
      await fetch('https://yoummajobs.com/api/send-reminder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telephone: p.telephone, prenom: p.prenom, jours })
      })
      rappelsEnvoyes++
      console.log('[sms-rappel] Rappel envoyé à', p.prenom, '— expire dans', jours, 'j')
    } catch (e) {
      console.error('[sms-rappel] Erreur rappel pour', p.prenom, ':', e.message)
    }
  }

  // ── Abonnements expirés : désactiver + SMS ──
  const { data: expires } = await supabase
    .from('providers')
    .select('id, prenom, telephone')
    .eq('statut', 'valide')
    .eq('abonnement_actif', true)
    .lt('abonnement_fin', maintenant.toISOString())

  let expiresTraites = 0
  for (const p of expires || []) {
    // Désactiver l'abonnement dans Supabase
    await supabase
      .from('providers')
      .update({ abonnement_actif: false })
      .eq('id', p.id)

    // SMS expiration
    try {
      await fetch('https://yoummajobs.com/api/send-reminder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telephone: p.telephone, prenom: p.prenom, jours: 0 })
      })
      expiresTraites++
      console.log('[sms-rappel] SMS expiration envoyé à', p.prenom)
    } catch (e) {
      console.error('[sms-rappel] Erreur expiration pour', p.prenom, ':', e.message)
    }
  }

  return new Response(
    JSON.stringify({
      ok: true,
      rappels_envoyes: rappelsEnvoyes,
      expires_traites: expiresTraites,
      timestamp: maintenant.toISOString()
    }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})

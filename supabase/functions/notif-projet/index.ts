// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare const Deno: { env: { get(key: string): string | undefined } };

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function normaliserTelephone(tel: string): string | null {
  const clean = tel.replace(/[\s\-\.]/g, '')
  const e164 = clean.startsWith('+')    ? clean
             : clean.startsWith('224')  ? '+' + clean
             : '+224' + clean.replace(/^0/, '')
  return /^\+224[0-9]{9}$/.test(e164) ? e164 : null
}

async function envoyerSMS(e164: string, message: string): Promise<boolean> {
  const sid   = Deno.env.get('NIMBA_SID')   || '1a3b6b6f9e6e5648f9492b07a26dbdd6'
  const token = Deno.env.get('NIMBA_TOKEN') || 'iEIMmNfZQJGKdUWv6NU7CHNDSvLiVmGruwnMNLTU2-_8DLLpc1HGON6gsfictrB2dfkgv_QMXJWnFpt5jyatV_-V32V2It85RGIxjbEY7Mk'
  const credentials = btoa(sid + ':' + token)
  const res = await fetch('https://api.nimbasms.com/v1/messages', {
    method: 'POST',
    headers: {
      'Authorization': 'Basic ' + credentials,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({ to: [e164], sender_name: 'YOUMMA JOBS', message }),
  })
  return res.ok
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS })
  }

  try {
    const { mission_id } = await req.json()
    if (!mission_id) {
      return new Response(JSON.stringify({ error: 'mission_id manquant' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') || '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    )

    // 1. Charger la mission
    const { data: mission, error: mErr } = await supabase
      .from('missions')
      .select('id, titre, categorie, commune, description')
      .eq('id', mission_id)
      .single()

    if (mErr || !mission) {
      return new Response(JSON.stringify({ error: 'Mission introuvable', details: mErr?.message }), {
        status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const categorie = (mission.categorie || '').trim()
    const commune   = (mission.commune   || 'Conakry').trim()
    const titreRaw  = (mission.titre || mission.description || '')

    if (!categorie) {
      return new Response(JSON.stringify({ ok: true, sms_envoyes: 0, notifs_creees: 0, raison: 'Pas de catégorie' }), {
        status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // 2. Sélectionner les prestataires de la même catégorie (statut valide)
    const { data: providers } = await supabase
      .from('providers')
      .select('id, prenom, telephone, commune, disponibilite, abonnement_actif, abonnement_fin, essai_actif, essai_fin')
      .eq('statut', 'valide')
      .eq('categorie', categorie)

    const cibles = providers || []

    // 3. Scorer et trier
    const now = new Date()
    const scored = cibles.map(p => {
      let score = 0
      if (p.commune && p.commune.toLowerCase() === commune.toLowerCase()) score += 3
      if (p.disponibilite && p.disponibilite !== 'Indisponible') score += 2
      const aboOk   = p.abonnement_actif && p.abonnement_fin && new Date(p.abonnement_fin) > now
      const essaiOk = p.essai_actif      && p.essai_fin      && new Date(p.essai_fin)      > now
      if (aboOk || essaiOk) score += 2
      return { ...p, score }
    }).sort((a, b) => b.score - a.score)

    // 4. Message SMS — max 160 chars
    const communeDisplay = commune.charAt(0).toUpperCase() + commune.slice(1)
    const catDisplay     = categorie.length > 25 ? categorie.substring(0, 25) : categorie
    const titreDisplay   = titreRaw.length  > 35 ? titreRaw.substring(0, 35)  : titreRaw
    const smsMsg = `YOUMMA JOBS: Nouveau projet ${catDisplay} a ${communeDisplay}: ${titreDisplay}. Devis sur yoummajobs.com`

    // 5. SMS — 10 premiers de la liste scorée
    const ciblesSMS = scored.slice(0, 10)
    let smsEnvoyes = 0
    for (const p of ciblesSMS) {
      if (!p.telephone) continue
      try {
        const e164 = normaliserTelephone(String(p.telephone))
        if (!e164) { console.warn('[notif-projet] Tél invalide:', p.telephone); continue }
        const ok = await envoyerSMS(e164, smsMsg)
        if (ok) { smsEnvoyes++; console.log('[notif-projet] SMS →', p.prenom, e164) }
        else console.warn('[notif-projet] SMS échoué →', p.prenom)
      } catch (e) {
        console.error('[notif-projet] Erreur SMS pour', p.prenom, ':', e.message)
      }
    }

    // 6. Notifications cloche — TOUS les prestataires de la catégorie
    let notifsCreees = 0
    try {
      const titreNotif = 'Nouveau projet dans votre domaine'
      const msgNotif   = `${titreRaw.substring(0, 50) || catDisplay} à ${communeDisplay} — Faites votre devis !`
      const notifRows  = cibles.map(p => ({
        destinataire_id:   String(p.id),
        destinataire_type: 'provider',
        type:              'projet',
        titre:             titreNotif,
        message:           msgNotif,
        lu:                false,
        data:              { mission_id: String(mission_id) },
      }))
      if (notifRows.length > 0) {
        const { error: notifErr } = await supabase.from('notifications').insert(notifRows)
        if (notifErr) console.warn('[notif-projet] Erreur notifs:', notifErr.message)
        else notifsCreees = notifRows.length
      }
    } catch (e) {
      console.error('[notif-projet] Erreur notifications:', e.message)
    }

    console.log(`[notif-projet] Mission ${mission_id}: ${smsEnvoyes} SMS, ${notifsCreees} notifs (${cibles.length} cibles)`)
    return new Response(JSON.stringify({
      ok:             true,
      sms_envoyes:    smsEnvoyes,
      notifs_creees:  notifsCreees,
      cibles_total:   cibles.length,
      mission_id,
    }), {
      status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
    })

  } catch (e) {
    console.error('[notif-projet] Erreur générale:', e.message)
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})

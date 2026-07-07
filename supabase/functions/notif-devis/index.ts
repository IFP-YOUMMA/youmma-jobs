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
  const e164 = clean.startsWith('+')   ? clean
             : clean.startsWith('224') ? '+' + clean
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
    const { devis_id } = await req.json()
    if (!devis_id) {
      return new Response(JSON.stringify({ error: 'devis_id manquant' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') || '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    )

    // 1. Charger le devis
    const { data: devis, error: dErr } = await supabase
      .from('devis')
      .select('id, mission_id, provider_id, montant, delai')
      .eq('id', devis_id)
      .single()

    if (dErr || !devis) {
      return new Response(JSON.stringify({ error: 'Devis introuvable', details: dErr?.message }), {
        status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // 2. Charger la mission (téléphone client + titre)
    const { data: mission } = await supabase
      .from('missions')
      .select('titre, description, client_telephone, client_tel')
      .eq('id', devis.mission_id)
      .single()

    // 3. Charger le prestataire (nom + métier + téléphone)
    const { data: provider } = await supabase
      .from('providers')
      .select('prenom, nom, metier, telephone')
      .eq('id', devis.provider_id)
      .single()

    // Téléphone client (deux noms de colonne possibles selon l'ancienneté)
    const clientTelRaw = mission?.client_telephone || mission?.client_tel || null
    if (!clientTelRaw) {
      console.warn('[notif-devis] Pas de téléphone client pour mission', devis.mission_id)
      return new Response(JSON.stringify({ ok: false, raison: 'Pas de téléphone client' }), {
        status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const e164 = normaliserTelephone(String(clientTelRaw))
    if (!e164) {
      console.warn('[notif-devis] Téléphone client invalide:', clientTelRaw)
      return new Response(JSON.stringify({ ok: false, raison: 'Téléphone invalide: ' + clientTelRaw }), {
        status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // 4. Composer le SMS ≤ 160 caractères
    const prenom  = (provider?.prenom || 'Un artisan').substring(0, 15)
    const metier  = (provider?.metier || 'Prestataire').substring(0, 15)
    const titre   = (mission?.titre || mission?.description || 'votre projet').substring(0, 22)
    const montant = devis.montant ? Number(devis.montant).toLocaleString('fr-FR') + ' GNF' : 'montant a convenir'
    const delai   = String(devis.delai || 'a definir').substring(0, 20)
    const provTel = provider?.telephone
      ? String(provider.telephone).replace(/[\s\-\.]/g, '')
      : ''

    let smsMsg = `YOUMMA JOBS: Vous avez recu un devis de ${prenom} (${metier}) pour '${titre}': ${montant}, delai ${delai}.`
    if (provTel) smsMsg += ` Appelez le ${provTel}`
    if (smsMsg.length > 160) smsMsg = smsMsg.substring(0, 157) + '...'

    const ok = await envoyerSMS(e164, smsMsg)
    console.log(`[notif-devis] SMS → ${e164} : ${ok ? 'OK' : 'ECHEC'} | "${smsMsg}"`)

    return new Response(JSON.stringify({ ok, sms_envoye: ok, destinataire: e164 }), {
      status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
    })

  } catch (e) {
    console.error('[notif-devis] Erreur générale:', e.message)
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})

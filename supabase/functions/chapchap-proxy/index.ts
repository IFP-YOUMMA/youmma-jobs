// @ts-nocheck
/* eslint-disable */
// Deno Edge Function — déployée sur Supabase, pas dans Node.js
// Les erreurs VS Code sur Deno/imports sont des faux positifs (pas de plugin Deno installé)

declare const Deno: { env: { get(key: string): string | undefined } };

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  try {
    const payload = await req.json();

    const providerId: string = payload.provider_id || payload.providerId || '';
    const providerNom: string = payload.provider_nom || payload.providerNom || 'Artisan';

    if (!providerId) {
      return new Response(JSON.stringify({ error: 'provider_id manquant' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' }
      });
    }

    const apiKey = Deno.env.get('CHAPCHAP_API_KEY') || '';
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'Clé API non configurée' }), {
        status: 500, headers: { ...CORS, 'Content-Type': 'application/json' }
      });
    }

    // orderId : utilise la référence fournie par l'appelant (ex. l'id de la
    // ligne paiements_youmma déjà créée côté client) si présente, sinon
    // génère un identifiant par défaut — comportement historique inchangé
    // pour les appels qui ne fournissent pas order_id (creerPaiementAbonnement,
    // lancerPaiementAbonnement).
    const orderId: string = payload.order_id || payload.orderId ||
      ('YOUMMA-' + String(providerId).slice(0, 8).toUpperCase() + '-' + Date.now());

    // amount/description/return_url : surchageables par l'appelant (utilisé
    // par lancerPaiementChapChap pour les achats de crédits à 5 000 GNF et
    // les renouvellements d'abonnement à 50 000 GNF) — valeurs par défaut
    // identiques à avant si non fournies, pour ne rien casser côté appels
    // existants.
    const body = {
      amount: payload.amount || 50000,
      description: payload.description || ('Abonnement YOUMMA JOBS 30 jours - ' + providerNom),
      order_id: orderId,
      return_url: payload.return_url || ('https://yoummajobs.com/?paiement=success&order=' + orderId),
      cancel_url: payload.cancel_url || 'https://yoummajobs.com/?paiement=cancel',
      fee_handling: 'deduct'
    };

    const ccpRes = await fetch('https://chapchappay.com/api/ecommerce/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CCP-Api-Key': apiKey,
        'Accept': 'application/json'
      },
      body: JSON.stringify(body)
    });

    const ccpData = await ccpRes.json();

    return new Response(JSON.stringify({ ...ccpData, order_id: orderId }), {
      status: ccpRes.status,
      headers: { ...CORS, 'Content-Type': 'application/json' }
    });

  } catch (err) {
    const msg = (err && typeof err === 'object' && 'message' in err)
      ? (err as { message: string }).message
      : String(err);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' }
    });
  }
});

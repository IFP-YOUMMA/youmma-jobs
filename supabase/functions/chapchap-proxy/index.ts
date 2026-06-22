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

    const orderId = 'YOUMMA-' + String(providerId).slice(0, 8).toUpperCase() + '-' + Date.now();

    const body = {
      amount: 50000,
      description: 'Abonnement YOUMMA JOBS 30 jours - ' + providerNom,
      order_id: orderId,
      return_url: 'https://yoummajobs.com/?paiement=success&order=' + orderId,
      cancel_url: 'https://yoummajobs.com/?paiement=cancel',
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

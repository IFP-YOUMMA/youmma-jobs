import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  try {
    const { providerId, providerNom, orderId } = await req.json();

    if (!providerId || !orderId) {
      return new Response(JSON.stringify({ error: 'Paramètres manquants' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' }
      });
    }

    const apiKey = Deno.env.get('CHAPCHAP_API_KEY');
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'Clé API non configurée' }), {
        status: 500, headers: { ...CORS, 'Content-Type': 'application/json' }
      });
    }

    const body = {
      amount: 50000,
      description: 'Abonnement YOUMMA JOBS 30 jours - ' + providerNom,
      order_id: orderId,
      return_url: 'https://yoummajobs.com/?paiement=success&order=' + orderId,
      cancel_url: 'https://yoummajobs.com/?paiement=cancel',
      fee_handling: 'add'
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

    return new Response(JSON.stringify(ccpData), {
      status: ccpRes.status,
      headers: { ...CORS, 'Content-Type': 'application/json' }
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' }
    });
  }
});

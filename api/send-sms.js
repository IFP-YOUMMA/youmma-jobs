// Vercel Serverless Function — Orange Guinea SMS
module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée' });

  const { phone, code } = req.body || {};

  if (!phone || !code) return res.status(400).json({ error: 'phone et code requis' });

  const cleanPhone = phone.replace(/[\s\-]/g, '');
  const e164 = cleanPhone.startsWith('+') ? cleanPhone
             : cleanPhone.startsWith('224') ? '+' + cleanPhone
             : '+224' + cleanPhone.replace(/^0/, '');

  if (!/^\+224[0-9]{9}$/.test(e164)) {
    return res.status(400).json({ error: 'Numéro guinéen invalide (+224XXXXXXXXX)' });
  }

  const clientId = process.env.ORANGE_CLIENT_ID;
  const clientSecret = process.env.ORANGE_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    return res.status(500).json({ error: 'Clés Orange non configurées sur le serveur' });
  }

  try {
    // Étape 1 : Obtenir le token OAuth2
    const creds = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const tokenRes = await fetch('https://api.orange.com/oauth/v3/token', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${creds}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      body: 'grant_type=client_credentials'
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      return res.status(502).json({ error: 'Erreur token Orange: ' + errText });
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token;

    // Étape 2 : Envoyer le SMS
    const senderAddress = process.env.ORANGE_SENDER_ADDRESS || e164;
    const encodedSender = encodeURIComponent(senderAddress);

    const smsPayload = {
      outboundSMSMessageRequest: {
        address: `tel:${e164}`,
        senderAddress: senderAddress,
        outboundSMSTextMessage: {
          message: `YOUMMA JOBS : Votre code de vérification est ${code}. Valable 10 minutes.`
        }
      }
    };

    const smsRes = await fetch(
      `https://api.orange.com/smsmessaging/v1/outbound/${encodedSender}/requests`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(smsPayload)
      }
    );

    if (!smsRes.ok) {
      const errText = await smsRes.text();
      return res.status(502).json({ error: 'Erreur envoi SMS Orange: ' + errText });
    }

    return res.status(200).json({ success: true });
  } catch (e) {
    return res.status(500).json({ error: 'Erreur serveur: ' + e.message });
  }
};

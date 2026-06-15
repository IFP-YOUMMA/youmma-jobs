// Vercel Serverless Function — Nimba SMS
const https = require('https');

module.exports = async function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée' });

  const body = req.body || {};
  const phone = body.phone;
  const code  = body.code;

  if (!phone || !code) return res.status(400).json({ error: 'phone et code requis' });

  // Normaliser le numéro au format +224XXXXXXXXX
  const clean = phone.replace(/[\s\-]/g, '');
  const e164  = clean.startsWith('+')   ? clean
              : clean.startsWith('224') ? '+' + clean
              : '+224' + clean.replace(/^0/, '');

  if (!/^\+224[0-9]{9}$/.test(e164)) {
    return res.status(400).json({ error: 'Numéro guinéen invalide (+224XXXXXXXXX)' });
  }

  const sid   = process.env.NIMBA_SID;
  const token = process.env.NIMBA_TOKEN;

  if (!sid || !token) {
    return res.status(500).json({ error: 'Clés Nimba SMS non configurées (NIMBA_SID / NIMBA_TOKEN)' });
  }

  const payload = JSON.stringify({
    to: [e164],
    sender_name: 'YOUMMAJOBS',
    message: `Votre code de verification YOUMMA JOBS : ${code}. Valable 10 minutes.`
  });

  const credentials = Buffer.from(`${sid}:${token}`).toString('base64');

  return new Promise(function(resolve) {
    const options = {
      hostname: 'api.nimbasms.com',
      port: 443,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + credentials,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const req2 = https.request(options, function(resp) {
      let data = '';
      resp.on('data', function(chunk) { data += chunk; });
      resp.on('end', function() {
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          resolve(res.status(200).json({ success: true }));
        } else {
          resolve(res.status(502).json({ error: 'Erreur Nimba SMS (' + resp.statusCode + '): ' + data }));
        }
      });
    });

    req2.on('error', function(e) {
      resolve(res.status(500).json({ error: 'Erreur réseau: ' + e.message }));
    });

    req2.write(payload);
    req2.end();
  });
};

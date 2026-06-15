// Vercel Serverless Function — Nimba SMS
const https = require('https');

module.exports = async function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée' });

  const body  = req.body || {};
  const phone = body.phone;
  const code  = body.code;

  if (!phone || !code) {
    return res.status(400).json({ error: 'phone et code requis' });
  }

  const clean = phone.replace(/[\s\-]/g, '');
  const e164  = clean.startsWith('+')   ? clean
              : clean.startsWith('224') ? '+' + clean
              : '+224' + clean.replace(/^0/, '');

  if (!/^\+224[0-9]{9}$/.test(e164)) {
    return res.status(400).json({ error: 'Numéro invalide', received: clean });
  }

  const sid   = process.env.NIMBA_SID   || '1a3b6b6f9e6e5648f9492b07a26dbdd6';
  const token = process.env.NIMBA_TOKEN || 'iEIMmNfZQJGKdUWv6NU7CHNDSvLiVmGruwnMNLTU2-_8DLLpc1HGON6gsfictrB2dfkgv_QMXJWnFpt5jyatV_-V32V2It85RGIxjbEY7Mk';

  const message = 'Votre code de verification YOUMMA JOBS : ' + code + '. Valable 10 minutes.';

  const payload = JSON.stringify({
    to: [e164],
    sender_name: 'YOUMMAJOBS',
    message: message
  });

  const credentials = Buffer.from(sid + ':' + token).toString('base64');

  console.log('[NimbaSMS] Numéro :', e164);
  console.log('[NimbaSMS] Code   :', code);
  console.log('[NimbaSMS] SID via:', process.env.NIMBA_SID ? 'env' : 'fallback');

  return new Promise(function(resolve) {
    const options = {
      hostname: 'api.nimbasms.com',
      port: 443,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + credentials,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const apiReq = https.request(options, function(apiRes) {
      let data = '';
      apiRes.on('data', function(chunk) { data += chunk; });
      apiRes.on('end', function() {
        console.log('[NimbaSMS] Statut HTTP :', apiRes.statusCode);
        console.log('[NimbaSMS] Réponse     :', data);

        let parsed = null;
        try { parsed = JSON.parse(data); } catch(_) {}

        if (apiRes.statusCode >= 200 && apiRes.statusCode < 300) {
          resolve(res.status(200).json({ success: true, response: parsed || data }));
        } else {
          resolve(res.status(502).json({
            error: 'Erreur Nimba SMS (HTTP ' + apiRes.statusCode + ')',
            details: parsed || data,
            numero: e164
          }));
        }
      });
    });

    apiReq.on('error', function(e) {
      console.error('[NimbaSMS] Erreur réseau :', e.message);
      resolve(res.status(500).json({ error: 'Erreur réseau vers Nimba : ' + e.message }));
    });

    apiReq.write(payload);
    apiReq.end();
  });
};

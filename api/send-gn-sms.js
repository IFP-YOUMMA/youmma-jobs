// Vercel Serverless Function — SMS marketing YOUMMA GN (message libre, envoi par lot)
// Réutilise exactement l'intégration Nimba SMS déjà utilisée par send-welcome.js /
// send-reminder.js (même identifiants, même endpoint, même auth) — seule différence :
// le message n'est pas figé côté serveur, il est fourni (déjà personnalisé) par l'appelant,
// un par destinataire, pour permettre {prenom} et du texte libre depuis la page Contacts.
const https = require('https');

function normaliserE164(telephone) {
  const raw = String(telephone || '').replace(/[\s\-.]/g, '');
  const e164 = raw.startsWith('+') ? raw
    : raw.startsWith('224') ? '+' + raw
    : '+224' + raw.replace(/^0/, '');
  return /^\+224[0-9]{9}$/.test(e164) ? e164 : null;
}

function envoyerUnSms(e164, message, sid, token) {
  const payload = JSON.stringify({ to: [e164], sender_name: 'YOUMMA GN', message: message });
  const credentials = Buffer.from(sid + ':' + token).toString('base64');
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
        'Content-Length': Buffer.byteLength(payload),
      },
    };
    const apiReq = https.request(options, function(apiRes) {
      let data = '';
      apiRes.on('data', function(chunk) { data += chunk; });
      apiRes.on('end', function() {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch (_) {}
        if (apiRes.statusCode >= 200 && apiRes.statusCode < 300) {
          resolve({ success: true });
        } else {
          resolve({ success: false, error: 'Erreur Nimba SMS (HTTP ' + apiRes.statusCode + ')', details: parsed || data });
        }
      });
    });
    apiReq.on('error', function(e) {
      resolve({ success: false, error: 'Erreur réseau vers Nimba : ' + e.message });
    });
    apiReq.write(payload);
    apiReq.end();
  });
}

module.exports = async function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée' });

  const { destinataires } = req.body || {};
  if (!Array.isArray(destinataires) || !destinataires.length) {
    return res.status(400).json({ error: 'destinataires requis (liste de { telephone, message })' });
  }

  const sid = process.env.NIMBA_SID || '1a3b6b6f9e6e5648f9492b07a26dbdd6';
  const token = process.env.NIMBA_TOKEN || 'iEIMmNfZQJGKdUWv6NU7CHNDSvLiVmGruwnMNLTU2-_8DLLpc1HGON6gsfictrB2dfkgv_QMXJWnFpt5jyatV_-V32V2It85RGIxjbEY7Mk';

  const resultats = [];
  for (const d of destinataires) {
    const e164 = normaliserE164(d && d.telephone);
    const message = (d && d.message || '').trim();
    if (!e164) { resultats.push({ telephone: d && d.telephone, success: false, error: 'Numéro invalide' }); continue; }
    if (!message) { resultats.push({ telephone: d.telephone, success: false, error: 'Message vide' }); continue; }
    const resultat = await envoyerUnSms(e164, message, sid, token);
    resultats.push(Object.assign({ telephone: d.telephone }, resultat));
  }

  return res.status(200).json({ resultats: resultats });
};

// Vercel Serverless Function — Orange Guinea SMS (utilise https natif, compatible toutes versions Node.js)
const https = require('https');

function httpsRequest(url, options, body) {
  return new Promise(function(resolve, reject) {
    var urlObj = new URL(url);
    var reqOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || 443,
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: Object.assign({}, options.headers, {
        'Content-Length': body ? Buffer.byteLength(body) : 0
      })
    };
    var req = https.request(reqOptions, function(res) {
      var data = '';
      res.on('data', function(chunk) { data += chunk; });
      res.on('end', function() {
        resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          body: data
        });
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

module.exports = async function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée' });

  var body = req.body || {};
  var phone = body.phone;
  var code = body.code;

  if (!phone || !code) return res.status(400).json({ error: 'phone et code requis' });

  var clean = phone.replace(/[\s\-]/g, '');
  var e164 = clean.startsWith('+') ? clean
           : clean.startsWith('224') ? '+' + clean
           : '+224' + clean.replace(/^0/, '');

  if (!/^\+224[0-9]{9}$/.test(e164)) {
    return res.status(400).json({ error: 'Numéro guinéen invalide (+224XXXXXXXXX)' });
  }

  var clientId = process.env.ORANGE_CLIENT_ID;
  var clientSecret = process.env.ORANGE_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    return res.status(500).json({ error: 'Clés Orange non configurées (ORANGE_CLIENT_ID / ORANGE_CLIENT_SECRET)' });
  }

  try {
    // Étape 1 : OAuth2 token
    var creds = Buffer.from(clientId + ':' + clientSecret).toString('base64');
    var tokenBody = 'grant_type=client_credentials';

    var tokenRes = await httpsRequest(
      'https://api.orange.com/oauth/v3/token',
      {
        method: 'POST',
        headers: {
          'Authorization': 'Basic ' + creds,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        }
      },
      tokenBody
    );

    if (!tokenRes.ok) {
      return res.status(502).json({ error: 'Erreur token Orange (' + tokenRes.status + '): ' + tokenRes.body });
    }

    var tokenData;
    try { tokenData = JSON.parse(tokenRes.body); }
    catch(e) { return res.status(502).json({ error: 'Réponse token Orange invalide: ' + tokenRes.body }); }

    var accessToken = tokenData.access_token;
    if (!accessToken) {
      return res.status(502).json({ error: 'Token Orange manquant dans: ' + tokenRes.body });
    }

    // Étape 2 : Envoi SMS
    var senderAddress = process.env.ORANGE_SENDER_ADDRESS || e164;
    var encodedSender = encodeURIComponent(senderAddress);

    var smsPayload = JSON.stringify({
      outboundSMSMessageRequest: {
        address: 'tel:' + e164,
        senderAddress: senderAddress,
        outboundSMSTextMessage: {
          message: 'YOUMMA JOBS : Votre code de vérification est ' + code + '. Valable 10 minutes.'
        }
      }
    });

    var smsRes = await httpsRequest(
      'https://api.orange.com/smsmessaging/v1/outbound/' + encodedSender + '/requests',
      {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + accessToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }
      },
      smsPayload
    );

    if (!smsRes.ok) {
      return res.status(502).json({ error: 'Erreur SMS Orange (' + smsRes.status + '): ' + smsRes.body });
    }

    return res.status(200).json({ success: true });

  } catch (e) {
    return res.status(500).json({ error: 'Erreur serveur: ' + e.message });
  }
};

// Endpoint de diagnostic temporaire — à supprimer après debug
module.exports = function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.json({
    nimba_sid_present:   !!process.env.NIMBA_SID,
    nimba_token_present: !!process.env.NIMBA_TOKEN,
    nimba_sid_length:    process.env.NIMBA_SID   ? process.env.NIMBA_SID.length   : 0,
    nimba_token_length:  process.env.NIMBA_TOKEN ? process.env.NIMBA_TOKEN.length : 0,
    node_version:        process.version,
    env:                 process.env.VERCEL_ENV || 'inconnu'
  });
};

// Endpoint de diagnostic — à supprimer après debug
module.exports = function(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');

  var sid   = process.env.NIMBA_SID;
  var token = process.env.NIMBA_TOKEN;

  // Lister toutes les clés d'env disponibles (pas les valeurs)
  var allKeys = Object.keys(process.env).sort();
  var nimbaKeys = allKeys.filter(function(k){ return k.toLowerCase().includes('nimba'); });

  res.json({
    nimba_sid_present:   !!sid,
    nimba_token_present: !!token,
    nimba_sid_length:    sid   ? sid.length   : 0,
    nimba_token_length:  token ? token.length : 0,
    nimba_related_keys:  nimbaKeys,
    vercel_env:          process.env.VERCEL_ENV   || 'non défini',
    vercel_region:       process.env.VERCEL_REGION || 'non défini',
    is_vercel:           !!process.env.VERCEL,
    node_version:        process.version,
    total_env_keys:      allKeys.length,
    all_env_keys:        allKeys
  });
};

// Volume bar manager API: status, theme selection, and uninstall only.
const P = require('./paths');
const web = require('./web');
const exec = require('./exec');
const audio = require('./audio');

function create(ctx) {
  const config = ctx.config;
  function status() {
    return { options: config.options(), service: { version: ctx.version }, frontend: { version: '' }, job: null };
  }
  async function handle(req, res, u, body) {
    const send = (obj, code) => web.json(res, obj, code);
    const act = u.replace('/api/manager/', '');
    if (act === 'status' && req.method === 'GET') return send(status());
    if (req.method !== 'POST') return send({ error: 'POST expected' }, 405);
    const data = await body(req);
    if (act === 'options') {
      if (audio.THEMES.indexOf(data.volumeTheme) < 0) return send({ error: 'unknown volume theme' }, 400);
      const before = config.options().volumeTheme;
      config.update('manager', c => { c.options = Object.assign({}, c.options || {}, { volumeTheme: data.volumeTheme }); });
      if (before !== data.volumeTheme && ctx.audio) await ctx.audio.syncStockVolumeOSD(data.volumeTheme);
      return send(status());
    }
    if (act === 'uninstall') {
      exec.detached('sleep 1; sh ' + P.SERVICE_DIR + '/scripts/uninstall.sh');
      return send({ returnValue: true });
    }
    return send({ error: 'unknown action' }, 404);
  }
  return { name: 'manager', prefix: '/api/manager/', handle, status };
}
module.exports = { create };

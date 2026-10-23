import {timingSafeEqual} from 'node:crypto';

export function createApi({query, token}) {
  if (typeof query !== 'function' || typeof token !== 'string' || token.length < 32)
    throw new Error('Read-only query adapter and strong operator token required');
  return async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const reply = (code, data) => {res.writeHead(code);res.end(JSON.stringify(data));};
    const auth = req.headers.authorization;
    const presented = typeof auth === 'string' && auth.startsWith('Bearer ')
      ? Buffer.from(auth.slice(7)) : Buffer.alloc(0);
    const expected = Buffer.from(token);
    if (presented.length !== expected.length || !timingSafeEqual(presented, expected))
      return reply(401, {error:'unauthorized'});
    if (req.method !== 'GET') return reply(405, {error:'method_not_allowed'});
    if (req.url !== '/api/snapshot') return reply(404, {error:'not_found'});
    try {
      const machines = await query('SELECT machine_id AS id, connectivity, app_version, android_version, observed_at FROM machine_heartbeats ORDER BY machine_id LIMIT 500');
      const products = await query('SELECT id, name, price_minor, currency, active FROM catalog_products ORDER BY id LIMIT 2000');
      const slots = await query('SELECT machine_id, slot_code, product_id, quantity, capacity, enabled FROM machine_slots ORDER BY machine_id, slot_code LIMIT 10000');
      reply(200, {source:'postgres',machines:machines.rows,products:products.rows,slots:slots.rows});
    } catch {reply(503, {error:'database_unavailable'});}
  };
}

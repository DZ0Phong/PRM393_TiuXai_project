'use strict';
// Bind to loopback; expose only through a trusted HTTPS reverse proxy.
if (process.env.GCLOUD_PROJECT !== 'ad2-8abfa540' || process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
  throw Error('Live host requires GCLOUD_PROJECT=ad2-8abfa540 and NO Firebase emulator variables');
}
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {createApiServer} = require('./online_server');
const handlers = require('./index');
(async () => {
  // Refuse to listen if credentials or access to either live service are missing.
  await Promise.all([getAuth().listUsers(1), getFirestore().collection('rooms').limit(1).get()]);
  const server = createApiServer({handlers, verifyToken: (token) => getAuth().verifyIdToken(token, true)});
  server.listen(8765, '127.0.0.1', () => console.log('Backend online ở 127.0.0.1:8765 (chỉ qua HTTPS proxy)'));
  let ticking = false;
  const tick = async () => {
    if (ticking) return;
    ticking = true;
    try {
      const results = await Promise.allSettled([handlers.tick.run(), handlers.cardTick.run()]);
      results.forEach((result, i) => {
        if (result.status === 'rejected') console.error(['Rounds', 'Cards'][i] + ' scheduler failed:', result.reason);
      });
    } finally { ticking = false; }
  };
  await tick();
  const interval = setInterval(tick, 60000);
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { clearInterval(interval); server.close(); });
})().catch((error) => { console.error('Backend chưa khởi động:', error); process.exitCode = 1; });

'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, httpsCallableFromURL} = require('firebase/functions');
const {getAuth: adminAuth} = require('firebase-admin/auth');
const {createApiServer} = require('../src/online_server');
const handlers = require('../src/index');

test('online bridge: Firebase SDK auth token, real game handlers, admin claim and ledger', async () => {
  const server = createApiServer({handlers, verifyToken: token => adminAuth().verifyIdToken(token)});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const apps = [];
  async function client(name) {
    const app = initializeApp({projectId: 'demo-tai-xiu', apiKey: 'demo-key', appId: 'demo'}, `bridge-${name}-${Date.now()}`);
    apps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
    const user = (await createUserWithEmailAndPassword(auth, `${name}-${Date.now()}@demo.test`, 'Demo123456!')).user;
    const functions = getFunctions(app, 'asia-southeast1');
    const call = async (name, data = {}) => (await httpsCallableFromURL(functions, `http://127.0.0.1:${server.address().port}/api/${name}`)(data)).data;
    return {user, call};
  }
  try {
    const player = await client('player');
    await player.call('ensureProfile');
    const rounds = await player.call('ensureGameRounds');
    const roundId = rounds.tai_xiu.roundId;
    const placed = await player.call('placeBet', {roundId, side: 'tai', amount: 1000, requestId: `bridge_${Date.now()}`});
    assert.equal(placed.amount, 1000);
    await assert.rejects(player.call('setRoundOutcome', {roundId, result: [6, 5, 4], reason: 'Lớp kiểm thử'}), /Chỉ quản trị viên/);
    const admin = await client('admin');
    await adminAuth().setCustomUserClaims(admin.user.uid, {admin: true});
    await admin.user.getIdToken(true);
    await admin.call('ensureProfile');
    assert.equal((await admin.call('setRoundOutcome', {roundId, result: [6, 5, 4], reason: 'Lớp kiểm thử'})).mode, 'admin');
  } finally { await Promise.all(apps.map(deleteApp)); server.close(); }
});


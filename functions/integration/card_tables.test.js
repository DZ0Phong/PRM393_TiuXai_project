const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const {initializeApp: adminApp} = require('firebase-admin/app');
const {getAuth: adminAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {register} = require('../src/card_tables');
const poker = require('../src/poker_engine');

test('card tables: private cards, 2–6 seats, bot, ledger, fixed-limit turns', async () => {
  const projectId = 'demo-tai-xiu';
  const admin = adminApp({projectId}, 'card-test-admin');
  const db = getFirestore(admin); const apps = [];
  async function client(i) {
    const app = initializeApp({projectId, apiKey: 'demo-key', appId: 'demo'}, `card-client-${i}-${Date.now()}`); apps.push(app);
    const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
    const functions = getFunctions(app, 'asia-southeast1'); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
    const {user} = await createUserWithEmailAndPassword(auth, `card-${i}-${Date.now()}@example.com`, 'password123');
    const call = async (name, data = {}) => (await httpsCallable(functions, name)(data)).data;
    await call('ensureProfile'); return {user, call};
  }
  try {
    const boss = await client(0); await adminAuth(admin).setCustomUserClaims(boss.user.uid, {admin: true}); await boss.user.getIdToken(true);
    const a = await client(1), b = await client(2), c = await client(3);
    const baReq = {game: 'ba_cay', stake: 100, maxSeats: 6, requestId: 'bacay-create-001'};
    const {tableId: baId} = await a.call('createCardTable', baReq);
    assert.equal((await a.call('createCardTable', baReq)).tableId, baId);
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance, 9000);
    await assert.rejects(a.call('startCardHand', {tableId: baId}));
    await assert.rejects(a.call('configureCardBots', {tableId: baId, enabled: true, maxBots: 1}));
    await boss.call('configureCardBots', {tableId: baId, enabled: true, maxBots: 1});
    await a.call('startCardHand', {tableId: baId});
    await a.call('startCardHand', {tableId: baId});
    const ba = (await db.doc(`cardTables/${baId}`).get()).data();
    assert.equal(ba.status, 'settled'); assert.equal(ba.seats.length, 2);
    assert.equal(ba.seats.filter(s => s.isBot).length, 1);
    assert.equal(ba.hands, undefined);
    assert.equal((await db.doc(`cardTables/${baId}/hands/${a.user.uid}`).get()).data().cards.length, 3);
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance + (await db.doc('users/bot_01').get()).data().balance, 20000);
    await assert.rejects(b.call('cardAction', {tableId: baId, type: 'bet', version: 1}));
    const pokerReq = {game: 'poker', stake: 50, maxSeats: 6, requestId: 'poker-create-001'};
    const {tableId: id} = await a.call('createCardTable', pokerReq);
    await b.call('joinCardTable', {tableId: id}); await b.call('joinCardTable', {tableId: id});
    const before = (await db.doc(`users/${a.user.uid}`).get()).data().balance + (await db.doc(`users/${b.user.uid}`).get()).data().balance;
    await a.call('startCardHand', {tableId: id});
    let table = (await db.doc(`cardTables/${id}`).get()).data();
    assert.equal(table.status, 'playing'); assert.equal(table.board.length, 0);
    assert.equal(table.hands, undefined);
    await assert.rejects(b.call('cardAction', {tableId: id, type: 'check', version: table.actionVersion}));
    await assert.rejects(a.call('cardAction', {tableId: id, type: 'check', version: 0}));
    for (let i = 0; i < 30 && table.status === 'playing'; i++) {
      const actor = table.turnUid === a.user.uid ? a : b;
      const state = (await db.doc(`cardSecrets/${id}`).get()).data().state;
      await actor.call('cardAction', {tableId: id, type: poker.canCheck(state, actor.user.uid) ? 'check' : 'call', version: table.actionVersion});
      table = (await db.doc(`cardTables/${id}`).get()).data();
    }
    assert.equal(table.status, 'settled'); assert.ok(table.winners.length >= 1);
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance + (await db.doc(`users/${b.user.uid}`).get()).data().balance, before + 1000);
    const {tableId: botPoker} = await c.call('createCardTable', {game: 'poker', stake: 10, maxSeats: 2, requestId: 'poker-bot-001'});
    await boss.call('configureCardBots', {tableId: botPoker, enabled: true, maxBots: 1});
    await c.call('startCardHand', {tableId: botPoker});
    let botTable = (await db.doc(`cardTables/${botPoker}`).get()).data();
    for (let i = 0; i < 30 && botTable.status === 'playing'; i++) {
      assert.equal(botTable.turnUid, c.user.uid);
      const state = (await db.doc(`cardSecrets/${botPoker}`).get()).data().state;
      await c.call('cardAction', {tableId: botPoker, type: poker.canCheck(state, c.user.uid) ? 'check' : 'call', version: botTable.actionVersion});
      botTable = (await db.doc(`cardTables/${botPoker}`).get()).data();
    }
    assert.equal(botTable.status, 'settled');
    const balance = (await db.doc(`users/${c.user.uid}`).get()).data().balance + (await db.doc('users/bot_01').get()).data().balance;
    assert.equal(balance, 10000 + (await db.doc('users/bot_01/operations/table_result_' + baId).get()).data().balance);

    const previous = async (...ids) => (await Promise.all(ids.map(uid => db.doc(`users/${uid}`).get())))
      .reduce((sum, snap) => sum + snap.data().balance, 0);
    const waitingBalances = await previous(a.user.uid, b.user.uid);
    const {tableId: waitingId} = await a.call('createCardTable',
      {game: 'poker', stake: 10, maxSeats: 3, requestId: 'waiting-refund-001'});
    await assert.rejects(b.call('startCardHand', {tableId: waitingId}));
    await b.call('joinCardTable', {tableId: waitingId});
    await b.call('leaveCardTable', {tableId: waitingId});
    await b.call('leaveCardTable', {tableId: waitingId});
    await assert.rejects(b.call('joinCardTable', {tableId: waitingId}));
    await assert.rejects(a.call('cancelCardTable', {tableId: waitingId, reason: 'Kiểm tra hoàn điểm'}));
    await boss.call('cancelCardTable', {tableId: waitingId, reason: 'Kiểm tra hoàn điểm'});
    await boss.call('cancelCardTable', {tableId: waitingId, reason: 'Kiểm tra hoàn điểm'});
    assert.equal(await previous(a.user.uid, b.user.uid), waitingBalances);
    assert.equal((await db.doc(`users/${a.user.uid}/operations/table_refund_${waitingId}`).get()).data().delta, 100);

    const beforeMultiBot = await previous(c.user.uid, 'bot_01') + 10000; // bot_02 not provisioned yet
    const {tableId: multiId} = await c.call('createCardTable',
      {game: 'ba_cay', stake: 10, maxSeats: 4, requestId: 'two-bots-001'});
    await boss.call('configureCardBots', {tableId: multiId, enabled: true, maxBots: 2});
    await c.call('startCardHand', {tableId: multiId});
    const multi = (await db.doc(`cardTables/${multiId}`).get()).data();
    assert.equal(multi.status, 'settled');
    assert.equal(multi.seats.length, 3);
    assert.equal(multi.seats.filter(s => s.isBot).length, 2);
    assert.equal(await previous(c.user.uid, 'bot_01', 'bot_02'), beforeMultiBot);
    const ranking = await b.call('getLeaderboard');
    assert.equal(ranking.length, 4);
    assert.ok(ranking.every(row => row.nickname.startsWith('Bạn ') && Number.isSafeInteger(row.balance)));

    const playingBalances = await previous(a.user.uid, b.user.uid);
    const {tableId: cancelId} = await a.call('createCardTable',
      {game: 'poker', stake: 10, maxSeats: 2, requestId: 'playing-cancel-001'});
    await b.call('joinCardTable', {tableId: cancelId});
    await a.call('startCardHand', {tableId: cancelId});
    await boss.call('cancelCardTable', {tableId: cancelId, reason: 'Test rời mạng'});
    await boss.call('cancelCardTable', {tableId: cancelId, reason: 'Test rời mạng'});
    assert.equal(await previous(a.user.uid, b.user.uid), playingBalances);
    assert.equal((await db.doc(`cardTables/${cancelId}`).get()).data().status, 'cancelled');
    await assert.rejects(a.call('cardAction', {tableId: cancelId, type: 'check', version: 1}));

    const timeoutBalances = await previous(a.user.uid, b.user.uid);
    const {tableId: timeoutId} = await a.call('createCardTable',
      {game: 'poker', stake: 10, maxSeats: 2, requestId: 'timeout-check-001'});
    await b.call('joinCardTable', {tableId: timeoutId});
    await a.call('startCardHand', {tableId: timeoutId});
    const tick = register({db, call: fn => fn, admin: () => {}}).tickCardTables;
    let timed = (await db.doc(`cardTables/${timeoutId}`).get()).data();
    for (let i = 0; timed.status === 'playing' && i < 12; i++) {
      const version = timed.actionVersion;
      await db.doc(`cardTables/${timeoutId}`).update({turnDeadline: Timestamp.fromMillis(Date.now() - 1000)});
      await tick();
      timed = (await db.doc(`cardTables/${timeoutId}`).get()).data();
      assert.equal(timed.actionVersion, version + 1);
    }
    assert.equal(timed.status, 'settled');
    assert.equal(await previous(a.user.uid, b.user.uid), timeoutBalances);
    await assert.rejects(b.call('cancelCardTable', {tableId: timeoutId, reason: 'Không được hủy'}));

    const raceBalances = await previous(a.user.uid, b.user.uid);
    const {tableId: raceId} = await a.call('createCardTable',
      {game: 'poker', stake: 10, maxSeats: 2, requestId: 'card-race-001'});
    await b.call('joinCardTable', {tableId: raceId});
    await a.call('startCardHand', {tableId: raceId});
    const turn = (await db.doc(`cardTables/${raceId}`).get()).data();
    const actor = turn.turnUid === a.user.uid ? a : b;
    const duplicate = await Promise.allSettled([1, 2].map(() => actor.call('cardAction',
      {tableId: raceId, type: 'check', version: turn.actionVersion})));
    assert.equal(duplicate.filter(result => result.status === 'fulfilled').length, 1);
    assert.equal((await db.doc(`cardTables/${raceId}`).get()).data().actionVersion, turn.actionVersion + 1);
    await boss.call('cancelCardTable', {tableId: raceId, reason: 'Hủy sau race'});
    assert.equal(await previous(a.user.uid, b.user.uid), raceBalances);
  } finally { await Promise.all(apps.map(deleteApp)); }
});

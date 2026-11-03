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
const testPort = (key, fallback) => Number(process.env[key] || fallback);
const authPort = testPort('TEST_AUTH_PORT', 9099);
const functionsPort = testPort('TEST_FUNCTIONS_PORT', 5001);

test('card tables: private cards, 2–6 seats, bot, ledger, fixed-limit turns', async () => {
  const projectId = 'demo-tai-xiu';
  const admin = adminApp({projectId}, 'card-test-admin');
  const db = getFirestore(admin); const apps = [];
  async function client(i) {
    const app = initializeApp({projectId, apiKey: 'demo-key', appId: 'demo'}, `card-client-${i}-${Date.now()}`); apps.push(app);
    const auth = getAuth(app); connectAuthEmulator(auth, `http://127.0.0.1:${authPort}`, {disableWarnings: true});
    const functions = getFunctions(app, 'asia-southeast1'); connectFunctionsEmulator(functions, '127.0.0.1', functionsPort);
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
    const waitingBa = (await db.doc(`cardTables/${baId}`).get()).data();
    const baBot = waitingBa.seats.find(s => s.uid !== a.user.uid).uid;
    assert.equal(waitingBa.seats.length, 2);
    assert.match(baBot, /^[A-Za-z0-9_-]{28}$/);
    assert.ok(!baBot.startsWith('bot_'));
    const poolIds = (await db.doc('cardBotPool/global').get()).data().uids;
    assert.equal(poolIds.length, 5);
    assert.equal(baBot, poolIds[0]);
    assert.equal(waitingBa.seats.find(s => s.uid === baBot).nickname, `Bạn ${baBot.slice(0, 6)}`);
    assert.equal(waitingBa.seats.find(s => s.uid === a.user.uid).nickname, `Bạn ${a.user.uid.slice(0, 6)}`);
    assert.ok(!Object.hasOwn(waitingBa, 'botsEnabled') && !Object.hasOwn(waitingBa, 'maxBots'));
    assert.ok(waitingBa.seats.every(s => !Object.hasOwn(s, 'isBot')));
    const getBotConfig = register({db, call: fn => fn, admin: req => {
      if (req.auth.token.admin !== true) throw Error('admin only');
    }}).getCardBotConfig;
    assert.deepEqual(await getBotConfig({data: {tableId: baId}, auth: {uid: boss.user.uid, token: {admin: true}}}),
      {botsEnabled: true, maxBots: 1});
    await assert.rejects(getBotConfig({data: {tableId: baId}, auth: {uid: a.user.uid, token: {}}}));
    assert.deepEqual(await boss.call('getCardBotConfig', {tableId: baId}), {botsEnabled: true, maxBots: 1});
    await assert.rejects(a.call('getCardBotConfig', {tableId: baId}));
    await assert.rejects(boss.call('configureCardBots', {tableId: baId}));
    await a.call('startCardHand', {tableId: baId});
    await a.call('startCardHand', {tableId: baId});
    const ba = (await db.doc(`cardTables/${baId}`).get()).data();
    assert.equal(ba.status, 'settled'); assert.equal(ba.seats.length, 2);
    assert.ok(ba.seats.every(s => !Object.hasOwn(s, 'isBot')));
    assert.equal(ba.hands, undefined);
    assert.equal((await db.doc(`cardTables/${baId}/hands/${a.user.uid}`).get()).data().cards.length, 3);
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance + (await db.doc(`users/${baBot}`).get()).data().balance, 19998);
    await assert.rejects(b.call('cardAction', {tableId: baId, type: 'bet', version: 1}));
    const {tableId: changingId} = await a.call('createCardTable', {game: 'poker', stake: 10, maxSeats: 3, requestId: 'bot-waiting-001'});
    await assert.rejects(b.call('configureCardBots', {tableId: changingId, enabled: true, maxBots: 2}));
    await assert.rejects(boss.call('configureCardBots', {tableId: changingId, enabled: true, maxBots: 3}));
    const parallel = await Promise.allSettled([1, 2].map(() => boss.call('configureCardBots', {tableId: changingId, enabled: true, maxBots: 2})));
    assert.ok(parallel.every(p => p.status === 'fulfilled'));
    let waiting = (await db.doc(`cardTables/${changingId}`).get()).data();
    assert.equal(waiting.seats.length, 3);
    const originalBots = waiting.seats.filter(s => s.uid !== a.user.uid).map(s => s.uid);
    assert.deepEqual(originalBots, poolIds.slice(0, 2));
    assert.equal((await db.doc(`users/${baBot}/operations/welcome`).get()).data().delta, 10000);
    assert.equal((await db.collection(`users/${baBot}/operations`).where('kind', '==', 'welcome').get()).size, 1);
    for (const uid of originalBots) assert.equal((await db.doc(`users/${uid}/operations/table_join_${changingId}`).get()).data().delta, -100);
    await b.call('joinCardTable', {tableId: changingId});
    waiting = (await db.doc(`cardTables/${changingId}`).get()).data();
    assert.equal(waiting.seats.length, 3);
    assert.ok(waiting.seats.some(s => s.uid === b.user.uid));
    const evicted = originalBots.find(uid => !waiting.seats.some(s => s.uid === uid));
    assert.equal((await db.doc(`users/${evicted}/operations/table_refund_${changingId}`).get()).data().delta, 100);
    await b.call('leaveCardTable', {tableId: changingId});
    waiting = (await db.doc(`cardTables/${changingId}`).get()).data();
    assert.equal(waiting.seats.length, 3);
    assert.equal(waiting.seats.find(s => s.uid !== a.user.uid).uid, baBot);
    assert.equal((await db.doc(`users/${evicted}/operations/table_join_${changingId}_2`).get()).data().delta, -100);
    await boss.call('configureCardBots', {tableId: changingId, enabled: false, maxBots: 0});
    assert.equal((await db.doc(`users/${evicted}/operations/table_refund_${changingId}_2`).get()).data().delta, 100);
    waiting = (await db.doc(`cardTables/${changingId}`).get()).data();
    assert.equal(waiting.seats.length, 1);
    assert.ok(!Object.hasOwn(waiting, 'botsEnabled') && !Object.hasOwn(waiting, 'maxBots'));
    for (const uid of waiting.seats.map(s => s.uid)) assert.equal(uid, a.user.uid);
    await boss.call('cancelCardTable', {tableId: changingId, reason: 'Dọn bàn test'});
    const {tableId: soloId} = await a.call('createCardTable', {game: 'ba_cay', stake: 10, maxSeats: 6, requestId: 'bot-owner-leave-001'});
    await boss.call('configureCardBots', {tableId: soloId, enabled: true, maxBots: 5});
    const soloBots = (await db.doc(`cardTables/${soloId}`).get()).data().seats.filter(s => s.uid !== a.user.uid);
    assert.deepEqual(soloBots.map(s => s.uid), poolIds);
    const soloBalances = await Promise.all(soloBots.map(s => db.doc(`users/${s.uid}`).get().then(v => v.data().balance)));
    assert.equal(soloBots.length, 5);
    await a.call('leaveCardTable', {tableId: soloId});
    await assert.rejects(a.call('leaveCardTable', {tableId: soloId}));
    const solo = (await db.doc(`cardTables/${soloId}`).get()).data();
    assert.equal(solo.status, 'cancelled'); assert.equal(solo.seats.length, 0);
    for (const [i, seat] of soloBots.entries()) {
      assert.equal((await db.doc(`users/${seat.uid}`).get()).data().balance, soloBalances[i] + 100);
      assert.equal((await db.doc(`users/${seat.uid}/operations/table_refund_${soloId}`).get()).data().delta, 100);
    }
    const sharedBefore = (await db.doc(`users/${a.user.uid}`).get()).data().balance +
      (await db.doc(`users/${c.user.uid}`).get()).data().balance +
      (await db.doc(`users/${baBot}`).get()).data().balance;
    const {tableId: sharedA} = await a.call('createCardTable',
      {game: 'ba_cay', stake: 10, maxSeats: 2, requestId: 'shared-bot-a-001'});
    const {tableId: sharedC} = await c.call('createCardTable',
      {game: 'ba_cay', stake: 10, maxSeats: 2, requestId: 'shared-bot-c-001'});
    await Promise.all([sharedA, sharedC].map(tableId => boss.call('configureCardBots', {tableId, enabled: true, maxBots: 1})));
    for (const tableId of [sharedA, sharedC]) {
      assert.equal((await db.doc(`cardTables/${tableId}`).get()).data().seats[1].uid, baBot);
      assert.equal((await db.doc(`users/${baBot}/operations/table_join_${tableId}`).get()).data().delta, -100);
    }
    assert.equal((await db.collection(`users/${baBot}/operations`).where('kind', '==', 'welcome').get()).size, 1);
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance +
      (await db.doc(`users/${c.user.uid}`).get()).data().balance +
      (await db.doc(`users/${baBot}`).get()).data().balance, sharedBefore - 400);
    await Promise.all([sharedA, sharedC].map(tableId => boss.call('cancelCardTable', {tableId, reason: 'Dọn bàn bot chung'})));
    assert.equal((await db.doc(`users/${a.user.uid}`).get()).data().balance +
      (await db.doc(`users/${c.user.uid}`).get()).data().balance +
      (await db.doc(`users/${baBot}`).get()).data().balance, sharedBefore);
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
    const pokerBot = botTable.seats.find(s => s.uid !== c.user.uid).uid;
    assert.equal(pokerBot, baBot);
    assert.equal((await db.collection(`users/${pokerBot}/operations`).where('kind', '==', 'welcome').get()).size, 1);
    assert.equal((await db.doc(`users/${pokerBot}/operations/table_join_${botPoker}`).get()).data().delta, -100);

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
    const beforeTableRefund = (await db.doc(`users/${a.user.uid}`).get()).data().balance;
    await db.doc(`users/${a.user.uid}`).update({balance: Number.MAX_SAFE_INTEGER});
    await assert.rejects(boss.call('cancelCardTable', {tableId: waitingId, reason: 'Không thể hoàn điểm tràn số'}));
    assert.equal((await db.doc(`cardTables/${waitingId}`).get()).data().status, 'waiting');
    assert.equal((await db.doc(`users/${a.user.uid}/operations/table_refund_${waitingId}`).get()).exists, false);
    await db.doc(`users/${a.user.uid}`).update({balance: beforeTableRefund});
    await boss.call('cancelCardTable', {tableId: waitingId, reason: 'Kiểm tra hoàn điểm'});
    await boss.call('cancelCardTable', {tableId: waitingId, reason: 'Kiểm tra hoàn điểm'});
    assert.equal(await previous(a.user.uid, b.user.uid), waitingBalances);
    assert.equal((await db.doc(`users/${a.user.uid}/operations/table_refund_${waitingId}`).get()).data().delta, 100);

    const beforeMultiBot = await previous(c.user.uid, ...poolIds.slice(0, 2));
    const {tableId: multiId} = await c.call('createCardTable',
      {game: 'ba_cay', stake: 10, maxSeats: 4, requestId: 'two-bots-001'});
    await boss.call('configureCardBots', {tableId: multiId, enabled: true, maxBots: 2});
    await c.call('startCardHand', {tableId: multiId});
    const multi = (await db.doc(`cardTables/${multiId}`).get()).data();
    assert.equal(multi.status, 'settled');
    assert.equal(multi.seats.length, 3);
    assert.ok(multi.seats.every(s => !Object.hasOwn(s, 'isBot')));
    const multiBots = multi.seats.filter(s => s.uid !== c.user.uid).map(s => s.uid);
    assert.deepEqual(multiBots, poolIds.slice(0, 2));
    assert.equal(await previous(c.user.uid, ...multiBots), beforeMultiBot - 2);
    const ranking = await b.call('getLeaderboard');
    assert.equal(ranking.length, 4);
    assert.ok(ranking.every(row => row.nickname.startsWith('Bạn ') && Number.isSafeInteger(row.balance)));

    const botBalance = (await db.doc(`users/${baBot}`).get()).data().balance;
    const {tableId: poorId} = await a.call('createCardTable',
      {game: 'ba_cay', stake: 10, maxSeats: 2, requestId: 'bot-poor-001'});
    await boss.call('adjustBalance', {uid: baBot, delta: -botBalance, requestId: 'bot-poor-001', reason: 'Test ví bot thiếu điểm'});
    await assert.rejects(boss.call('configureCardBots', {tableId: poorId, enabled: true, maxBots: 1}));
    assert.equal((await db.doc(`cardTables/${poorId}`).get()).data().seats.length, 1);
    assert.deepEqual(await boss.call('getCardBotConfig', {tableId: poorId}), {botsEnabled: false, maxBots: 0});
    assert.equal((await db.doc(`users/${baBot}/operations/table_join_${poorId}`).get()).exists, false);
    await boss.call('adjustBalance', {uid: baBot, delta: botBalance, requestId: 'bot-restore-001', reason: 'Hoàn điểm thử nghiệm bot'});
    await boss.call('configureCardBots', {tableId: poorId, enabled: true, maxBots: 1});
    assert.equal((await db.doc(`cardTables/${poorId}`).get()).data().seats[1].uid, baBot);
    await boss.call('cancelCardTable', {tableId: poorId, reason: 'Dọn bàn thử bot'});
    assert.equal((await db.doc(`users/${baBot}`).get()).data().balance, botBalance);
    assert.equal((await db.collection(`users/${baBot}/operations`).where('kind', '==', 'welcome').get()).size, 1);
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

const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const {doc, setDoc, getDoc, collection, getDocs, query, where, orderBy, limit, startAfter} = require('firebase/firestore');
const {initializeApp: adminApp} = require('firebase-admin/app');
const {getAuth: adminAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const projectId = 'demo-tai-xiu';
const testPort = (key, fallback) => Number(process.env[key] || fallback);
const firestorePort = testPort('TEST_FIRESTORE_PORT', 8080);
const authPort = testPort('TEST_AUTH_PORT', 9099);
const functionsPort = testPort('TEST_FUNCTIONS_PORT', 5001);

test('rules: không ghi client, ví/bài riêng, audit chỉ admin', async () => {
  const env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: firestorePort, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
  try {
    await env.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'users/alice'), {balance: 100, createdAt: new Date(1)});
      await setDoc(doc(c.firestore(), 'users/locked'), {balance: 100, blocked: true, createdAt: new Date(2)});
      await setDoc(doc(c.firestore(), 'rounds/rule-test'), {status: 'open'});
      await setDoc(doc(c.firestore(), 'rounds/settled-test'), {game: 'tai_xiu', status: 'settled', settledAt: new Date(), result: [6, 6, 6], outcome: {side: 'tai', total: 18}});
      await setDoc(doc(c.firestore(), 'rounds/rule-test/bets/alice'), {amount: 10});
      await setDoc(doc(c.firestore(), 'auditLogs/test'), {action: 'TEST'});
      await setDoc(doc(c.firestore(), 'roundPlans/rule-test'), {result: [1, 2, 3]});
      await setDoc(doc(c.firestore(), 'rooms/tai_xiu/members/alice'), {lastSeen: new Date()});
      await setDoc(doc(c.firestore(), 'cardTables/card-test'), {game: 'poker', status: 'playing'});
      await setDoc(doc(c.firestore(), 'cardTables/card-test/hands/alice'), {cards: ['AS', 'AH']});
      await setDoc(doc(c.firestore(), 'cardSecrets/card-test'), {state: {hands: {alice: ['AS', 'AH']}}});
      await setDoc(doc(c.firestore(), 'cardBotPool/global'), {uids: ['private-bot-id']});
      const logs = Array.from({length: 25}, (_, i) => setDoc(doc(c.firestore(), `auditLogs/page-${i.toString().padStart(2, '0')}`), {
        actor: 'boss', action: 'TEST', details: {index: i}, at: new Date(1000 + i),
      }));
      await Promise.all(logs);
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const anon = env.unauthenticatedContext().firestore();
    const admin = env.authenticatedContext('boss', {admin: true}).firestore();
    await assertSucceeds(getDoc(doc(alice, 'users/alice')));
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertSucceeds(getDoc(doc(admin, 'users/alice')));
    const adminPlayers = await assertSucceeds(getDocs(query(collection(admin, 'users'), orderBy('createdAt', 'desc'), limit(50))));
    assert.ok(adminPlayers.docs.some((player) => player.id === 'alice'));
    await assertFails(getDocs(query(collection(alice, 'users'), orderBy('createdAt', 'desc'), limit(50))));
    await assertFails(setDoc(doc(alice, 'users/alice'), {balance: 999999}));
    await assertFails(setDoc(doc(admin, 'auditLogs/test'), {action: 'EDIT'}));
    await assertFails(getDoc(doc(alice, 'auditLogs/test')));
    await assertSucceeds(getDoc(doc(admin, 'auditLogs/test')));
    await assertFails(getDoc(doc(anon, 'auditLogs/test')));
    const firstAuditPage = await assertSucceeds(getDocs(query(collection(admin, 'auditLogs'), where('at', '>=', new Date(1000)), where('at', '<=', new Date(1024)), orderBy('at', 'desc'), limit(20))));
    assert.equal(firstAuditPage.docs.length, 20);
    assert.equal(firstAuditPage.docs[0].data().details.index, 24);
    const secondAuditPage = await assertSucceeds(getDocs(query(collection(admin, 'auditLogs'), where('at', '>=', new Date(1000)), where('at', '<=', new Date(1024)), orderBy('at', 'desc'), startAfter(firstAuditPage.docs.at(-1)), limit(20))));
    assert.equal(secondAuditPage.docs.length, 5);
    await assertFails(getDocs(query(collection(alice, 'auditLogs'), orderBy('at', 'desc'), limit(20))));
    await assertFails(getDoc(doc(bob, 'rounds/rule-test/bets/alice')));
    await assertFails(getDoc(doc(alice, 'roundPlans/rule-test')));
    await assertSucceeds(getDoc(doc(admin, 'roundPlans/rule-test')));
    await assertSucceeds(getDocs(collection(admin, 'rooms/tai_xiu/members')));
    await assertFails(getDocs(collection(alice, 'rooms/tai_xiu/members')));
    await assertFails(setDoc(doc(alice, 'rooms/tai_xiu/members/alice'), {lastSeen: new Date()}));
    await assertFails(setDoc(doc(admin, 'roundPlans/rule-test'), {result: [6, 6, 6]}));
    await assertSucceeds(getDoc(doc(bob, 'cardTables/card-test')));
    await assertSucceeds(getDoc(doc(alice, 'cardTables/card-test/hands/alice')));
    await assertFails(getDoc(doc(bob, 'cardTables/card-test/hands/alice')));
    await assertFails(getDoc(doc(admin, 'cardTables/card-test/hands/alice')));
    await assertFails(getDoc(doc(alice, 'cardSecrets/card-test')));
    await assertFails(getDoc(doc(admin, 'cardSecrets/card-test')));
    await assertFails(getDoc(doc(alice, 'cardBotPool/global')));
    await assertFails(getDoc(doc(admin, 'cardBotPool/global')));
    await assertSucceeds(getDoc(doc(alice, 'rounds/rule-test/bets/alice')));
    const history = await assertSucceeds(getDocs(query(collection(alice, 'rounds'),
      where('game', '==', 'tai_xiu'), where('status', '==', 'settled'),
      orderBy('settledAt', 'desc'), limit(125))));
    assert.equal(history.docs.length, 1);
    assert.deepEqual(history.docs[0].data().result, [6, 6, 6]);
    await assertFails(getDoc(doc(env.authenticatedContext('locked').firestore(), 'rounds/rule-test')));
  } finally { await env.cleanup(); }
});

test('callable: ba trò, quyền admin, khóa, chốt/hoàn retry, ledger', async () => {
  const app = adminApp({projectId}); const db = getFirestore(app); const apps = [];
  async function client(i) {
    const a = initializeApp({projectId, apiKey: 'demo-key', appId: 'demo'}, `test-${i}-${Date.now()}`); apps.push(a);
    const auth = getAuth(a); connectAuthEmulator(auth, `http://127.0.0.1:${authPort}`, {disableWarnings: true});
    const f = getFunctions(a, 'asia-southeast1'); connectFunctionsEmulator(f, '127.0.0.1', functionsPort);
    const {user} = await createUserWithEmailAndPassword(auth, `test${i}-${Date.now()}@example.com`, 'password123');
    return {user, call: async (name, data = {}) => (await httpsCallable(f, name)(data)).data};
  }
  try {
    const boss = await client(0); await adminAuth(app).setCustomUserClaims(boss.user.uid, {admin: true}); await boss.user.getIdToken(true); await boss.call('ensureProfile');
    const p = await client(1); await p.call('ensureProfile');
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 10000);
    const joined = await p.call('touchGameRoom', {game: 'tai_xiu'});
    assert.equal((await db.doc(`rooms/tai_xiu/members/${p.user.uid}`).get()).exists, true);
    await p.call('leaveGameRoom', {game: 'tai_xiu'});
    assert.equal((await db.doc(`rooms/tai_xiu/members/${p.user.uid}`).get()).exists, false);
    await boss.call('cancelRound', {roundId: joined.roundId, reason: 'Dọn phiên kiểm thử'});
    await assert.rejects(p.call('startRound', {game: 'tai_xiu', mode: 'admin'}));
    await assert.rejects(p.call('adjustBalance', {uid: p.user.uid, delta: 100, reason: 'Không có quyền', requestId: 'no-rights-001'}));
    await assert.rejects(p.call('wallet', {kind: 'deposit', amount: 100}));
    for (const [game, side, result, credit] of [
      ['tai_xiu', 'tai', [2, 3, 6], 1980],
      ['bau_cua', 'cua', ['cua', 'cua', 'bau'], 4940],
      ['xoc_xoc', 'chan', [0, 1, 0, 1], 1980],
    ]) {
      const {roundId} = await boss.call('startRound', {game, mode: 'admin'});
      const initial = (await db.doc(`rounds/${roundId}`).get()).data();
      assert.equal(Object.hasOwn(initial, 'mode'), false);
      assert.equal(Object.hasOwn(initial, 'plannedAt'), false);
      await assert.rejects(boss.call('startRound', {game, mode: 'random'}));
      await p.call('placeBet', {roundId, side, amount: 1000, requestId: `first-${game}`});
      await p.call('placeBet', {roundId, side, amount: 1000, requestId: `first-${game}`});
      await assert.rejects(p.call('placeBet', {roundId, side, amount: 10000, requestId: `first-${game}`}));
      if (game === 'bau_cua') {
        await p.call('placeBet', {roundId, side: 'bau', amount: 1000, requestId: 'second-bau'});
        const beforeReplay = (await db.doc(`users/${p.user.uid}`).get()).data().balance;
        const replay = await p.call('placeBet', {roundId, side, amount: 1000, requestId: `first-${game}`});
        assert.equal(replay.amount, 1000); assert.deepEqual(replay.stakes, {cua: 1000});
        assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, beforeReplay);
      }
      const stakeStats = (await db.doc(`rounds/${roundId}`).get()).data();
      assert.equal(stakeStats.totals[side], 1000);
      assert.equal(stakeStats.playerCounts[side], 1);
      assert.ok((await db.doc(`rounds/${roundId}/bets/${p.user.uid}`).get()).data().nickname);
      await assert.rejects(p.call('setRoundOutcome', {roundId, result, reason: 'Không có quyền'}));
      await assert.rejects(boss.call('setRoundOutcome', {roundId, result: [9, 9, 9], reason: 'Không hợp lệ'}));
      const beforePlan = await db.doc(`rounds/${roundId}`).get();
      await boss.call('setRoundOutcome', {roundId, result, reason: 'Bài kiểm thử'});
      await assert.rejects(boss.call('setRoundOutcome', {roundId, result, reason: 'Không đổi được'}));
      const publicAfterPlan = await db.doc(`rounds/${roundId}`).get();
      assert.equal(publicAfterPlan.updateTime.toMillis(), beforePlan.updateTime.toMillis());
      const pending = publicAfterPlan.data();
      assert.equal(pending.result, undefined);
      assert.equal(Object.hasOwn(pending, 'mode'), false);
      assert.equal(Object.hasOwn(pending, 'plannedAt'), false);
      assert.deepEqual((await db.doc(`roundPlans/${roundId}`).get()).data().result, result);
      await db.doc(`rounds/${roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
      await assert.rejects(boss.call('setRoundOutcome', {roundId, result, reason: 'Đã muộn'}));
      await Promise.all([1, 2].map(() => p.call('advanceRandomRound', {roundId})));
      const round = (await db.doc(`rounds/${roundId}`).get()).data();
      assert.equal(round.status, 'settled'); assert.equal(round.reason, undefined);
      assert.equal(Object.hasOwn(round, 'mode'), false);
      assert.equal(Object.hasOwn(round, 'plannedAt'), false);
      assert.deepEqual(round.result, result);
      assert.equal((await db.doc(`rounds/${roundId}/bets/${p.user.uid}`).get()).data().credit, credit);
      assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${roundId}`).get()).data().delta, credit);
      await assert.rejects(boss.call('cancelRound', {roundId, reason: 'Không hủy đã chốt'}));
    }
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 14900);
    const {roundId: cancelled} = await boss.call('startRound', {game: 'tai_xiu', mode: 'admin'});
    await p.call('placeBet', {roundId: cancelled, side: 'xiu', amount: 1000, requestId: 'cancel-first'});
    const beforeRefund = (await db.doc(`users/${p.user.uid}`).get()).data().balance;
    await db.doc(`users/${p.user.uid}`).update({balance: Number.MAX_SAFE_INTEGER});
    await assert.rejects(boss.call('cancelRound', {roundId: cancelled, reason: 'Không thể hoàn điểm tràn số'}));
    assert.equal((await db.doc(`rounds/${cancelled}`).get()).data().status, 'open');
    assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${cancelled}`).get()).exists, false);
    await db.doc(`users/${p.user.uid}`).update({balance: beforeRefund});
    await Promise.all([1, 2].map(() => boss.call('cancelRound', {roundId: cancelled, reason: 'Hủy phiên thử nghiệm'})));
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 14900);
    assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${cancelled}`).get()).data().kind, 'refund');
    await assert.rejects(boss.call('setRoundOutcome', {roundId: cancelled, result: [2, 3, 6], reason: 'Không chốt đã hủy'}));
    const random = await boss.call('startRound', {game: 'bau_cua', mode: 'random'});
    const refundBet = {roundId: random.roundId, side: 'cua', amount: 1000, requestId: 'refunded-bet-001'};
    const startingBalance = (await db.doc(`users/${p.user.uid}`).get()).data().balance;
    await Promise.all([p.call('placeBet', refundBet), p.call('placeBet', refundBet)]);
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, startingBalance - 1000);
    const refund = {roundId: random.roundId, requestId: 'refund-001'};
    await Promise.all([p.call('refundMyBet', refund), p.call('refundMyBet', refund)]);
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, startingBalance);
    assert.equal((await p.call('placeBet', refundBet)).amount, 1000);
    await assert.rejects(p.call('placeBet', {...refundBet, side: 'bau'}));
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, startingBalance);
    await db.doc(`rounds/${random.roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
    await p.call('advanceRandomRound', {roundId: random.roundId});
    await p.call('advanceRandomRound', {roundId: random.roundId});
    assert.equal((await db.doc(`rounds/${random.roundId}`).get()).data().result.length, 3);
    const logs = await db.collection('auditLogs').where('action', '==', 'SETTLE').get();
    assert.equal(logs.size, 4);
    assert.equal(logs.docs[0].data().details.reason.length > 0, true);
    const other = await client(2); await other.call('ensureProfile');
    const race = await boss.call('startRound', {game: 'tai_xiu', mode: 'admin'});
    await Promise.all([
      p.call('placeBet', {roundId: race.roundId, side: 'tai', amount: 1000, requestId: 'race-p'}),
      other.call('placeBet', {roundId: race.roundId, side: 'xiu', amount: 1000, requestId: 'race-other'}),
    ]);
    await boss.call('setRoundOutcome', {roundId: race.roundId, result: [2, 3, 6], reason: 'Chốt cùng thời điểm'});
    await db.doc(`rounds/${race.roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
    const late = await client(3); await late.call('ensureProfile');
    await assert.rejects(late.call('placeBet', {roundId: race.roundId, side: 'xiu', amount: 1000, requestId: 'race-late'}));
    await p.call('lockRound', {roundId: race.roundId});
    const raced = await Promise.allSettled([
      boss.call('cancelRound', {roundId: race.roundId, reason: 'Hủy cùng thời điểm'}),
      p.call('advanceRandomRound', {roundId: race.roundId}),
    ]);
    assert.equal(raced.filter(item => item.status === 'fulfilled').length, 1);
    const final = (await db.doc(`rounds/${race.roundId}`).get()).data();
    assert.ok(['cancelled', 'settled'].includes(final.status));
    const operation = (await db.doc(`users/${p.user.uid}/operations/result_${race.roundId}`).get()).data();
    assert.equal(operation.kind, final.status === 'cancelled' ? 'refund' : 'payout');
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, final.status === 'cancelled' ? 14900 : 15880);
    const otherResult = (await db.doc(`users/${other.user.uid}/operations/result_${race.roundId}`).get()).data();
    assert.equal(otherResult.kind, final.status === 'cancelled' ? 'refund' : 'payout');
    assert.equal(otherResult.delta, final.status === 'cancelled' ? 1000 : 0);
    assert.equal((await db.doc(`users/${other.user.uid}`).get()).data().balance, final.status === 'cancelled' ? 10000 : 9000);
    await boss.call('setPlayerBlocked', {uid: other.user.uid, blocked: true, reason: 'Khóa thử nghiệm'});
    await assert.rejects(other.call('ensureProfile'));
    await boss.call('setPlayerBlocked', {uid: other.user.uid, blocked: false, reason: 'Mở lại thử nghiệm'});
    // Bot accounts can outnumber the old fixed 25-row leaderboard window.
    const seedBots = db.batch();
    for (let i = 0; i < 105; i++) {
      seedBots.set(db.doc(`users/rank_test_bot_${i}`), {balance: 100000 - i, isBot: true});
    }
    await seedBots.commit();
    const ranking = await p.call('getLeaderboard');
    assert.ok(ranking.some((row) => row.nickname === `Bạn ${p.user.uid.slice(0, 6)}`));
    assert.ok(ranking.every((row) => row.balance < 100000));
  } finally { await Promise.all(apps.map(deleteApp)); }
});

test('callable player management: point adjustment, account lock and audit', async () => {
  const app = adminApp({projectId}, `player-management-${Date.now()}`);
  const db = getFirestore(app);
  const apps = [];
  async function client(label) {
    const a = initializeApp({projectId, apiKey: 'demo-key', appId: 'demo'}, `players-${label}-${Date.now()}`);
    apps.push(a);
    const auth = getAuth(a);
    connectAuthEmulator(auth, `http://127.0.0.1:${authPort}`, {disableWarnings: true});
    const functions = getFunctions(a, 'asia-southeast1');
    connectFunctionsEmulator(functions, '127.0.0.1', functionsPort);
    const {user} = await createUserWithEmailAndPassword(auth, `player-${label}-${Date.now()}@example.com`, 'password123');
    return {user, call: async (name, data = {}) => (await httpsCallable(functions, name)(data)).data};
  }
  try {
    const admin = await client('admin');
    await adminAuth(app).setCustomUserClaims(admin.user.uid, {admin: true});
    await admin.user.getIdToken(true);
    await admin.call('ensureProfile');
    const player = await client('target');
    await player.call('ensureProfile');
    const target = db.doc(`users/${player.user.uid}`);
    const initial = (await target.get()).data().balance;

    const positive = {uid: player.user.uid, delta: 1000, reason: 'Bù lỗi phiên test', requestId: 'player-adjust-positive'};
    const first = await admin.call('adjustBalance', positive);
    const retry = await admin.call('adjustBalance', positive);
    assert.equal(first.balance, initial + 1000);
    assert.equal(retry.balance, initial + 1000);
    await assert.rejects(admin.call('adjustBalance', {...positive, delta: 900}));

    const negative = await admin.call('adjustBalance', {
      uid: player.user.uid, delta: -500, reason: 'Thu hồi điểm test', requestId: 'player-adjust-negative',
    });
    assert.equal(negative.balance, initial + 500);
    await assert.rejects(admin.call('adjustBalance', {
      uid: player.user.uid, delta: 100001, reason: 'Vượt hạn mức backend', requestId: 'player-adjust-too-large',
    }));
    assert.equal((await target.get()).data().balance, initial + 500);

    await assert.rejects(admin.call('setPlayerBlocked', {
      uid: admin.user.uid, blocked: true, reason: 'Tự khóa thử nghiệm',
    }));
    await admin.call('setPlayerBlocked', {
      uid: player.user.uid, blocked: true, reason: 'Tạm khóa kiểm thử',
    });
    assert.equal((await target.get()).data().blocked, true);
    await assert.rejects(player.call('ensureProfile'));
    await admin.call('setPlayerBlocked', {
      uid: player.user.uid, blocked: false, reason: 'Mở khóa kiểm thử',
    });
    assert.equal((await target.get()).data().blocked, false);
    await player.call('ensureProfile');

    const events = await db.collection('auditLogs').where('details.uid', '==', player.user.uid).get();
    assert.ok(events.docs.some((doc) => doc.data().action === 'ADJUST_BALANCE'));
    assert.ok(events.docs.some((doc) => doc.data().action === 'BLOCK_PLAYER'));
    assert.ok(events.docs.some((doc) => doc.data().action === 'UNBLOCK_PLAYER'));
  } finally {
    await Promise.all(apps.map(deleteApp));
  }
});

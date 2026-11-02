const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const {doc, setDoc, getDoc, collection, getDocs, query, where, orderBy, limit} = require('firebase/firestore');
const {initializeApp: adminApp} = require('firebase-admin/app');
const {getAuth: adminAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const projectId = 'demo-tai-xiu';

test('rules: không ghi client, ví/bài riêng, audit chỉ admin', async () => {
  const env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
  try {
    await env.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'users/alice'), {balance: 100});
      await setDoc(doc(c.firestore(), 'users/locked'), {balance: 100, blocked: true});
      await setDoc(doc(c.firestore(), 'rounds/rule-test'), {status: 'open'});
      await setDoc(doc(c.firestore(), 'rounds/settled-test'), {game: 'tai_xiu', status: 'settled', settledAt: new Date(), result: [6, 6, 6], outcome: {side: 'tai', total: 18}});
      await setDoc(doc(c.firestore(), 'rounds/rule-test/bets/alice'), {amount: 10});
      await setDoc(doc(c.firestore(), 'auditLogs/test'), {action: 'TEST'});
      await setDoc(doc(c.firestore(), 'cardTables/card-test'), {game: 'poker', status: 'playing'});
      await setDoc(doc(c.firestore(), 'cardTables/card-test/hands/alice'), {cards: ['AS', 'AH']});
      await setDoc(doc(c.firestore(), 'cardSecrets/card-test'), {state: {hands: {alice: ['AS', 'AH']}}});
      await setDoc(doc(c.firestore(), 'cardBotPool/global'), {uids: ['private-bot-id']});
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const anon = env.unauthenticatedContext().firestore();
    const admin = env.authenticatedContext('boss', {admin: true}).firestore();
    await assertSucceeds(getDoc(doc(alice, 'users/alice')));
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertSucceeds(getDoc(doc(admin, 'users/alice')));
    await assertFails(setDoc(doc(alice, 'users/alice'), {balance: 999999}));
    await assertFails(setDoc(doc(admin, 'auditLogs/test'), {action: 'EDIT'}));
    await assertFails(getDoc(doc(alice, 'auditLogs/test')));
    await assertSucceeds(getDoc(doc(admin, 'auditLogs/test')));
    await assertFails(getDoc(doc(anon, 'auditLogs/test')));
    await assertFails(getDoc(doc(bob, 'rounds/rule-test/bets/alice')));
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
    const auth = getAuth(a); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
    const f = getFunctions(a, 'asia-southeast1'); connectFunctionsEmulator(f, '127.0.0.1', 5001);
    const {user} = await createUserWithEmailAndPassword(auth, `test${i}-${Date.now()}@example.com`, 'password123');
    return {user, call: async (name, data = {}) => (await httpsCallable(f, name)(data)).data};
  }
  try {
    const boss = await client(0); await adminAuth(app).setCustomUserClaims(boss.user.uid, {admin: true}); await boss.user.getIdToken(true); await boss.call('ensureProfile');
    const p = await client(1); await p.call('ensureProfile');
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 10000);
    await assert.rejects(p.call('startRound', {game: 'tai_xiu', mode: 'admin'}));
    await assert.rejects(p.call('adjustBalance', {uid: p.user.uid, delta: 100, reason: 'Không có quyền', requestId: 'no-rights-001'}));
    await assert.rejects(p.call('wallet', {kind: 'deposit', amount: 100}));
    for (const [game, side, result, credit] of [
      ['tai_xiu', 'tai', [2, 3, 6], 1980],
      ['bau_cua', 'cua', ['cua', 'cua', 'bau'], 4940],
      ['xoc_xoc', 'chan', [0, 1, 0, 1], 1980],
    ]) {
      const {roundId} = await boss.call('startRound', {game, mode: 'admin'});
      await assert.rejects(boss.call('startRound', {game, mode: 'random'}));
      await p.call('placeBet', {roundId, side, amount: 1000, requestId: `first-${game}`});
      await p.call('placeBet', {roundId, side, amount: 1000, requestId: `first-${game}`});
      await assert.rejects(p.call('placeBet', {roundId, side, amount: 10000, requestId: `first-${game}`}));
      if (game === 'bau_cua') await p.call('placeBet', {roundId, side: 'bau', amount: 1000, requestId: 'second-bau'});
      await assert.rejects(boss.call('settleRound', {roundId, result, reason: 'Bài kiểm thử'}));
      await db.doc(`rounds/${roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
      await assert.rejects(p.call('lockRound', {roundId}));
      await boss.call('lockRound', {roundId}); await boss.call('lockRound', {roundId});
      await assert.rejects(p.call('settleRound', {roundId, result, reason: 'Không có quyền'}));
      await assert.rejects(boss.call('settleRound', {roundId, result: [9, 9, 9], reason: 'Không hợp lệ'}));
      await Promise.all([1, 2].map(() => boss.call('settleRound', {roundId, result, reason: 'Bài kiểm thử'})));
      const round = (await db.doc(`rounds/${roundId}`).get()).data();
      assert.equal(round.status, 'settled'); assert.equal(round.reason, undefined);
      assert.equal((await db.doc(`rounds/${roundId}/bets/${p.user.uid}`).get()).data().credit, credit);
      assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${roundId}`).get()).data().delta, credit);
      await assert.rejects(boss.call('cancelRound', {roundId, reason: 'Không hủy đã chốt'}));
    }
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 14900);
    const {roundId: cancelled} = await boss.call('startRound', {game: 'tai_xiu', mode: 'admin'});
    await p.call('placeBet', {roundId: cancelled, side: 'xiu', amount: 1000, requestId: 'cancel-first'});
    await db.doc(`rounds/${cancelled}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
    await boss.call('lockRound', {roundId: cancelled});
    const beforeRefund = (await db.doc(`users/${p.user.uid}`).get()).data().balance;
    await db.doc(`users/${p.user.uid}`).update({balance: Number.MAX_SAFE_INTEGER});
    await assert.rejects(boss.call('cancelRound', {roundId: cancelled, reason: 'Không thể hoàn điểm tràn số'}));
    assert.equal((await db.doc(`rounds/${cancelled}`).get()).data().status, 'locked');
    assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${cancelled}`).get()).exists, false);
    await db.doc(`users/${p.user.uid}`).update({balance: beforeRefund});
    await Promise.all([1, 2].map(() => boss.call('cancelRound', {roundId: cancelled, reason: 'Hủy phiên thử nghiệm'})));
    assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance, 14900);
    assert.equal((await db.doc(`users/${p.user.uid}/operations/result_${cancelled}`).get()).data().kind, 'refund');
    await assert.rejects(boss.call('settleRound', {roundId: cancelled, result: [2, 3, 6], reason: 'Không chốt đã hủy'}));
    const random = await boss.call('startRound', {game: 'bau_cua', mode: 'random'});
    await db.doc(`rounds/${random.roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
    await boss.call('lockRound', {roundId: random.roundId});
    await boss.call('settleRound', {roundId: random.roundId});
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
    await db.doc(`rounds/${race.roundId}`).update({closesAt: Timestamp.fromMillis(Date.now() - 1000)});
    const late = await client(3); await late.call('ensureProfile');
    await assert.rejects(late.call('placeBet', {roundId: race.roundId, side: 'xiu', amount: 1000, requestId: 'race-late'}));
    await boss.call('lockRound', {roundId: race.roundId});
    const raced = await Promise.allSettled([
      boss.call('cancelRound', {roundId: race.roundId, reason: 'Hủy cùng thời điểm'}),
      boss.call('settleRound', {roundId: race.roundId, result: [2, 3, 6], reason: 'Chốt cùng thời điểm'}),
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

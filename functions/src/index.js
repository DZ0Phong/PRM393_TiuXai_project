'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const games = require('./round_games');
initializeApp();
const db = getFirestore();
const now = () => Timestamp.now();
const fail = (message) => { throw new HttpsError('failed-precondition', message); };
const validId = (id) => typeof id === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(id);
const id = (value) => { if (!validId(value)) throw new HttpsError('invalid-argument', 'ID không hợp lệ'); return value; };
const reason = (value) => { if (typeof value !== 'string' || value.trim().length < 5 || value.length > 300) throw new HttpsError('invalid-argument', 'Lý do phải có 5–300 ký tự'); return value.trim(); };
const audit = (tx, actor, action, details) => tx.create(db.collection('auditLogs').doc(), {actor, action, details, at: now()});
const admin = (req) => { if (req.auth.token.admin !== true) throw new HttpsError('permission-denied', 'Chỉ quản trị viên'); };
const call = (fn) => onCall({region: 'asia-southeast1', maxInstances: 10}, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Đăng nhập trước');
  const profile = await db.doc(`users/${req.auth.uid}`).get();
  if (profile.data()?.blocked === true) throw new HttpsError('permission-denied', 'Tài khoản đã bị khóa');
  return fn(req);
});
const active = (snapshot) => {
  if (!snapshot.exists) fail('Chưa tạo hồ sơ');
  if (snapshot.data().blocked === true) throw new HttpsError('permission-denied', 'Tài khoản đã bị khóa');
};
const allowedGame = (value) => {
  if (!['tai_xiu', 'bau_cua', 'xoc_xoc'].includes(value)) throw new HttpsError('invalid-argument', 'Trò chơi không hợp lệ');
  return value;
};

// Public ranking exposes only a pseudonym and simulated balance, never email or private profile.
exports.getLeaderboard = call(async () => {
  // Bot wallets may accumulate across tables. Page past them instead of assuming
  // that the first 25 wallet rows contain 20 human players.
  const people = [];
  let cursor = null;
  for (let page = 0; page < 20 && people.length < 20; page++) {
    let query = db.collection('users').orderBy('balance', 'desc').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    people.push(...snapshot.docs.filter((doc) => doc.data().isBot !== true && doc.data().preferences?.hideLeaderboard !== true));
    if (snapshot.size < 100) break;
    cursor = snapshot.docs.at(-1);
  }
  return people.slice(0, 20).map((doc, i) => ({
    rank: i + 1, nickname: `Bạn ${doc.id.slice(0, 6)}`,
    balance: doc.data().balance,
  }));
});

exports.ensureProfile = call(async (req) => {
  const ref = db.doc(`users/${req.auth.uid}`);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.create(ref, {balance: 10000, blocked: false, createdAt: now()});
    tx.create(ref.collection('operations').doc('welcome'), {kind: 'welcome', delta: 10000, balance: 10000, at: now()});
    audit(tx, req.auth.uid, 'WELCOME', {amount: 10000});
  });
  return {ok: true};
});

// Update the signed-in user's email immediately; the new address remains unverified.
exports.updateMyEmail = call(async (req) => {
  const email = typeof req.data?.email === 'string' ? req.data.email.trim() : '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new HttpsError('invalid-argument', 'Địa chỉ email không hợp lệ');
  }
  try {
    await getAuth().updateUser(req.auth.uid, {email, emailVerified: false});
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'Email này đã được tài khoản khác sử dụng');
    }
    if (error.code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Địa chỉ email không hợp lệ');
    }
    throw error;
  }
  return {ok: true, email};
});

// Profile changes are server-validated because client writes to users/{uid} are denied by Firestore rules.
exports.updateMyProfile = call(async (req) => {
  const input = req.data || {};
  if (typeof input !== 'object' || Array.isArray(input)) throw new HttpsError('invalid-argument', 'Hồ sơ không hợp lệ');
  const allowed = new Set(['nickname', 'bio', 'birthday', 'gender', 'avatarFrame']);
  if (Object.keys(input).some((key) => !allowed.has(key))) throw new HttpsError('invalid-argument', 'Có trường hồ sơ không được hỗ trợ');
  const updates = {};
  if ('nickname' in input) {
    if (typeof input.nickname !== 'string' || input.nickname.trim().length < 2 || input.nickname.trim().length > 24) throw new HttpsError('invalid-argument', 'Biệt danh cần từ 2 đến 24 ký tự');
    updates.nickname = input.nickname.trim();
  }
  if ('bio' in input) {
    if (typeof input.bio !== 'string' || input.bio.trim().length > 60) throw new HttpsError('invalid-argument', 'Giới thiệu tối đa 60 ký tự');
    updates.bio = input.bio.trim();
  }
  if ('birthday' in input) {
    if (input.birthday !== null) {
      if (typeof input.birthday !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.birthday)) throw new HttpsError('invalid-argument', 'Ngày sinh không hợp lệ');
      const date = new Date(`${input.birthday}T00:00:00Z`);
      if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== input.birthday || date.getTime() > Date.now()) {
        throw new HttpsError('invalid-argument', 'Ngày sinh không hợp lệ');
      }
    }
    updates.birthday = input.birthday;
  }
  if ('gender' in input) {
    if (!['male', 'female', 'other'].includes(input.gender)) throw new HttpsError('invalid-argument', 'Tuỳ chọn giới tính không hợp lệ');
    updates.gender = input.gender;
  }
  if ('avatarFrame' in input) {
    if (!['dragon', 'phoenix', 'wealth'].includes(input.avatarFrame)) throw new HttpsError('invalid-argument', 'Khung đại diện không hợp lệ');
    updates.avatarFrame = input.avatarFrame;
  }
  if (Object.keys(updates).length === 0) throw new HttpsError('invalid-argument', 'Không có thông tin cần lưu');
  const ref = db.doc(`users/${req.auth.uid}`);
  await db.runTransaction(async (tx) => {
    const user = await tx.get(ref);
    active(user);
    tx.update(ref, {...updates, profileUpdatedAt: now()});
    audit(tx, req.auth.uid, 'PROFILE_UPDATE', {fields: Object.keys(updates)});
  });
  return {ok: true, profile: updates};
});

// The phone number comes from the Firebase Auth token only; callers cannot claim a verified number.
exports.syncVerifiedPhoneNumber = call(async (req) => {
  const phoneNumber = req.auth.token.phone_number;
  if (typeof phoneNumber !== 'string' || !/^\+[1-9]\d{7,14}$/.test(phoneNumber)) {
    throw new HttpsError('failed-precondition', 'Tài khoản chưa xác minh số điện thoại');
  }
  const ref = db.doc(`users/${req.auth.uid}`);
  await db.runTransaction(async (tx) => {
    const user = await tx.get(ref);
    active(user);
    tx.update(ref, {phone: phoneNumber, verifiedPhoneNumber: phoneNumber, phoneVerifiedAt: now()});
    audit(tx, req.auth.uid, 'PHONE_VERIFIED', {method: 'firebase_phone_auth'});
  });
  return {ok: true, phoneNumber};
});

// Only preferences that have a real effect in the app are accepted here.
exports.updateMyPrivacyPreferences = call(async (req) => {
  const input = req.data?.preferences;
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new HttpsError('invalid-argument', 'Tuỳ chọn không hợp lệ');
  const allowed = new Set(['hideBalance', 'hideLeaderboard']);
  const entries = Object.entries(input);
  if (entries.length === 0 || entries.some(([key, value]) => !allowed.has(key) || typeof value !== 'boolean')) throw new HttpsError('invalid-argument', 'Tuỳ chọn không được hỗ trợ');
  const ref = db.doc(`users/${req.auth.uid}`);
  let preferences;
  await db.runTransaction(async (tx) => {
    const user = await tx.get(ref);
    active(user);
    preferences = {...(user.data().preferences || {}), ...Object.fromEntries(entries)};
    tx.update(ref, {preferences, preferencesUpdatedAt: now()});
    audit(tx, req.auth.uid, 'PRIVACY_PREFERENCES_UPDATE', {fields: entries.map(([key]) => key)});
  });
  return {ok: true, preferences};
});

exports.startRound = call(async (req) => {
  admin(req);
  const game = allowedGame(req.data?.game), mode = req.data?.mode;
  if (!['random', 'admin'].includes(mode)) throw new HttpsError('invalid-argument', 'Chế độ không hợp lệ');
  const room = db.doc(`rooms/${game}`), ref = db.collection('rounds').doc();
  await db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(room);
    const previous = roomSnap.exists && validId(roomSnap.data().roundId) ? await tx.get(db.doc(`rounds/${roomSnap.data().roundId}`)) : null;
    if (previous?.exists && !['settled', 'cancelled'].includes(previous.data().status)) fail('Phiên trước chưa kết thúc');
    tx.create(ref, {game, mode, status: 'open', closesAt: Timestamp.fromMillis(Date.now() + 30000), createdAt: now(), betCount: 0});
    tx.set(room, {roundId: ref.id, game});
    audit(tx, req.auth.uid, 'START', {roundId: ref.id, game, mode});
  });
  return {roundId: ref.id};
});

exports.placeBet = call(async (req) => {
  const roundId = id(req.data?.roundId), requestId = id(req.data?.requestId), {side, amount} = req.data || {};
  const ref = db.doc(`rounds/${roundId}`), user = db.doc(`users/${req.auth.uid}`), bet = ref.collection('bets').doc(req.auth.uid);
  const op = user.collection('operations').doc(`bet_${roundId}_${requestId}`);
  return db.runTransaction(async (tx) => {
    const [r, u, b, existing] = await Promise.all([tx.get(ref), tx.get(user), tx.get(bet), tx.get(op)]);
    active(u);
    if (!r.exists) fail('Không có phiên');
    const game = r.data().game;
    if (!games.validateBet(game, side, amount)) throw new HttpsError('invalid-argument', 'Cược không hợp lệ');
    if (existing.exists) {
      const old = existing.data();
      if (old.side !== side || old.stake !== amount) throw new HttpsError('already-exists', 'requestId đã dùng với cược khác');
      return b.data();
    }
    if (r.data().status !== 'open' || r.data().closesAt.toMillis() <= Date.now()) fail('Đã khóa cược');
    if (u.data().balance < amount) fail('Không đủ điểm');
    if (!b.exists && r.data().betCount >= 100) fail('Phòng tối đa 100 người/phiên');
    const old = b.exists ? b.data() : null;
    if (old && (!old.stakes || !Number.isSafeInteger(old.amount))) fail('Dữ liệu cược cũ không tương thích');
    if (game === 'tai_xiu' && old && old.side !== side) fail('Tài Xỉu chỉ được cược cùng một cửa');
    const total = (old?.amount || 0) + amount;
    if (!Number.isSafeInteger(total) || total > 1000000) fail('Tổng cược mỗi người tối đa 1000000');
    const balance = u.data().balance - amount;
    const data = {uid: req.auth.uid, side: game === 'tai_xiu' ? side : null, amount: total,
      stakes: {...(old?.stakes || {}), [side]: (old?.stakes?.[side] || 0) + amount},
      at: old?.at || now(), lastAt: now()};
    tx.update(user, {balance});
    if (b.exists) tx.update(bet, data); else tx.create(bet, data);
    tx.create(op, {kind: 'bet', game, roundId, side, stake: amount, delta: -amount, balance, at: now()});
    if (!b.exists) tx.update(ref, {betCount: r.data().betCount + 1});
    audit(tx, req.auth.uid, 'BET', {game, roundId, requestId, side, amount});
    return data;
  });
});

async function lock(roundId, actor) {
  const ref = db.doc(`rounds/${roundId}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail('Không có phiên');
    if (snap.data().status !== 'open') return {status: snap.data().status};
    if (snap.data().closesAt.toMillis() > Date.now()) fail('Chưa hết hạn cược');
    tx.update(ref, {status: 'locked', lockedAt: now()});
    audit(tx, actor, 'LOCK', {roundId});
    return {status: 'locked'};
  });
}
exports.lockRound = call(async (req) => { admin(req); return lock(id(req.data?.roundId), req.auth.uid); });

async function settle(roundId, actor, suppliedResult, suppliedReason) {
  const ref = db.doc(`rounds/${roundId}`);
  return db.runTransaction(async (tx) => {
    const r = await tx.get(ref);
    if (!r.exists) fail('Không có phiên');
    const data = r.data();
    if (data.status === 'settled') return {ok: true, alreadySettled: true};
    if (data.status !== 'locked') fail('Phiên chưa khóa hoặc đã hủy');
    if (data.mode === 'admin' && actor === 'scheduler') return {waiting: true};
    const result = data.mode === 'admin' ? suppliedResult : games.randomOutcome(data.game);
    if (!games.validateOutcome(data.game, result)) throw new HttpsError('invalid-argument', 'Kết quả không hợp lệ');
    const auditReason = data.mode === 'admin' ? reason(suppliedReason) : 'Server CSPRNG';
    const bets = await tx.get(ref.collection('bets'));
    const users = await Promise.all(bets.docs.map((b) => tx.get(db.doc(`users/${b.id}`))));
    const credits = games.creditsForRound(data.game, bets.docs.map((b) => ({
      uid: b.id, ...b.data(), atMillis: b.data().at?.toMillis() || 0,
    })), result);
    bets.docs.forEach((b, i) => {
      const {credit, refund} = credits[i];
      const balance = users[i].data().balance + credit;
      if (!Number.isSafeInteger(balance)) fail('Số dư vượt giới hạn');
      tx.update(users[i].ref, {balance});
      tx.update(b.ref, {credit, refund, settledAt: now()});
      tx.create(users[i].ref.collection('operations').doc(`result_${roundId}`), {kind: 'payout', game: data.game, roundId, delta: credit, refund, balance, at: now()});
    });
    tx.update(ref, {status: 'settled', result, outcome: games.describeOutcome(data.game, result), settledAt: now()});
    audit(tx, actor, 'SETTLE', {game: data.game, roundId, mode: data.mode, result, reason: auditReason, credits});
    return {ok: true};
  });
}
exports.settleRound = call(async (req) => {
  admin(req);
  const roundId = id(req.data?.roundId);
  return settle(roundId, req.auth.uid, req.data?.result, req.data?.reason);
});
exports.cancelRound = call(async (req) => {
  admin(req);
  const roundId = id(req.data?.roundId), why = reason(req.data?.reason), ref = db.doc(`rounds/${roundId}`);
  return db.runTransaction(async (tx) => {
    const r = await tx.get(ref);
    if (!r.exists) fail('Không có phiên');
    if (r.data().status === 'cancelled') return {ok: true, alreadyCancelled: true};
    if (!['open', 'locked'].includes(r.data().status)) fail('Không thể hủy phiên đã chốt');
    const bets = await tx.get(ref.collection('bets'));
    const users = await Promise.all(bets.docs.map((b) => tx.get(db.doc(`users/${b.id}`))));
    bets.docs.forEach((b, i) => {
      const credit = b.data().amount, balance = users[i].data().balance + credit;
      if (!Number.isSafeInteger(balance)) fail('Số dư vượt giới hạn');
      tx.update(users[i].ref, {balance});
      tx.update(b.ref, {credit, refunded: true, settledAt: now()});
      tx.create(users[i].ref.collection('operations').doc(`result_${roundId}`), {kind: 'refund', roundId, delta: credit, balance, at: now()});
    });
    tx.update(ref, {status: 'cancelled', cancelledAt: now()});
    audit(tx, req.auth.uid, 'CANCEL', {roundId, reason: why, refundedPlayers: bets.size});
    return {ok: true};
  });
});

exports.adjustBalance = call(async (req) => {
  admin(req);
  const uid = id(req.data?.uid), requestId = id(req.data?.requestId), why = reason(req.data?.reason), delta = req.data?.delta;
  if (!Number.isSafeInteger(delta) || delta === 0 || Math.abs(delta) > 100000) throw new HttpsError('invalid-argument', 'Điều chỉnh ±1–100000 điểm');
  const ref = db.doc(`users/${uid}`), op = ref.collection('operations').doc(`admin_${requestId}`);
  return db.runTransaction(async (tx) => {
    const [u, o] = await Promise.all([tx.get(ref), tx.get(op)]);
    if (!u.exists) fail('Không có tài khoản');
    if (o.exists) {
      if (o.data().delta !== delta || o.data().reason !== why || o.data().actor !== req.auth.uid) throw new HttpsError('already-exists', 'requestId đã dùng');
      return o.data();
    }
    const balance = u.data().balance + delta;
    if (balance < 0 || balance > 1000000) fail('Số dư phải từ 0 đến 1000000');
    const data = {kind: 'admin_adjust', delta, balance, reason: why, actor: req.auth.uid, at: now()};
    tx.update(ref, {balance});
    tx.create(op, data);
    audit(tx, req.auth.uid, 'ADJUST_BALANCE', {uid, ...data});
    return data;
  });
});
exports.setPlayerBlocked = call(async (req) => {
  admin(req);
  const uid = id(req.data?.uid), why = reason(req.data?.reason), blocked = req.data?.blocked;
  if (typeof blocked !== 'boolean') throw new HttpsError('invalid-argument', 'Trạng thái không hợp lệ');
  if (uid === req.auth.uid) fail('Không tự khóa quản trị viên');
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const u = await tx.get(ref);
    if (!u.exists) fail('Không có tài khoản');
    if ((u.data().blocked === true) === blocked) return;
    tx.update(ref, {blocked, blockReason: why, blockedBy: req.auth.uid, blockUpdatedAt: now()});
    audit(tx, req.auth.uid, blocked ? 'BLOCK_PLAYER' : 'UNBLOCK_PLAYER', {uid, reason: why});
  });
  return {ok: true};
});
exports.tick = onSchedule({schedule: 'every 1 minutes', region: 'asia-southeast1'}, async () => {
  const due = await db.collection('rounds').where('status', '==', 'open').where('closesAt', '<=', now()).get();
  for (const r of due.docs) await lock(r.id, 'scheduler');
  const random = await db.collection('rounds').where('status', '==', 'locked').get();
  for (const r of random.docs) if (r.data().mode === 'random') await settle(r.id, 'scheduler');
});
const cardTables = require('./card_tables').register({db, call, admin});
for (const name of ['createCardTable', 'joinCardTable', 'leaveCardTable', 'configureCardBots', 'getCardBotConfig', 'startCardHand', 'cardAction', 'cancelCardTable']) exports[name] = cardTables[name];
exports.cardTick = onSchedule({schedule: 'every 1 minutes', region: 'asia-southeast1'}, cardTables.tickCardTables);

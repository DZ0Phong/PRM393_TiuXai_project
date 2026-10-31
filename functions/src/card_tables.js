'use strict';
const {Timestamp} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');
const poker = require('./poker_engine');
const baCay = require('./bacay_engine');
const engines = {poker, ba_cay: baCay};
const aliases = ['Mây Xanh', 'Sao Nhỏ', 'Lá Vàng', 'Sóng Biển', 'Nắng Mai'];
const botIds = aliases.map((_, i) => `bot_${String(i + 1).padStart(2, '0')}`);
const now = () => Timestamp.now();
const error = (message) => { throw new HttpsError('failed-precondition', message); };
const ident = (value) => { if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new HttpsError('invalid-argument', 'ID không hợp lệ'); return value; };
const why = (value) => { if (typeof value !== 'string' || value.trim().length < 5 || value.length > 300) throw new HttpsError('invalid-argument', 'Lý do phải có 5–300 ký tự'); return value.trim(); };
const safeGame = (value) => { if (!Object.hasOwn(engines, value)) throw new HttpsError('invalid-argument', 'Trò bài không hợp lệ'); return value; };
const botSeat = (uid, stake) => ({uid, nickname: aliases[botIds.indexOf(uid)], isBot: true, stack: stake * 10});
const humanSeat = (uid, stake) => ({uid, nickname: `Bạn ${uid.slice(0, 6)}`, isBot: false, stack: stake * 10});

function register({db, call, admin}) {
  const tableRef = (tableId) => db.doc(`cardTables/${ident(tableId)}`);
  const audit = (tx, actor, action, details) => tx.create(db.collection('auditLogs').doc(), {actor, action, details, at: now()});
  const walletOp = (tx, uid, opId, delta, balance, kind, tableId) => tx.create(db.doc(`users/${uid}/operations/${opId}`), {kind, tableId, delta, balance, at: now()});
  const assertUser = (snap, amount) => {
    if (!snap.exists || snap.data().blocked === true) error('Tài khoản không hoạt động');
    if (!Number.isSafeInteger(snap.data().balance) || snap.data().balance < amount) error('Không đủ điểm ảo');
  };
  function view(state, seats) {
    const raw = engines[state.game].publicView(state);
    // Explicit whitelist: a future engine field can never publish a deck or private hand.
    const publicSeats = (raw.seats || state.seats).map((s) => {
      const original = seats.find((seat) => seat.uid === s.uid);
      return {uid: s.uid, nickname: original.nickname, isBot: original.isBot, stack: s.stack, committed: s.committed || 0, roundBet: s.roundBet || 0, folded: s.folded === true};
    });
    const winners = (raw.winners || []).map((uid) => ({uid, nickname: seats.find((seat) => seat.uid === uid)?.nickname || uid}));
    return {seats: publicSeats, board: raw.board || [], pot: raw.pot ?? state.pot, street: raw.street || state.street || 'showdown', turnUid: raw.turnUid || null, winners, status: state.phase === 'settled' ? 'settled' : 'playing', turnDeadline: state.phase === 'settled' ? null : Timestamp.fromMillis(Date.now() + 45000)};
  }
  function botActions(state, seats, stake) {
    let steps = 0;
    while (state.phase !== 'settled' && botIds.includes(state.turnUid)) {
      if (++steps > 100) error('Vòng bot vượt giới hạn');
      const action = poker.chooseBotAction(state, state.turnUid);
      state = poker.act(state, state.turnUid, action, stake);
      if (state.phase === 'showdown') state = poker.settle(state);
    }
    return state;
  }
  function writeSettlement(tx, tableId, state, walletSnaps) {
    const stakeSum = state.seats.reduce((total, s) => total + s.stack, 0);
    const buyInSum = state.seats.length * state.stake * 10;
    if (stakeSum !== buyInSum) error('Bảo toàn điểm thất bại');
    for (const seat of state.seats) {
      const snap = walletSnaps.get(seat.uid);
      if (!snap?.exists) error('Ví người chơi không còn');
      const balance = snap.data().balance + seat.stack;
      if (!Number.isSafeInteger(balance)) error('Số dư vượt giới hạn');
      tx.update(snap.ref, {balance});
      walletOp(tx, seat.uid, `table_result_${tableId}`, seat.stack, balance, 'table_result', tableId);
    }
  }
  return {
    createCardTable: call(async (req) => {
      const game = safeGame(req.data?.game), stake = req.data?.stake, maxSeats = req.data?.maxSeats;
      if (!Number.isSafeInteger(stake) || stake < 10 || stake > 100 || !Number.isSafeInteger(maxSeats) || maxSeats < 2 || maxSeats > 6) throw new HttpsError('invalid-argument', 'Cược 10–100, 2–6 ghế');
      const uid = req.auth.uid, requestId = ident(req.data?.requestId);
      if (requestId.length < 8 || requestId.length > 80) throw new HttpsError('invalid-argument', 'requestId phải 8–80 ký tự');
      const ref = db.doc(`cardTables/${uid}_${requestId}`), user = db.doc(`users/${uid}`), buyIn = stake * 10;
      await db.runTransaction(async (tx) => {
        const [previous, snap] = await Promise.all([tx.get(ref), tx.get(user)]);
        if (previous.exists) {
          if (previous.data().ownerUid !== uid || previous.data().game !== game || previous.data().stake !== stake || previous.data().maxSeats !== maxSeats) throw new HttpsError('already-exists', 'requestId đã dùng cho bàn khác');
          return;
        }
        assertUser(snap, buyIn);
        const balance = snap.data().balance - buyIn;
        tx.update(user, {balance}); walletOp(tx, uid, `table_join_${ref.id}`, -buyIn, balance, 'table_join', ref.id);
        tx.create(ref, {game, stake, maxSeats, ownerUid: uid, status: 'waiting', actionVersion: 0, seats: [humanSeat(uid, stake)], botsEnabled: false, maxBots: 0, board: [], pot: 0, createdAt: now()});
        audit(tx, uid, 'TABLE_CREATE', {tableId: ref.id, game, stake, buyIn});
      });
      return {tableId: ref.id};
    }),
    joinCardTable: call(async (req) => {
      const ref = tableRef(req.data?.tableId), uid = req.auth.uid, user = db.doc(`users/${uid}`);
      return db.runTransaction(async (tx) => {
        const [table, wallet, refunded] = await Promise.all([tx.get(ref), tx.get(user), tx.get(user.collection('operations').doc(`table_refund_${ref.id}`))]);
        if (!table.exists || table.data().status !== 'waiting') error('Bàn không nhận người chơi');
        if (refunded.exists) error('Đã rời bàn; không thể tham gia lại phiên này');
        const data = table.data(), buyIn = data.stake * 10;
        if (data.seats.some((s) => s.uid === uid)) return {tableId: ref.id, alreadyJoined: true};
        if (data.seats.length >= data.maxSeats) error('Bàn đã đủ ghế');
        assertUser(wallet, buyIn);
        const balance = wallet.data().balance - buyIn;
        tx.update(user, {balance}); walletOp(tx, uid, `table_join_${ref.id}`, -buyIn, balance, 'table_join', ref.id);
        tx.update(ref, {seats: [...data.seats, humanSeat(uid, data.stake)]});
        audit(tx, uid, 'TABLE_JOIN', {tableId: ref.id, buyIn});
        return {tableId: ref.id};
      });
    }),
    leaveCardTable: call(async (req) => {
      const ref = tableRef(req.data?.tableId), uid = req.auth.uid, user = db.doc(`users/${uid}`);
      return db.runTransaction(async (tx) => {
        const [table, wallet] = await Promise.all([tx.get(ref), tx.get(user)]);
        if (!table.exists) error('Không có bàn');
        const data = table.data();
        if (data.status !== 'waiting') error('Đã bắt đầu; dùng hủy bàn để hoàn điểm');
        const index = data.seats.findIndex((s) => s.uid === uid);
        if (index < 0) return {ok: true, alreadyLeft: true};
        const buyIn = data.stake * 10, balance = wallet.data().balance + buyIn;
        tx.update(user, {balance}); walletOp(tx, uid, `table_refund_${ref.id}`, buyIn, balance, 'table_refund', ref.id);
        const seats = data.seats.filter((s) => s.uid !== uid);
        tx.update(ref, {seats, ownerUid: data.ownerUid === uid ? seats[0]?.uid || null : data.ownerUid, status: seats.length ? 'waiting' : 'cancelled'});
        audit(tx, uid, 'TABLE_LEAVE', {tableId: ref.id, buyIn});
        return {ok: true};
      });
    }),
    configureCardBots: call(async (req) => {
      admin(req);
      const ref = tableRef(req.data?.tableId), enabled = req.data?.enabled, maxBots = req.data?.maxBots;
      if (typeof enabled !== 'boolean' || !Number.isSafeInteger(maxBots) || maxBots < 0 || maxBots > 5) throw new HttpsError('invalid-argument', 'Giới hạn bot không hợp lệ');
      await db.runTransaction(async (tx) => {
        const table = await tx.get(ref);
        if (!table.exists || table.data().status !== 'waiting') error('Chỉ chỉnh bot khi bàn chờ');
        tx.update(ref, {botsEnabled: enabled, maxBots: enabled ? maxBots : 0});
        audit(tx, req.auth.uid, 'TABLE_BOT_CONFIG', {tableId: ref.id, enabled, maxBots});
      });
      return {ok: true};
    }),
    startCardHand: call(async (req) => {
      const ref = tableRef(req.data?.tableId), secret = db.doc(`cardSecrets/${ref.id}`), actor = req.auth.uid;
      return db.runTransaction(async (tx) => {
        const table = await tx.get(ref);
        if (!table.exists) error('Không có bàn');
        const data = table.data();
        if (data.ownerUid !== actor && req.auth.token.admin !== true) throw new HttpsError('permission-denied', 'Chỉ chủ bàn hoặc Admin');
        if (['playing', 'settled'].includes(data.status)) return {tableId: ref.id, status: data.status, alreadyStarted: true};
        if (data.status !== 'waiting') error('Bàn không còn chờ');
        const seats = [...data.seats];
        if (data.botsEnabled) {
          const count = Math.min(data.maxBots, data.maxSeats - seats.length);
          for (const botId of botIds.slice(0, count)) seats.push(botSeat(botId, data.stake));
        }
        if (seats.length < 2 || seats.length > data.maxSeats) error('Cần 2–6 người/bot và còn ghế trống');
        const wallets = new Map();
        for (const seat of seats) wallets.set(seat.uid, await tx.get(db.doc(`users/${seat.uid}`)));
        // First-time bot wallets are funded once, then every game uses the same debit/credit ledger as players.
        for (const seat of seats.filter((s) => s.isBot)) {
          const snap = wallets.get(seat.uid);
          if (snap.exists) assertUser(snap, data.stake * 10);
        }
        let state = engines[data.game].start(seats.map(({uid, stack}) => ({uid, stack})), data.stake);
        state.game = data.game; state.stake = data.stake;
        if (data.game === 'ba_cay') state = baCay.settle(state);
        else state = botActions(state, seats, data.stake);
        state.game = data.game; state.stake = data.stake;
        const publicData = view(state, seats);
        if (state.phase === 'settled') {
          if (state.seats.reduce((sum, seat) => sum + seat.stack, 0) !== seats.length * data.stake * 10) error('Bảo toàn điểm thất bại');
          // Balance computation includes a newly provisioned bot's welcome bankroll and escrow debit.
          const botSnaps = new Map(wallets);
          for (const seat of seats.filter((s) => s.isBot && !wallets.get(s.uid).exists)) {
            const refBot = db.doc(`users/${seat.uid}`);
            botSnaps.set(seat.uid, {exists: true, ref: refBot, data: () => ({balance: 10000 - data.stake * 10})});
          }
          for (const seat of state.seats) {
            const snap = botSnaps.get(seat.uid), finalBalance = snap.data().balance + seat.stack - (seat.uid.startsWith('bot_') && wallets.get(seat.uid).exists ? data.stake * 10 : 0);
            if (!Number.isSafeInteger(finalBalance)) error('Số dư vượt giới hạn');
            if (!wallets.get(seat.uid).exists) tx.create(snap.ref, {balance: finalBalance, isBot: true, nickname: aliases[botIds.indexOf(seat.uid)], blocked: false, createdAt: now()});
            else tx.update(snap.ref, {balance: finalBalance});
            walletOp(tx, seat.uid, `table_result_${ref.id}`, seat.stack, finalBalance, 'table_result', ref.id);
          }
        }
        for (const seat of seats.filter((s) => s.isBot)) {
          const snap = wallets.get(seat.uid), buyIn = data.stake * 10;
          if (!snap.exists) {
            if (state.phase !== 'settled') tx.create(snap.ref, {balance: 10000 - buyIn, isBot: true, nickname: aliases[botIds.indexOf(seat.uid)], blocked: false, createdAt: now()});
            walletOp(tx, seat.uid, 'welcome', 10000, 10000, 'welcome', ref.id);
          } else if (state.phase !== 'settled') tx.update(snap.ref, {balance: snap.data().balance - buyIn});
          walletOp(tx, seat.uid, `table_join_${ref.id}`, -buyIn, snap.exists ? snap.data().balance - buyIn : 10000 - buyIn, 'table_join', ref.id);
        }
        tx.create(secret, {state});
        for (const seat of seats) tx.create(ref.collection('hands').doc(seat.uid), {cards: engines[data.game].privateHand(state, seat.uid), tableId: ref.id});
        tx.update(ref, {...publicData, actionVersion: 1, startedAt: now()});
        audit(tx, actor, 'TABLE_START', {tableId: ref.id, game: data.game, players: seats.map((s) => ({uid: s.uid, isBot: s.isBot})), status: publicData.status});
        return {tableId: ref.id, status: publicData.status};
      });
    }),
    cardAction: call(async (req) => {
      const ref = tableRef(req.data?.tableId), secret = db.doc(`cardSecrets/${ref.id}`), uid = req.auth.uid;
      return db.runTransaction(async (tx) => {
        const [table, hidden] = await Promise.all([tx.get(ref), tx.get(secret)]);
        if (!table.exists || table.data().status !== 'playing' || !hidden.exists) error('Bàn chưa chơi hoặc đã kết thúc');
        const data = table.data();
        if (data.game !== 'poker') error('Ba Cây tự lật bài sau khi đủ ghế');
        if (!Number.isSafeInteger(req.data?.version) || req.data.version !== data.actionVersion) error('Lượt đã thay đổi; tải lại bàn');
        if (data.turnDeadline?.toMillis() <= Date.now()) error('Đã hết thời gian lượt');
        if (data.turnUid !== uid || !data.seats.some((s) => s.uid === uid && !s.isBot)) throw new HttpsError('permission-denied', 'Chưa tới lượt của bạn');
        const input = req.data?.type;
        if (!['check', 'bet', 'call', 'raise', 'fold'].includes(input)) throw new HttpsError('invalid-argument', 'Hành động không hợp lệ');
        let state = poker.act(hidden.data().state, uid, {type: input}, data.stake);
        if (state.phase === 'showdown') state = poker.settle(state);
        state = botActions(state, data.seats, data.stake);
        state.game = data.game; state.stake = data.stake;
        let wallets;
        if (state.phase === 'settled') {
          wallets = new Map();
          for (const seat of state.seats) wallets.set(seat.uid, await tx.get(db.doc(`users/${seat.uid}`)));
        }
        const publicData = view(state, data.seats);
        if (state.phase === 'settled') writeSettlement(tx, ref.id, state, wallets);
        tx.update(secret, {state}); tx.update(ref, {...publicData, actionVersion: data.actionVersion + 1});
        audit(tx, uid, 'TABLE_ACTION', {tableId: ref.id, type: input, street: state.street, status: publicData.status});
        return {status: publicData.status};
      });
    }),
    cancelCardTable: call(async (req) => {
      admin(req);
      const ref = tableRef(req.data?.tableId), reason = why(req.data?.reason);
      return db.runTransaction(async (tx) => {
        const table = await tx.get(ref);
        if (!table.exists) error('Không có bàn');
        const data = table.data();
        if (data.status === 'cancelled') return {ok: true, alreadyCancelled: true};
        if (data.status === 'settled') error('Không thể hủy đã chốt');
        const wallets = await Promise.all(data.seats.map((seat) => tx.get(db.doc(`users/${seat.uid}`))));
        data.seats.forEach((seat, i) => {
          const buyIn = data.stake * 10, balance = wallets[i].data().balance + buyIn;
          tx.update(wallets[i].ref, {balance});
          walletOp(tx, seat.uid, `table_refund_${ref.id}`, buyIn, balance, 'table_refund', ref.id);
        });
        tx.update(ref, {status: 'cancelled', cancelledAt: now(), turnUid: null});
        audit(tx, req.auth.uid, 'TABLE_CANCEL', {tableId: ref.id, reason, refundedPlayers: data.seats.length});
        return {ok: true};
      });
    }),
    // Scheduler invokes this without a player identity. It uses the same engine action validation.
    tickCardTables: async () => {
      const playing = await db.collection('cardTables').where('status', '==', 'playing').where('turnDeadline', '<=', now()).limit(50).get();
      for (const table of playing.docs) {
        if (table.data().turnDeadline?.toMillis() > Date.now()) continue;
        const secret = db.doc(`cardSecrets/${table.id}`);
        await db.runTransaction(async (tx) => {
          const [fresh, hidden] = await Promise.all([tx.get(table.ref), tx.get(secret)]);
          if (!fresh.exists || fresh.data().status !== 'playing' || fresh.data().turnDeadline?.toMillis() > Date.now()) return;
          let state = hidden.data().state;
          if (botIds.includes(state.turnUid)) state = botActions(state, fresh.data().seats, fresh.data().stake);
          else {
            const type = poker.canCheck(state, state.turnUid) ? 'check' : 'fold';
            state = poker.act(state, state.turnUid, {type}, fresh.data().stake);
            if (state.phase === 'showdown') state = poker.settle(state);
            state = botActions(state, fresh.data().seats, fresh.data().stake);
          }
          state.game = fresh.data().game; state.stake = fresh.data().stake;
          let wallets;
          if (state.phase === 'settled') {
            wallets = new Map();
            for (const seat of state.seats) wallets.set(seat.uid, await tx.get(db.doc(`users/${seat.uid}`)));
          }
          const publicData = view(state, fresh.data().seats);
          if (state.phase === 'settled') writeSettlement(tx, table.id, state, wallets);
          tx.update(secret, {state}); tx.update(table.ref, {...publicData, actionVersion: fresh.data().actionVersion + 1});
          audit(tx, 'scheduler', 'TABLE_TIMEOUT', {tableId: table.id, status: publicData.status});
        });
      }
    },
  };
}
module.exports = {register};

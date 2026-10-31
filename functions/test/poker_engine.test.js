'use strict';

const {test} = require('node:test');
const assert = require('node:assert/strict');
const {newDeck} = require('../src/card_games');
const {start, act, settle, canCheck, publicView, privateHand, chooseBotAction} = require('../src/poker_engine');

const seats = (count, stack = 100) => Array.from({length: count}, (_, i) => ({uid: `p${i}`, stack}));
const play = (state, type) => act(state, state.turnUid, {type}, state.stake);
const orderedDeck = cards => [...cards, ...newDeck().filter(card => !cards.includes(card))];
const total = state => state.pot + state.seats.reduce((sum, seat) => sum + seat.stack, 0);

function checkToEnd(state) {
  while (state.phase === 'playing') state = play(state, state.roundBet >
    state.seats.find(seat => seat.uid === state.turnUid).committed ? 'call' : 'check');
  return state;
}

test('2–6 seats: JSON state, complete unique cards, private/public separation and conservation', () => {
  for (let count = 2; count <= 6; count++) {
    const s = start(seats(count), 10, newDeck());
    assert.equal(s.turnUid, 'p0');
    assert.equal(s.street, 'preflop');
    assert.equal(s.phase, 'playing');
    assert.equal(s.pot, count * 10);
    assert.equal(total(s), count * 100);
    const dealt = [...Object.values(s.hands).flat(), ...s.board, ...s.deck];
    assert.equal(dealt.length, 52);
    assert.equal(new Set(dealt).size, 52);
    assert.equal(s.deck.length, 52 - count * 2 - 5);
    assert.deepEqual(JSON.parse(JSON.stringify(s)), s);
    assert.deepEqual(privateHand(s, 'p0'), s.hands.p0);
    const view = publicView(s);
    assert.deepEqual(Object.keys(view), ['seats', 'turnUid', 'street', 'board', 'pot', 'winners', 'status']);
    assert.deepEqual(view.board, []);
    assert.equal(view.status, 'playing');
    assert.ok(!JSON.stringify(view).includes('hands'));
    assert.ok(!JSON.stringify(view).includes('deck'));
    assert.ok(!JSON.stringify(view).includes(s.hands.p0[0]));
    const done = checkToEnd(s);
    assert.equal(done.phase, 'settled');
    assert.equal(total(done), count * 100);
    assert.deepEqual(publicView(done).board, done.board);
    assert.strictEqual(settle(done), done);
  }
});

test('fixed betting, turn enforcement, immutable input and street reveal', () => {
  const original = start(seats(2), 10, newDeck());
  assert.throws(() => settle(original), /complete/);
  assert.equal(canCheck(original, 'p0'), true);
  assert.equal(canCheck(original, 'p1'), false);
  assert.throws(() => act(original, 'p1', {type: 'check'}, 10));
  const bet = play(original, 'bet');
  assert.equal(original.seats[0].stack, 90);
  assert.equal(bet.seats[0].stack, 80);
  assert.equal(bet.roundBet, 10);
  assert.equal(bet.seats[0].roundBet, 10);
  assert.equal(bet.turnUid, 'p1');
  assert.equal(canCheck(bet, 'p1'), false);
  assert.throws(() => play(bet, 'check'));
  const raised = play(bet, 'raise');
  assert.equal(raised.roundBet, 20);
  assert.equal(raised.raises, 1);
  assert.equal(raised.turnUid, 'p0');
  assert.throws(() => play(raised, 'raise'));
  const flop = play(raised, 'call');
  assert.equal(flop.street, 'flop');
  assert.equal(flop.roundBet, 0);
  assert.equal(flop.seats[0].committed, 0);
  assert.deepEqual(publicView(flop).board, flop.board.slice(0, 3));
  const turn = play(play(flop, 'check'), 'check');
  assert.equal(turn.street, 'turn');
  assert.deepEqual(publicView(turn).board, turn.board.slice(0, 4));
  const river = play(play(turn, 'check'), 'check');
  assert.equal(river.street, 'river');
  assert.deepEqual(publicView(river).board, river.board);
  const done = play(play(river, 'check'), 'check');
  assert.equal(done.street, 'showdown');
  assert.equal(done.phase, 'settled');
  assert.equal(canCheck(done, 'p0'), false);
  assert.strictEqual(settle(done), done);
  assert.equal(total(done), 200);
});

test('all-in short call creates side pot; best hand wins main, second best wins side', () => {
  const deck = orderedDeck(['KS', 'AS', 'QS', 'KH', 'AH', 'QH', '2C', '3D', '7S', '9C', 'JD']);
  let s = start([{uid: 'a', stack: 100}, {uid: 'b', stack: 15}, {uid: 'c', stack: 100}], 10, deck);
  s = play(s, 'bet');
  s = play(s, 'call'); // b pays only five, without reopening betting
  assert.equal(s.seats[1].stack, 0);
  s = play(s, 'call');
  s = checkToEnd(s);
  assert.deepEqual(s.seats.map(seat => seat.stack), [90, 45, 80]);
  assert.deepEqual(s.winners, ['a', 'b']);
  assert.equal(total(s), 215);
});

test('all-in bettor, full raise and a second side pot', () => {
  const deck = orderedDeck(['AS', 'KS', 'QS', 'AH', 'KH', 'QH', '2C', '3D', '7S', '9C', 'JD']);
  let s = start([{uid: 'a', stack: 20}, {uid: 'b', stack: 100}, {uid: 'c', stack: 100}], 10, deck);
  s = play(s, 'bet');
  s = play(s, 'raise');
  s = play(s, 'call');
  assert.equal(s.street, 'flop');
  s = checkToEnd(s);
  assert.deepEqual(s.seats.map(seat => seat.stack), [60, 90, 70]);
  assert.deepEqual(s.winners, ['a', 'b']);
  assert.equal(total(s), 220);
});

test('fold refunds unmatched bet; tied odd chip goes to earliest seat', () => {
  let s = start(seats(2), 10, newDeck());
  s = play(play(s, 'bet'), 'fold');
  assert.equal(s.phase, 'settled');
  assert.equal(s.street, 'preflop');
  assert.deepEqual(s.seats.map(seat => seat.stack), [110, 90]);
  assert.deepEqual(s.winners, ['p0']);
  assert.deepEqual(publicView(s).board, []);

  const deck = orderedDeck(['2C', '3D', '4C', '5D', '6C', '7D', 'AS', 'KS', 'QS', 'JS', 'TS']);
  s = start(seats(3, 10), 1, deck);
  s = play(play(play(s, 'check'), 'check'), 'fold');
  s = checkToEnd(s);
  assert.deepEqual(s.seats.map(seat => seat.stack), [11, 10, 9]);
  assert.deepEqual(s.winners, ['p0', 'p1']);
  assert.equal(total(s), 30);
});

test('all-in from ante runs out without turn; bot uses legal actions only', () => {
  const allIn = start(seats(2, 10), 10, newDeck());
  assert.equal(allIn.phase, 'settled');
  assert.equal(total(allIn), 20);
  const bot = start([{uid: 'b', stack: 100, isBot: true}, {uid: 'p', stack: 100}], 10, newDeck());
  assert.equal(publicView(bot).seats[0].isBot, true);
  for (let i = 0; i < 3; i++) {
    const action = chooseBotAction(bot, 'b', size => i % size);
    assert.doesNotThrow(() => act(bot, 'b', action, 10));
  }
  assert.deepEqual(chooseBotAction(bot, 'b', n => n - 1), {type: 'fold'});
  assert.throws(() => chooseBotAction(bot, 'p'));
  assert.throws(() => chooseBotAction(bot, 'b', () => 99));
});

test('reject malformed seats, deck, stake, actions and private hand access', () => {
  for (const bad of [[], seats(1), seats(7), [{uid: 'x', stack: 10}, {uid: 'x', stack: 20}],
    [{uid: 'x', stack: 9}, {uid: 'y', stack: 20}], [{uid: 'x', stack: 10.5}, {uid: 'y', stack: 20}],
    [{uid: 'x', stack: 10, isBot: 'yes'}, {uid: 'y', stack: 20}]]) {
    assert.throws(() => start(bad, 10));
  }
  for (const stake of [0, -1, 0.5, NaN, '10']) assert.throws(() => start(seats(2), stake));
  const deck = newDeck();
  for (const bad of [deck.slice(1), [...deck.slice(1), deck[1]], [...deck.slice(1), 'ZZ'],
    [...deck.slice(1), null], [...deck.slice(1), '10D']]) assert.throws(() => start(seats(2), 10, bad));
  const s = start(seats(2), 10, deck);
  for (const action of [null, {}, {type: 'wat'}, {type: 'all-in'}, {type: 'call'},
    {type: 'raise'}, {type: 'check', amount: 0}, {type: 'bet', amount: 10},
    {type: 'fold', extra: true}, ['check']]) {
    assert.throws(() => act(s, 'p0', action, 10));
  }
  assert.throws(() => act(s, 'p0', {type: 'check'}, 11));
  assert.throws(() => privateHand(s, 'outsider'));
  assert.throws(() => play(start(seats(2, 10), 10, deck), 'check'));
  const small = start(seats(2, 11), 10, deck);
  assert.throws(() => play(small, 'bet'));
});

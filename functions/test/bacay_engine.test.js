'use strict';

const {test} = require('node:test');
const assert = require('node:assert/strict');
const {newDeck, compareBaCay} = require('../src/card_games');
const {start, privateHand, publicView, settle} = require('../src/bacay_engine');

function deckWith(...first) {
  return [...first, ...newDeck().filter(card => !first.includes(card))];
}

const headsUp = deckWith('AS', 'AC', '2D', '2S', '7H', '7D');

test('deterministic deal, private access, exact public view, and idempotent payout', () => {
  const players = [{uid: 'human', stack: 100}, {uid: 'bot', stack: 70, isBot: true}];
  const original = structuredClone(players);
  const deck = [...headsUp];
  const hand = start(players, 10, deck);
  assert.deepEqual(players, original);
  assert.deepEqual(deck, headsUp);
  assert.deepEqual(hand, {
    phase: 'showdown', pot: 20,
    hands: {human: ['AS', '2D', '7H'], bot: ['AC', '2S', '7D']},
    seats: [{uid: 'human', stack: 90, committed: 10}, {uid: 'bot', stack: 60, committed: 10, isBot: true}],
  });
  const restored = JSON.parse(JSON.stringify(hand));
  const publicBefore = publicView(restored);
  assert.deepEqual(publicBefore, {
    seats: restored.seats, board: [], turnUid: null, street: 'showdown', pot: 20,
    winners: [], status: 'settled',
  });
  assert.equal(JSON.stringify(publicBefore).includes('AS'), false);
  assert.equal(Object.hasOwn(publicBefore, 'hands'), false);
  assert.deepEqual(privateHand(restored, 'human'), ['AS', '2D', '7H']);
  const copy = privateHand(restored, 'human'); copy[0] = 'KC';
  assert.equal(restored.hands.human[0], 'AS');
  assert.throws(() => privateHand(restored, 'stranger'), /Unknown seat/);
  assert.equal(compareBaCay(restored.hands.human, restored.hands.bot), 1);

  const result = settle(restored);
  assert.deepEqual(result.seats, [
    {uid: 'human', stack: 110, committed: 10}, {uid: 'bot', stack: 60, committed: 10, isBot: true},
  ]);
  assert.deepEqual(result.winners, ['human']);
  assert.equal(result.pot, 0);
  assert.deepEqual(settle(JSON.parse(JSON.stringify(result))), result);
  assert.deepEqual(restored, hand); // settlement does not mutate the open hand
  assert.deepEqual(publicView(result), {
    seats: result.seats, board: [], turnUid: null, street: 'showdown', pot: 0,
    winners: ['human'], status: 'settled',
  });
  assert.equal(Object.hasOwn(publicView(result), 'hands'), false);
});

test('a bot wins the same full pot under the same tie break', () => {
  const state = start([{uid: 'human', stack: 100}, {uid: 'bot', stack: 70, isBot: true}], 10,
    deckWith('AC', 'AS', '2S', '2D', '7D', '7H'));
  const result = settle(state);
  assert.deepEqual(result.winners, ['bot']);
  assert.deepEqual(result.seats.map(seat => seat.stack), [90, 80]);
  assert.deepEqual(result.seats.map(seat => seat.isBot), [undefined, true]);
});

test('safe-integer boundary preserves the full reserved buy-in', () => {
  const max = Number.MAX_SAFE_INTEGER;
  const result = settle(start([{uid: 'a', stack: max - 10}, {uid: 'b', stack: 10}], 10, headsUp));
  assert.equal(result.seats.reduce((sum, seat) => sum + seat.stack, 0), max);
});
test('2–6 seats: all buy-ins and the pot are conserved, including bot funds', () => {
  for (let count = 2; count <= 6; count++) {
    const seats = Array.from({length: count}, (_, index) => ({
      uid: `seat-${index}`, stack: 100 + index, ...(index === 1 ? {isBot: true} : {}),
    }));
    const state = start(seats, 13, newDeck());
    assert.equal(state.pot, count * 13);
    assert.deepEqual(state.seats.map(seat => seat.committed), Array(count).fill(13));
    assert.equal(new Set(Object.values(state.hands).flat()).size, count * 3);
    const result = settle(JSON.parse(JSON.stringify(state)));
    const expected = state.seats.reduce((best, seat) =>
      compareBaCay(state.hands[seat.uid], state.hands[best.uid]) > 0 ? seat : best);
    assert.deepEqual(result.winners, [expected.uid]);
    assert.equal(result.seats.reduce((sum, seat) => sum + seat.stack, 0),
      seats.reduce((sum, seat) => sum + seat.stack, 0));
    assert.equal(state.seats.reduce((sum, seat) => sum + seat.stack, 0) + state.pot,
      seats.reduce((sum, seat) => sum + seat.stack, 0));
    assert.equal(result.seats[1].isBot, true);
  }
});

test('reject malformed seats, unaffordable/unsafe stakes, and invalid decks', () => {
  const valid = [{uid: 'a', stack: 10}, {uid: 'b', stack: 20}];
  for (const seats of [null, [], [valid[0]], [...valid, ...valid, ...valid, valid[0]],
    [valid[0], valid[0]], [{uid: '', stack: 10}, valid[1]],
    [{uid: 'a', stack: 9}, valid[1]], [{uid: 'a', stack: 10.5}, valid[1]],
    [{uid: 'a', stack: NaN}, valid[1]], [{uid: 'a', stack: '10'}, valid[1]],
    [{uid: 'a', stack: 10, isBot: 'true'}, valid[1]], [null, valid[1]],
    Object.assign([...valid], {extra: true}), Array(2)]) {
    assert.throws(() => start(seats, 10, newDeck()));
  }
  for (const stake of [0, -1, 1.5, '10', null, NaN, Infinity, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => start(valid, stake, newDeck()));
  }
  assert.throws(() => start([{uid: 'a', stack: Number.MAX_SAFE_INTEGER}, {uid: 'b', stack: 10}], 10));
  for (const deck of [null, [], newDeck().slice(1), Array(52),
    Object.assign(newDeck(), {extra: true}),
    [...newDeck().slice(0, 51), '2C'],
    [...newDeck().slice(0, 51), '10C'],
    [...newDeck().slice(0, 51), 'ZZ']]) {
    assert.throws(() => start(valid, 10, deck));
  }
  const withAlias = deckWith('TC'); withAlias[0] = '10C';
  assert.equal(start(valid, 10, withAlias).hands.a[0], 'TC');
  assert.equal(start(valid, 10, withAlias).pot, 20);
});

test('malformed internal state is rejected; special UID is a safe map key', () => {
  const state = start([{uid: '__proto__', stack: 10}, {uid: 'other', stack: 10}], 3, headsUp);
  const restored = JSON.parse(JSON.stringify(state));
  assert.deepEqual(privateHand(restored, '__proto__'), ['AS', '2D', '7H']);
  for (const bad of [
    {...state, phase: 'betting'}, {...state, pot: 100},
    {...state, hands: {...state.hands, other: state.hands.__proto__}},
    {...state, hands: {other: state.hands.other}},
    {...state, seats: state.seats.map(seat => ({...seat, committed: 999}))},
  ]) {
    assert.throws(() => settle(bad));
    assert.throws(() => publicView(bad));
  }
});

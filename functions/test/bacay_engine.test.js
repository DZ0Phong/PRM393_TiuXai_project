'use strict';

const {test} = require('node:test');
const assert = require('node:assert/strict');
const {start, privateHand, publicView, settle, newDeck, evaluate, compare} = require('../src/bacay_engine');

function deckWith(...first) {
  return [...first, ...newDeck().filter(card => !first.includes(card))];
}
const seats = (count, stack = 100) => Array.from({length: count}, (_, i) => ({
  uid: `p${i}`, stack, ...(i === 1 ? {isBot: true} : {}),
}));

// Independent transcription of room.js's card indexes and remapped suit types.
function sourceScore(hand) {
  const rank = 'A23456789', suit = {H: 4, D: 5, C: 2, S: 3};
  const points = hand.reduce((n, card) => n + rank.indexOf(card[0]) + 1, 0) % 10 || 10;
  const highest = hand.map(card => [suit[card[1]], card === 'AD' ? 13 : rank.indexOf(card[0])])
    .sort((a, b) => b[0] - a[0] || b[1] - a[1])[0];
  return [points, ...highest];
}

test('36 A–9 cards, three contiguous cards per seat, no leaked private cards', () => {
  const deck = newDeck(), input = seats(6), original = structuredClone(input);
  assert.equal(deck.length, 36);
  assert.equal(new Set(deck).size, 36);
  assert.deepEqual(new Set(deck.map(c => c[0])), new Set('A23456789'));
  assert.deepEqual(new Set(deck.map(c => c[1])), new Set('HDCS'));
  const state = start(input, 10, deck, 'p0');
  assert.deepEqual(input, original);
  assert.deepEqual(deck, newDeck());
  assert.equal(state.dealerUid, 'p0');
  assert.equal(state.pot, 50);
  assert.deepEqual(state.seats.map(s => s.stack), [100, 90, 90, 90, 90, 90]);
  for (let i = 0; i < 6; i++) assert.deepEqual(privateHand(state, `p${i}`), deck.slice(i * 3, i * 3 + 3));
  const saved = JSON.parse(JSON.stringify(state));
  const hand = privateHand(saved, 'p0'); hand[0] = '9S';
  assert.equal(saved.hands.p0[0], deck[0]);
  assert.deepEqual(publicView(saved), {
    seats: saved.seats, dealerUid: 'p0', board: [], turnUid: null, street: 'showdown',
    pot: 50, winners: [], status: 'settled',
  });
  assert.equal(JSON.stringify(publicView(saved)).includes('"hands"'), false);
  assert.throws(() => privateHand(saved, 'stranger'), /Unknown seat/);
});

test('all 7,140 three-card combinations match the extracted scoring algorithm', () => {
  const deck = newDeck(), counts = Array(11).fill(0);
  for (let a = 0; a < 34; a++) for (let b = a + 1; b < 35; b++)
    for (let c = b + 1; c < 36; c++) {
      const hand = [deck[a], deck[b], deck[c]];
      const expected = sourceScore(hand), actual = evaluate(hand);
      assert.deepEqual([actual.points, ...actual.highest], expected, hand.join(','));
      counts[actual.points]++;
      assert.deepEqual(evaluate([...hand].reverse()), actual);
    }
  assert.equal(counts.slice(1).reduce((sum, count) => sum + count, 0), 7140);
  assert.ok(counts.slice(1).every(count => count > 0));
});

test('all hands compare in source score order, including equal-score hands', () => {
  const deck = newDeck(), hands = [];
  for (let a = 0; a < 34; a++) for (let b = a + 1; b < 35; b++)
    for (let c = b + 1; c < 36; c++) hands.push([deck[a], deck[b], deck[c]]);
  const order = (a, b) => {
    const x = sourceScore(a), y = sourceScore(b);
    return Math.sign(x[0] - y[0] || x[1] - y[1] || x[2] - y[2]);
  };
  hands.sort(order);
  for (let i = 1; i < hands.length; i++) {
    const expected = order(hands[i], hands[i - 1]);
    assert.equal(compare(hands[i], hands[i - 1]), expected);
    assert.equal(compare(hands[i - 1], hands[i]), expected === 0 ? 0 : -expected);
  }
});
test('point 10 outranks 9; D > H > S > C; diamond A alone is high', () => {
  assert.equal(evaluate(['AH', '2C', '7S']).points, 10);
  assert.equal(compare(['AH', '2C', '7S'], ['9H', '9C', '9S']), 1);
  for (const [high, low] of [['D', 'H'], ['H', 'S'], ['S', 'C']]) {
    assert.equal(compare([`2${high}`, '3C', '4C'],
      [`2${low}`, '3C', '4C']), 1);
  }
  assert.equal(compare(['AD', '2C', '7H'], ['9D', '9C', '2S']), 1);
  assert.equal(compare(['AH', '2C', '7C'], ['9H', '9C', '2C']), -1);
  assert.equal(compare(['2C', '3D', '4S'], ['2C', '3D', '4S']), 0);
});

test('dealer compares independently with every opponent; rake leaves the table', () => {
  // Dealer: 1+2+7=10; p1: 9+9+2=10, D9 beats dealer H7;
  // p2: 3+3+4=10, dealer H7 beats p2 S4.
  const deck = deckWith('AH', '2C', '7S', '9D', '9S', '2H', '3S', '3C', '4S');
  const input = seats(3, 100), state = start(input, 10, deck, 'p0');
  const before = structuredClone(state), result = settle(JSON.parse(JSON.stringify(state)));
  assert.deepEqual(state, before);
  assert.deepEqual(result.winners, ['p1']);
  assert.equal(result.nextDealerUid, 'p1');
  assert.deepEqual(result.seats.map(s => s.stack), [99, 109, 90]);
  assert.equal(result.rake, 2);
  assert.equal(result.seats.reduce((sum, s) => sum + s.stack, 0) + result.rake, 300);
  assert.equal(result.pot, 0);
  assert.deepEqual(settle(JSON.parse(JSON.stringify(result))), result);
  assert.deepEqual(publicView(result).winners, ['p1']);
});

test('dealer wins every comparison or pays multiple opponents, 2–6 seats', () => {
  for (let count = 2; count <= 6; count++) {
    // A-D is dealer's highest card and the dealer has point 10.
    const deck = deckWith('AD', '2C', '7H');
    const state = start(seats(count), 10, deck, 'p0');
    const result = settle(state);
    assert.equal(result.seats.length, count);
    assert.deepEqual(result.winners, ['p0']);
    assert.equal(result.nextDealerUid, 'p0');
    assert.equal(result.rake, count - 1);
    assert.equal(result.seats.reduce((sum, s) => sum + s.stack, 0) + result.rake, 100 * count);
    assert.equal(result.seats[1].isBot, true);
  }
  const state = start(seats(3), 10, deckWith(
    '2C', '3H', '4S', // dealer 9
    'AH', '2S', '7H', // 10
    '3D', '4H', '3S', // 10
  ), 'p0');
  const result = settle(state);
  assert.deepEqual(result.winners, ['p1', 'p2']);
  assert.equal(result.nextDealerUid, 'p2');
  assert.deepEqual(result.seats.map(s => s.stack), [80, 109, 109]);
});

test('reject invalid cards, dealers, insufficient cover and malformed states', () => {
  const valid = seats(2);
  for (const bad of [null, [], newDeck().slice(1), Array(36),
    Object.assign(newDeck(), {extra: true}), [...newDeck().slice(0, 35), 'TH'],
    [...newDeck().slice(0, 35), '10H'], [...newDeck().slice(0, 35), 'AH'],
    [...newDeck().slice(0, 35), 'ZZ']]) assert.throws(() => start(valid, 10, bad, 'p0'));
  for (const stake of [0, -1, 1.5, '10', NaN, Infinity, Number.MAX_SAFE_INTEGER])
    assert.throws(() => start(valid, stake, newDeck(), 'p0'));
  for (const bad of [null, [], [valid[0]], Array(2),
    [valid[0], valid[0]], [{uid: '', stack: 10}, valid[1]],
    [{uid: 'p0', stack: 9}, valid[1]], [{uid: 'p0', stack: NaN}, valid[1]],
    [{uid: 'p0', stack: 100, isBot: 'true'}, valid[1]]])
    assert.throws(() => start(bad, 10, newDeck(), 'p0'));
  assert.throws(() => start(valid, 10, newDeck(), 'other'), /Unknown dealer/);
  assert.throws(() => start(seats(3, 10), 10, newDeck(), 'p0'), /cover/);
  const state = start(valid, 10, newDeck(), 'p0');
  for (const bad of [{...state, phase: 'betting'}, {...state, pot: 20},
    {...state, dealerUid: 'unknown'}, {...state, hands: {...state.hands, p1: state.hands.p0}},
    {...state, seats: state.seats.map(s => ({...s, committed: 10}))}]) {
    assert.throws(() => settle(bad));
    assert.throws(() => publicView(bad));
  }
});

test('special UID is a safe hand key; default dealer and shuffled cards stay valid', () => {
  const state = start([{uid: '__proto__', stack: 100}, {uid: 'other', stack: 100}], 10);
  assert.ok(['__proto__', 'other'].includes(state.dealerUid));
  assert.equal(new Set(Object.values(state.hands).flat()).size, 6);
  assert.equal(privateHand(JSON.parse(JSON.stringify(state)), '__proto__').length, 3);
  assert.equal(settle(state).seats.reduce((sum, s) => sum + s.stack, 0), 199);
});




test('the dealer stays when nobody has 10; safe-integer balance is conserved including rake', () => {
  const max = Number.MAX_SAFE_INTEGER;
  const state = start([{uid: 'p0', stack: max - 10}, {uid: 'p1', stack: 10}], 10,
    deckWith('2C', '3H', '4S', '2H', '3D', '6S'), 'p0');
  const result = settle(state);
  assert.equal(result.nextDealerUid, 'p0');
  assert.equal(result.seats.reduce((sum, seat) => sum + seat.stack, 0) + result.rake, max);
});

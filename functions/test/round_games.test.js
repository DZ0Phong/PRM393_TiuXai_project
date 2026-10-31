'use strict';

const {test, mock} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {validateBet, validateOutcome, randomOutcome, payout, describeOutcome, games} = require('../src/round_games');

const faces = ['bau', 'cua', 'tom', 'ca', 'ga', 'nai'];

test('metadata and bet boundaries', () => {
  assert.deepEqual(Object.keys(games), ['tai_xiu', 'bau_cua', 'xoc_xoc']);
  assert.match(games.xoc_xoc.rule, /mô phỏng.*4 đồng xu.*2 lần/);
  for (const [game, sides] of Object.entries({tai_xiu: ['tai', 'xiu'], bau_cua: faces, xoc_xoc: ['chan', 'le']})) {
    assert.deepEqual(games[game].sides, sides);
    for (const side of sides) {
      for (const amount of [10, 100, 1000]) assert.equal(validateBet(game, side, amount), true);
      for (const amount of [undefined, null, '10', 9, 1001, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
        assert.equal(validateBet(game, side, amount), false);
        assert.throws(() => payout(game, side, amount, game === 'xoc_xoc' ? [0, 0, 0, 0] : game === 'bau_cua' ? faces.slice(0, 3) : [1, 2, 3]));
      }
    }
    for (const side of [undefined, null, '', 'TRIPLE', 'triple', 'constructor', [], {}]) {
      assert.equal(validateBet(game, side, 10), false);
    }
  }
  for (const game of [undefined, null, '', '__proto__', 'unknown', {}, {toString: () => 'tai_xiu'}]) {
    assert.equal(validateBet(game, 'tai', 10), false);
    assert.equal(validateOutcome(game, [1, 2, 3]), false);
    assert.throws(() => randomOutcome(game));
    assert.throws(() => payout(game, 'tai', 10, [1, 2, 3]));
    assert.throws(() => describeOutcome(game, [1, 2, 3]));
  }
});

test('strict outcome shapes and values (including sparse arrays)', () => {
  for (const [game, valid, invalidValues] of [
    ['tai_xiu', [1, 2, 6], [0, 7, 1.5, '1', NaN, Infinity, null, undefined]],
    ['bau_cua', ['bau', 'cua', 'tom'], [0, 'BAU', 'triple', null, undefined, {}]],
    ['xoc_xoc', [0, 1, 0, 1], [-1, 2, true, '0', NaN, null, undefined]],
  ]) {
    assert.equal(validateOutcome(game, valid), true);
    for (const result of [undefined, null, {}, '123', [], valid.slice(1), [...valid, valid[0]],
      Array(valid.length), Object.assign([...valid], {extra: 1})]) {
      assert.equal(validateOutcome(game, result), false);
      assert.throws(() => describeOutcome(game, result));
      assert.throws(() => payout(game, games[game].sides[0], 10, result));
    }
    for (const bad of invalidValues) {
      const result = [...valid]; result[0] = bad;
      assert.equal(validateOutcome(game, result), false);
    }
    const sparse = [...valid]; delete sparse[1];
    assert.equal(validateOutcome(game, sparse), false);
  }
});

test('Tài Xỉu: exhaustive 216 rolls, triples lose both, 10/11 boundary', () => {
  const counts = {tai: 0, xiu: 0, triple: 0};
  for (let a = 1; a <= 6; a++) for (let b = 1; b <= 6; b++) for (let c = 1; c <= 6; c++) {
    const dice = [a, b, c];
    const expected = a === b && b === c ? 'triple' : a + b + c >= 11 ? 'tai' : 'xiu';
    const description = describeOutcome('tai_xiu', dice);
    assert.deepEqual(description, {dice, total: a + b + c, side: expected});
    counts[expected]++;
    for (const side of games.tai_xiu.sides) assert.equal(payout('tai_xiu', side, 1000, dice), expected === side ? 2000 : 0);
  }
  assert.deepEqual(counts, {tai: 105, xiu: 105, triple: 6});
  assert.equal(describeOutcome('tai_xiu', [1, 3, 6]).side, 'xiu');
  assert.equal(describeOutcome('tai_xiu', [2, 3, 6]).side, 'tai');
});

test('Bầu Cua: exhaustive 216 rolls and every bet face, zero to three matches', () => {
  for (const a of faces) for (const b of faces) for (const c of faces) {
    const dice = [a, b, c];
    const description = describeOutcome('bau_cua', dice);
    assert.deepEqual(description.dice, dice);
    for (const side of faces) {
      const matches = dice.filter(face => face === side).length;
      assert.equal(description.counts[side], matches);
      assert.equal(payout('bau_cua', side, 1000, dice), matches ? 1000 * (1 + matches) : 0);
    }
  }
  const dice = ['bau', 'bau', 'bau'];
  assert.equal(payout('bau_cua', 'bau', 10, dice), 40);
  assert.equal(payout('bau_cua', 'cua', 10, dice), 0);
});

test('Xóc Xóc: exhaustive 16 bit patterns and parity payout', () => {
  let chan = 0, le = 0;
  for (let pattern = 0; pattern < 16; pattern++) {
    const coins = Array.from({length: 4}, (_, i) => (pattern >> i) & 1);
    const ones = coins.reduce((sum, bit) => sum + bit, 0);
    const side = ones % 2 ? 'le' : 'chan';
    assert.deepEqual(describeOutcome('xoc_xoc', coins), {coins, ones, side});
    if (side === 'chan') chan++; else le++;
    for (const betSide of games.xoc_xoc.sides) assert.equal(payout('xoc_xoc', betSide, 1000, coins), betSide === side ? 2000 : 0);
  }
  assert.equal(chan, 8); assert.equal(le, 8);
});

test('randomOutcome uses crypto.randomInt with valid exclusive bounds', () => {
  const calls = [];
  const stub = mock.method(crypto, 'randomInt', max => { calls.push(max); return calls.length % max === 0 ? max - 1 : 0; });
  try {
    for (const [game, length, max] of [['tai_xiu', 3, 6], ['bau_cua', 3, 6], ['xoc_xoc', 4, 2]]) {
      const result = randomOutcome(game);
      assert.equal(result.length, length);
      assert.equal(validateOutcome(game, result), true);
      assert.deepEqual(calls.splice(0), Array(length).fill(max));
    }
    assert.equal(stub.mock.callCount(), 10);
  } finally { stub.mock.restore(); }
});
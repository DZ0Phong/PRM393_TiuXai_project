'use strict';
const {test, mock} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {validateBet, validateOutcome, randomOutcome, payout, describeOutcome, creditsForRound, games} = require('../src/round_games');
const faces = ['nai', 'bau', 'ga', 'ca', 'cua', 'tom'];

test('source-informed sides, denominations, strict input and outcome shape', () => {
  assert.deepEqual(Object.keys(games), ['tai_xiu', 'bau_cua', 'xoc_xoc']);
  assert.deepEqual(games.bau_cua.sides, faces);
  assert.deepEqual(games.xoc_xoc.sides, ['chan', 'le', 'red3', 'red4', 'white3', 'white4']);
  for (const game of Object.keys(games)) {
    for (const side of games[game].sides) {
      assert.equal(validateBet(game, side, 1000), true);
      for (const n of [undefined, null, '1000', -1, 999, 1050, 1000001, Infinity, NaN, 1.5]) {
        assert.equal(validateBet(game, side, n), false);
      }
    }
    const good = game === 'bau_cua' ? faces.slice(0, 3) : game === 'tai_xiu' ? [1, 2, 3] : [0, 1, 0, 1];
    assert.equal(validateOutcome(game, good), true);
    for (const bad of [[], good.slice(1), Array(good.length), Object.assign([...good], {extra: 1})]) {
      assert.equal(validateOutcome(game, bad), false);
      assert.throws(() => describeOutcome(game, bad));
    }
    const invalid = [...good]; invalid[0] = game === 'bau_cua' ? 'bauu' : 7;
    assert.equal(validateOutcome(game, invalid), false);
  }
  for (const bad of [null, undefined, '__proto__', {}, 'other']) {
    assert.equal(validateBet(bad, 'tai', 1000), false);
    assert.equal(validateOutcome(bad, [1, 2, 3]), false);
    assert.throws(() => randomOutcome(bad));
  }
  assert.equal(validateBet('xoc_xoc', 'chan', 50000), true);
  assert.equal(validateBet('xoc_xoc', 'chan', 2000), false);
});

test('Tài/Xỉu: all 216 outcomes including triples, 10/11 boundary, 2% fee', () => {
  const counts = {tai: 0, xiu: 0};
  for (let a = 1; a <= 6; a++) for (let b = 1; b <= 6; b++) for (let c = 1; c <= 6; c++) {
    const dice = [a, b, c];
    const side = a + b + c > 10 ? 'tai' : 'xiu'; counts[side]++;
    assert.deepEqual(describeOutcome('tai_xiu', dice), {dice, total: a + b + c, side});
    assert.equal(payout('tai_xiu', side, 1000, dice), 1980);
    assert.equal(payout('tai_xiu', side === 'tai' ? 'xiu' : 'tai', 1000, dice), 0);
  }
  assert.deepEqual(counts, {tai: 108, xiu: 108});
  assert.equal(describeOutcome('tai_xiu', [6, 6, 6]).side, 'tai');
  assert.equal(describeOutcome('tai_xiu', [1, 1, 1]).side, 'xiu');
});

test('Tài/Xỉu majority refunds excess deterministically before stake payout', () => {
  const bets = [
    {uid: 'a', side: 'tai', stakes: {tai: 2000}, amount: 2000, atMillis: 1},
    {uid: 'b', side: 'tai', stakes: {tai: 2000}, amount: 2000, atMillis: 2},
    {uid: 'c', side: 'xiu', stakes: {xiu: 1000}, amount: 1000, atMillis: 3},
  ];
  assert.deepEqual(creditsForRound('tai_xiu', bets, [6, 6, 6]), [
    {uid: 'a', refund: 2000, credit: 2000},
    {uid: 'b', refund: 1000, credit: 2980},
    {uid: 'c', refund: 0, credit: 0},
  ]);
  assert.deepEqual(creditsForRound('tai_xiu', bets, [1, 1, 1]).map(x => x.credit), [2000, 1000, 1980]);
  assert.deepEqual(creditsForRound('tai_xiu', [bets[0]], [6, 6, 6])[0].credit, 2000);
});

test('Bầu Cua: all 216 rolls and 0–3 matching faces at 98% profit', () => {
  for (const a of faces) for (const b of faces) for (const c of faces) {
    const dice = [a, b, c], outcome = describeOutcome('bau_cua', dice);
    for (const side of faces) {
      const matches = dice.filter(face => face === side).length;
      assert.equal(outcome.counts[side], matches);
      assert.equal(payout('bau_cua', side, 1000, dice), matches ? 1000 + 980 * matches : 0);
    }
  }
  assert.equal(payout('bau_cua', 'nai', 1000, ['nai', 'nai', 'nai']), 3940);
});

test('Xóc Xóc: all 16 results and six overlapping doors', () => {
  const odds = {chan: 198, le: 198, red3: 394, red4: 1470, white3: 394, white4: 1470};
  for (let pattern = 0; pattern < 16; pattern++) {
    const coins = Array.from({length: 4}, (_, i) => (pattern >> i) & 1);
    const ones = coins.reduce((a, b) => a + b, 0);
    const winning = [ones % 2 ? 'le' : 'chan', ... (ones === 3 ? ['red3'] : ones === 4 ? ['red4'] : []),
      ...(ones === 1 ? ['white3'] : ones === 0 ? ['white4'] : [])];
    const description = describeOutcome('xoc_xoc', coins);
    assert.equal(description.ones, ones);
    assert.deepEqual(description.winningSides, winning);
    for (const side of games.xoc_xoc.sides) {
      assert.equal(payout('xoc_xoc', side, 1000, coins), winning.includes(side) ? odds[side] * 10 : 0);
    }
  }
  assert.deepEqual(creditsForRound('xoc_xoc', [{uid:'a', amount: 2000, stakes:{chan:1000,white4:1000}}], [0,0,0,0]),
    [{uid:'a', credit: 16680, refund: 0}]);
});

test('random outcomes sample crypto.randomInt exclusive bounds', () => {
  const calls = [];
  const stub = mock.method(crypto, 'randomInt', max => {calls.push(max); return 0;});
  try {
    for (const [game, length, max] of [['tai_xiu', 3, 6], ['bau_cua', 3, 6], ['xoc_xoc', 4, 2]]) {
      assert.equal(validateOutcome(game, randomOutcome(game)), true);
      assert.deepEqual(calls.splice(0), Array(length).fill(max));
    }
  } finally {stub.mock.restore();}
});

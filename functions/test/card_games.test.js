'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {newDeck, shuffle, evaluateBaCay, compareBaCay, evaluateHoldem, compareHoldem,
  isLegalHoldemAction, isLegalBaCayAction} = require('../src/card_games');

test('deck/shuffle: unique 52, permutation, no mutation', () => {
  const deck = newDeck(), copy = deck.slice(), shuffled = shuffle(deck);
  assert.equal(new Set(deck).size, 52);
  assert.deepEqual(new Set(shuffled), new Set(deck));
  assert.deepEqual(deck, copy);
  assert.equal(new Set(shuffle()).size, 52);
});

test('Ba Cây scores and documented deterministic tie rule', () => {
  assert.equal(evaluateBaCay(['AS', '2D', '7H']).points, 10);
  assert.equal(evaluateBaCay(['TC', 'JH', 'QD']).points, 10);
  assert.equal(evaluateBaCay(['10C', 'KC', '9S']).points, 9);
  assert.equal(evaluateBaCay(['8C', '9D', '4H']).points, 1);
  assert.equal(compareBaCay(['AS', '2D', '7H'], ['AC', '2S', '7D']), 1);
  assert.equal(compareBaCay(['2C', '3D', '4H'], ['2C', '3D', '4H']), 0);
});

test('Hold’em best five: wheel, flush, full house, straight flush', () => {
  const wheel = ['AS', '2D', '3H', '4C', '5S', 'KD', 'QH'];
  assert.deepEqual(evaluateHoldem(wheel).tiebreak, [5]);
  assert.equal(evaluateHoldem(wheel).name, 'straight');
  assert.equal(compareHoldem(wheel, ['2S', '3D', '4H', '5C', '6S', 'KD', 'QH']), -1);
  const fullHouse = ['AS', 'AH', 'AD', 'KS', 'KH', '3C', '4C'];
  const flush = ['AS', 'QS', '9S', '6S', '2S', 'KD', 'KH'];
  assert.equal(evaluateHoldem(fullHouse).name, 'full house');
  assert.equal(evaluateHoldem(flush).name, 'flush');
  assert.equal(compareHoldem(fullHouse, flush), 1);
  assert.equal(evaluateHoldem(['AS', '2S', '3S', '4S', '5S', 'KD', 'KH']).name, 'straight flush');
  assert.deepEqual(evaluateHoldem(['AS', '2S', '3S', '4S', '5S', 'KD', 'KH']).tiebreak, [5]);
  assert.equal(evaluateHoldem(['AS', 'AH', 'AD', 'KS', 'KH', 'KD', '2C']).tiebreak[0], 14);
});

test('Hold’em remaining categories and best-of-seven tie breakers', () => {
  const four = ['AC', 'AD', 'AH', 'AS', '2C', '3D', '4H'];
  const twoPair = ['AC', 'AD', 'KH', 'KS', '2C', '3D', '4H'];
  assert.equal(evaluateHoldem(four).name, 'four of a kind');
  assert.equal(evaluateHoldem(twoPair).name, 'two pair');
  assert.equal(evaluateHoldem(['AC', 'AD', '2H', '3S', '5C', '7D', '9H']).name, 'pair');
  assert.equal(evaluateHoldem(['AC', 'KD', '2H', '3S', '5C', '7D', '9H']).name, 'high card');
  assert.equal(compareHoldem(four, twoPair), 1);
  assert.equal(compareHoldem(['AC', 'AD', 'AH', 'KC', 'KD', 'KH', '2H'],
      ['QC', 'QD', 'QH', 'JC', 'JD', 'JH', '2D']), 1);
  assert.equal(evaluateHoldem(['AC', 'KD', 'QH', 'JS', '2C', '3D', '8H']).name, 'high card');
});

test('Hold’em ties ignore suits, kickers decide', () => {
  const board = ['AS', 'KS', 'QS', 'JS', 'TS'];
  assert.equal(compareHoldem([...board, '2C', '3D'], [...board, '4C', '5D']), 0);
  assert.equal(compareHoldem(['AS', 'AH', 'KD', 'QC', '9H', '2C', '3D'],
      ['AD', 'AC', 'KD', 'QC', '8H', '2S', '3C']), 1);
  assert.equal(evaluateHoldem([...board, '2C', '3D']).bestFive.length, 5);
});

test('invalid, duplicate and aliased cards are rejected', () => {
  for (const hand of [['AS', 'AS', '2D'], ['TC', '10C', '2D'], ['xs', '2D', '3C'], ['AS', '2D'], [null, '2D', '3C']])
    assert.throws(() => evaluateBaCay(hand));
  assert.throws(() => evaluateHoldem(['AS', '2D', '3H', '4C', '5S', 'AS', '7D']));
  assert.throws(() => evaluateHoldem(newDeck()));
  assert.throws(() => shuffle([...newDeck().slice(1), '10D']));
});

test('Hold’em turn, check/call, min raise, short all-in, closed betting', () => {
  const s = {phase: 'betting', isTurn: true, active: true, stack: 100, toCall: 10, minRaise: 10, canRaise: true};
  assert.equal(isLegalHoldemAction(s, {type: 'call'}), true);
  assert.equal(isLegalHoldemAction(s, {type: 'check'}), false);
  assert.equal(isLegalHoldemAction(s, {type: 'raise', amount: 19}), false);
  assert.equal(isLegalHoldemAction(s, {type: 'raise', amount: 20}), true);
  assert.equal(isLegalHoldemAction(s, {type: 'raise', amount: 101}), false);
  assert.equal(isLegalHoldemAction({...s, stack: 12}, {type: 'all-in'}), true);
  assert.equal(isLegalHoldemAction({...s, canRaise: false}, {type: 'all-in'}), false);
  assert.equal(isLegalHoldemAction({...s, canRaise: false, stack: 5}, {type: 'all-in'}), true);
  assert.equal(isLegalHoldemAction({...s, isTurn: false}, {type: 'fold'}), false);
  assert.equal(isLegalHoldemAction({...s, phase: 'showdown'}, {type: 'fold'}), false);
  assert.equal(isLegalHoldemAction({...s, stack: 0}, {type: 'check'}), false);
  assert.equal(isLegalHoldemAction({...s, toCall: 0}, {type: 'check'}), true);
  assert.equal(isLegalHoldemAction({...s, toCall: 0}, {type: 'bet', amount: 10}), true);
  assert.equal(isLegalHoldemAction({...s, toCall: 0}, {type: 'bet', amount: 9}), false);
  assert.equal(isLegalHoldemAction(s, {type: 'raise', amount: NaN}), false);
});

test('Ba Cây only permits affordable bet before deal', () => {
  const s = {phase: 'betting', isTurn: true, stack: 20};
  assert.equal(isLegalBaCayAction(s, {type: 'bet', amount: 20}), true);
  for (const amount of [0, -1, 1.5, 21, NaN])
    assert.equal(isLegalBaCayAction(s, {type: 'bet', amount}), false);
  assert.equal(isLegalBaCayAction({...s, phase: 'showdown'}, {type: 'bet', amount: 5}), false);
  assert.equal(isLegalBaCayAction(s, {type: 'check'}), false);
});

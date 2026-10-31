'use strict';
const {randomInt} = require('node:crypto');
const RANKS = '23456789TJQKA';
const SUITS = 'CDHS';
const NAMES = ['high card', 'pair', 'two pair', 'three of a kind', 'straight', 'flush', 'full house', 'four of a kind', 'straight flush'];
const rankOf = card => RANKS.indexOf(card[0]) + 2;

// Cards use uppercase rank + suit (C/D/H/S): AS, TH; 10H is an alias for TH.
function validate(cards, length) {
  if (!Array.isArray(cards) || cards.length !== length) throw new RangeError(`Expected ${length} cards`);
  const result = cards.map(card => {
    if (typeof card !== 'string' || !/^(?:10|[2-9TJQKA])[CDHS]$/.test(card)) throw new TypeError('Invalid card');
    return card.startsWith('10') ? `T${card[2]}` : card;
  });
  if (new Set(result).size !== length) throw new RangeError('Duplicate card');
  return result;
}

function newDeck() {
  return [...SUITS].flatMap(suit => [...RANKS].map(rank => rank + suit));
}

// Fisher-Yates with cryptographic randomness; does not mutate the input.
function shuffle(deck = newDeck()) {
  const cards = validate(deck, 52);
  for (let i = cards.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }
  return cards;
}

// House tie rule (not universal): compare sorted ranks A>K>...>2, then suits S>H>D>C.
function evaluateBaCay(hand) {
  const cards = validate(hand, 3);
  const sum = cards.reduce((total, card) => {
    const rank = rankOf(card);
    return total + (rank === 14 ? 1 : rank >= 10 ? 0 : rank);
  }, 0);
  const tiebreak = cards.map(card => [rankOf(card), SUITS.indexOf(card[1])])
      .sort((a, b) => b[0] - a[0] || b[1] - a[1]).flat();
  return {points: sum % 10 || 10, tiebreak};
}

function scoreFive(cards) {
  const ranks = cards.map(rankOf).sort((a, b) => b - a);
  const groups = [...new Set(ranks)].map(rank => [ranks.filter(n => n === rank).length, rank])
      .sort((a, b) => b[0] - a[0] || b[1] - a[1]);
  const flush = cards.every(card => card[1] === cards[0][1]);
  const distinct = [...new Set(ranks)];
  if (distinct.includes(14)) distinct.push(1);
  let high = 0;
  for (let i = 0; i <= distinct.length - 5; i++) {
    if (distinct[i] - distinct[i + 4] === 4) { high = distinct[i]; break; }
  }
  if (flush && high) return [8, high];
  if (groups[0][0] === 4) return [7, groups[0][1], groups[1][1]];
  if (groups[0][0] === 3 && groups[1][0] === 2) return [6, groups[0][1], groups[1][1]];
  if (flush) return [5, ...ranks];
  if (high) return [4, high];
  if (groups[0][0] === 3) return [3, groups[0][1], ...groups.slice(1).map(g => g[1])];
  if (groups[0][0] === 2 && groups[1][0] === 2) return [2, groups[0][1], groups[1][1], groups[2][1]];
  if (groups[0][0] === 2) return [1, groups[0][1], ...groups.slice(1).map(g => g[1])];
  return [0, ...ranks];
}

function compareScores(a, b) {
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const diff = (a[i] || 0) - (b[i] || 0);
    if (diff) return Math.sign(diff);
  }
  return 0;
}

function evaluateHoldem(sevenCards) {
  const cards = validate(sevenCards, 7);
  let best, bestFive;
  for (let a = 0; a < 3; a++) for (let b = a + 1; b < 4; b++)
    for (let c = b + 1; c < 5; c++) for (let d = c + 1; d < 6; d++)
      for (let e = d + 1; e < 7; e++) {
        const five = [cards[a], cards[b], cards[c], cards[d], cards[e]];
        const score = scoreFive(five);
        if (!best || compareScores(score, best) > 0) { best = score; bestFive = five; }
      }
  return {rank: best[0], name: NAMES[best[0]], tiebreak: best.slice(1), bestFive};
}

// Comparators return -1/0/1. Poker suits never break a tie.
function compareHoldem(a, b) {
  const x = evaluateHoldem(a), y = evaluateHoldem(b);
  return compareScores([x.rank, ...x.tiebreak], [y.rank, ...y.tiebreak]);
}
function compareBaCay(a, b) {
  const x = evaluateBaCay(a), y = evaluateBaCay(b);
  return compareScores([x.points, ...x.tiebreak], [y.points, ...y.tiebreak]);
}

// State: {phase: 'betting', isTurn, active, stack, toCall, minRaise, canRaise}.
// `amount` is extra chips paid NOW; short all-in can be below minRaise.
// canRaise=false means a short all-in has not reopened betting.
function isLegalHoldemAction(state, action) {
  if (!state || !action || state.phase !== 'betting' || state.isTurn !== true || state.active !== true ||
      !Number.isSafeInteger(state.stack) || state.stack <= 0 ||
      !Number.isSafeInteger(state.toCall) || state.toCall < 0 ||
      !Number.isSafeInteger(state.minRaise) || state.minRaise < 1 ||
      typeof action.type !== 'string') return false;
  const {stack, toCall, minRaise, canRaise} = state;
  if (action.type === 'fold') return true;
  if (action.type === 'check') return toCall === 0;
  if (action.type === 'call') return toCall > 0 && stack > 0;
  if (action.type === 'all-in') return stack > 0 && (stack <= toCall || canRaise === true);
  if (!Number.isSafeInteger(action.amount) || action.amount <= 0 || action.amount > stack || canRaise !== true) return false;
  if (action.type === 'bet') return toCall === 0 && action.amount >= minRaise;
  if (action.type === 'raise') return toCall > 0 && action.amount >= toCall + minRaise;
  return false;
}

// One bet before dealing; dealing/showdown is not a player action here.
function isLegalBaCayAction(state, action) {
  return Boolean(state && action && state.phase === 'betting' && state.isTurn === true &&
      action.type === 'bet' && Number.isSafeInteger(state.stack) && state.stack > 0 &&
      Number.isSafeInteger(action.amount) && action.amount > 0 && action.amount <= state.stack);
}

module.exports = {newDeck, shuffle, evaluateBaCay, compareBaCay, evaluateHoldem, compareHoldem,
  isLegalHoldemAction, isLegalBaCayAction};

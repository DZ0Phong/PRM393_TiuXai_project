'use strict';

const {randomInt} = require('node:crypto');
const RANKS = 'A23456789';
const SUITS = 'HDCS'; // Extracted data/card.js: type 0=H, 1=D, 2=C, 3=S.
const SUIT_STRENGTH = {H: 4, D: 5, C: 2, S: 3}; // room.js maps types 1->5, 0->4.
const DECK = [...RANKS].flatMap(rank => [...SUITS].map(suit => rank + suit));
const CARD_SET = new Set(DECK);

function cardList(cards, length) {
  if (!Array.isArray(cards) || cards.length !== length || Object.keys(cards).length !== length) {
    throw new RangeError(`Expected ${length} cards`);
  }
  for (const card of cards) {
    if (typeof card !== 'string' || !CARD_SET.has(card)) throw new TypeError('Invalid Ba Cây card');
  }
  if (new Set(cards).size !== length) throw new RangeError('Duplicate card');
  return [...cards];
}

function newDeck() { return [...DECK]; }

function shuffle(deck = newDeck()) {
  const cards = cardList(deck, 36);
  for (let i = cards.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }
  return cards;
}

function evaluate(hand) {
  const cards = cardList(hand, 3);
  const points = cards.reduce((sum, card) => sum + RANKS.indexOf(card[0]) + 1, 0) % 10 || 10;
  // Only diamond A is promoted above 9; A is low in every other suit.
  const highest = cards.map(card => [SUIT_STRENGTH[card[1]],
    card === 'AD' ? 13 : RANKS.indexOf(card[0])])
    .sort((a, b) => b[0] - a[0] || b[1] - a[1])[0];
  return {points, highest};
}

function compare(a, b) {
  const x = evaluate(a), y = evaluate(b);
  return Math.sign(x.points - y.points || x.highest[0] - y.highest[0] ||
    x.highest[1] - y.highest[1]);
}

function seatsAreValid(seats, stake, dealerUid, started) {
  if (!Array.isArray(seats) || seats.length < 2 || seats.length > 6 ||
      Object.keys(seats).length !== seats.length || !Number.isSafeInteger(stake) || stake <= 0 ||
      !Number.isSafeInteger(stake * (seats.length - 1))) throw new RangeError('Invalid seats or stake');
  const ids = new Set();
  let total = 0;
  for (const seat of seats) {
    if (!seat || typeof seat !== 'object' || Array.isArray(seat) ||
        typeof seat.uid !== 'string' || !seat.uid.trim() || ids.has(seat.uid) ||
        !Number.isSafeInteger(seat.stack) || seat.stack < 0 ||
        (seat.isBot !== undefined && typeof seat.isBot !== 'boolean') ||
        (started && seat.committed !== (seat.uid === dealerUid ? 0 : stake))) {
      throw new RangeError('Invalid seat');
    }
    ids.add(seat.uid);
    total += seat.stack;
    if (!Number.isSafeInteger(total)) throw new RangeError('Unsafe total');
  }
  if (!ids.has(dealerUid)) throw new RangeError('Unknown dealer');
  if (!started && seats.some(seat => seat.stack < (seat.uid === dealerUid ? stake * (seats.length - 1) : stake))) {
    throw new RangeError('Insufficient stake or dealer cover');
  }
}

// Non-dealers reserve their bet; the dealer covers every opposing bet from their stack.
// The optional dealerUid and deck allow deterministic replay; otherwise the dealer is random.
function start(seats, stake, deck, dealerUid) {
  if (!Array.isArray(seats) || seats.length < 2 || seats.length > 6) throw new RangeError('Invalid seats');
  const dealer = dealerUid === undefined ? seats[randomInt(seats.length)]?.uid : dealerUid;
  seatsAreValid(seats, stake, dealer, false);
  const cards = deck === undefined ? shuffle() : cardList(deck, 36);
  const hands = Object.fromEntries(seats.map((seat, index) => [seat.uid, cards.slice(index * 3, index * 3 + 3)]));
  return {
    phase: 'showdown', dealerUid: dealer, stake, pot: stake * (seats.length - 1), rake: 0, hands,
    seats: seats.map(seat => ({uid: seat.uid, stack: seat.stack - (seat.uid === dealer ? 0 : stake),
      committed: seat.uid === dealer ? 0 : stake,
      ...(seat.isBot === undefined ? {} : {isBot: seat.isBot})})),
  };
}

function verifyState(state) {
  if (!state || (state.phase !== 'showdown' && state.phase !== 'settled') ||
      !Array.isArray(state.seats)) throw new RangeError('Invalid hand state');
  seatsAreValid(state.seats, state.stake, state.dealerUid, true);
  if (!state.hands || typeof state.hands !== 'object' || Array.isArray(state.hands) ||
      Object.keys(state.hands).length !== state.seats.length) throw new RangeError('Invalid hands');
  const dealt = new Set();
  for (const seat of state.seats) {
    if (!Object.hasOwn(state.hands, seat.uid)) throw new RangeError('Missing hand');
    for (const card of cardList(state.hands[seat.uid], 3)) {
      if (dealt.has(card)) throw new RangeError('Duplicate dealt card');
      dealt.add(card);
    }
  }
  const fee = state.stake - Math.floor(state.stake * 0.98);
  if (!Number.isSafeInteger(state.pot) || !Number.isSafeInteger(state.rake) ||
      (state.phase === 'showdown' ? state.pot !== state.stake * (state.seats.length - 1) || state.rake !== 0 :
        state.pot !== 0 || state.rake !== fee * (state.seats.length - 1) ||
        !Array.isArray(state.winners) || !state.winners.length ||
        new Set(state.winners).size !== state.winners.length ||
        state.winners.some(uid => !state.seats.some(seat => seat.uid === uid)) ||
        !state.seats.some(seat => seat.uid === state.nextDealerUid)) ||
      !Number.isSafeInteger(state.seats.reduce((sum, seat) => sum + seat.stack, 0) + state.pot + state.rake)) {
    throw new RangeError('Invalid pot or settlement');
  }
}

function privateHand(state, uid) {
  verifyState(state);
  if (typeof uid !== 'string' || !state.seats.some(seat => seat.uid === uid)) throw new RangeError('Unknown seat');
  return [...state.hands[uid]];
}

function publicView(state) {
  verifyState(state);
  return {
    seats: state.seats.map(seat => ({uid: seat.uid, stack: seat.stack, committed: seat.committed,
      ...(seat.isBot === undefined ? {} : {isBot: seat.isBot})})),
    dealerUid: state.dealerUid, board: [], turnUid: null, street: 'showdown', pot: state.pot,
    winners: state.phase === 'settled' ? [...state.winners] : [], status: 'settled',
  };
}

function settle(state) {
  verifyState(state);
  if (state.phase === 'settled') return state;
  const dealer = state.seats.find(seat => seat.uid === state.dealerUid);
  const stacks = new Map(state.seats.map(seat => [seat.uid, seat.stack]));
  const winners = [];
  const net = Math.floor(state.stake * 0.98); // room.js: (bet * .98) >> 0.
  for (const seat of state.seats) {
    if (seat === dealer) continue;
    if (compare(state.hands[seat.uid], state.hands[dealer.uid]) > 0) {
      winners.push(seat.uid);
      stacks.set(seat.uid, stacks.get(seat.uid) + state.stake + net);
      stacks.set(dealer.uid, stacks.get(dealer.uid) - state.stake);
    } else {
      stacks.set(dealer.uid, stacks.get(dealer.uid) + net);
    }
  }
  // room.js hands the next round's dealer role to the strongest point-10 hand.
  const tens = state.seats.filter(seat => evaluate(state.hands[seat.uid]).points === 10);
  const nextDealerUid = tens.length ? tens.reduce((best, seat) =>
    compare(state.hands[seat.uid], state.hands[best.uid]) > 0 ? seat : best).uid : dealer.uid;
  const result = {
    phase: 'settled', dealerUid: state.dealerUid, nextDealerUid, stake: state.stake, pot: 0,
    rake: (state.stake - net) * (state.seats.length - 1),
    hands: Object.fromEntries(state.seats.map(seat => [seat.uid, [...state.hands[seat.uid]]])),
    winners: winners.length ? winners : [dealer.uid],
    seats: state.seats.map(seat => ({uid: seat.uid, stack: stacks.get(seat.uid),
      committed: seat.committed, ...(seat.isBot === undefined ? {} : {isBot: seat.isBot})})),
  };
  verifyState(result);
  return result;
}

module.exports = {start, privateHand, publicView, settle, newDeck, evaluate, compare};

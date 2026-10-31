'use strict';

const {newDeck, shuffle, compareBaCay} = require('./card_games');
const CARD_SET = new Set(newDeck());

function cardList(cards, length) {
  if (!Array.isArray(cards) || cards.length !== length || Object.keys(cards).length !== length) {
    throw new RangeError(`Expected ${length} cards`);
  }
  const normalized = cards.map(card => {
    if (typeof card !== 'string' || !/^(?:10|[2-9TJQKA])[CDHS]$/.test(card)) {
      throw new TypeError('Invalid card');
    }
    const name = card.startsWith('10') ? `T${card[2]}` : card;
    if (!CARD_SET.has(name)) throw new TypeError('Invalid card');
    return name;
  });
  if (new Set(normalized).size !== length) throw new RangeError('Duplicate card');
  return normalized;
}

function seatsAreValid(seats, stake, started) {
  if (!Array.isArray(seats) || seats.length < 2 || seats.length > 6 ||
      Object.keys(seats).length !== seats.length || !Number.isSafeInteger(stake) || stake <= 0) {
    throw new RangeError('Invalid seats or stake');
  }
  const ids = new Set();
  let total = 0;
  for (const seat of seats) {
    if (!seat || typeof seat !== 'object' || Array.isArray(seat) ||
        typeof seat.uid !== 'string' || !seat.uid.trim() || ids.has(seat.uid) ||
        !Number.isSafeInteger(seat.stack) || seat.stack < (started ? 0 : stake) ||
        (seat.isBot !== undefined && typeof seat.isBot !== 'boolean') ||
        (started && seat.committed !== stake)) throw new RangeError('Invalid seat');
    ids.add(seat.uid);
    total += seat.stack;
    if (!Number.isSafeInteger(total)) throw new RangeError('Unsafe total');
  }
  if (!Number.isSafeInteger(stake * seats.length)) throw new RangeError('Unsafe pot');
}

// Buy-ins are pre-reserved. A supplied 52-card deck is dealt as-is, round-robin.
function start(seats, stake, deck) {
  seatsAreValid(seats, stake, false);
  const cards = deck === undefined ? shuffle() : cardList(deck, 52);
  const hands = Object.fromEntries(seats.map((seat, index) => [seat.uid,
    [cards[index], cards[index + seats.length], cards[index + 2 * seats.length]]]));
  return {
    phase: 'showdown', pot: stake * seats.length, hands,
    seats: seats.map(seat => ({
      uid: seat.uid, stack: seat.stack - stake, committed: stake,
      ...(seat.isBot === undefined ? {} : {isBot: seat.isBot}),
    })),
  };
}

function verifyState(state) {
  if (!state || (state.phase !== 'showdown' && state.phase !== 'settled') ||
      !Array.isArray(state.seats) || state.seats.length < 2 ||
      !Number.isSafeInteger(state.seats[0]?.committed)) throw new RangeError('Invalid hand state');
  const stake = state.seats[0].committed;
  seatsAreValid(state.seats, stake, true);
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
  if (!Number.isSafeInteger(state.seats.reduce((sum, seat) => sum + seat.stack, 0) + state.pot)) {
    throw new RangeError('Unsafe total');
  }
  if (state.phase === 'showdown' ? state.pot !== stake * state.seats.length :
    state.pot !== 0 || !Array.isArray(state.winners) || state.winners.length !== 1 ||
    !state.seats.some(seat => seat.uid === state.winners[0])) throw new RangeError('Invalid pot or settlement');
}

function privateHand(state, uid) {
  verifyState(state);
  if (typeof uid !== 'string' || !state.seats.some(seat => seat.uid === uid)) {
    throw new RangeError('Unknown seat');
  }
  return [...state.hands[uid]];
}

function publicView(state) {
  verifyState(state);
  return {
    seats: state.seats.map(seat => ({
      uid: seat.uid, stack: seat.stack, committed: seat.committed,
      ...(seat.isBot === undefined ? {} : {isBot: seat.isBot}),
    })),
    board: [], turnUid: null, street: 'showdown', pot: state.pot,
    winners: state.phase === 'settled' ? [...state.winners] : [], status: 'settled',
  };
}

// card_games tie rule: points (0 remainder is 10), then ranks A>K>...>2,
// then suits S>H>D>C. Distinct cards make exact ties impossible.
function settle(state) {
  verifyState(state);
  if (state.phase === 'settled') return state;
  let winner = state.seats[0];
  for (const seat of state.seats.slice(1)) {
    if (compareBaCay(state.hands[seat.uid], state.hands[winner.uid]) > 0) winner = seat;
  }
  return {
    phase: 'settled', pot: 0, hands: Object.fromEntries(state.seats.map(seat => [seat.uid, [...state.hands[seat.uid]]])),
    winners: [winner.uid],
    seats: state.seats.map(seat => ({
      uid: seat.uid, stack: seat.stack + (seat.uid === winner.uid ? state.pot : 0),
      committed: seat.committed,
      ...(seat.isBot === undefined ? {} : {isBot: seat.isBot}),
    })),
  };
}

module.exports = {start, privateHand, publicView, settle};

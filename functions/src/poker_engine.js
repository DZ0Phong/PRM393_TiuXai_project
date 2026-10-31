'use strict';

const {randomInt} = require('node:crypto');
const {newDeck, shuffle, compareHoldem} = require('./card_games');

const STREETS = ['preflop', 'flop', 'turn', 'river'];
const visibleCards = {preflop: 0, flop: 3, turn: 4, river: 5, showdown: 5};
const integer = n => Number.isSafeInteger(n) && n >= 0;
const live = seat => !seat.folded;
const able = seat => live(seat) && seat.stack > 0;

function start(seats, stake, deck) {
  if (!integer(stake) || stake === 0 || !Array.isArray(seats) || seats.length < 2 || seats.length > 6 ||
      seats.some(seat => !seat || typeof seat.uid !== 'string' || !seat.uid.trim() ||
        !integer(seat.stack) || seat.stack < stake ||
        (seat.isBot !== undefined && typeof seat.isBot !== 'boolean')) ||
      new Set(seats.map(seat => seat.uid)).size !== seats.length ||
      !Number.isSafeInteger(seats.reduce((sum, seat) => sum + seat.stack, 0))) {
    throw new RangeError('Invalid seats or stake');
  }
  const cards = deck === undefined ? shuffle() : deck;
  if (!Array.isArray(cards) || cards.length !== 52) throw new RangeError('Deck must have 52 cards');
  const normalized = cards.map(card => {
    if (typeof card !== 'string' || !/^(?:10|[2-9TJQKA])[CDHS]$/.test(card)) throw new TypeError('Invalid card');
    return card.startsWith('10') ? `T${card[2]}` : card;
  });
  if (new Set(normalized).size !== 52) throw new RangeError('Duplicate card');
  let index = 0;
  const players = seats.map(seat => ({uid: seat.uid, stack: seat.stack - stake, committed: 0,
    roundBet: 0, contributed: stake, folded: false,
    ...(seat.isBot === undefined ? {} : {isBot: seat.isBot})}));
  const hands = Object.fromEntries(players.map(player => [player.uid, []]));
  for (let round = 0; round < 2; round++) for (const player of players) hands[player.uid].push(normalized[index++]);
  const state = {phase: 'playing', street: 'preflop', stake, seats: players,
    hands, board: normalized.slice(index, index + 5), deck: normalized.slice(index + 5),
    pot: stake * players.length, roundBet: 0, raises: 0,
    pending: players.filter(able).map(p => p.uid), turnUid: null, winners: []};
  return advance(state, -1);
}

function settleNow(state) {
  const seats = state.seats.map(seat => ({...seat, payout: 0}));
  const contenders = seats.filter(live);
  let previous = 0;
  const levels = [...new Set(seats.map(seat => seat.contributed))].sort((a, b) => a - b);
  for (const level of levels) {
    const contributors = seats.filter(seat => seat.contributed >= level);
    const amount = (level - previous) * contributors.length;
    previous = level;
    const eligible = contributors.filter(live);
    if (!eligible.length) throw new Error('Unclaimable pot');
    let winners = eligible;
    if (eligible.length > 1) {
      winners = [eligible[0]];
      for (const player of eligible.slice(1)) {
        const comparison = compareHoldem([...state.board, ...state.hands[player.uid]],
          [...state.board, ...state.hands[winners[0].uid]]);
        if (comparison > 0) winners = [player];
        else if (comparison === 0) winners.push(player);
      }
    }
    const share = Math.floor(amount / winners.length);
    winners.forEach((winner, i) => {
      // Odd chips go to earlier seats, consistently across all pots.
      const award = share + (i < amount % winners.length ? 1 : 0);
      winner.stack += award;
      winner.payout += award;
    });
  }
  return {...state, phase: 'settled', street: contenders.length === 1 ? state.street : 'showdown',
    seats, pot: 0, pending: [], turnUid: null,
    winners: seats.filter(seat => seat.payout > 0).map(seat => seat.uid)};
}

function settle(state) {
  if (!state || !['playing', 'settled'].includes(state.phase)) throw new TypeError('Invalid state');
  if (state.phase === 'settled') return state;
  if (state.seats.filter(live).length !== 1 &&
      (state.street !== 'river' || state.pending.length !== 0)) {
    throw new RangeError('Betting is not complete');
  }
  return settleNow(state);
}

function nextTurn(state, after) {
  for (let step = 1; step <= state.seats.length; step++) {
    const uid = state.seats[(after + step) % state.seats.length].uid;
    if (state.pending.includes(uid)) return uid;
  }
  return null;
}

function advance(state, after) {
  let current = state;
  for (;;) {
    if (current.seats.filter(live).length === 1) return settleNow(current);
    const actionable = current.seats.filter(able);
    const pending = current.pending.filter(uid => actionable.some(seat => seat.uid === uid));
    if (pending.length && !(actionable.length <= 1 &&
        actionable[0].committed === current.roundBet)) {
      return {...current, pending, turnUid: nextTurn({...current, pending}, after)};
    }
    const next = STREETS.indexOf(current.street) + 1;
    if (next === STREETS.length) return settleNow(current);
    current = {...current, street: STREETS[next], roundBet: 0, raises: 0,
      seats: current.seats.map(seat => ({...seat, committed: 0, roundBet: 0})),
      pending: actionable.map(seat => seat.uid)};
    after = -1;
  }
}

function act(state, uid, action, stake) {
  if (!state || state.phase !== 'playing' || !integer(stake) || stake !== state.stake ||
      typeof uid !== 'string' || uid !== state.turnUid || !action || Array.isArray(action) ||
      typeof action !== 'object' || Object.keys(action).length !== 1 ||
      !['check', 'bet', 'call', 'raise', 'fold'].includes(action.type)) {
    throw new RangeError('Invalid turn or action');
  }
  const index = state.seats.findIndex(seat => seat.uid === uid);
  const seat = state.seats[index];
  if (!seat || !able(seat) || !state.pending.includes(uid)) throw new RangeError('Not actionable');
  const toCall = state.roundBet - seat.committed;
  let amount = 0;
  if (action.type === 'check' && toCall !== 0 ||
      action.type === 'call' && toCall <= 0 ||
      action.type === 'bet' && state.roundBet !== 0 ||
      action.type === 'raise' && (state.roundBet === 0 || state.raises !== 0)) {
    throw new RangeError('Illegal betting action');
  }
  if (action.type === 'call') amount = Math.min(toCall, seat.stack);
  if (action.type === 'bet') amount = stake;
  if (action.type === 'raise') amount = toCall + stake;
  if (amount > seat.stack) throw new RangeError('Insufficient stack');
  const updated = {...seat, stack: seat.stack - amount, committed: seat.committed + amount,
    roundBet: seat.committed + amount, contributed: seat.contributed + amount,
    folded: action.type === 'fold' ? true : seat.folded};
  const players = state.seats.map((player, i) => i === index ? updated : player);
  const aggression = action.type === 'bet' || action.type === 'raise';
  const next = {...state, seats: players, pot: state.pot + amount,
    roundBet: aggression ? updated.committed : state.roundBet,
    raises: state.raises + (action.type === 'raise' ? 1 : 0),
    pending: aggression ? players.filter(player => player.uid !== uid && able(player)).map(player => player.uid) :
      state.pending.filter(id => id !== uid)};
  return advance(next, index);
}

function publicView(state) {
  if (!state || !['playing', 'settled'].includes(state.phase)) throw new TypeError('Invalid state');
  return {seats: state.seats.map(seat => ({uid: seat.uid, stack: seat.stack,
    committed: seat.committed, roundBet: seat.roundBet, folded: seat.folded,
    ...(seat.isBot === undefined ? {} : {isBot: seat.isBot})})),
  turnUid: state.turnUid, street: state.street,
  board: state.board.slice(0, visibleCards[state.street]), pot: state.pot,
  winners: [...state.winners], status: state.phase};
}

function privateHand(state, uid) {
  if (!state || !state.seats || !state.seats.some(player => player.uid === uid)) throw new RangeError('Unknown seat');
  return [...state.hands[uid]];
}

function canCheck(state, uid) {
  if (!state || state.phase !== 'playing' || typeof uid !== 'string' || uid !== state.turnUid ||
      !Array.isArray(state.seats) || !Array.isArray(state.pending) || !state.pending.includes(uid)) return false;
  const seat = state.seats.find(player => player.uid === uid);
  return Boolean(seat && able(seat) && seat.committed === state.roundBet);
}

function chooseBotAction(state, uid, rng = randomInt) {
  if (typeof rng !== 'function') throw new TypeError('Invalid random source');
  const candidates = ['check', 'call', 'bet', 'raise', 'fold'].map(type => ({type}));
  const legal = candidates.filter(action => {
    try { act(state, uid, action, state.stake); return true; } catch (error) {
      if (error instanceof RangeError) return false;
      throw error;
    }
  });
  if (!legal.length) throw new RangeError('Bot has no legal action');
  const choice = rng(legal.length);
  if (!integer(choice) || choice >= legal.length) throw new RangeError('Invalid random choice');
  return legal[choice];
}

module.exports = {start, act, settle, canCheck, publicView, privateHand, chooseBotAction};

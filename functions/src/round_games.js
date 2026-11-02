'use strict';

const crypto = require('node:crypto');

// Source face order: Hươu, Bầu, Gà, Cá, Cua, Tôm (BauCua_cuoc 0..5).
const faces = Object.freeze(['nai', 'bau', 'ga', 'ca', 'cua', 'tom']);
const games = Object.freeze({
  tai_xiu: Object.freeze({sides: Object.freeze(['tai', 'xiu']), dice: 3, rule: 'Ba xúc xắc; bộ ba thua cả Tài và Xỉu. Nếu không phải bộ ba, tổng <= 10 là Xỉu, >= 11 là Tài. Cửa thắng nhận gốc + 98% lãi trên phần cược không được hoàn; chỉ hoàn phần cược dư khi cả Tài và Xỉu đều có cược.'}),
  bau_cua: Object.freeze({sides: faces, dice: 3, rule: 'Ba mặt Hươu/Bầu/Gà/Cá/Cua/Tôm; trúng nhận gốc + 98% × số mặt trúng × cược.'}),
  xoc_xoc: Object.freeze({sides: Object.freeze(['chan', 'le', 'red3', 'red4', 'white3', 'white4']), coins: 4, rule: 'Bốn đồng xu; Chẵn/Lẻ 1.98×, ba đỏ/trắng 3.94×, bốn đỏ/trắng 14.7× tiền cược.'}),
});

function validateBet(game, side, amount) {
  return typeof game === 'string' && Object.hasOwn(games, game) && games[game].sides.includes(side) &&
    Number.isSafeInteger(amount) && amount >= 1000 && amount <= 1000000 && amount % 100 === 0 &&
    (game !== 'xoc_xoc' || amount % 1000 === 0);
}

function validateOutcome(game, result) {
  if (typeof game !== 'string' || !Object.hasOwn(games, game) || !Array.isArray(result)) return false;
  const length = game === 'xoc_xoc' ? 4 : 3;
  if (result.length !== length || Object.keys(result).length !== length) return false;
  for (let i = 0; i < length; i++) {
    if (!Object.hasOwn(result, i)) return false;
    const value = result[i];
    if (game === 'bau_cua' ? !faces.includes(value) :
      !Number.isSafeInteger(value) || value < (game === 'xoc_xoc' ? 0 : 1) ||
      value > (game === 'xoc_xoc' ? 1 : 6)) return false;
  }
  return true;
}

function randomOutcome(game) {
  if (typeof game !== 'string' || !Object.hasOwn(games, game)) throw new RangeError('Game không hợp lệ');
  return Array.from({length: game === 'xoc_xoc' ? 4 : 3}, () => {
    const n = crypto.randomInt(game === 'xoc_xoc' ? 2 : 6);
    return game === 'bau_cua' ? faces[n] : game === 'tai_xiu' ? n + 1 : n;
  });
}

function describeOutcome(game, result) {
  if (!validateOutcome(game, result)) throw new RangeError('Kết quả không hợp lệ');
  if (game === 'bau_cua') {
    const counts = Object.fromEntries(faces.map(face => [face, result.filter(die => die === face).length]));
    return {dice: [...result], counts};
  }
  if (game === 'xoc_xoc') {
    const ones = result.reduce((sum, bit) => sum + bit, 0);
    return {coins: [...result], ones, side: ones % 2 === 0 ? 'chan' : 'le',
      winningSides: [ones % 2 === 0 ? 'chan' : 'le',
        ...(ones === 3 ? ['red3'] : ones === 4 ? ['red4'] : []),
        ...(ones === 1 ? ['white3'] : ones === 0 ? ['white4'] : [])]};
  }
  const total = result.reduce((sum, die) => sum + die, 0);
  const triple = result[0] === result[1] && result[1] === result[2];
  return {dice: [...result], total, triple, side: triple ? null : total > 10 ? 'tai' : 'xiu'};
}

function payoutStake(game, side, amount, description) {
  if (game === 'bau_cua') {
    const matches = description.counts[side];
    return matches ? amount + amount * matches * 98 / 100 : 0;
  }
  if (game === 'xoc_xoc') {
    if (!description.winningSides.includes(side)) return 0;
    return amount * (['chan', 'le'].includes(side) ? 198 : ['red3', 'white3'].includes(side) ? 394 : 1470) / 100;
  }
  return description.side === side ? amount + amount - Math.ceil(amount * 2 / 100) : 0;
}

function payout(game, side, amount, result) {
  if (!validateBet(game, side, amount)) throw new RangeError('Cược không hợp lệ');
  return payoutStake(game, side, amount, describeOutcome(game, result));
}

// Return excess from the larger pool only when both sides have accepted bets.
// With no opposing pool, a solo player's wager is exposed to the result normally.
// Use first-bet timestamp + uid for a stable allocation.
function creditsForRound(game, bets, result) {
  const outcome = describeOutcome(game, result);
  const refund = new Map();
  if (game === 'tai_xiu') {
    const totals = {tai: 0, xiu: 0};
    for (const b of bets) totals[b.stakes.tai ? 'tai' : 'xiu'] += b.amount;
    if (totals.tai > 0 && totals.xiu > 0) {
      const majority = totals.tai > totals.xiu ? 'tai' : 'xiu';
      let excess = Math.abs(totals.tai - totals.xiu);
      for (const b of [...bets].sort((a, b) => a.atMillis - b.atMillis || a.uid.localeCompare(b.uid))) {
        if (b.stakes[majority] && excess) {
          const returned = Math.min(excess, b.amount);
          refund.set(b.uid, returned);
          excess -= returned;
        }
      }
    }
  }
  return bets.map(b => {
    const returned = refund.get(b.uid) || 0;
    const credit = returned + Object.entries(b.stakes).reduce((sum, [side, amount]) =>
      sum + payoutStake(game, side, amount - (game === 'tai_xiu' ? returned : 0), outcome), 0);
    return {uid: b.uid, credit, refund: returned};
  });
}

module.exports = {validateBet, validateOutcome, randomOutcome, payout, describeOutcome, creditsForRound, games};

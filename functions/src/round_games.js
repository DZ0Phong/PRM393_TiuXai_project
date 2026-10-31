'use strict';

const crypto = require('node:crypto');

const faces = Object.freeze(['bau', 'cua', 'tom', 'ca', 'ga', 'nai']);
const games = Object.freeze({
  tai_xiu: Object.freeze({sides: Object.freeze(['tai', 'xiu']), dice: 3, rule: 'Ba xúc xắc 1–6; tổng từ 11 là tài, dưới 11 là xỉu; bộ ba đồng mặt thua cả hai; trúng nhận 2 lần tiền cược.'}),
  bau_cua: Object.freeze({sides: faces, dice: 3, rule: 'Ba xúc xắc sáu mặt; trúng nhận tiền cược nhân (1 + số mặt khớp).'}),
  xoc_xoc: Object.freeze({sides: Object.freeze(['chan', 'le']), coins: 4, rule: 'Luật mô phỏng: 4 đồng xu 0/1; tổng bit chẵn là chẵn, lẻ là lẻ; trúng nhận 2 lần tiền cược.'}),
});

function validateBet(game, side, amount) {
  return typeof game === 'string' && Object.hasOwn(games, game) && games[game].sides.includes(side) &&
    Number.isSafeInteger(amount) && amount >= 10 && amount <= 1000;
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
    return {coins: [...result], ones, side: ones % 2 === 0 ? 'chan' : 'le'};
  }
  const total = result.reduce((sum, die) => sum + die, 0);
  const side = result.every(die => die === result[0]) ? 'triple' : total >= 11 ? 'tai' : 'xiu';
  return {dice: [...result], total, side};
}

function payout(game, side, amount, result) {
  if (!validateBet(game, side, amount)) throw new RangeError('Cược không hợp lệ');
  const description = describeOutcome(game, result);
  if (game === 'bau_cua') {
    const matches = description.counts[side];
    return matches ? amount * (1 + matches) : 0;
  }
  return description.side === side ? amount * 2 : 0;
}

module.exports = {validateBet, validateOutcome, randomOutcome, payout, describeOutcome, games};
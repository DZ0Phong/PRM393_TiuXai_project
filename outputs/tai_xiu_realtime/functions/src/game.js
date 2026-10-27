'use strict';
function outcome(dice) {
  if (!Array.isArray(dice) || dice.length !== 3 || dice.some(d => !Number.isInteger(d) || d < 1 || d > 6)) throw new Error('Ba xúc xắc phải từ 1 đến 6');
  if (dice.every(d => d === dice[0])) return 'triple';
  return dice.reduce((a,b) => a+b,0) >= 11 ? 'tai' : 'xiu';
}
function payout(side, amount, dice) { return outcome(dice) === side ? amount * 2 : 0; }
function validBet(side, amount) { return ['tai','xiu'].includes(side) && Number.isSafeInteger(amount) && amount >= 10 && amount <= 1000; }
module.exports = {outcome, payout, validBet};

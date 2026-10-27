'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {randomInt} = require('node:crypto');
const {outcome,payout,validBet} = require('./game');
initializeApp();
const db=getFirestore();
const room=db.doc('rooms/main');
const call=fn=>onCall({region:'asia-southeast1',maxInstances:10},async req=>{
  if(!req.auth) throw new HttpsError('unauthenticated','Đăng nhập trước');
  const profile=await db.doc(`users/${req.auth.uid}`).get();
  if(profile.data()?.blocked===true) throw new HttpsError('permission-denied','Tài khoản đã bị khóa truy cập game');
  return fn(req);
});
const admin=req=>{if(req.auth.token.admin!==true) throw new HttpsError('permission-denied','Chỉ Admin');};
const fail=message=>{throw new HttpsError('failed-precondition',message);};
function requestId(req){const id=req.data?.requestId;if(typeof id!=='string'||! /^[a-zA-Z0-9_-]{8,80}$/.test(id)) throw new HttpsError('invalid-argument','requestId không hợp lệ');return id;}
function audit(tx,actor,action,details){tx.create(db.collection('auditLogs').doc(),{actor,action,details,at:Timestamp.now()});}
function identifier(value){if(typeof value!=='string'||! /^[a-zA-Z0-9_-]{1,128}$/.test(value))throw new HttpsError('invalid-argument','ID không hợp lệ');return value;}
function explanation(value){if(typeof value!=='string'||value.trim().length<5||value.length>300)throw new HttpsError('invalid-argument','Nhập lý do 5–300 ký tự');return value.trim();}
function active(snapshot){if(!snapshot.exists)fail('Chưa tạo ví');if(snapshot.data().blocked===true)throw new HttpsError('permission-denied','Tài khoản đã bị khóa truy cập game');}
exports.ensureProfile=call(async req=>{
 const ref=db.doc(`users/${req.auth.uid}`);
 await db.runTransaction(async tx=>{const s=await tx.get(ref);if(!s.exists){tx.create(ref,{balance:10000,blocked:false,createdAt:Timestamp.now()});tx.create(ref.collection('operations').doc('welcome'),{kind:'welcome',delta:10000,balance:10000,at:Timestamp.now()});audit(tx,req.auth.uid,'WELCOME',{amount:10000});}});
 return {ok:true};
});
exports.wallet=call(async req=>{
 const id=requestId(req),{amount,kind}=req.data;
 if(!Number.isSafeInteger(amount)||amount<10||amount>1000||!['deposit','withdraw'].includes(kind)) throw new HttpsError('invalid-argument','10–1000 xu/lần');
 const user=db.doc(`users/${req.auth.uid}`),op=user.collection('operations').doc(`wallet_${id}`);
 return db.runTransaction(async tx=>{
  const [u,o]=await Promise.all([tx.get(user),tx.get(op)]);active(u);if(o.exists){if(o.data().kind!==kind||o.data().amount!==amount)throw new HttpsError('already-exists','requestId đã dùng cho thao tác khác');return o.data();}
  const delta=kind==='deposit'?amount:-amount,balance=u.data().balance+delta;
  if(balance<0||balance>100000)fail('Số dư phải từ 0 đến 100000');
  const result={kind,amount,delta,balance,at:Timestamp.now()};tx.update(user,{balance});tx.create(op,result);audit(tx,req.auth.uid,kind,result);return result;
 });
});
exports.startRound=call(async req=>{
 admin(req);const mode=req.data?.mode;if(!['random','admin'].includes(mode))throw new HttpsError('invalid-argument','Chọn chế độ');
 const ref=db.collection('rounds').doc();
 await db.runTransaction(async tx=>{
  const r=await tx.get(room);let previous;
  if(r.exists)previous=await tx.get(db.doc(`rounds/${r.data().roundId}`));
  if(previous?.exists&&!['settled','cancelled'].includes(previous.data().status))fail('Phiên trước chưa kết thúc');
  tx.create(ref,{mode,status:'open',closesAt:Timestamp.fromMillis(Date.now()+30000),createdAt:Timestamp.now(),betCount:0});
  tx.set(room,{roundId:ref.id});audit(tx,req.auth.uid,'START',{roundId:ref.id,mode});
 });return {roundId:ref.id};
});
exports.placeBet=call(async req=>{
 const {roundId,side,amount}=req.data||{};
 if(typeof roundId!=='string'||! /^[a-zA-Z0-9]{1,80}$/.test(roundId)||!validBet(side,amount))throw new HttpsError('invalid-argument','Cược không hợp lệ');
 const round=db.doc(`rounds/${roundId}`),user=db.doc(`users/${req.auth.uid}`),bet=round.collection('bets').doc(req.auth.uid);
 return db.runTransaction(async tx=>{
  const [r,u,b]=await Promise.all([tx.get(round),tx.get(user),tx.get(bet)]);
  active(u);if(b.exists){if(b.data().side!==side||b.data().amount!==amount)throw new HttpsError('already-exists','Đã đặt cược khác trong phiên này');return b.data();}if(!r.exists||r.data().status!=='open'||r.data().closesAt.toMillis()<=Date.now())fail('Đã khóa cược');
  if(!u.exists||u.data().balance<amount)fail('Không đủ xu');if(r.data().betCount>=100)fail('MVP tối đa 100 người/phiên');
  const data={uid:req.auth.uid,side,amount,at:Timestamp.now()};const balance=u.data().balance-amount;tx.update(user,{balance});tx.create(bet,data);tx.create(user.collection('operations').doc(`bet_${roundId}`),{kind:'bet',roundId,delta:-amount,balance,at:Timestamp.now()});tx.update(round,{betCount:r.data().betCount+1});audit(tx,req.auth.uid,'BET',{roundId,side,amount});return data;
 });
});
async function settle(roundId,actor,dice,reason){
 const ref=db.doc(`rounds/${roundId}`);
 return db.runTransaction(async tx=>{
  const r=await tx.get(ref);if(!r.exists)fail('Không có phiên');const data=r.data();if(data.status==='settled')return {ok:true};
  if(data.status!=='open')fail('Phiên đã bị hủy');
  if(data.closesAt.toMillis()>Date.now())fail('Chưa hết thời gian');
  if(data.mode==='admin'&&actor==='scheduler')return {waiting:true};
  const resultDice=data.mode==='admin'?dice:[randomInt(1,7),randomInt(1,7),randomInt(1,7)];
  try{outcome(resultDice);}catch{throw new HttpsError('invalid-argument','Xúc xắc không hợp lệ');}
  if(data.mode==='admin'&&(typeof reason!=='string'||reason.trim().length<5||reason.length>300))throw new HttpsError('invalid-argument','Nhập lý do 5–300 ký tự');
  const bets=await tx.get(ref.collection('bets'));
  const users=await Promise.all(bets.docs.map(b=>tx.get(db.doc(`users/${b.id}`))));
  bets.docs.forEach((b,i)=>{const credit=payout(b.data().side,b.data().amount,resultDice);const balance=users[i].data().balance+credit;tx.update(users[i].ref,{balance});tx.update(b.ref,{credit,settledAt:Timestamp.now()});tx.create(users[i].ref.collection('operations').doc(`result_${roundId}`),{kind:'payout',roundId,delta:credit,balance,at:Timestamp.now()});});
  tx.update(ref,{status:'settled',dice:resultDice,outcome:outcome(resultDice),reason:data.mode==='admin'?reason:'CSPRNG server',settledAt:Timestamp.now(),settledBy:actor});
  audit(tx,actor,'SETTLE',{roundId,mode:data.mode,dice:resultDice,reason:data.mode==='admin'?reason:'CSPRNG server'});return {ok:true};
 });
}
exports.settleRound=call(async req=>{admin(req);const id=req.data?.roundId;if(typeof id!=='string'||! /^[a-zA-Z0-9]{1,80}$/.test(id))throw new HttpsError('invalid-argument','ID phiên');return settle(id,req.auth.uid,req.data.dice,req.data.reason);});
exports.cancelRound=call(async req=>{
 admin(req);const id=identifier(req.data?.roundId),reason=explanation(req.data?.reason),ref=db.doc(`rounds/${id}`);
 return db.runTransaction(async tx=>{
  const r=await tx.get(ref);if(!r.exists)fail('Không có phiên');if(r.data().status==='cancelled')return {ok:true};if(r.data().status!=='open')fail('Không thể hủy phiên đã chốt');
  const bets=await tx.get(ref.collection('bets'));const users=await Promise.all(bets.docs.map(b=>tx.get(db.doc(`users/${b.id}`))));
  bets.docs.forEach((b,i)=>{const credit=b.data().amount,balance=users[i].data().balance+credit;tx.update(users[i].ref,{balance});tx.update(b.ref,{credit,refunded:true,settledAt:Timestamp.now()});tx.create(users[i].ref.collection('operations').doc(`result_${id}`),{kind:'refund',roundId:id,delta:credit,balance,at:Timestamp.now()});});
  tx.update(ref,{status:'cancelled',reason,cancelledBy:req.auth.uid,cancelledAt:Timestamp.now()});audit(tx,req.auth.uid,'CANCEL',{roundId:id,reason,refundedPlayers:bets.size});return {ok:true};
 });
});
exports.adjustBalance=call(async req=>{
 admin(req);const uid=identifier(req.data?.uid),id=requestId(req),reason=explanation(req.data?.reason),delta=req.data?.delta;
 if(!Number.isSafeInteger(delta)||delta===0||Math.abs(delta)>100000)throw new HttpsError('invalid-argument','Điều chỉnh ±1–100000 xu');
 const ref=db.doc(`users/${uid}`),op=ref.collection('operations').doc(`admin_${id}`);
 return db.runTransaction(async tx=>{const [u,o]=await Promise.all([tx.get(ref),tx.get(op)]);if(!u.exists)fail('Không có tài khoản');if(o.exists){if(o.data().delta!==delta||o.data().reason!==reason||o.data().actor!==req.auth.uid)throw new HttpsError('already-exists','requestId đã dùng');return o.data();}const balance=u.data().balance+delta;if(balance<0||balance>1000000)fail('Số dư sau điều chỉnh phải 0–1000000');const data={kind:'admin_adjust',delta,balance,reason,actor:req.auth.uid,at:Timestamp.now()};tx.update(ref,{balance});tx.create(op,data);audit(tx,req.auth.uid,'ADJUST_BALANCE',{uid,...data});return data;});
});
exports.setPlayerBlocked=call(async req=>{
 admin(req);const uid=identifier(req.data?.uid),reason=explanation(req.data?.reason),blocked=req.data?.blocked;
 if(typeof blocked!=='boolean')throw new HttpsError('invalid-argument','Trạng thái khóa không hợp lệ');if(uid===req.auth.uid)fail('Không tự khóa tài khoản quản trị');
 const ref=db.doc(`users/${uid}`);await db.runTransaction(async tx=>{const u=await tx.get(ref);if(!u.exists)fail('Không có tài khoản');if((u.data().blocked===true)===blocked)return;tx.update(ref,{blocked,blockReason:reason,blockedBy:req.auth.uid,blockUpdatedAt:Timestamp.now()});audit(tx,req.auth.uid,blocked?'BLOCK_PLAYER':'UNBLOCK_PLAYER',{uid,reason});});return {ok:true};
});
exports.tick=onSchedule({schedule:'every 1 minutes',region:'asia-southeast1'},async()=>{
 const due=await db.collection('rounds').where('status','==','open').where('closesAt','<=',Timestamp.now()).get();
 for(const r of due.docs)if(r.data().mode==='random')await settle(r.id,'scheduler');
});

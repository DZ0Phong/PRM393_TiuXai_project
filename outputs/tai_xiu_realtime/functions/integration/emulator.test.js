const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {initializeApp,deleteApp}=require('firebase/app');const {getAuth,connectAuthEmulator,createUserWithEmailAndPassword}=require('firebase/auth');
const {getFunctions,connectFunctionsEmulator,httpsCallable}=require('firebase/functions');const {doc,setDoc,getDoc}=require('firebase/firestore');
const {initializeApp:adminApp}=require('firebase-admin/app');const {getAuth:adminAuth}=require('firebase-admin/auth');const {getFirestore,Timestamp}=require('firebase-admin/firestore');
test('rules: deny client writes, isolate ví/cược, audit public authenticated',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-tai-xiu',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(require('node:path').join(__dirname,'../../firestore.rules'),'utf8')}});
 try{
  await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'users/alice'),{balance:100});await setDoc(doc(c.firestore(),'users/locked'),{balance:100,blocked:true});await setDoc(doc(c.firestore(),'rounds/rule-test'),{status:'open'});await setDoc(doc(c.firestore(),'auditLogs/test'),{action:'TEST'});});
  const alice=env.authenticatedContext('alice').firestore(),bob=env.authenticatedContext('bob').firestore(),anon=env.unauthenticatedContext().firestore(),admin=env.authenticatedContext('boss',{admin:true}).firestore();
  await assertSucceeds(getDoc(doc(alice,'users/alice')));await assertFails(getDoc(doc(bob,'users/alice')));await assertSucceeds(getDoc(doc(admin,'users/alice')));
  await assertFails(setDoc(doc(alice,'users/alice'),{balance:999999,admin:true}));await assertFails(setDoc(doc(admin,'auditLogs/test'),{action:'EDIT'}));
  await assertSucceeds(getDoc(doc(bob,'auditLogs/test')));await assertFails(getDoc(doc(anon,'auditLogs/test')));
  await assertFails(getDoc(doc(env.authenticatedContext('locked').firestore(),'rounds/rule-test')));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('locked').firestore(),'users/locked')));
 }finally{await env.cleanup();}
});
test('callable: multiplayer, quyền, cược trùng, deadline, settlement retry, ví retry',async()=>{
 const admin=adminApp({projectId:'demo-tai-xiu'});const db=getFirestore(admin);const apps=[];
 async function client(i){const app=initializeApp({projectId:'demo-tai-xiu',apiKey:'demo-key',appId:'demo'},`test-${i}-${Date.now()}`);apps.push(app);const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});const f=getFunctions(app,'asia-southeast1');connectFunctionsEmulator(f,'127.0.0.1',5001);const {user}=await createUserWithEmailAndPassword(auth,`test${i}-${Date.now()}@example.com`,'password123');return {user,call:async(name,data={})=>(await httpsCallable(f,name)(data)).data};}
 try{
 const boss=await client(0);await adminAuth(admin).setCustomUserClaims(boss.user.uid,{admin:true});await boss.user.getIdToken(true);await boss.call('ensureProfile');
 const players=await Promise.all([1,2,3,4,5].map(client));await Promise.all(players.map(p=>p.call('ensureProfile')));
 await assert.rejects(players[0].call('startRound',{mode:'admin'}));
 const {roundId}=await boss.call('startRound',{mode:'admin'});await assert.rejects(boss.call('startRound',{mode:'random'}));
 await Promise.all(players.map(p=>p.call('placeBet',{roundId,side:'tai',amount:100})));
 await Promise.all(Array.from({length:4},()=>players[0].call('placeBet',{roundId,side:'tai',amount:100})));
 assert.equal((await db.doc(`users/${players[0].user.uid}`).get()).data().balance,9900);
 await assert.rejects(boss.call('settleRound',{roundId,dice:[2,3,6],reason:'Demo công khai'}));
 await db.doc(`rounds/${roundId}`).update({closesAt:Timestamp.fromMillis(Date.now()-1000)});
 await assert.rejects(boss.call('placeBet',{roundId,side:'xiu',amount:100}));
 await assert.rejects(boss.call('settleRound',{roundId,dice:[0,3,6],reason:'Demo công khai'}));
 await Promise.all([1,2].map(()=>boss.call('settleRound',{roundId,dice:[2,3,6],reason:'Demo công khai'})));
 for(const p of players)assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance,10100);
 const p=players[0];await Promise.all([1,2].map(()=>p.call('wallet',{requestId:'same-request-123',kind:'deposit',amount:100})));
 assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance,10200);
 await assert.rejects(p.call('wallet',{requestId:'negative-123',kind:'withdraw',amount:-100}));
 const random=await boss.call('startRound',{mode:'random'});await db.doc(`rounds/${random.roundId}`).update({closesAt:Timestamp.fromMillis(Date.now()-1000)});await boss.call('settleRound',{roundId:random.roundId});
 assert.equal((await db.doc(`rounds/${random.roundId}`).get()).data().dice.length,3);
 // Admin quyền, điều chỉnh và khóa tài khoản có hiệu lực với token cũ.
 await assert.rejects(p.call('adjustBalance',{uid:p.user.uid,delta:100,reason:'Không có quyền',requestId:'forbidden-123'}));
 await assert.rejects(p.call('cancelRound',{roundId:random.roundId,reason:'Không có quyền'}));
 await assert.rejects(p.call('setPlayerBlocked',{uid:players[1].user.uid,blocked:true,reason:'Không có quyền'}));
 const adjust={uid:p.user.uid,delta:-200,reason:'Điều chỉnh thử nghiệm',requestId:'admin-adjust-123'};
 await Promise.all([1,2].map(()=>boss.call('adjustBalance',adjust)));
 assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance,10000);
 await assert.rejects(boss.call('adjustBalance',{...adjust,delta:100}));
 await assert.rejects(boss.call('adjustBalance',{...adjust,delta:-100001,requestId:'invalid-adjust-123'}));
 await assert.rejects(boss.call('setPlayerBlocked',{uid:boss.user.uid,blocked:true,reason:'Không tự khóa'}));
 await boss.call('setPlayerBlocked',{uid:p.user.uid,blocked:true,reason:'Kiểm thử khóa game'});
 await assert.rejects(p.call('wallet',{requestId:'blocked-wallet-123',kind:'deposit',amount:100}));
 await assert.rejects(p.call('ensureProfile'));
 await boss.call('setPlayerBlocked',{uid:p.user.uid,blocked:false,reason:'Kiểm thử mở khóa'});
 const cancel=await boss.call('startRound',{mode:'admin'});
 const q=players[1];
 await q.call('wallet',{requestId:`result_${cancel.roundId}`,kind:'deposit',amount:100});
 await q.call('placeBet',{roundId:cancel.roundId,side:'xiu',amount:100});
 await p.call('placeBet',{roundId:cancel.roundId,side:'xiu',amount:100});
 await assert.rejects(p.call('placeBet',{roundId:cancel.roundId,side:'tai',amount:100}));
 await Promise.all([1,2].map(()=>boss.call('cancelRound',{roundId:cancel.roundId,reason:'Hủy phiên thử nghiệm'})));
 assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance,10000);
 assert.equal((await db.doc(`rounds/${cancel.roundId}`).get()).data().status,'cancelled');
 assert.equal((await db.doc(`users/${q.user.uid}`).get()).data().balance,10200);
 assert.equal((await db.doc(`users/${q.user.uid}/operations/result_${cancel.roundId}`).get()).data().kind,'refund');
 await assert.rejects(boss.call('settleRound',{roundId:cancel.roundId,dice:[2,3,6],reason:'Không chốt phiên hủy'}));
 const race=await boss.call('startRound',{mode:'admin'});await p.call('placeBet',{roundId:race.roundId,side:'tai',amount:100});
 await db.doc(`rounds/${race.roundId}`).update({closesAt:Timestamp.fromMillis(Date.now()-1000)});
 const raced=await Promise.allSettled([boss.call('cancelRound',{roundId:race.roundId,reason:'Hủy đồng thời chốt'}),boss.call('settleRound',{roundId:race.roundId,dice:[2,3,6],reason:'Chốt đồng thời hủy'})]);
 assert.equal(raced.filter(r=>r.status==='fulfilled').length,1);
 const racedRound=(await db.doc(`rounds/${race.roundId}`).get()).data();
 assert.equal((await db.doc(`users/${p.user.uid}`).get()).data().balance,racedRound.status==='cancelled'?10000:10100);
 const ledger=(await db.doc(`users/${p.user.uid}/operations/result_${race.roundId}`).get()).data();
 assert.equal(ledger.kind,racedRound.status==='cancelled'?'refund':'payout');
 const logs=await db.collection('auditLogs').where('action','==','ADJUST_BALANCE').get();assert.equal(logs.size,1);
 }finally{await Promise.all(apps.map(deleteApp));}
});

'use strict';
// Chỉ tạo danh tính demo; ví do ensureProfile tạo khi đăng nhập lần đầu.
if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') {
  throw new Error('Chỉ chạy với FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099');
}
if (process.env.GCLOUD_PROJECT !== 'demo-tai-xiu') {
  throw new Error('Chỉ chạy với GCLOUD_PROJECT=demo-tai-xiu');
}
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
initializeApp({projectId:'demo-tai-xiu'});
async function main(){
  const auth=getAuth();
  for(let i=0;i<=5;i++){
    const uid=i===0?'demo-admin':`demo-player-${i}`;
    const email=i===0?'admin@demo.test':`player${i}@demo.test`;
    try{await auth.getUser(uid);}catch(e){if(e.code!=='auth/user-not-found')throw e;await auth.createUser({uid,email,password:'Demo123456!'});}
    await auth.setCustomUserClaims(uid,{admin:i===0});
    console.log(`${i===0?'Admin':'Player'}: ${email} / Demo123456!`);
  }
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});

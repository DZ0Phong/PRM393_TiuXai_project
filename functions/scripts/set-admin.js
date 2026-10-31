// Chỉ chạy bằng tài khoản dịch vụ tin cậy, tuyệt đối không đưa key vào Git.
const {initializeApp}=require('firebase-admin/app');const {getAuth}=require('firebase-admin/auth');initializeApp();
const uid=process.argv[2];if(!uid)throw Error('node scripts/set-admin.js UID [revoke]');
(async()=>{const auth=getAuth();const user=await auth.getUser(uid);await auth.setCustomUserClaims(uid,{...user.customClaims,admin:process.argv[3]!=='revoke'});console.log('Đã cập nhật role. Đăng nhập lại để làm mới token.');})();

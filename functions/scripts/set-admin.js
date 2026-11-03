// Chạy bằng Admin SDK credentials tin cậy; chỉ UID đã chọn được đổi quyền.
const uid = process.argv[2];
const projectId = process.env.GCLOUD_PROJECT;
const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!uid || !projectId) throw Error('Cần UID và GCLOUD_PROJECT rõ ràng');
if (!['demo-tai-xiu', 'ad2-8abfa540'].includes(projectId)) {
  throw Error('Chỉ cho phép project demo-tai-xiu hoặc ad2-8abfa540');
}
if (projectId === 'demo-tai-xiu' && emulatorHost !== '127.0.0.1:9099') {
  throw Error('Project demo-tai-xiu chỉ dùng với Auth Emulator local');
}
if (projectId !== 'demo-tai-xiu' && emulatorHost) {
  throw Error('Không cấp quyền project thật khi FIREBASE_AUTH_EMULATOR_HOST còn bật');
}
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
initializeApp({projectId});
(async () => {
  const auth = getAuth();
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {...user.customClaims, admin: process.argv[3] !== 'revoke'});
  console.log(`Đã cập nhật role tại ${projectId}. Đăng nhập lại để làm mới token.`);
})().catch((error) => { console.error(error.message); process.exitCode = 1; });

const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const script = path.join(__dirname, '..', 'scripts', 'set-admin.js');

function run(env) {
  return spawnSync(process.execPath, [script, 'some-uid'], {
    env: {...process.env, GCLOUD_PROJECT: '', FIREBASE_AUTH_EMULATOR_HOST: '', ...env},
    encoding: 'utf8',
  });
}

test('admin script requires an explicit project', () => {
  const result = run({});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /GCLOUD_PROJECT/);
});

test('demo project cannot silently target production', () => {
  const result = run({GCLOUD_PROJECT: 'demo-tai-xiu'});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Auth Emulator local/);
});

test('live project refuses an inherited emulator host', () => {
  const result = run({GCLOUD_PROJECT: 'ad2-8abfa540', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099'});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /project thật/);
});

test('admin script refuses an unrelated project', () => {
  const result = run({GCLOUD_PROJECT: 'other-project'});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Chỉ cho phép project/);
});

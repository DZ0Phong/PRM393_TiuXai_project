const {test} = require('node:test');
const assert = require('node:assert/strict');
const {HttpsError} = require('firebase-functions/v2/https');
const {createApiServer} = require('../src/online_server');

test('private backend authenticates tokens, rejects unknown/scheduler calls and translates errors', async () => {
  const server = createApiServer({handlers: {
    placeBet: {run: async ({auth, data}) => ({uid: auth.uid, data})},
    setRoundOutcome: {run: async ({auth}) => { if (!auth.token.admin) throw new HttpsError('permission-denied', 'Admin only'); return {ok: true}; }},
    tick: {run: async () => ({ok: true})},
  }, verifyToken: async (token) => { if (token !== 'valid') throw Error('bad token'); return {uid: 'alice', admin: false}; }});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}`;
    const post = async (name, token, data = {}) => {
      const response = await fetch(`${url}/api/${name}`, {method: 'POST', headers: {'content-type': 'application/json', ...(token ? {authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data})});
      return {status: response.status, body: await response.json()};
    };
    assert.deepEqual(await post('placeBet', 'valid', {side: 'tai'}), {status: 200, body: {data: {uid: 'alice', data: {side: 'tai'}}}});
    assert.equal((await post('placeBet')).status, 401);
    assert.equal((await post('placeBet', 'bad')).status, 401); // no details leaked
    assert.equal((await post('setRoundOutcome', 'valid')).status, 403);
    assert.equal((await post('tick', 'valid')).status, 404);
    assert.equal((await post('unknown', 'valid')).status, 404);
    assert.equal((await fetch(`${url}/health`)).status, 200);
  } finally { server.close(); }
});

test('per-UID quota rejects repeated expensive reads before invoking handler', async () => {
  let reads = 0;
  const server = createApiServer({handlers: {getLeaderboard: {run: async () => { reads++; return []; }}},
    verifyToken: async (token) => ({uid: token})});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/getLeaderboard`;
    const call = async (uid) => (await fetch(url, {method: 'POST', headers: {
      'content-type': 'application/json', authorization: `Bearer ${uid}`,
    }, body: JSON.stringify({data: {}})})).status;
    for (let i = 0; i < 6; i++) assert.equal(await call('alice'), 200);
    assert.equal(await call('alice'), 429);
    assert.equal(reads, 6);
    assert.equal(await call('bob'), 200);
  } finally { server.close(); }
});


test('Android callable integer wrappers decode recursively and reject unsafe values', async () => {
  const server = createApiServer({handlers: {placeBet: {run: async ({data}) => data}},
    verifyToken: async () => ({uid: 'alice'})});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/placeBet`;
    const post = async (data) => {
      const response = await fetch(url, {method: 'POST', headers: {
        'content-type': 'application/json', authorization: 'Bearer valid',
      }, body: JSON.stringify({data})});
      return {status: response.status, body: await response.json()};
    };
    const int64 = value => ({'@type': 'type.googleapis.com/google.protobuf.Int64Value', value});
    assert.deepEqual(await post({amount: int64('10000'), nested: [int64('-2'), 1000]}),
        {status: 200, body: {data: {amount: 10000, nested: [-2, 1000]}}});
    assert.deepEqual(await post({amount: {'@type': 'type.googleapis.com/google.protobuf.UInt64Value', value: '5'}}),
        {status: 200, body: {data: {amount: 5}}});
    for (const amount of [int64('9007199254740992'), int64('10.5'), int64(10000),
      {...int64('10000'), extra: true}]) {
      assert.equal((await post({amount})).status, 400);
    }
  } finally { server.close(); }
});

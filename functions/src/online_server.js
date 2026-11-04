'use strict';
const http = require('node:http');
const {HttpsError} = require('firebase-functions/v2/https');
const statuses = {'invalid-argument': 400, unauthenticated: 401, 'permission-denied': 403,
  'not-found': 404, 'already-exists': 409, 'resource-exhausted': 429,
  'failed-precondition': 400, aborted: 409, unavailable: 503};
function reply(res, status, body) {
  res.writeHead(status, {'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'});
  res.end(JSON.stringify(body));
}
function createApiServer({handlers, verifyToken, maxBytes = 65536}) {
  return http.createServer(async (req, res) => {
    if (req.url === '/health' && req.method === 'GET') return reply(res, 200, {ok: true});
    const match = /^\/api\/([A-Za-z][A-Za-z0-9]*)$/.exec(req.url || '');
    if (!match || req.method !== 'POST' || !handlers[match[1]] || typeof handlers[match[1]].run !== 'function'
        || match[1] === 'tick' || match[1] === 'cardTick') return reply(res, 404, {error: {status: 'NOT_FOUND', message: 'Không có lệnh'}});
    if (!/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'] || ''))
      return reply(res, 400, {error: {status: 'INVALID_ARGUMENT', message: 'Yêu cầu JSON'}});
    const token = /^Bearer (\S+)$/i.exec(req.headers.authorization || '')?.[1];
    if (!token) return reply(res, 401, {error: {status: 'UNAUTHENTICATED', message: 'Đăng nhập trước'}});
    try {
      let bytes = 0, body = '';
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > maxBytes) return reply(res, 413, {error: {status: 'RESOURCE_EXHAUSTED', message: 'Yêu cầu quá lớn'}});
        body += chunk;
      }
      let payload;
      try { payload = JSON.parse(body); } catch { throw new HttpsError('invalid-argument', 'JSON không hợp lệ'); }
      if (!payload || typeof payload !== 'object' || Array.isArray(payload) || !Object.hasOwn(payload, 'data') || Object.keys(payload).length !== 1)
        throw new HttpsError('invalid-argument', 'Thiếu data');
      let auth;
      try { auth = await verifyToken(token); } catch { return reply(res, 401, {error: {status: 'UNAUTHENTICATED', message: 'Phiên đăng nhập không hợp lệ'}}); }
      const data = await handlers[match[1]].run({data: payload.data, auth: {uid: auth.uid, token: auth}});
      reply(res, 200, {data: data ?? null});
    } catch (error) {
      const code = error instanceof HttpsError ? error.code : 'internal';
      if (code === 'internal') console.error('Backend callable failed:', error);
      reply(res, statuses[code] || 500, {error: {status: code.toUpperCase().replaceAll('-', '_'),
        message: error instanceof HttpsError ? error.message : 'Lỗi máy chủ'}});
    }
  });
}
module.exports = {createApiServer};

// @ts-check

import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeVirtualKemomimiRelayServer, VirtualKemomimiRelayServerList } from './virtual-kemomimi-relay.js';

const logger = { warn() {} };

/**
 * @param {unknown} payload
 * @param {number} [status]
 * @returns {Response}
 */
const jsonResponse = (payload, status = 200) => new Response(JSON.stringify(payload), {
  headers: { 'Content-Type': 'application/json' },
  status,
});

test('normalizes supported relay server entries', () => {
  assert.equal(normalizeVirtualKemomimiRelayServer('Example.COM.'), 'example.com');
  assert.equal(normalizeVirtualKemomimiRelayServer({ Url: 'https://relay.example/path' }), 'relay.example');
  assert.equal(normalizeVirtualKemomimiRelayServer({ domain: '@social.example' }), 'social.example');
  assert.equal(normalizeVirtualKemomimiRelayServer({ unexpected: true }), undefined);
});

test('caches a successful list for the configured TTL', async () => {
  let currentTime = 0;
  let requests = 0;
  const serverList = new VirtualKemomimiRelayServerList({
    logger,
    now: () => currentTime,
    successTtl: 100,
    fetchImpl: async () => {
      requests += 1;
      return jsonResponse([{ Url: 'https://relay.example' }]);
    },
  });

  assert.deepEqual([...await serverList.refresh()], ['relay.example']);
  assert.deepEqual([...await serverList.refresh()], ['relay.example']);
  assert.equal(requests, 1);

  currentTime = 101;
  await serverList.refresh();
  assert.equal(requests, 2);
});

test('retains the last successful list and retries failures on a shorter TTL', async () => {
  let currentTime = 0;
  let requests = 0;
  let warnings = 0;
  const serverList = new VirtualKemomimiRelayServerList({
    logger: { warn: () => { warnings += 1; } },
    now: () => currentTime,
    successTtl: 10,
    retryTtl: 10,
    fetchImpl: async () => {
      requests += 1;
      return requests === 1 ? jsonResponse(['relay.example']) : jsonResponse({}, 503);
    },
  });

  await serverList.refresh();
  currentTime = 11;

  assert.deepEqual([...await serverList.refresh()], ['relay.example']);
  assert.equal(warnings, 1);

  currentTime = 15;
  assert.deepEqual([...serverList.cachedDomains()], ['relay.example']);
  assert.equal(requests, 2);

  currentTime = 22;
  await serverList.refresh();
  assert.equal(requests, 3);
});

test('de-duplicates concurrent refreshes', async () => {
  /** @type {((response: Response) => void)|undefined} */
  let resolveFetch;
  let requests = 0;
  const serverList = new VirtualKemomimiRelayServerList({
    logger,
    fetchImpl: () => {
      requests += 1;
      return new Promise(resolve => {
        resolveFetch = resolve;
      });
    },
  });

  const firstRefresh = serverList.refresh();
  const secondRefresh = serverList.refresh();

  assert.equal(firstRefresh, secondRefresh);
  assert.equal(requests, 1);
  assert.ok(resolveFetch);
  resolveFetch(jsonResponse(['relay.example']));
  await firstRefresh;
});

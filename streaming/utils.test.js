// @ts-check

import assert from 'node:assert/strict';
import test from 'node:test';

import { statusFilterTargets } from './utils.js';

test('collects the author, mentions, and remote domain of a status', () => {
  const status = {
    account: { id: '1', acct: 'author@relay.example' },
    mentions: [{ id: '2', acct: 'mentioned@example.com' }],
  };

  assert.deepEqual(statusFilterTargets(status), {
    authorAccountIds: ['1'],
    targetAccountIds: ['1', '2'],
    accountDomains: ['relay.example'],
  });
});

test('also collects the author, mentions, and domain of a boosted status', () => {
  const status = {
    account: { id: '1', acct: 'booster@relay.example' },
    mentions: [],
    reblog: {
      account: { id: '2', acct: 'original@original.example' },
      mentions: [{ id: '3', acct: 'mentioned@example.com' }],
    },
  };

  assert.deepEqual(statusFilterTargets(status), {
    authorAccountIds: ['1', '2'],
    targetAccountIds: ['1', '2', '3'],
    accountDomains: ['relay.example', 'original.example'],
  });
});

test('does not return a domain for local accounts and de-duplicates targets', () => {
  const status = {
    account: { id: '1', acct: 'local' },
  };

  assert.deepEqual(statusFilterTargets(status), {
    authorAccountIds: ['1'],
    targetAccountIds: ['1'],
    accountDomains: [],
  });
});

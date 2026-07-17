// @ts-check

export const VIRTUAL_KEMOMIMI_RELAY_SERVERS_URL = 'https://relay.virtualkemomimi.net/api/servers';

const DEFAULT_SUCCESS_TTL = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_RETRY_TTL = 5 * 60 * 1000;
const DEFAULT_REQUEST_TIMEOUT = 10 * 1000;

/**
 * @param {unknown} entry
 * @returns {string|undefined}
 */
export const normalizeVirtualKemomimiRelayServer = entry => {
  let value;

  if (typeof entry === 'string') {
    value = entry;
  } else if (entry && typeof entry === 'object') {
    const record = /** @type {Record<string, unknown>} */ (entry);
    value = record.domain || record.host || record.server || record.url || record.Url;
  }

  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined;
  }

  try {
    value = value.trim().replace(/^@/, '');
    const parsed = new URL(/^https?:\/\//i.test(value) ? value : `https://${value}`);
    return parsed.hostname.toLowerCase().replace(/\.$/, '') || undefined;
  } catch {
    return undefined;
  }
};

/**
 * Caches the relay server list while retaining the last successful result
 * during transient failures.
 */
export class VirtualKemomimiRelayServerList {
  /**
   * @param {object} options
   * @param {Pick<import('pino').Logger, 'warn'>} options.logger
   * @param {typeof fetch} [options.fetchImpl]
   * @param {() => number} [options.now]
   * @param {string} [options.url]
   * @param {number} [options.successTtl]
   * @param {number} [options.retryTtl]
   * @param {number} [options.requestTimeout]
   */
  constructor({
    logger,
    fetchImpl = globalThis.fetch,
    now = Date.now,
    url = VIRTUAL_KEMOMIMI_RELAY_SERVERS_URL,
    successTtl = DEFAULT_SUCCESS_TTL,
    retryTtl = DEFAULT_RETRY_TTL,
    requestTimeout = DEFAULT_REQUEST_TIMEOUT,
  }) {
    this.logger = logger;
    this.fetchImpl = fetchImpl;
    this.now = now;
    this.url = url;
    this.successTtl = successTtl;
    this.retryTtl = retryTtl;
    this.requestTimeout = requestTimeout;
    /** @type {Set<string>} */
    this.domains = new Set();
    this.expiresAt = 0;
    /** @type {Promise<Set<string>>|undefined} */
    this.refreshPromise = undefined;
  }

  /**
   * Returns the current list immediately and starts a refresh when stale.
   * @returns {Set<string>}
   */
  cachedDomains() {
    if (this.expiresAt <= this.now()) {
      void this.refresh();
    }

    return this.domains;
  }

  /**
   * Refreshes the list once per TTL, de-duplicating concurrent requests.
   * @returns {Promise<Set<string>>}
   */
  refresh() {
    const now = this.now();

    if (this.expiresAt > now) {
      return Promise.resolve(this.domains);
    }

    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.fetchImpl(this.url, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.requestTimeout),
    }).then(async response => {
      if (!response.ok) {
        throw new Error(`VirtualKemomimi relay server list returned ${response.status}`);
      }

      const payload = /** @type {unknown} */ (await response.json());
      const record = payload && typeof payload === 'object' ? /** @type {Record<string, unknown>} */ (payload) : {};
      const candidateEntries = Array.isArray(payload) ? payload : record.servers ?? record.domains ?? record.data ?? record.items ?? [];
      const entries = Array.isArray(candidateEntries) ? candidateEntries : [];
      this.domains = new Set(entries.map(normalizeVirtualKemomimiRelayServer).filter(value => value !== undefined));
      this.expiresAt = this.now() + this.successTtl;

      return this.domains;
    }).catch(err => {
      this.expiresAt = this.now() + this.retryTtl;
      this.logger.warn({ err }, 'Unable to refresh VirtualKemomimi relay server list');
      return this.domains;
    }).finally(() => {
      this.refreshPromise = undefined;
    });

    return this.refreshPromise;
  }
}

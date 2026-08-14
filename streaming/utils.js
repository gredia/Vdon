// @ts-check

const FALSE_VALUES = [
  false,
  0,
  '0',
  'f',
  'F',
  'false',
  'FALSE',
  'off',
  'OFF',
];

/**
 * @typedef {typeof FALSE_VALUES[number]} FalseValue
 */

/**
 * @param {unknown} value
 * @returns {boolean}
 */
export function isTruthy(value) {
  return !!value && !FALSE_VALUES.includes(/** @type {FalseValue} */ (value));
}

/**
 * See app/lib/ascii_folder.rb for the canon definitions
 * of these constants
 */
const NON_ASCII_CHARS        = 'ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž';
const EQUIVALENT_ASCII_CHARS = 'AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz';
const FOLDTOASCII_REGEX = new RegExp(NON_ASCII_CHARS.split('').join('|'), 'g');
/**
 * @param {string} str
 * @returns {string}
 */
export function foldToASCII(str) {
  return str.replace(FOLDTOASCII_REGEX, function(match) {
    const index = NON_ASCII_CHARS.indexOf(match);
    return EQUIVALENT_ASCII_CHARS[index];
  });
}

/**
 * @param {string} str
 * @returns {string}
 */
export function normalizeHashtag(str) {
  return foldToASCII(str.normalize('NFKC').toLowerCase()).replace(/[^\p{L}\p{N}_\u00b7\u200c]/gu, '');
}

/**
 * @param {string|string[]} arrayOrString
 * @returns {string}
 */
export function firstParam(arrayOrString) {
  if (Array.isArray(arrayOrString)) {
    return arrayOrString[0];
  } else {
    return arrayOrString;
  }
}

/**
 * @typedef FilterAccount
 * @property {string} id
 * @property {string} acct
 */

/**
 * @typedef FilterStatus
 * @property {FilterAccount} account
 * @property {FilterAccount[]} [mentions]
 * @property {FilterStatus?} [reblog]
 */

/**
 * Collects the accounts that need relationship checks before a status is
 * streamed. The author of a boosted status needs the same block, mute, and
 * domain-block checks as the account that performed the boost.
 * @param {FilterStatus} status
 * @returns {{ authorAccountIds: string[], targetAccountIds: string[], accountDomains: string[] }}
 */
export function statusFilterTargets(status) {
  const authorAccounts = [status.account];
  const mentionedAccounts = [...(status.mentions ?? [])];

  if (status.reblog) {
    authorAccounts.push(status.reblog.account);
    mentionedAccounts.push(...(status.reblog.mentions ?? []));
  }

  const authorAccountIds = [...new Set(authorAccounts.map(account => account.id))];
  const targetAccountIds = [...new Set(authorAccountIds.concat(mentionedAccounts.map(account => account.id)))];
  const accountDomains = [...new Set(authorAccounts.map(account => account.acct.split('@')[1]?.toLowerCase()).filter(domain => domain !== undefined))];

  return { authorAccountIds, targetAccountIds, accountDomains };
}

/**
 * Takes an environment variable that should be an integer, attempts to parse
 * it falling back to a default if not set, and handles errors parsing.
 * @param {string|undefined} value
 * @param {number} defaultValue
 * @param {string} variableName
 * @returns {number}
 */
export function parseIntFromEnvValue(value, defaultValue, variableName) {
  if (typeof value === 'string' && value.length > 0) {
    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue)) {
      throw new Error(`Invalid ${variableName} environment variable: ${value}`);
    }
    return parsedValue;
  } else {
    return defaultValue;
  }
}

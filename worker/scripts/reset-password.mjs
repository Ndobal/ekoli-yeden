#!/usr/bin/env node
/**
 * RESET AN ADMINISTRATOR'S PASSWORD
 *
 * The recovery path of last resort. The reset-link flow cannot help here,
 * because generating a link requires an account that already works — so when
 * nobody can sign in, the only way back is straight to D1.
 *
 * This reproduces exactly what `worker/src/utils/crypto.ts` does: PBKDF2-SHA256,
 * 100,000 iterations, a 16-byte salt, a 256-bit key, both stored base64url. If
 * those constants ever change in the Worker they must change here too, or the
 * password this writes will not verify.
 *
 *   node scripts/reset-password.mjs --list
 *   node scripts/reset-password.mjs --email you@example.com
 *   node scripts/reset-password.mjs --email you@example.com --password "a long passphrase"
 *   node scripts/reset-password.mjs --email you@example.com --local
 *   node scripts/reset-password.mjs --email you@example.com --print-sql
 *
 * With no --password one is generated: six words, which is both stronger and
 * easier to read down a phone line than the usual mangled string. Nothing is
 * written until you confirm, and the SQL is always available to run by hand.
 */

import { pbkdf2Sync, randomBytes, randomInt } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { stdin, stdout } from 'node:process';

// --- These four must match worker/src/utils/crypto.ts -----------------------
const PBKDF2_ITERATIONS = 100_000;
const SALT_BYTES = 16;
const KEY_BYTES = 32; // 256 bits
const DIGEST = 'sha256';

/** Minimum the API enforces (`password_min_length` in site_settings). */
const MIN_PASSWORD_LENGTH = 12;

const WORDS = [
  'yam', 'river', 'palm', 'drum', 'harvest', 'elder', 'market', 'iron', 'compound',
  'thunder', 'season', 'kernel', 'bronze', 'shelter', 'lantern', 'granary', 'cassava',
  'weaver', 'anthill', 'moonrise', 'footpath', 'clay', 'cocoyam', 'raffia', 'kola',
  'bamboo', 'stream', 'ridge', 'dawn', 'hearth', 'basket', 'calabash', 'plantain',
];

function parseArgs(argv) {
  const args = { local: false, printSql: false, list: false, env: 'production', yes: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--email': args.email = argv[++i]; break;
      case '--password': args.password = argv[++i]; break;
      case '--database': args.database = argv[++i]; break;
      case '--env': args.env = argv[++i]; break;
      case '--local': args.local = true; break;
      case '--print-sql': args.printSql = true; break;
      case '--list': args.list = true; break;
      case '--yes': case '-y': args.yes = true; break;
      case '--help': case '-h': args.help = true; break;
      default:
        if (arg.startsWith('--')) {
          console.error('Unknown option: ' + arg);
          process.exit(1);
        }
    }
  }
  return args;
}

function generatePassphrase() {
  const words = Array.from({ length: 6 }, () => WORDS[randomInt(WORDS.length)]);
  // A trailing number satisfies any policy that insists on a digit without
  // making the phrase hard to read aloud.
  return words.join('-') + '-' + randomInt(10, 100);
}

/** PBKDF2, encoded exactly as the Worker encodes it. */
function hashPassword(password) {
  const salt = randomBytes(SALT_BYTES);
  const hash = pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, KEY_BYTES, DIGEST);
  return { hash: hash.toString('base64url'), salt: salt.toString('base64url') };
}

/** SQLite string literal — single quotes doubled. */
function quote(value) {
  return "'" + String(value).replace(/'/g, "''") + "'";
}

function buildUpdateSql(email, hash, salt) {
  const now = new Date().toISOString();
  // Sessions are revoked alongside the password change. A reset that leaves an
  // existing session alive has not actually taken the account back from
  // whoever was in it.
  return [
    'UPDATE users SET password_hash = ' + quote(hash) + ', password_salt = ' + quote(salt) + ',',
    "  status = 'active', updated_at = " + quote(now),
    'WHERE lower(email) = lower(' + quote(email) + ');',
    '',
    'UPDATE sessions SET revoked_at = ' + quote(now),
    'WHERE revoked_at IS NULL',
    '  AND user_id IN (SELECT id FROM users WHERE lower(email) = lower(' + quote(email) + '));',
  ].join('\n');
}

const LIST_SQL = [
  'SELECT u.email, u.display_name, u.status, group_concat(r.slug) AS roles',
  'FROM users u',
  'LEFT JOIN user_roles ur ON ur.user_id = u.id',
  'LEFT JOIN roles r ON r.id = ur.role_id',
  'GROUP BY u.id',
  "HAVING roles LIKE '%super_admin%'",
  'ORDER BY u.email;',
].join(' ');

/** Every account, when no Super Admin exists yet to list. */
const LIST_ALL_SQL = [
  'SELECT u.email, u.display_name, u.status, group_concat(r.slug) AS roles',
  'FROM users u',
  'LEFT JOIN user_roles ur ON ur.user_id = u.id',
  'LEFT JOIN roles r ON r.id = ur.role_id',
  'GROUP BY u.id ORDER BY u.created_at;',
].join(' ');

/**
 * Runs SQL through wrangler.
 *
 * Two things here are deliberate, and both were learned the hard way.
 *
 * The SQL goes through a temporary FILE rather than `--command`. A password
 * reset is two statements, and passing multi-statement SQL as a single
 * argument is fragile in a way that fails confusingly rather than loudly.
 *
 * And `shell` is off. On Windows, `spawnSync` with `shell: true` concatenates
 * the argument array into one command line WITHOUT quoting it — so a SQL
 * string is split on every space and wrangler receives forty nonsense
 * arguments. Turning the shell off passes argv through intact, which means the
 * executable has to be named exactly: `npx.cmd` on Windows, `npx` elsewhere.
 */
function runWrangler(sql, args) {
  const file = join(tmpdir(), `ekoli-reset-${randomBytes(6).toString('hex')}.sql`);
  writeFileSync(file, sql, 'utf8');

  const parts = [
    'npx wrangler d1 execute',
    args.database ?? 'ekoli-yeden-db',
    args.local ? '--local' : `--remote --env ${args.env}`,
    `--file "${file}"`,
    '--yes',
  ];
  const command = parts.join(' ');

  console.log('\n> ' + command.replace(file, '<sql>') + '\n');

  try {
    // ONE STRING, not an argv array.
    //
    // `spawnSync(cmd, argsArray, { shell: true })` on Windows joins the array
    // into a command line without quoting anything, so a path with spaces — and
    // the temp directory always has spaces — is split apart. Passing a single
    // pre-quoted string instead hands the shell exactly what it should parse.
    //
    // The array form with `shell: false` does not work here either: Node will
    // not resolve `npx.cmd` through PATHEXT without a shell, and fails to spawn
    // at all.
    //
    // The only interpolated value is a temp path this script generated, so the
    // quoting is sound.
    const result = spawnSync(command, { stdio: 'inherit', shell: true });

    if (result.error) {
      console.error('\nCould not run wrangler: ' + result.error.message);
      return false;
    }
    return result.status === 0;
  } finally {
    // The file holds a password hash. It does not linger in the temp directory.
    try {
      unlinkSync(file);
    } catch {
      // Nothing useful to do if it is already gone.
    }
  }
}

async function confirm(question) {
  const rl = createInterface({ input: stdin, output: stdout });
  const answer = await rl.question(question + ' [y/N] ');
  rl.close();
  return answer.trim().toLowerCase() === 'y';
}

const HELP = [
  'Reset an Ekoli Yeden administrator password directly in D1.',
  '',
  '  --email <address>     Whose password to reset. Required unless --list.',
  '  --password <text>     The new password. Generated if omitted.',
  '  --list                Show every account holding super_admin, then exit.',
  '  --local               Act on the local development database.',
  '  --env <name>          Wrangler environment for --remote (default: production).',
  '  --database <name>     D1 database name (default: ekoli-yeden-db).',
  '  --print-sql           Print the SQL and exit without touching anything.',
  '  --yes                 Do not ask for confirmation.',
  '',
  'Examples:',
  '  node scripts/reset-password.mjs --list',
  '  node scripts/reset-password.mjs --email you@example.com',
  '  node scripts/reset-password.mjs --email you@example.com --password "six word passphrase here"',
].join('\n');

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    console.log(HELP);
    return;
  }

  if (args.list) {
    if (args.printSql) {
      console.log(LIST_SQL);
      console.log('\n-- If that returns nothing, no Super Admin exists yet. Every account:');
      console.log(LIST_ALL_SQL);
      return;
    }
    console.log('Accounts holding super_admin:');
    if (!runWrangler(LIST_SQL, args)) process.exitCode = 1;
    console.log('\nIf that listed nothing, no account holds super_admin yet. Every account:');
    runWrangler(LIST_ALL_SQL, args);
    return;
  }

  if (!args.email) {
    console.error('An --email is required. Run with --help for usage, or --list to see the Super Admins.');
    process.exitCode = 1;
    return;
  }

  const password = args.password ?? generatePassphrase();
  if (password.length < MIN_PASSWORD_LENGTH) {
    console.error('The password must be at least ' + MIN_PASSWORD_LENGTH + ' characters. The API refuses anything shorter.');
    process.exitCode = 1;
    return;
  }

  const { hash, salt } = hashPassword(password);
  const sql = buildUpdateSql(args.email, hash, salt);
  const target = args.local
    ? 'local development database'
    : 'remote - ' + (args.database ?? 'ekoli-yeden-db') + ' (' + args.env + ')';

  console.log('\n-------------------------------------------------------------');
  console.log('  Account   ' + args.email);
  console.log('  Target    ' + target);
  console.log('  Password  ' + password);
  console.log('-------------------------------------------------------------');
  console.log('\nWrite this down now. It is not stored anywhere and cannot be shown again.');
  console.log('Change it from Account -> Password once you are signed in.\n');

  if (args.printSql) {
    console.log('SQL:\n');
    console.log(sql);
    return;
  }

  if (!args.yes && !(await confirm('Apply this now?'))) {
    console.log('\nNothing was changed. The SQL, should you want to run it yourself:\n');
    console.log(sql);
    return;
  }

  // Both statements in one call, so the password change and the session
  // revocation cannot end up half-applied.
  if (!runWrangler(sql.replace(/\s*\n\s*/g, ' ').trim(), args)) {
    console.error('\nThe update did not complete.');
    console.error('If wrangler asked you to sign in, run `npx wrangler login` and try again.');
    console.error('Otherwise run the SQL above by hand:\n');
    console.log(sql);
    process.exitCode = 1;
    return;
  }

  console.log('\nDone. Sign in at /sign-in as ' + args.email + '.');
  console.log('Every existing session for that account has been ended.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const addonParent = join(repositoryRoot, 'wow-addon');
const addonName = 'Localog_Companion';
const addonDirectory = join(addonParent, addonName);
const distributionDirectory = join(repositoryRoot, 'dist', 'wow-addon');
const checkOnly = process.argv.includes('--check');

const expectedFiles = [
  'Capture.lua',
  'Core.lua',
  'Localog_Companion.toc',
  'Protocol.lua',
  'README.txt',
  'SimcIntegration.lua',
  'UI.lua',
];

const fail = (message) => {
  throw new Error(`Localog Companion packaging failed: ${message}`);
};

const entries = readdirSync(addonDirectory, { withFileTypes: true });
for (const entry of entries) {
  if (!entry.isFile()) fail(`unexpected non-file entry ${entry.name}`);
}

const actualFiles = entries.map((entry) => entry.name).sort();
if (actualFiles.join('\n') !== expectedFiles.join('\n')) {
  fail(
    `addon contents differ from the release allowlist\nexpected: ${expectedFiles.join(', ')}\nactual: ${actualFiles.join(', ')}`,
  );
}

const toc = readFileSync(join(addonDirectory, 'Localog_Companion.toc'), 'utf8');
const version = /^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$/m.exec(toc)?.[1];
if (!version) fail('the TOC must contain a semantic ## Version field');
if (!/^## Interface: 120100$/m.test(toc)) fail('the TOC is not pinned to Retail interface 120100');
if (!/^## Dependencies: Simulationcraft$/m.test(toc)) {
  fail('the TOC must retain Simulationcraft as its only required dependency');
}
const bundledReadme = readFileSync(join(addonDirectory, 'README.txt'), 'utf8');
if (!bundledReadme.startsWith(`LOCALOG COMPANION ${version}\n`)) {
  fail('README.txt version does not match the TOC version');
}

for (const file of actualFiles.filter((file) => file.endsWith('.lua'))) {
  const contents = readFileSync(join(addonDirectory, file), 'utf8');
  if (/\brequire\s*\(/.test(contents) || /(?:^|["'])\.\.\//m.test(contents)) {
    fail(`${file} contains an external runtime import`);
  }
  if (/\bsrc\//.test(contents)) fail(`${file} refers to the web application's src tree`);
}

if (checkOnly) {
  console.log(`Localog Companion ${version}: standalone source layout verified.`);
  process.exit(0);
}

mkdirSync(distributionDirectory, { recursive: true });
const archive = join(distributionDirectory, `${addonName}-${version}.zip`);
rmSync(archive, { force: true });

const zip = spawnSync('zip', ['-q', '-X', '-r', archive, addonName], {
  cwd: addonParent,
  encoding: 'utf8',
});
if (zip.error) fail(`could not run zip: ${zip.error.message}`);
if (zip.status !== 0) fail(`zip exited with status ${zip.status}: ${zip.stderr.trim()}`);

const listing = spawnSync('unzip', ['-Z1', archive], { encoding: 'utf8' });
if (listing.error) fail(`could not inspect archive: ${listing.error.message}`);
if (listing.status !== 0) {
  fail(`unzip exited with status ${listing.status}: ${listing.stderr.trim()}`);
}

const archivedFiles = listing.stdout
  .trim()
  .split('\n')
  .filter((entry) => entry && !entry.endsWith('/'))
  .map((entry) => relative(`${addonName}/`, entry))
  .sort();
if (archivedFiles.join('\n') !== expectedFiles.join('\n')) {
  fail(`archive contents differ from the release allowlist: ${archivedFiles.join(', ')}`);
}

const checksum = createHash('sha256').update(readFileSync(archive)).digest('hex');
console.log(`Packaged Localog Companion ${version}: ${relative(repositoryRoot, archive)}`);
console.log(`SHA-256: ${checksum}`);

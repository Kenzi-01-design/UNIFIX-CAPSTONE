import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const clientSource = path.resolve('src');
const builtAssets = path.resolve('dist', 'assets');
const forbiddenNames = /(?:VITE_)?SUPABASE_SERVICE_ROLE_KEY/;
const jwtPattern = /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]+/g;
const findings = [];

async function scan(directory, inspect) {
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    const filePath = path.join(directory, entry.name);
    if (entry.isDirectory()) await scan(filePath, inspect);
    else if (entry.isFile()) await inspect(filePath, await readFile(filePath, 'utf8'));
  }
}

await scan(clientSource, async (filePath, contents) => {
  if (forbiddenNames.test(contents)) findings.push(`${filePath}: service-role key reference in client source`);
});

await scan(builtAssets, async (filePath, contents) => {
  if (forbiddenNames.test(contents)) findings.push(`${filePath}: service-role key reference in client bundle`);
  for (const token of contents.match(jwtPattern) || []) {
    try {
      const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
      if (payload.role === 'service_role') findings.push(`${filePath}: service-role JWT found in client bundle`);
    } catch {
      continue;
    }
  }
});

if (findings.length) {
  console.error('Client secret scan failed:\n' + findings.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Client source and production bundle contain no service-role key reference or service-role JWT.');
}

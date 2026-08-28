import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { execFileSync } from 'node:child_process';

const root = path.resolve(process.cwd());
const srcDir = path.join(root, 'src');
const problems = [];

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const jsFiles = walk(srcDir).filter((file) => file.endsWith('.js'));
for (const file of jsFiles) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
  } catch (error) {
    problems.push(`Syntax check failed: ${path.relative(root, file)}\n${error.stderr?.toString() ?? error.message}`);
  }
}

const router = fs.readFileSync(path.join(srcDir, 'ai/provider_router.js'), 'utf8');
const solver = fs.readFileSync(path.join(srcDir, 'ai_solver.js'), 'utf8');
const cloudflare = fs.readFileSync(path.join(srcDir, 'ai/providers/cloudflare_provider.js'), 'utf8');

if (!router.includes("PRIMARY_AI_PROVIDER = 'cloudflare'")) problems.push('Cloudflare is not the primary AI provider');
if (!router.includes('solveWithCloudflare')) problems.push('Cloudflare provider routing missing');
if (router.includes('solveWithOpenRouter') || router.includes('solveWithGroq')) problems.push('Legacy provider fallback still active in router');
if (!cloudflare.includes("CLOUDFLARE_MODEL = '@cf/google/gemma-4-26b-a4b-it'")) problems.push('Cloudflare Gemma 4 model missing');
if (!cloudflare.includes("type: 'image_url'")) problems.push('Cloudflare vision image input missing');
if (!cloudflare.includes('enable_thinking: !recovery')) problems.push('Gemma adaptive thinking mode missing');
if (!cloudflare.includes('reasoning_content')) problems.push('Gemma reasoning_content handling missing');
if (!cloudflare.includes('cloudflare_recovery_start')) problems.push('Cloudflare recovery retry missing');
if (!cloudflare.includes("reasoning_effort: recovery ? 'low' : 'medium'")) problems.push('Cloudflare recovery reasoning reduction missing');
if (!cloudflare.includes('RECOVERY_TIMEOUT_MS = 30000')) problems.push('Cloudflare recovery timeout missing');
if (!cloudflare.includes("['cloudflare_timeout', 'cloudflare_empty_output', 'cloudflare_invalid_json']")) problems.push('Cloudflare recoverable failure list missing');

if (!cloudflare.includes("throw new Error('cloudflare_timeout')")) problems.push('Cloudflare timeout handling missing');
if (!cloudflare.includes('cloudflare_http_')) problems.push('Cloudflare HTTP failure mapping missing');
if (!cloudflare.includes('parseSolution')) problems.push('Cloudflare JSON solution parser missing');
if (!solver.includes("defineSecret('CLOUDFLARE_ACCOUNT_ID')")) problems.push('CLOUDFLARE_ACCOUNT_ID secret missing');
if (!solver.includes("defineSecret('CLOUDFLARE_AI_TOKEN')")) problems.push('CLOUDFLARE_AI_TOKEN secret missing');
if (!solver.includes('secrets: [CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_AI_TOKEN]')) problems.push('Cloudflare secrets are not bound to callable');
if (solver.includes('OPENROUTER_API_KEY.value()') || solver.includes('GROQ_API_KEY.value()')) problems.push('Legacy provider secrets still used by solver');
if (!solver.includes('visualAnalysis: ai.visualAnalysis ?? null')) problems.push('Visual analysis metadata is not persisted');
if (!solver.includes('failureCode = sanitizeProviderFailure(error)')) problems.push('Sanitized provider failure mapping missing');

if (problems.length) {
  console.error(`Regression check FAILED (${problems.length} problem(s)):\n- ${problems.join('\n- ')}`);
  process.exit(1);
}

console.log(`Regression check PASS (${jsFiles.length} production JS files).`);

import { CLOUDFLARE_MODEL, solveWithCloudflare } from './providers/cloudflare_provider.js';

export const PRIMARY_AI_PROVIDER = 'cloudflare';
export const PRIMARY_AI_MODEL = CLOUDFLARE_MODEL;
export { CLOUDFLARE_MODEL };

export async function solveWithProviderRouter({
  cloudflareAccountId,
  cloudflareApiToken,
  ...input
}) {
  const result = await solveWithCloudflare({
    accountId: cloudflareAccountId,
    apiToken: cloudflareApiToken,
    ...input,
  });

  return {
    ...result,
    fallbackUsed: false,
  };
}

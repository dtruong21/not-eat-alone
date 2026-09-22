export interface SendResponse { success: boolean; error?: { code: string } }

const PRUNE_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

export function tokensToPrune(tokens: string[], responses: SendResponse[]): string[] {
  const out: string[] = [];
  responses.forEach((r, i) => {
    if (!r.success && r.error && PRUNE_CODES.has(r.error.code)) out.push(tokens[i]);
  });
  return out;
}

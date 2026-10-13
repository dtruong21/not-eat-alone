/** Push languages: the app writes `lang` on each token doc; anything unknown is English. */
export type PushLang = 'en' | 'fr';

export function normalizePushLang(v: unknown): PushLang {
  return v === 'fr' ? 'fr' : 'en';
}

/** Token doc ids grouped by the doc's `lang` (missing/unknown -> `en`). */
export function groupTokensByLang(
  docs: { id: string; data(): Record<string, unknown> }[],
): Map<PushLang, string[]> {
  const out = new Map<PushLang, string[]>();
  for (const d of docs) {
    const lang = normalizePushLang(d.data().lang);
    const ids = out.get(lang);
    if (ids) ids.push(d.id);
    else out.set(lang, [d.id]);
  }
  return out;
}

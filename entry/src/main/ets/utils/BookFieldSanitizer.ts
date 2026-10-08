export class BookFieldSanitizer {
  static prefer(newValue: string, fallback: string): string {
    const cleaned = BookFieldSanitizer.clean(newValue);
    return cleaned || BookFieldSanitizer.clean(fallback);
  }

  // 书源规则常把字段标签一起抓回来（如 author 规则返回"作者：天蚕土豆"），
  // 展示层自己会加"作者："前缀，不剥离就会出现"作者：作者：xxx"；
  // 换源的作者一致性校验也会因标签前缀把正确结果整条过滤掉。
  static cleanAuthor(value: string): string {
    const cleaned = BookFieldSanitizer.clean(value);
    if (!cleaned) return '';
    let text = BookFieldSanitizer.stripLeadingLabel(cleaned,
      ['作\\s*者', '作者名', '作\\s*家', '著\\s*者', 'author']);
    const withoutZhuSuffix = text.replace(/[\s·]*著$/, '').trim();
    if (withoutZhuSuffix) text = withoutZhuSuffix;
    return text;
  }

  static cleanChapterTitle(value: string): string {
    const cleaned = BookFieldSanitizer.clean(value);
    if (!cleaned) return '';
    return BookFieldSanitizer.stripLeadingLabel(cleaned,
      ['最新章节', '最新章', '章节', '最新']);
  }

  static cleanWordCount(value: string): string {
    const cleaned = BookFieldSanitizer.clean(value);
    if (!cleaned) return '';
    return BookFieldSanitizer.stripLeadingLabel(cleaned, ['字\\s*数', '字数统计']);
  }

  static cleanUpdateTime(value: string): string {
    const cleaned = BookFieldSanitizer.clean(value);
    if (!cleaned) return '';
    return BookFieldSanitizer.stripLeadingLabel(cleaned,
      ['更新时间', '更新日期', '最后更新', '更新']);
  }

  private static stripLeadingLabel(value: string, labels: string[]): string {
    let text = value.trim().replace(/^[\s【\[（(]+/, '');
    // 最多剥两层，容忍"作者：作者：xxx"这类双层标签。
    for (let round = 0; round < 2; round++) {
      let replaced = false;
      for (const label of labels) {
        const next = text.replace(new RegExp(`^${label}\\s*(?:[\\]）)】]|[:：=＝])\\s*`, 'i'), '');
        if (next !== text) {
          text = next;
          replaced = true;
          break;
        }
      }
      if (!replaced) break;
    }
    return text.trim();
  }

  static clean(value: string): string {
    // A combined selector + JS rule may produce useful text even when one optional template
    // expression is unsupported or absent. Remove those isolated placeholders before deciding
    // whether the whole field is unresolved; never expose the rule expression itself.
    const text = (value || '').replace(/\{\{[\s\S]*?\}\}/g, '').trim();
    if (!text || BookFieldSanitizer.isUnresolved(text)) {
      return '';
    }
    const cleaned = text
      .replace(/&nbsp;/gi, ' ')
      .replace(/&lrm;/gi, '')
      .replace(/&shy;/gi, '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    const structuredIntro = BookFieldSanitizer.extractStructuredIntro(cleaned);
    if (structuredIntro) return structuredIntro;
    // Some explore rules accidentally return the whole JSON record as the intro. Do not flash that record on
    // the detail page while the real book-info request is still running.
    if (/^[\[{]/.test(cleaned) && /"(?:type|name|author|cover|status|data)"\s*:/i.test(cleaned)) return '';
    return cleaned;
  }

  private static extractStructuredIntro(value: string): string {
    if (!/^[\[{]/.test(value || '')) return '';
    const keys = ['desc', 'intro', 'description', 'abstract'];
    for (const key of keys) {
      const match = new RegExp(`"${key}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`, 'i').exec(value);
      if (!match || !match[1]) continue;
      try {
        const decoded = String(JSON.parse(`"${match[1]}"`));
        if (decoded.trim()) return BookFieldSanitizer.clean(decoded);
      } catch (_) {
        const fallback = match[1].replace(/\\n/g, '\n').replace(/\\"/g, '"').trim();
        if (fallback) return fallback;
      }
    }
    return '';
  }

  static isUnresolved(value: string): boolean {
    const text = (value || '').trim();
    if (!text) return true;
    if (/^(?:undefined|null)$/i.test(text)) return true;
    return text.includes('{{') || text.includes('}}') || text.includes('@js:') || text.includes('java.') ||
      text.includes('result.replace') || /(^|[^\w])\$\.\.?[A-Za-z_]/.test(text);
  }
}

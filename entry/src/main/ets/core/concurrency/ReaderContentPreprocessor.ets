import taskpool from '@ohos.taskpool';
import { Book } from '../../model/data/Book';
import { ReaderReplaceRule } from '../../utils/ReaderReplaceRuleStore';
import { JavaRegexCompat } from '../rule/JavaRegexCompat';
import { RegexSafetyGuard } from '../rule/RegexSafetyGuard';
import { QuickJsReplaceEvaluator } from '../script/QuickJsScriptRuntime';

/**
 * Pure TaskPool entry. It deliberately owns no UI or database state so a pathological imported
 * replacement rule cannot block ArkUI's event loop.
 */
@Concurrent
function applyReaderRulesInTask(text: string, rulesJson: string, scopeText: string): string {
  let rules: Record<string, Object>[] = [];
  try {
    const parsed = JSON.parse(rulesJson || '[]') as Object;
    if (Array.isArray(parsed)) rules = parsed as Record<string, Object>[];
  } catch (_) {
    return text;
  }
  // Reader action markers are app-internal interaction metadata (paragraph-comment bubbles,
  // source buttons) baked into the content text. They are not book prose, and cleaning rules
  // such as `\[.*?\]` or "strip non-CJK" must never destroy them, so every rule is applied per
  // plain-text segment and the markers are reattached verbatim afterwards.
  // EPUB image markers carry percent-encoded absolute paths (local books) or image URLs (online
  // comics) — the same exemption applies: a rule matching inside an encoded payload corrupts the
  // path (e.g. "base" -> "ba色") and every comic page then fails to load.
  const hasMarkers = (text || '').indexOf('[[LEGADO_') >= 0;
  const segments: string[] = hasMarkers ?
    (text || '').split(/(\[\[LEGADO_(?:READER_ACTION(?:_V[23])?|EPUB_IMAGE):[\s\S]*?\]\])/g) : [text || ''];
  const target = (scopeText || '').toLowerCase();
  for (let index = 0; index < rules.length; index++) {
    const rule = rules[index];
    if (rule['enabled'] === false || rule['applyToContent'] === false) continue;
    const pattern = String(rule['pattern'] || '');
    if (!pattern) continue;

    let scopeAllowed = true;
    const includeTokens = String(rule['scope'] || '').split(/[\n,，;；]+/)
      .map((value: string): string => value.trim().toLowerCase())
      .filter((value: string): boolean => !!value);
    if (includeTokens.length > 0) {
      scopeAllowed = false;
      for (let tokenIndex = 0; tokenIndex < includeTokens.length; tokenIndex++) {
        const token = includeTokens[tokenIndex];
        let matches = false;
        if (token.startsWith('/') && token.lastIndexOf('/') > 0) {
          const end = token.lastIndexOf('/');
          try { matches = new RegExp(token.substring(1, end), token.substring(end + 1)).test(target); } catch (_) {}
        } else if (token.includes('*')) {
          const escaped = token.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
          try { matches = new RegExp(escaped, 'i').test(target); } catch (_) {}
        } else {
          matches = target.includes(token);
        }
        if (matches) {
          scopeAllowed = true;
          break;
        }
      }
    }
    if (!scopeAllowed) continue;
    const excludeTokens = String(rule['excludeScope'] || '').split(/[\n,，;；]+/)
      .map((value: string): string => value.trim().toLowerCase())
      .filter((value: string): boolean => !!value);
    let excluded = false;
    for (let tokenIndex = 0; tokenIndex < excludeTokens.length; tokenIndex++) {
      const token = excludeTokens[tokenIndex];
      let matches = false;
      if (token.startsWith('/') && token.lastIndexOf('/') > 0) {
        const end = token.lastIndexOf('/');
        try { matches = new RegExp(token.substring(1, end), token.substring(end + 1)).test(target); } catch (_) {}
      } else if (token.includes('*')) {
        const escaped = token.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
        try { matches = new RegExp(escaped, 'i').test(target); } catch (_) {}
      } else {
        matches = target.includes(token);
      }
      if (matches) {
        excluded = true;
        break;
      }
    }
    if (excluded) continue;

    const rawReplacement = String(rule['replacement'] || '');
    // 阅读(Legado) 的 @js: 替换：脚本在 QuickJS 沙箱内按程序完成值求值，result 绑定匹配文本；
    // 求值失败的匹配保留原文，绝不把脚本字面量写进正文。
    let jsEvaluator: QuickJsReplaceEvaluator | null = null;
    try {
      let matcher: RegExp | null = null;
      let plain = '';
      let replacement = rawReplacement;
      if (rule['isRegex'] !== false) {
        // 与主线程预览路径保持同一语义：Java 方言先经 JavaRegexCompat 转换（内联标志、
        // 占有量词、\Q..\E、$0 替换串等），否则导入的 Android 规则在阅读时要么静默失效、
        // 要么把 `$0`/`\n` 字面写进正文。
        if (RegexSafetyGuard.isLikelyCatastrophic(pattern)) {
          console.warn(`[ReaderPreprocessor] 替换净化规则存在灾难性回溯风险，已跳过: ${pattern}`);
          continue;
        }
        matcher = JavaRegexCompat.compile(pattern, 'g');
        if (rawReplacement.indexOf('@js:') === 0) {
          const timeoutMs = Number(rule['timeoutMs']);
          jsEvaluator = new QuickJsReplaceEvaluator(rawReplacement.substring(4),
            Number.isFinite(timeoutMs) ? timeoutMs : 3000);
          if (!jsEvaluator.begin()) {
            jsEvaluator = null;
            console.warn(`[ReaderPreprocessor] @js: 替换脚本无法在 QuickJS 沙箱执行，已跳过: ${pattern}`);
            continue;
          }
        } else {
          replacement = JavaRegexCompat.convertReplacement(rawReplacement);
        }
      } else if (rawReplacement.indexOf('@js:') === 0) {
        console.warn(`[ReaderPreprocessor] 非 @js: 正则规则不支持脚本替换，已跳过: ${pattern}`);
        continue;
      } else {
        plain = pattern;
      }
      // 误删防护：单条规则把整章替换为空而原文非空时，视为误删，回滚该规则。
      const snapshot: string[] = segments.slice();
      // Even indices are plain text; odd indices are captured markers kept out of rule scope.
      for (let si = 0; si < segments.length; si += 2) {
        const segment = segments[si];
        if (!segment) continue;
        if (jsEvaluator !== null && matcher !== null) {
          segments[si] = QuickJsReplaceEvaluator.applyToText(segment, matcher, jsEvaluator);
        } else if (matcher !== null) {
          segments[si] = segment.replace(matcher, replacement);
        } else {
          segments[si] = segment.split(plain).join(replacement);
        }
      }
      if (!segments.join('').trim() && (text || '').trim()) {
        console.warn(`[ReaderPreprocessor] 替换净化规则把整章清空，已回滚: ${pattern}`);
        for (let si = 0; si < snapshot.length; si++) segments[si] = snapshot[si];
      }
    } catch (_) {
    } finally {
      if (jsEvaluator !== null) jsEvaluator.end();
    }
  }
  return segments.join('');
}

export class ReaderContentPreprocessor {
  /** TaskPool 净化的兜底时限：守卫漏拦的灾难性回溯最多占用一个 worker 这么久。 */
  static readonly TASK_TIMEOUT_MS: number = 10000;

  static hasActiveContentRules(rules: ReaderReplaceRule[]): boolean {
    return rules.some((rule: ReaderReplaceRule): boolean =>
      rule.enabled !== false && rule.applyToContent !== false && !!rule.pattern);
  }

  static async apply(text: string, rules: ReaderReplaceRule[], book: Book | null): Promise<string> {
    if (!text || !ReaderContentPreprocessor.hasActiveContentRules(rules)) return text;
    const scopeText = book ? `${book.name || ''}\n${book.author || ''}\n${book.originName || ''}\n` +
      `${book.origin || ''}\n${book.bookUrl || ''}` : '';
    let timedOut = false;
    const deadline = new Promise<boolean>((resolve) => {
      setTimeout((): void => {
        timedOut = true;
        resolve(true);
      }, ReaderContentPreprocessor.TASK_TIMEOUT_MS);
    });
    try {
      // taskpool 不支持中断执行中的同步正则；超时后放弃等待并保留原文，
      // 避免守卫漏拦的灾难性回溯把 await 永久挂起（章节永远“正在加载”）。
      const winner = await Promise.race([
        taskpool.execute(applyReaderRulesInTask, text, JSON.stringify(rules), scopeText),
        deadline
      ]);
      if (timedOut) {
        console.warn('[ReaderPreprocessor] 替换净化执行超时，保留原文（规则可能存在灾难性回溯）');
        return text;
      }
      return typeof winner === 'string' ? winner : text;
    } catch (error) {
      console.warn('[ReaderPreprocessor] TaskPool failed, keep original content:', error);
      return text;
    }
  }
}

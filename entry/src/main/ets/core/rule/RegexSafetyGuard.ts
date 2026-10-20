/**
 * 用户可编辑正则（替换净化规则、书源 replaceRegex）的灾难性回溯（ReDoS）启发式检测。
 *
 * 这些正则在主线程或 TaskPool 中同步执行且无法中断。嵌套量词（如 `(a+)+`、`(a{1,10}){1,10}`）
 * 或首字符重叠的量词化分支（如 `(a|aa)+`）在失败回溯时呈指数级膨胀，会冻结 UI 线程或
 * 永久占用 worker。这里用轻量扫描器识别高危结构，调用方据此跳过该规则：
 * - 量词化分组（外层 +、*、{n,} 或 {n,m}）内还含普通量词：`(a+)+`、`(a{2,})+`、`((a){1,10}){2,}`；
 * - 量词化分组内分支首字符重叠：`(a|a)+`、`(a|aa)+b`；
 * - 量词化分组内含可匹配空的分支：`(a|)+`；
 * - 反向引用（\1-\9）与无界量词并存：`(\w+)\1`。
 *
 * 已知局限（保守放行，不误伤常规写法）：`(\d|[a-z])+` 的字符类成员重叠、`(a?)+` 的可空内层、
 * `(a*+)+` 一类占有量词残留均不在拦截范围内，由执行方的超时/TaskPool 隔离兜底。
 */
interface RegexGroupFrame {
  contentStart: number;
  hasInnerQuantifier: boolean;
}

export class RegexSafetyGuard {
  static isLikelyCatastrophic(pattern: string): boolean {
    const source = pattern || '';
    if (source.length === 0) {
      return false;
    }
    const stack: RegexGroupFrame[] = [];
    let inClass = false;
    let hasBackreference = false;
    let hasUnboundedQuantifier = false;
    let index = 0;
    while (index < source.length) {
      const ch = source.charAt(index);
      if (ch === '\\') {
        const next = source.charAt(index + 1);
        if (!inClass && next >= '1' && next <= '9') {
          hasBackreference = true;
        }
        index += 2;
        continue;
      }
      if (inClass) {
        if (ch === ']') {
          inClass = false;
        }
        index++;
        continue;
      }
      if (ch === '[') {
        inClass = true;
        index++;
        continue;
      }
      if (ch === '(') {
        const contentStart = RegexSafetyGuard.groupContentStart(source, index);
        stack.push({ contentStart: contentStart, hasInnerQuantifier: false });
        index = contentStart;
        continue;
      }
      if (ch === ')') {
        const frame: RegexGroupFrame | undefined = stack.length > 0 ? stack.pop() : undefined;
        let cursor = index + 1;
        let quantifier = '';
        const next = source.charAt(cursor);
        if (next === '+' || next === '*') {
          quantifier = next;
          cursor++;
        } else if (next === '{') {
          const braceMatch = /^\{\d+(,\d*)?\}/.exec(source.substring(cursor));
          if (braceMatch) {
            quantifier = braceMatch[0];
            cursor += braceMatch[0].length;
          }
        }
        while (cursor < source.length &&
          (source.charAt(cursor) === '?' || source.charAt(cursor) === '+')) {
          cursor++;
        }
        if (quantifier !== '') {
          const outerUnbounded = quantifier === '+' || quantifier === '*' || quantifier.includes(',');
          if (outerUnbounded) {
            hasUnboundedQuantifier = true;
            if (frame && (frame.hasInnerQuantifier ||
              RegexSafetyGuard.hasOverlappingAlternatives(source.substring(frame.contentStart, index)))) {
              return true;
            }
          }
        }
        if (frame && stack.length > 0 && (quantifier !== '' || frame.hasInnerQuantifier)) {
          stack[stack.length - 1].hasInnerQuantifier = true;
        }
        index = cursor;
        continue;
      }
      if (ch === '+') {
        hasUnboundedQuantifier = true;
        if (stack.length > 0) {
          stack[stack.length - 1].hasInnerQuantifier = true;
        }
        index++;
        continue;
      }
      if (ch === '*') {
        hasUnboundedQuantifier = true;
        if (stack.length > 0) {
          stack[stack.length - 1].hasInnerQuantifier = true;
        }
        index++;
        continue;
      }
      if (ch === '?') {
        index++;
        continue;
      }
      if (ch === '{') {
        const braceMatch = /^\{(\d+)(,(\d*)?)?\}/.exec(source.substring(index));
        if (braceMatch) {
          if (braceMatch[2] !== undefined) {
            hasUnboundedQuantifier = true;
            if (stack.length > 0) {
              stack[stack.length - 1].hasInnerQuantifier = true;
            }
          }
          index += braceMatch[0].length;
        } else {
          index++;
        }
        continue;
      }
      index++;
    }
    return hasBackreference && hasUnboundedQuantifier;
  }

  /** 跳过分组前缀（(?: (?= (?! (?<name> (?<= (?i) 等），返回组内容的起始下标。 */
  private static groupContentStart(source: string, openIndex: number): number {
    let start = openIndex + 1;
    if (source.charAt(start) !== '?') {
      return start;
    }
    start++;
    const marker = source.charAt(start);
    if (marker === ':' || marker === '=' || marker === '!' || marker === '>') {
      return start + 1;
    }
    if (marker === '<') {
      const after = source.charAt(start + 1);
      if (after === '=' || after === '!') {
        return start + 2;
      }
      const close = source.indexOf('>', start);
      return close >= 0 ? close + 1 : start + 1;
    }
    return start;
  }

  private static hasOverlappingAlternatives(content: string): boolean {
    if (!content || content.indexOf('|') < 0) {
      return false;
    }
    const parts = RegexSafetyGuard.splitAlternatives(content);
    if (parts.length < 2) {
      return false;
    }
    const seenFirstChars: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (part.length === 0) {
        // 量词化分组里存在可匹配空的分支，回溯路径无界。
        return true;
      }
      const first = RegexSafetyGuard.firstMeaningfulChar(part);
      if (!first) {
        continue;
      }
      if (seenFirstChars.indexOf(first) >= 0) {
        return true;
      }
      seenFirstChars.push(first);
    }
    return false;
  }

  /** 按任意深度的 `|` 切分（忽略字符类与转义内的竖线）。 */
  private static splitAlternatives(content: string): string[] {
    const parts: string[] = [];
    let start = 0;
    let inClass = false;
    let index = 0;
    while (index < content.length) {
      const ch = content.charAt(index);
      if (ch === '\\') {
        index += 2;
        continue;
      }
      if (inClass) {
        if (ch === ']') {
          inClass = false;
        }
        index++;
        continue;
      }
      if (ch === '[') {
        inClass = true;
        index++;
        continue;
      }
      if (ch === '|') {
        parts.push(content.substring(start, index));
        start = index + 1;
      }
      index++;
    }
    parts.push(content.substring(start));
    return parts;
  }

  /** 分支的第一个确定字符；字符类、锚点、分组逃逸等无法静态判定时返回空串。 */
  private static firstMeaningfulChar(alternative: string): string {
    let text = alternative;
    let depth = 0;
    while (text.length > 0 && depth < 8) {
      const ch = text.charAt(0);
      if (ch === '\\') {
        const escaped = text.charAt(1);
        if (!escaped) {
          return '';
        }
        // 转义字母（\d \w \s \p…）语义不透明，按未知处理避免误判重叠。
        return (escaped >= 'a' && escaped <= 'z') || (escaped >= 'A' && escaped <= 'Z') ? '' : escaped;
      }
      if (ch === '(') {
        text = text.substring(RegexSafetyGuard.groupContentStart(text, 0));
        depth++;
        continue;
      }
      if (ch === '[' || ch === '.' || ch === '^' || ch === '$' || ch === '{') {
        return '';
      }
      return ch;
    }
    return '';
  }
}

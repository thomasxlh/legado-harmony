/**
 * 章节实测字数的展示格式化：换源面板与搜索结果列表共用。
 *
 * 换源是"逐条横向对比"场景，用户要在几十条结果里比较字数多少，因此保留精确位数
 * 并加千分位分隔（34,567 字）比换算成"3.5 万字"更利于比较；
 * 统一两处的分隔符与单位，避免同一个数字在不同界面呈现成两种形态。
 */
export class WordCountFormatter {
  /** 带千分位的纯数字文本，如 34,567。非正数返回 "0"。 */
  static format(count: number): string {
    const value = Number.isFinite(count) ? Math.max(0, Math.floor(count)) : 0;
    const text = `${value}`;
    // 从低位起每三位插入分隔符：对剩余位数取模即可，无需反转字符串。
    let result = '';
    for (let index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 === 0) {
        result += ',';
      }
      result += text[index];
    }
    return result;
  }

  /** 带单位与分隔符的完整文本，如 "34,567 字"。仅用于 >0 的实测值。 */
  static formatWithUnit(count: number): string {
    return `${WordCountFormatter.format(count)} 字`;
  }
}

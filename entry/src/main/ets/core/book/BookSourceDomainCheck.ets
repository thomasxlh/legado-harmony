import { BookSource } from '../../model/data/Book';
import { HttpClient } from '../http/HttpClient';
import { BookSourceCheckOptions } from '../../utils/BookSourceCheckOptionsStore';

/** 单个书源一个环节的校验结论，供上层聚合成一次校验收据。 */
export class BookSourceStageCheckResult {
  ok: boolean = false;
  message: string = '';
}

/**
 * 域名可达性检查。
 * 只发一次 GET 根路径，判定"能不能连上"而非"规则对不对"，
 * 因此 4xx 也算可达（很多站点根路径就是 403/404），只有网络层失败与 5xx 才判为不可用。
 */
export class BookSourceDomainCheck {
  static origin(url: string): string {
    const matched = (url || '').match(/^https?:\/\/[^/?#]+/i);
    return matched ? matched[0] : '';
  }

  static async probe(source: BookSource, timeoutMs: number = 15000): Promise<BookSourceStageCheckResult> {
    const result = new BookSourceStageCheckResult();
    const origin = BookSourceDomainCheck.origin(source.bookSourceUrl || '');
    if (!origin) {
      result.ok = false;
      result.message = '书源地址不是有效域名';
      return result;
    }
    const http = new HttpClient(Math.max(3000, Math.min(timeoutMs, 30000)));
    try {
      const response = await http.execute({
        url: origin,
        method: 'GET',
        headers: { Accept: 'text/html,application/xhtml+xml' },
        connectTimeout: Math.max(3000, Math.min(timeoutMs, 15000)),
        readTimeout: Math.max(3000, Math.min(timeoutMs, 20000)),
        maxResponseBytes: 64 * 1024
      });
      if (response.success || (response.statusCode >= 200 && response.statusCode < 500)) {
        result.ok = true;
        result.message = `域名可达（HTTP ${response.statusCode}）`;
        return result;
      }
      result.ok = false;
      result.message = response.statusCode > 0 ?
        `域名返回 HTTP ${response.statusCode}` : `域名不可达：${response.error || '网络异常'}`;
      return result;
    } catch (e) {
      result.ok = false;
      result.message = `域名不可达：${e instanceof Error ? e.message : String(e || '网络异常')}`;
      return result;
    }
  }

  /** 按配置决定是否要跑域名检查。 */
  static shouldProbe(options: BookSourceCheckOptions): boolean {
    return options.checkDomain;
  }
}

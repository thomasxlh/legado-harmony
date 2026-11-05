import { BookSource, SearchRule, ExploreRule, BookInfoRule, TocRule, ContentRule } from '../../model/data/Book';

/**
 * 书源 JSON 的解析与文本抓取。
 *
 * 这些逻辑原本长在 BookSource 管理页里（页面方法无法在别处调用），规则订阅页需要
 * 在不打开书源页的前提下完成「下载 → 解析 → 比对」全流程，因此抽成公共模块。
 * 管理页保留同名方法并转调这里，避免调用点大改。
 */

export const SOURCE_IMPORT_FILE_LIMIT_BYTES: number = 25 * 1024 * 1024;
export const SOURCE_IMPORT_TIMEOUT_MS: number = 20000;
/**
 * 大文件传输预算：共享书源包动辄 5-10MB，弱网下 20s 内根本下不完，
 * 截断的正文 JSON.parse 必失败（表现为"不是有效书源JSON"）。
 * 连接超时保持快速失败，只放宽读取/下载等待。
 */
export const SOURCE_IMPORT_TRANSFER_TIMEOUT_MS: number = 60000;

/** 把导入异常转成可直接展示的中文文案。 */
export function importErrorMessageText(error: Object): string {
  if (error instanceof Error && isReadableErrorText(error.message)) return error.message;
  if (typeof error === 'string' && isReadableErrorText(error as string)) return error as string;
  if (error && typeof error === 'object') {
    const record = error as Record<string, Object>;
    const rawMessage = record['message'] || record['msg'] || record['reason'];
    let message = typeof rawMessage === 'string' ? (rawMessage as string).trim() : '';
    if (!isReadableErrorText(message) && rawMessage && typeof rawMessage === 'object') {
      const nested = rawMessage as Record<string, Object>;
      message = String(nested['message'] || nested['msg'] || nested['reason'] || '').trim();
    }
    const code = String(record['code'] || record['errorCode'] || '').trim();
    if (isReadableErrorText(message)) return code ? `${message} (${code})` : message;
    try {
      const json = JSON.stringify(error);
      if (json && json !== '{}') return json;
    } catch (_) {
    }
  }
  const fallback = String(error || '').trim();
  return isReadableErrorText(fallback) ? fallback : '未知错误';
}

export function isReadableErrorText(value: string): boolean {
  const text = (value || '').trim().toLowerCase();
  return !!text && !text.includes('[object object]') && text !== 'object object' && text !== '{}';
}

/** 去掉 BOM：各类导入来源都可能带 BOM。没有 BOM 时原样返回，避免对十几 MB 的字符串做整串复制。 */
export function stripBom(body: string): string {
  if (!body) return '';
  return body.charCodeAt(0) === 0xFEFF ? body.substring(1) : body;
}

/** 跳过前导空白后返回首个有效字符位置，不切割整串。 */
export function sourceJsonContentStart(body: string): number {
  if (!body) return 0;
  let index = 0;
  if (body.charCodeAt(0) === 0xFEFF) index++;
  const length = body.length;
  while (index < length) {
    const code = body.charCodeAt(index);
    if (code === 0x20 || code === 0x09 || code === 0x0A || code === 0x0D) {
      index++;
      continue;
    }
    break;
  }
  return index;
}

export function looksLikeSourceJson(body: string): boolean {
  if (!body) return false;
  const lead = body.charAt(sourceJsonContentStart(body));
  return lead === '[' || lead === '{';
}

export function isValidSourceJson(body: string): boolean {
  if (!looksLikeSourceJson(body)) return false;
  try {
    const parsed = JSON.parse(stripBom(body)) as Object;
    return Array.isArray(parsed) || (!!parsed && typeof parsed === 'object');
  } catch (_) {
    return false;
  }
}

export function importUrlHost(url: string): string {
  const match = (url || '').match(/^https?:\/\/([^/?#]+)/i);
  return match ? match[1] : '订阅地址';
}

export function importUrlOrigin(url: string): string {
  const match = (url || '').match(/^(https?:\/\/[^/?#]+)/i);
  return match ? match[1] : '';
}

/**
 * 生成候选地址：原始地址 + http→https + jsdelivr 官方镜像。
 * jsdelivr 主站在部分网络下 SSL 握手被直接重置，镜像主机路径与内容完全一致。
 */
export function importUrlCandidates(url: string): string[] {
  const raw = (url || '').trim();
  if (!raw) return [];
  const candidates: string[] = [raw];
  if (/^http:\/\//i.test(raw)) {
    const secure = `https://${raw.substring('http://'.length)}`;
    if (!candidates.includes(secure)) candidates.push(secure);
  }
  const jsdelivr = raw.match(/^https?:\/\/(?:cdn|fastly|gcore|testingcf)\.jsdelivr\.net(\/.*)$/i);
  if (jsdelivr) {
    for (const host of ['fastly.jsdelivr.net', 'gcore.jsdelivr.net', 'testingcf.jsdelivr.net']) {
      const mirror = `https://${host}${jsdelivr[1]}`;
      if (!candidates.includes(mirror)) candidates.push(mirror);
    }
  }
  return candidates;
}

/** 解析书源 JSON：根可以是数组、`{value: []}` 或单个书源对象；按 URL 去重且后者覆盖前者。 */
export function parseImportedSourcesFromJson(json: string): BookSource[] {
  const parsed: Object = JSON.parse(stripBom(json));
  let items: Record<string, Object>[] = [];
  if (Array.isArray(parsed)) {
    items = parsed as Record<string, Object>[];
  } else if (typeof parsed === 'object') {
    const obj = parsed as Record<string, Object>;
    if (Array.isArray(obj['value'])) {
      items = obj['value'] as Record<string, Object>[];
    } else if (obj['bookSourceUrl']) {
      items = [obj];
    }
  }
  const sources: BookSource[] = [];
  const indexByUrl = new Map<string, number>();
  for (const item of items) {
    const source = parseBookSourceJson(item);
    if (source.bookSourceUrl) {
      const existingIndex = indexByUrl.get(source.bookSourceUrl);
      if (existingIndex !== undefined) {
        sources[existingIndex] = source;
      } else {
        indexByUrl.set(source.bookSourceUrl, sources.length);
        sources.push(source);
      }
    }
  }
  return sources;
}

export function parseBookSourceJson(obj: Record<string, Object>): BookSource {
  const source = new BookSource();
  source.bookSourceUrl = obj['bookSourceUrl'] as string || '';
  source.bookSourceName = obj['bookSourceName'] as string || '';
  source.bookSourceType = Number(obj['bookSourceType'] || 0);
  source.bookSourceGroup = obj['bookSourceGroup'] as string || '';
  source.bookSourceComment = obj['bookSourceComment'] as string || '';
  source.loginUrl = obj['loginUrl'] as string || '';
  source.loginUi = obj['loginUi'] as string || '';
  source.loginCheckJs = obj['loginCheckJs'] as string || '';
  source.loginHeader = obj['loginHeader'] as string || '';
  source.loginInfo = String(obj['loginInfo'] || '');
  source.rawSourceJson = JSON.stringify(obj);
  source.bookUrlPattern = obj['bookUrlPattern'] as string || '';
  source.searchUrl = obj['searchUrl'] as string || '';
  source.exploreUrl = obj['exploreUrl'] as string || '';
  source.jsLib = obj['jsLib'] as string || '';
  source.header = obj['header'] as string || '';
  source.variableComment = obj['variableComment'] as string || '';
  source.variable = obj['variable'] as string || '';
  source.enabledCookieJar = obj['enabledCookieJar'] !== false;
  source.enabled = obj['enabled'] !== false;
  source.enabledExplore = obj['enabledExplore'] !== false;
  source.isPinned = obj['isPinned'] === true;
  source.isLocked = obj['isLocked'] === true || obj['locked'] === true;
  source.weight = (obj['weight'] as number) || 0;
  source.concurrentRate = obj['concurrentRate'] as string || '';
  // 远端文件常不带 lastUpdateTime；缺省按「刚更新」处理，订阅更新时才能覆盖旧副本。
  source.lastUpdateTime = Number(obj['lastUpdateTime'] || Date.now());
  if (!Number.isFinite(source.lastUpdateTime)) source.lastUpdateTime = Date.now();
  source.respondTime = Number(obj['respondTime'] || 180000);
  if (!Number.isFinite(source.respondTime)) source.respondTime = 180000;
  source.customOrder = Math.floor(Number(obj['customOrder'] || 0));
  source.customButton = obj['customButton'] === true;
  source.eventListener = obj['eventListener'] === true;

  const ruleSearch = obj['ruleSearch'];
  if (ruleSearch && typeof ruleSearch === 'string') {
    const rule = new SearchRule();
    applyRuleToSearchRule(parseCompactRule(ruleSearch as string), rule);
    source.searchRule = rule;
  } else if (ruleSearch && typeof ruleSearch === 'object') {
    source.searchRule = ruleSearch as SearchRule;
  } else if (obj['searchRule'] && typeof obj['searchRule'] === 'object') {
    source.searchRule = obj['searchRule'] as SearchRule;
  }

  const ruleExplore = obj['ruleExplore'];
  if (ruleExplore && typeof ruleExplore === 'string') {
    const rule = new ExploreRule();
    applyRuleToSearchRule(parseCompactRule(ruleExplore as string), rule);
    source.exploreRule = rule;
  } else if (ruleExplore && typeof ruleExplore === 'object' && !Array.isArray(ruleExplore)) {
    source.exploreRule = ruleExplore as ExploreRule;
  } else if (obj['exploreRule'] && typeof obj['exploreRule'] === 'object') {
    source.exploreRule = obj['exploreRule'] as ExploreRule;
  }

  const ruleBookInfo = obj['ruleBookInfo'];
  if (ruleBookInfo && typeof ruleBookInfo === 'string') {
    const rule = new BookInfoRule();
    applyRuleToBookInfoRule(parseCompactRule(ruleBookInfo as string), rule);
    source.bookInfoRule = rule;
  } else if (ruleBookInfo && typeof ruleBookInfo === 'object') {
    source.bookInfoRule = ruleBookInfo as BookInfoRule;
  } else if (obj['bookInfoRule'] && typeof obj['bookInfoRule'] === 'object') {
    source.bookInfoRule = obj['bookInfoRule'] as BookInfoRule;
  }

  const ruleToc = obj['ruleToc'];
  if (ruleToc && typeof ruleToc === 'string') {
    const rule = new TocRule();
    applyRuleToTocRule(parseCompactRule(ruleToc as string), rule);
    source.tocRule = rule;
  } else if (ruleToc && typeof ruleToc === 'object') {
    source.tocRule = ruleToc as TocRule;
  } else if (obj['tocRule'] && typeof obj['tocRule'] === 'object') {
    source.tocRule = obj['tocRule'] as TocRule;
  }

  const ruleContent = obj['ruleContent'];
  if (ruleContent && typeof ruleContent === 'string') {
    const rule = new ContentRule();
    applyRuleToContentRule(parseCompactRule(ruleContent as string), rule);
    source.contentRule = rule;
  } else if (ruleContent && typeof ruleContent === 'object') {
    source.contentRule = ruleContent as ContentRule;
  } else if (obj['contentRule'] && typeof obj['contentRule'] === 'object') {
    source.contentRule = obj['contentRule'] as ContentRule;
  }

  return source;
}

/**
 * 解析 `@{{key=value;key=value}}` 形式的紧凑规则串。
 * 分号只有在括号深度 0、且不在 `@js:` 值内部时才是分隔符。
 */
export function parseCompactRule(ruleStr: string): Record<string, string> {
  const result: Record<string, string> = {};

  let content = ruleStr.trim();
  if (content.startsWith('@{')) {
    content = content.substring(2);
  }
  if (content.endsWith('}')) {
    content = content.substring(0, content.length - 1);
  }

  let depth = 0;
  let inString = false;
  let stringChar = '';
  let inJsValue = false;

  const pairs: string[] = [];
  let current = '';

  for (let i = 0; i < content.length; i++) {
    const ch = content[i];

    if (inString) {
      current += ch;
      if (ch === '\\') {
        i++;
        if (i < content.length) current += content[i];
      } else if (ch === stringChar) {
        inString = false;
      }
      continue;
    }

    if (ch === '"' || ch === "'") {
      inString = true;
      stringChar = ch;
      current += ch;
      continue;
    }

    if (ch === '(' || ch === '[' || ch === '{') {
      depth++;
      current += ch;
      continue;
    }

    if (ch === ')' || ch === ']' || ch === '}') {
      if (depth > 0) depth--;
      current += ch;
      continue;
    }

    if (!inJsValue && current.trim().includes('=@js:')) {
      inJsValue = true;
    }

    if (ch === ';' && depth === 0 && !inJsValue) {
      pairs.push(current.trim());
      current = '';
      continue;
    }

    if (ch === ';' && depth === 0 && inJsValue) {
      const rest = content.substring(i + 1);
      const nextFieldMatch = rest.match(/^\s*(\w+)=/);
      if (nextFieldMatch) {
        pairs.push(current.trim());
        current = '';
        inJsValue = false;
        while (i + 1 < content.length &&
          (content[i + 1] === ' ' || content[i + 1] === '\n' || content[i + 1] === '\r')) {
          i++;
        }
        continue;
      }
    }

    current += ch;
  }

  if (current.trim()) {
    pairs.push(current.trim());
  }

  for (const pair of pairs) {
    const eqIdx = pair.indexOf('=');
    if (eqIdx > 0) {
      const field = pair.substring(0, eqIdx).trim();
      let value = pair.substring(eqIdx + 1).trim();

      if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      result[field] = value;
    }
  }

  return result;
}

export function applyRuleToSearchRule(fields: Record<string, string>, rule: SearchRule): void {
  rule.bookList = fields['bookList'] || fields['booklist'] || '';
  rule.name = fields['name'] || '';
  rule.author = fields['author'] || '';
  rule.coverUrl = fields['coverUrl'] || '';
  rule.intro = fields['intro'] || fields['desc'] || '';
  rule.kind = fields['kind'] || '';
  rule.status = fields['status'] || '';
  rule.lastChapter = fields['lastChapter'] || fields['lastchapter'] || '';
  rule.bookUrl = fields['bookUrl'] || fields['bookurl'] || '';
  rule.wordCount = fields['wordCount'] || fields['wordcount'] || '';
}

export function applyRuleToTocRule(fields: Record<string, string>, rule: TocRule): void {
  rule.chapterList = fields['chapterList'] || fields['chapterlist'] || '';
  rule.chapterName = fields['chapterName'] || fields['chaptername'] || '';
  rule.chapterUrl = fields['chapterUrl'] || fields['chapterurl'] || '';
  rule.nextTocUrl = fields['nextTocUrl'] || fields['nexttocurl'] || '';
  rule.isVip = fields['isVip'] || fields['isvip'] || '';
  rule.isPay = fields['isPay'] || fields['ispay'] || '';
  rule.updateTime = fields['updateTime'] || fields['updatetime'] || '';
}

export function applyRuleToContentRule(fields: Record<string, string>, rule: ContentRule): void {
  rule.content = fields['content'] || '';
  rule.title = fields['title'] || '';
  rule.images = fields['images'] || '';
  rule.sourceRegex = fields['sourceRegex'] || fields['sourceregex'] || '';
  rule.nextContentUrl = fields['nextContentUrl'] || fields['nextcontenturl'] || '';
  rule.replaceRegex = fields['replaceRegex'] || fields['replaceregex'] || '';
  rule.imageDecode = fields['imageDecode'] || fields['imagedecode'] || '';
  rule.imageStyle = fields['imageStyle'] || fields['imagestyle'] || '';
  rule.payAction = fields['payAction'] || fields['payaction'] || '';
}

export function applyRuleToBookInfoRule(fields: Record<string, string>, rule: BookInfoRule): void {
  rule.init = fields['init'] || '';
  rule.name = fields['name'] || '';
  rule.author = fields['author'] || '';
  rule.coverUrl = fields['coverUrl'] || '';
  rule.intro = fields['intro'] || fields['desc'] || '';
  rule.kind = fields['kind'] || '';
  rule.lastChapter = fields['lastChapter'] || fields['lastchapter'] || '';
  rule.wordCount = fields['wordCount'] || fields['wordcount'] || '';
  rule.updateTime = fields['updateTime'] || fields['updatetime'] || '';
  rule.tocUrl = fields['tocUrl'] || fields['tocurl'] || '';
}

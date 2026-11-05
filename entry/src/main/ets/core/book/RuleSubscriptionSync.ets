import { common } from '@kit.AbilityKit';
import request from '@ohos.request';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { HttpClient, HttpRequest, HttpResponse } from '../http/HttpClient';
import { RawHttpTextClient } from '../http/RawHttpTextClient';
import { AppDatabase, BookSourceImportBatchResult } from '../../model/data/AppDatabase';
import { BookSource } from '../../model/data/Book';
import {
  importErrorMessageText,
  importUrlCandidates,
  importUrlHost,
  isValidSourceJson,
  stripBom,
  parseImportedSourcesFromJson,
  SOURCE_IMPORT_FILE_LIMIT_BYTES,
  SOURCE_IMPORT_TIMEOUT_MS,
  SOURCE_IMPORT_TRANSFER_TIMEOUT_MS
} from './BookSourceJsonCodec';
import { ImportedReplaceRule, ReplaceRuleImport, ReplaceRuleImportResult } from '../rule/ReplaceRuleImport';
import { ReaderReplaceRule, ReaderReplaceRuleStore } from '../../utils/ReaderReplaceRuleStore';
import {
  RuleSubscription,
  RuleSubscriptionStore,
  RULE_SUB_TYPE_BOOK_SOURCE,
  RULE_SUB_TYPE_REPLACE_RULE
} from '../../utils/RuleSubscriptionStore';

export const RULE_SUB_TIMEOUT_MS: number = SOURCE_IMPORT_TIMEOUT_MS;
/** 批量更新时同时进行的订阅数。主机普遍同源，4 路已能压住总耗时又不至于被限流。 */
export const RULE_SUB_SYNC_CONCURRENCY: number = 4;

export enum RuleSubscriptionSyncStatus {
  Ok = 'ok',
  NeedConfirm = 'needConfirm',
  NoChange = 'noChange',
  Error = 'error'
}

/** 一次订阅更新的结果。needConfirm 时 pendingSources/pendingRules 是等待用户确认的条目。 */
export class RuleSubscriptionSyncResult {
  status: RuleSubscriptionSyncStatus = RuleSubscriptionSyncStatus.Ok;
  remoteCount: number = 0;
  newCount: number = 0;
  updateCount: number = 0;
  lockedCount: number = 0;
  failedCount: number = 0;
  message: string = '';
  pendingSources: BookSource[] = [];
  pendingRules: ImportedReplaceRule[] = [];
}

/**
 * 规则订阅的更新引擎：抓取 → 解析 → 与本地比对 → 落库或交给界面确认。
 *
 * 拆出来的原因是书源管理与订阅页都要用同一套判断（静默更新、按 lastUpdateTime 判新旧、
 * 保留本地分组），放在页面里没法复用。
 */
export class RuleSubscriptionSync {
  /** 抓取订阅正文：并发候选竞速，失败后走系统下载服务兜底。 */
  static async fetchText(context: common.UIAbilityContext, url: string): Promise<string> {
    const candidates = importUrlCandidates(url);
    if (candidates.length === 0) throw new Error('订阅地址为空');
    const failures: string[] = [];

    const raced = await RuleSubscriptionSync.raceCandidates(candidates);
    if (raced) return raced;
    failures.push('直连获取失败');

    const plainHttpUrl = candidates.find((candidate: string) => /^http:\/\//i.test(candidate));
    if (plainHttpUrl) {
      try {
        const body = await RawHttpTextClient.get(plainHttpUrl, SOURCE_IMPORT_FILE_LIMIT_BYTES, SOURCE_IMPORT_TRANSFER_TIMEOUT_MS);
        if (isValidSourceJson(body)) return stripBom(body);
      } catch (error) {
        failures.push(`${importUrlHost(plainHttpUrl)}: ${importErrorMessageText(error as Object)}`);
      }
    }

    for (const candidate of candidates) {
      try {
        const body = await RuleSubscriptionSync.downloadText(context, candidate);
        if (isValidSourceJson(body)) return stripBom(body);
      } catch (error) {
        failures.push(`${importUrlHost(candidate)}: ${importErrorMessageText(error as Object)}`);
      }
    }
    throw new Error(failures.join('；') || '获取订阅内容失败');
  }

  private static raceCandidates(candidates: string[]): Promise<string> {
    const targets = candidates.slice(0, Math.min(candidates.length, 6));
    return new Promise<string>((resolve, reject) => {
      let remaining = targets.length;
      const failures: string[] = [];
      for (const requestUrl of targets) {
        const request: HttpRequest = {
          url: requestUrl,
          method: 'GET',
          headers: { 'Accept': 'application/json,text/plain,*/*' },
          connectTimeout: RULE_SUB_TIMEOUT_MS,
          readTimeout: SOURCE_IMPORT_TRANSFER_TIMEOUT_MS,
          maxResponseBytes: SOURCE_IMPORT_FILE_LIMIT_BYTES
        };
        new HttpClient(RULE_SUB_TIMEOUT_MS).execute(request).then((response: HttpResponse): void => {
          if (isValidSourceJson(response.body)) {
            resolve(stripBom(response.body));
            return;
          }
          const reason = response.success ? '响应内容不是有效 JSON' : (response.error || `HTTP ${response.statusCode}`);
          throw new Error(reason);
        }).catch((error: Object): void => {
          failures.push(`${importUrlHost(requestUrl)}: ${importErrorMessageText(error)}`);
          remaining--;
          if (remaining === 0) reject(new Error(failures.join('；')));
        });
      }
    });
  }

  private static async downloadText(context: common.UIAbilityContext, url: string): Promise<string> {
    const filePath = `${context.cacheDir}/rule_sub_${Date.now()}_${Math.floor(Math.random() * 1000000)}.json`;
    let task: request.DownloadTask | null = null;
    try {
      task = await request.downloadFile(context, {
        url: url,
        header: {
          'Accept': 'application/json,text/plain,*/*',
          'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS; Mobile) AppleWebKit/537.36 Safari/537.36'
        },
        enableMetered: true,
        enableRoaming: true,
        filePath: filePath,
        background: false,
        title: '更新规则订阅'
      });
      await RuleSubscriptionSync.waitDownload(task);
      return await RuleSubscriptionSync.readText(filePath);
    } finally {
      if (task) {
        try {
          await task.delete();
        } catch (_) {
        }
      }
      try {
        fs.unlinkSync(filePath);
      } catch (_) {
      }
    }
  }

  private static waitDownload(task: request.DownloadTask): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let settled = false;
      const finish = (errorMessage: string = ''): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timeoutId);
        try {
          task.off('complete', onComplete);
          task.off('fail', onFail);
        } catch (_) {
        }
        if (errorMessage) reject(new Error(errorMessage));
        else resolve();
      };
      const onComplete = (): void => finish();
      const onFail = (errorCode: number): void => finish(`下载服务失败 (${errorCode})`);
      const timeoutId = setTimeout(() => finish('下载服务超时'), SOURCE_IMPORT_TRANSFER_TIMEOUT_MS);
      try {
        task.on('complete', onComplete);
        task.on('fail', onFail);
      } catch (error) {
        finish(importErrorMessageText(error as Object));
        return;
      }
      task.query().then((info: request.DownloadInfo): void => {
        if (info.status === request.SESSION_SUCCESSFUL) finish();
        else if (info.status === request.SESSION_FAILED) finish(`下载服务失败 (${info.failedReason})`);
      }).catch((_error: Object): void => {
      });
    });
  }

  private static async readText(path: string): Promise<string> {
    let file: fs.File | null = null;
    try {
      const stat = await fs.stat(path);
      if (stat.size <= 0) return '';
      if (stat.size > SOURCE_IMPORT_FILE_LIMIT_BYTES) return '';
      file = await fs.open(path, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, buffer, { offset: 0, length: stat.size });
      return stripBom(util.TextDecoder.create('utf-8')
        .decodeWithStream(new Uint8Array(buffer), { stream: false }));
    } finally {
      if (file) await fs.close(file);
    }
  }

  /**
   * 更新一条书源订阅。
   * silent 为真直接写库（保留本地分组/置顶/锁定/顺序）；否则只把待更新条目交回界面确认。
   */
  static async syncBookSourceSubscription(context: common.UIAbilityContext, sub: RuleSubscription,
    silent: boolean): Promise<RuleSubscriptionSyncResult> {
    const result = new RuleSubscriptionSyncResult();
    let content = '';
    try {
      content = await RuleSubscriptionSync.fetchText(context, sub.url);
    } catch (error) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = importErrorMessageText(error as Object);
      return result;
    }
    let remote: BookSource[] = [];
    try {
      remote = parseImportedSourcesFromJson(content);
    } catch (error) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = '订阅内容不是有效的书源 JSON';
      return result;
    }
    if (remote.length === 0) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = '未找到有效的书源';
      return result;
    }
    result.remoteCount = remote.length;

    const db = AppDatabase.getInstance();
    await db.initWithContext(context);
    const summaries = await db.getBookSourceSummaries();
    const localByUrl = new Map<string, BookSource>();
    for (const item of summaries) localByUrl.set(item.bookSourceUrl, item);

    const pending: BookSource[] = [];
    for (const source of remote) {
      const local = localByUrl.get(source.bookSourceUrl);
      if (!local) {
        source.bookSourceGroup = source.bookSourceGroup || '';
        pending.push(source);
        result.newCount++;
        continue;
      }
      if (local.isLocked) {
        result.lockedCount++;
        continue;
      }
      // 远端没有 lastUpdateTime 时解析层已补为「现在」，这里只比远端更新才覆盖本地。
      if (local.lastUpdateTime < source.lastUpdateTime) {
        if (silent) {
          // 静默更新保留用户在本机整理的分组，其余规则整体换成远端新版。
          if ((local.bookSourceGroup || '').trim()) source.bookSourceGroup = local.bookSourceGroup;
        }
        pending.push(source);
        result.updateCount++;
      }
    }

    if (pending.length === 0) {
      result.status = RuleSubscriptionSyncStatus.NoChange;
      result.message = result.lockedCount > 0 ? `已是最新版本（${result.lockedCount} 个已锁定未覆盖）` : '已是最新版本';
      return result;
    }
    if (!silent) {
      result.status = RuleSubscriptionSyncStatus.NeedConfirm;
      result.pendingSources = pending;
      result.message = `发现 ${result.newCount} 个新增、${result.updateCount} 个更新`;
      return result;
    }

    const applied = await RuleSubscriptionSync.applyBookSources(pending);
    result.lockedCount += applied.lockedCount;
    result.failedCount = applied.failedCount;
    if (applied.importedSources.length === 0) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = applied.lastErrorMessage || '写入书源失败';
      return result;
    }
    result.status = RuleSubscriptionSyncStatus.Ok;
    result.message = RuleSubscriptionSync.describeApply(result.newCount, result.updateCount, applied);
    return result;
  }

  /** 把待更新书源写库。insertBookSourcesBatch 已负责保留顺序、置顶与锁定跳过。 */
  static async applyBookSources(sources: BookSource[]): Promise<BookSourceImportBatchResult> {
    const db = AppDatabase.getInstance();
    return db.insertBookSourcesBatch(sources);
  }

  /**
   * 更新一条替换规则订阅。
   * allowConvert 为假时遇到 Android 格式的规则集直接报错，由界面先弹确认再重试。
   */
  static async syncReplaceRuleSubscription(context: common.UIAbilityContext, sub: RuleSubscription,
    allowConvert: boolean): Promise<RuleSubscriptionSyncResult> {
    const result = new RuleSubscriptionSyncResult();
    let content = '';
    try {
      content = await RuleSubscriptionSync.fetchText(context, sub.url);
    } catch (error) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = importErrorMessageText(error as Object);
      return result;
    }
    let parsed: ReplaceRuleImportResult;
    try {
      parsed = ReplaceRuleImport.parse(content);
    } catch (error) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = '订阅内容不是有效的替换规则 JSON';
      return result;
    }
    if (parsed.rules.length === 0) {
      result.status = RuleSubscriptionSyncStatus.Error;
      result.message = '未找到有效的替换净化规则';
      return result;
    }
    result.remoteCount = parsed.rules.length;
    if (ReplaceRuleImport.needsConfirm(parsed) && !allowConvert) {
      result.status = RuleSubscriptionSyncStatus.NeedConfirm;
      result.pendingRules = parsed.rules;
      result.message = `检测到${parsed.formatLabel}净化规则，需转换后导入`;
      return result;
    }

    const local = await ReaderReplaceRuleStore.load(context, true);
    const merged = RuleSubscriptionSync.mergeReplaceRules(local, parsed.rules);
    if (merged.added === 0 && merged.updated === 0) {
      result.status = RuleSubscriptionSyncStatus.NoChange;
      result.message = '已是最新版本';
      return result;
    }
    await ReaderReplaceRuleStore.save(context, merged.rules);
    result.newCount = merged.added;
    result.updateCount = merged.updated;
    result.status = RuleSubscriptionSyncStatus.Ok;
    const source = parsed.formatLabel === '本应用' ? '' : `（来源：${parsed.formatLabel}）`;
    const skipped = parsed.skipped > 0 ? `，跳过 ${parsed.skipped} 条` : '';
    result.message = `新增 ${merged.added} 条、更新 ${merged.updated} 条${source}${skipped}`;
    return result;
  }

  /** 按「id 与匹配规则都相同」判为同一条，避免不同来源的小 id 互相覆盖。 */
  private static mergeReplaceRules(local: ReaderReplaceRule[],
    entries: ImportedReplaceRule[]): ReplaceRuleMergeResult {
    const result = new ReplaceRuleMergeResult();
    const next = local.map((rule: ReaderReplaceRule) => ReaderReplaceRuleStore.cloneRule(rule));
    const usedIds = new Set<number>();
    for (const rule of next) usedIds.add(rule.id);
    let nextId = Date.now();
    for (const entry of entries) {
      const imported = ReaderReplaceRuleStore.fromImportEntry(entry);
      if (!imported.pattern.trim()) continue;
      const index = next.findIndex((rule: ReaderReplaceRule) =>
        rule.id === imported.id && rule.pattern === imported.pattern);
      if (index >= 0) {
        next[index] = imported;
        result.updated++;
      } else {
        while (usedIds.has(imported.id) || imported.id <= 0) imported.id = nextId++;
        usedIds.add(imported.id);
        next.push(imported);
        result.added++;
      }
    }
    result.rules = next;
    return result;
  }

  static describeApply(newCount: number, updateCount: number, applied: BookSourceImportBatchResult): string {
    const parts: string[] = [];
    if (newCount > 0) parts.push(`新增 ${newCount} 个书源`);
    if (updateCount > 0) parts.push(`更新 ${updateCount} 个书源`);
    if (applied.lockedCount > 0) parts.push(`${applied.lockedCount} 个已锁定未覆盖`);
    if (applied.failedCount > 0) parts.push(`${applied.failedCount} 个失败`);
    return parts.join('，') || '已是最新版本';
  }

  /** 自动更新判定：开启自动更新且距上次自动更新已超过设定间隔。 */
  static shouldAutoUpdate(sub: RuleSubscription, now: number = Date.now()): boolean {
    if (!sub.autoUpdate || !RuleSubscriptionStore.isTypeSupported(sub.type)) return false;
    if (sub.updateAt <= 0) return true;
    const intervalMs = Math.max(1, sub.updateIntervalHours) * 3600 * 1000;
    return now - sub.updateAt >= intervalMs;
  }

  static canSync(sub: RuleSubscription): boolean {
    return RuleSubscriptionStore.isTypeSupported(sub.type) && RuleSubscriptionStore.isValidUrl(sub.url);
  }

  static isBookSourceSubscription(sub: RuleSubscription): boolean {
    return sub.type === RULE_SUB_TYPE_BOOK_SOURCE;
  }

  static isReplaceRuleSubscription(sub: RuleSubscription): boolean {
    return sub.type === RULE_SUB_TYPE_REPLACE_RULE;
  }
}

class ReplaceRuleMergeResult {
  rules: ReaderReplaceRule[] = [];
  added: number = 0;
  updated: number = 0;
}

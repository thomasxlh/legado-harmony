import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import { BookSourceSubscription, BookSourceSubscriptionStore } from './BookSourceSubscriptionStore';

/** 订阅类型：书源。 */
export const RULE_SUB_TYPE_BOOK_SOURCE: number = 0;
/** 订阅类型：RSS 订阅源（当前版本无 RSS 阅读模块，仅保留类型位以便后续接入）。 */
export const RULE_SUB_TYPE_RSS: number = 1;
/** 订阅类型：替换净化规则。 */
export const RULE_SUB_TYPE_REPLACE_RULE: number = 2;

export const RULE_SUB_DEFAULT_INTERVAL_HOURS: number = 12;
export const RULE_SUB_MIN_INTERVAL_HOURS: number = 1;
export const RULE_SUB_MAX_INTERVAL_HOURS: number = 24 * 30;

/**
 * 一条规则订阅。
 *
 * 对齐 Android 的 RuleSub：书源与替换规则共用一张订阅表，靠 type 区分；
 * 自动更新判断依赖 update/updateAt/updateIntervalHours，静默更新决定是否绕过用户确认。
 */
export class RuleSubscription {
  id: number = 0;
  name: string = '';
  url: string = '';
  type: number = RULE_SUB_TYPE_BOOK_SOURCE;
  customOrder: number = 0;
  autoUpdate: boolean = false;
  /** 上次自动更新的时间戳（手动更新不写这里，避免打断自动更新的节奏判断）。 */
  updateAt: number = 0;
  updateIntervalHours: number = RULE_SUB_DEFAULT_INTERVAL_HOURS;
  silentUpdate: boolean = false;
  lastSyncTime: number = 0;
  lastSyncCount: number = 0;
  lastSyncError: string = '';

  constructor(url: string = '', type: number = RULE_SUB_TYPE_BOOK_SOURCE) {
    this.url = url;
    this.type = type;
  }
}

interface RuleSubscriptionRawItem {
  id?: number;
  name?: string;
  url?: string;
  type?: number;
  customOrder?: number;
  autoUpdate?: boolean;
  updateAt?: number;
  updateIntervalHours?: number;
  silentUpdate?: boolean;
  lastSyncTime?: number;
  lastSyncCount?: number;
  lastSyncError?: string;
}

/**
 * 规则订阅表：书源订阅与替换规则订阅的统一存储。
 * 存储形态同其它 preferences 名单（JSON 数组），并负责从旧的「书源订阅」表迁移。
 */
export class RuleSubscriptionStore {
  private static readonly STORE_NAME: string = 'rule_subscriptions';
  private static readonly KEY: string = 'subscriptionsV1';
  private static readonly MIGRATED_KEY: string = 'migratedFromBookSourceSubscriptions';
  private static cached: RuleSubscription[] | null = null;

  static invalidateCache(): void {
    RuleSubscriptionStore.cached = null;
  }

  static isValidUrl(url: string): boolean {
    return /^https?:\/\//i.test((url || '').trim());
  }

  /**
   * 订阅去重键：忽略协议（http/https）、host 大小写与默认端口、尾斜杠，
   * 其余路径与查询参数保留原样参与比较。
   */
  static normalizeKey(url: string): string {
    const trimmed = (url || '').trim();
    const match = trimmed.match(/^https?:\/\/([^/?#]+)([^#]*)/i);
    if (!match) {
      return trimmed.toLowerCase();
    }
    const host = match[1].toLowerCase().replace(/:(80|443)$/, '');
    let path = match[2] || '';
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return `//${host}${path}`;
  }

  static typeLabel(type: number): string {
    if (type === RULE_SUB_TYPE_REPLACE_RULE) return '替换规则';
    if (type === RULE_SUB_TYPE_RSS) return 'RSS';
    return '书源';
  }

  /** 该类型在当前版本是否真正可同步。RSS 缺阅读模块，只记录地址。 */
  static isTypeSupported(type: number): boolean {
    return type === RULE_SUB_TYPE_BOOK_SOURCE || type === RULE_SUB_TYPE_REPLACE_RULE;
  }

  static newSubscription(url: string = '', type: number = RULE_SUB_TYPE_BOOK_SOURCE): RuleSubscription {
    const sub = new RuleSubscription(url, type);
    sub.id = Date.now();
    sub.autoUpdate = false;
    sub.updateIntervalHours = RULE_SUB_DEFAULT_INTERVAL_HOURS;
    return sub;
  }

  static cloneSubscription(source: RuleSubscription): RuleSubscription {
    const copy = new RuleSubscription(source.url, source.type);
    copy.id = source.id;
    copy.name = source.name;
    copy.customOrder = source.customOrder;
    copy.autoUpdate = source.autoUpdate;
    copy.updateAt = source.updateAt;
    copy.updateIntervalHours = source.updateIntervalHours;
    copy.silentUpdate = source.silentUpdate;
    copy.lastSyncTime = source.lastSyncTime;
    copy.lastSyncCount = source.lastSyncCount;
    copy.lastSyncError = source.lastSyncError;
    return copy;
  }

  static async load(context: Context, force: boolean = false): Promise<RuleSubscription[]> {
    if (!force && RuleSubscriptionStore.cached) {
      return RuleSubscriptionStore.cloneAll(RuleSubscriptionStore.cached);
    }
    const store = await preferences.getPreferences(context, RuleSubscriptionStore.STORE_NAME);
    const value = await store.get(RuleSubscriptionStore.KEY, '');
    const raw = typeof value === 'string' ? value : '';
    let subs = RuleSubscriptionStore.decode(raw);
    if (subs.length === 0 && !(await store.get(RuleSubscriptionStore.MIGRATED_KEY, false) as boolean)) {
      subs = await RuleSubscriptionStore.migrateLegacy(context);
      await store.put(RuleSubscriptionStore.MIGRATED_KEY, true);
      await store.put(RuleSubscriptionStore.KEY, JSON.stringify(subs));
      await store.flush();
    }
    subs = RuleSubscriptionStore.normalizeOrder(subs);
    RuleSubscriptionStore.cached = RuleSubscriptionStore.cloneAll(subs);
    return subs;
  }

  static async save(context: Context, subs: RuleSubscription[]): Promise<void> {
    const normalized = RuleSubscriptionStore.normalizeOrder(subs);
    RuleSubscriptionStore.cached = RuleSubscriptionStore.cloneAll(normalized);
    const store = await preferences.getPreferences(context, RuleSubscriptionStore.STORE_NAME);
    await store.put(RuleSubscriptionStore.KEY, JSON.stringify(normalized));
    await store.flush();
  }

  /** 写入单条（新增或按 id 覆盖），返回最新全表。调用方负责再 save。 */
  static upsert(list: RuleSubscription[], sub: RuleSubscription): RuleSubscription[] {
    const result = RuleSubscriptionStore.cloneAll(list);
    const index = result.findIndex((item: RuleSubscription) => item.id === sub.id);
    if (index >= 0) {
      result[index] = RuleSubscriptionStore.cloneSubscription(sub);
    } else {
      sub.customOrder = result.length;
      result.push(RuleSubscriptionStore.cloneSubscription(sub));
    }
    return RuleSubscriptionStore.normalizeOrder(result);
  }

  /** 按 normalizeKey 找同地址同类型的订阅。 */
  static findByUrl(list: RuleSubscription[], url: string, type: number): RuleSubscription | null {
    const key = RuleSubscriptionStore.normalizeKey(url);
    for (const item of list) {
      if (item.type === type && RuleSubscriptionStore.normalizeKey(item.url) === key) return item;
    }
    return null;
  }

  /**
   * 把旧的「书源订阅」表迁移成 type=0 的规则订阅。
   * 旧表只有地址与同步结果，名称按 host 补，其余取默认值。
   */
  private static async migrateLegacy(context: Context): Promise<RuleSubscription[]> {
    let legacy: BookSourceSubscription[] = [];
    try {
      legacy = await BookSourceSubscriptionStore.load(context, true);
    } catch (_) {
      return [];
    }
    const subs: RuleSubscription[] = [];
    let order = 0;
    for (const item of legacy) {
      if (!item || !item.url) continue;
      const sub = new RuleSubscription(item.url, RULE_SUB_TYPE_BOOK_SOURCE);
      sub.id = Date.now() + order;
      sub.name = RuleSubscriptionStore.hostOf(item.url);
      sub.customOrder = order++;
      sub.lastSyncTime = item.lastSyncTime;
      sub.lastSyncCount = item.lastSyncCount;
      sub.lastSyncError = item.lastSyncError;
      subs.push(sub);
    }
    return subs;
  }

  static hostOf(url: string): string {
    const match = (url || '').match(/^https?:\/\/([^/?#]+)/i);
    return match ? match[1] : '订阅';
  }

  private static normalizeOrder(subs: RuleSubscription[]): RuleSubscription[] {
    return subs.map((sub: RuleSubscription, index: number) => {
      const copy = RuleSubscriptionStore.cloneSubscription(sub);
      copy.customOrder = index;
      return copy;
    });
  }

  private static decode(raw: string): RuleSubscription[] {
    if (!raw) return [];
    try {
      const items = JSON.parse(raw) as RuleSubscriptionRawItem[];
      if (!Array.isArray(items)) return [];
      const subs: RuleSubscription[] = [];
      for (const item of items) {
        if (!item || typeof item.url !== 'string' || !item.url) continue;
        const type = Number(item.type);
        const sub = new RuleSubscription(item.url, Number.isFinite(type) ? type : RULE_SUB_TYPE_BOOK_SOURCE);
        sub.id = Number(item.id || 0);
        if (!Number.isFinite(sub.id) || sub.id <= 0) sub.id = Date.now() + subs.length;
        sub.name = typeof item.name === 'string' && item.name.trim() ? item.name.trim() :
          RuleSubscriptionStore.hostOf(item.url);
        sub.customOrder = Number(item.customOrder || 0);
        if (!Number.isFinite(sub.customOrder)) sub.customOrder = subs.length;
        sub.autoUpdate = item.autoUpdate === true;
        sub.silentUpdate = item.silentUpdate === true;
        sub.updateAt = Number(item.updateAt || 0);
        if (!Number.isFinite(sub.updateAt)) sub.updateAt = 0;
        const interval = Number(item.updateIntervalHours || RULE_SUB_DEFAULT_INTERVAL_HOURS);
        sub.updateIntervalHours = Number.isFinite(interval) ?
          Math.min(RULE_SUB_MAX_INTERVAL_HOURS, Math.max(RULE_SUB_MIN_INTERVAL_HOURS, interval)) :
          RULE_SUB_DEFAULT_INTERVAL_HOURS;
        sub.lastSyncTime = Number(item.lastSyncTime || 0);
        if (!Number.isFinite(sub.lastSyncTime)) sub.lastSyncTime = 0;
        sub.lastSyncCount = Number(item.lastSyncCount || 0);
        if (!Number.isFinite(sub.lastSyncCount)) sub.lastSyncCount = 0;
        sub.lastSyncError = typeof item.lastSyncError === 'string' ? item.lastSyncError : '';
        subs.push(sub);
      }
      return subs;
    } catch (_) {
      return [];
    }
  }

  private static cloneAll(subs: RuleSubscription[]): RuleSubscription[] {
    return subs.map((sub: RuleSubscription) => RuleSubscriptionStore.cloneSubscription(sub));
  }
}

import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { BookSource } from '../model/data/Book';
import { AppDatabase } from '../model/data/AppDatabase';
import { AppBackgroundLayer } from '../components/AppBackgroundLayer';
import { SettingsTitleBar } from '../components/SettingsTitleBar';
import { AdaptiveSwitch } from '../components/AdaptiveSwitch';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { HdsFeedback } from '../utils/HdsFeedback';
import { syncSystemBars } from '../utils/SystemBars';
import { SystemDialogSession } from '../utils/SystemDialogSession';
import { AsyncSemaphore } from '../core/concurrency/AsyncSemaphore';
import {
  RuleSubscription,
  RuleSubscriptionStore,
  RULE_SUB_DEFAULT_INTERVAL_HOURS,
  RULE_SUB_MAX_INTERVAL_HOURS,
  RULE_SUB_MIN_INTERVAL_HOURS,
  RULE_SUB_TYPE_BOOK_SOURCE,
  RULE_SUB_TYPE_RSS,
  RULE_SUB_TYPE_REPLACE_RULE
} from '../utils/RuleSubscriptionStore';
import {
  RuleSubscriptionSync,
  RuleSubscriptionSyncResult,
  RuleSubscriptionSyncStatus,
  RULE_SUB_SYNC_CONCURRENCY
} from '../core/book/RuleSubscriptionSync';

const FILTER_ALL: number = -1;

/** 筛选 chip 的渲染描述；key 带上计数与选中态，变化时才会重建文本。 */
class FilterChipSpec {
  key: string = '';
  name: string = '';
  text: string = '';
  type: number = FILTER_ALL;
}

/**
 * 规则订阅管理页。
 *
 * 书源与替换净化规则共用一张订阅表（对齐 Android 的 RuleSub），因此订阅不再挂在
 * 书源页的「+」下拉弹窗里，而是一个独立页面：列表 + 类型徽章 + 上次同步 + 失败原因，
 * 点按更新、长按出菜单、拖动排序、顶部批量更新。
 */
@Entry
@Component
struct RuleSubscriptionPage {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State subs: RuleSubscription[] = [];
  @State isLoading: boolean = true;
  @State filterType: number = FILTER_ALL;
  @State syncingIds: string[] = [];
  @State isBatchRunning: boolean = false;
  @State batchDone: number = 0;
  @State batchTotal: number = 0;
  @State batchFailCount: number = 0;
  @State showAddMenu: boolean = false;
  @State draggingIndex: number = -1;
  // 卡片右上角「更多操作」被点后的一小段时间内，忽略整卡的点按刷新。
  private suppressCardClickUntil: number = 0;
  @State @Watch('onEditDialogFlagChanged') showEditDialog: boolean = false;
  @State editingId: number = 0;
  @State draftName: string = '';
  @State draftUrl: string = '';
  @State draftType: number = RULE_SUB_TYPE_BOOK_SOURCE;
  @State draftAutoUpdate: boolean = false;
  @State draftSilentUpdate: boolean = false;
  @State draftInterval: string = `${RULE_SUB_DEFAULT_INTERVAL_HOURS}`;
  @State @Watch('onConfirmDialogFlagChanged') showConfirmDialog: boolean = false;
  @State confirmTitle: string = '';
  @State confirmMessage: string = '';
  @State pendingSources: BookSource[] = [];
  @State pendingSelectedUrls: string[] = [];
  private editingDialogSession: SystemDialogSession = new SystemDialogSession();
  private confirmDialogSession: SystemDialogSession = new SystemDialogSession();

  aboutToAppear(): void {
    this.syncBars();
    this.loadSubscriptions(false);
  }

  onPageShow(): void {
    this.syncBars();
    this.loadSubscriptions(false);
    this.runAutoUpdate();
  }

  onEditDialogFlagChanged(): void {
    if (!this.showEditDialog) this.editingDialogSession.close(this.getUIContext());
  }

  onConfirmDialogFlagChanged(): void {
    if (!this.showConfirmDialog) this.confirmDialogSession.close(this.getUIContext());
  }

  async loadSubscriptions(force: boolean): Promise<void> {
    this.isLoading = true;
    try {
      this.subs = await RuleSubscriptionStore.load(getContext(this), force);
    } catch (e) {
      console.error('加载规则订阅失败:', e);
      HdsFeedback.showToast('加载订阅失败');
    } finally {
      this.isLoading = false;
    }
  }

  async reloadSubscriptions(): Promise<void> {
    this.subs = await RuleSubscriptionStore.load(getContext(this), true);
  }

  async saveSubscriptions(): Promise<void> {
    await RuleSubscriptionStore.save(getContext(this), this.subs);
  }

  // ---------- 派生数据 ----------

  visibleSubs(): RuleSubscription[] {
    if (this.filterType === FILTER_ALL) return this.subs;
    return this.subs.filter((sub: RuleSubscription) => sub.type === this.filterType);
  }

  countOfType(type: number): number {
    return this.subs.filter((sub: RuleSubscription) => sub.type === type).length;
  }

  isSyncing(sub: RuleSubscription): boolean {
    return this.syncingIds.includes(`${sub.id}`);
  }

  subscriptionKey(sub: RuleSubscription): string {
    return `${sub.id}_${sub.type}_${sub.name}_${sub.autoUpdate}_${sub.silentUpdate}_${sub.updateIntervalHours}` +
      `_${sub.lastSyncTime}_${sub.lastSyncCount}_${sub.lastSyncError}`;
  }

  typeLabel(type: number): string {
    return RuleSubscriptionStore.typeLabel(type);
  }

  typeColor(type: number): string {
    if (type === RULE_SUB_TYPE_REPLACE_RULE) return this.appDarkMode ? '#7FB2DF' : '#3B7EBF';
    if (type === RULE_SUB_TYPE_RSS) return this.appDarkMode ? '#C9A6E0' : '#8C5FB0';
    return ThemeRuntime.accentColor(this.appDarkMode);
  }

  formatTime(time: number): string {
    if (!time || time <= 0) return '未同步';
    const date = new Date(time);
    const hours = date.getHours() < 10 ? `0${date.getHours()}` : `${date.getHours()}`;
    const minutes = date.getMinutes() < 10 ? `0${date.getMinutes()}` : `${date.getMinutes()}`;
    return `${date.getMonth() + 1}月${date.getDate()}日 ${hours}:${minutes}`;
  }

  statusText(sub: RuleSubscription): string {
    if (sub.lastSyncError) return `更新失败：${sub.lastSyncError}`;
    if (sub.lastSyncTime > 0) return `上次更新 ${this.formatTime(sub.lastSyncTime)} · ${sub.lastSyncCount} 条`;
    return '尚未更新';
  }

  metaText(sub: RuleSubscription): string {
    const parts: string[] = [];
    if (sub.autoUpdate) {
      parts.push(`自动更新 ${sub.updateIntervalHours} 小时`);
      if (sub.silentUpdate) parts.push('静默');
    }
    if (!RuleSubscriptionStore.isTypeSupported(sub.type)) parts.push('当前版本不支持同步');
    return parts.join(' · ');
  }

  // ---------- 更新 ----------

  /** 单条更新。书源订阅非静默更新时先预览再让用户确认。 */
  async syncSubscription(sub: RuleSubscription): Promise<void> {
    if (this.isBatchRunning || this.isSyncing(sub)) return;
    if (!RuleSubscriptionSync.canSync(sub)) {
      HdsFeedback.showToast(sub.type === RULE_SUB_TYPE_RSS ? '当前版本还没有 RSS 阅读模块，暂时无法更新' :
        '订阅地址无效');
      return;
    }
    this.syncingIds = this.syncingIds.concat([`${sub.id}`]);
    try {
      const result = await this.performSync(sub, false);
      if (result.status === RuleSubscriptionSyncStatus.NeedConfirm) {
        if (sub.type === RULE_SUB_TYPE_REPLACE_RULE) {
          const confirmed = await this.confirmConvert(result.message);
          if (confirmed) {
            const retried = await this.performSync(sub, true);
            await this.applyResult(sub, retried);
          } else {
            HdsFeedback.showToast('已取消更新');
          }
          return;
        }
        this.openConfirmDialog(`更新「${sub.name}」`, result.message, result.pendingSources);
        return;
      }
      await this.applyResult(sub, result);
    } finally {
      this.syncingIds = this.syncingIds.filter((id: string) => id !== `${sub.id}`);
    }
  }

  /**
   * 批量更新：并发跑，静默订阅直接写库，其余汇总成一次确认。
   * 取消时不再发起新的更新，已经进入网络请求的等它自然结束。
   */
  async syncAllSubscriptions(): Promise<void> {
    if (this.isBatchRunning) return;
    const targets = this.visibleSubs().filter((sub: RuleSubscription) => RuleSubscriptionSync.canSync(sub));
    if (targets.length === 0) {
      HdsFeedback.showToast(this.subs.length === 0 ? '还没有订阅' : '当前筛选下没有可更新的订阅');
      return;
    }
    this.isBatchRunning = true;
    this.batchDone = 0;
    this.batchTotal = targets.length;
    this.batchFailCount = 0;
    const gate = new AsyncSemaphore(RULE_SUB_SYNC_CONCURRENCY);
    const pendingSources: BookSource[] = [];
    const pendingConvert: RuleSubscription[] = [];
    try {
      const tasks: Promise<void>[] = [];
      for (const sub of targets) {
        const task = this.runBatchItem(gate, sub, pendingSources, pendingConvert);
        tasks.push(task);
      }
      await Promise.all(tasks);
      await this.saveSubscriptions();
      if (pendingSources.length > 0) {
        this.openConfirmDialog('批量更新', `发现 ${pendingSources.length} 个书源有更新，是否导入？`, pendingSources);
      } else if (pendingConvert.length > 0) {
        const confirmed = await this.confirmConvert(`检测到 ${pendingConvert.length} 个订阅使用安卓格式的净化规则`);
        if (confirmed) {
          for (const sub of pendingConvert) {
            this.syncingIds = this.syncingIds.concat([`${sub.id}`]);
            try {
              const result = await this.performSync(sub, true);
              await this.applyResult(sub, result);
            } finally {
              this.syncingIds = this.syncingIds.filter((id: string) => id !== `${sub.id}`);
            }
          }
        }
      } else if (this.batchFailCount === 0) {
        HdsFeedback.showToast(`已更新 ${this.batchDone} 个订阅`);
      } else {
        HdsFeedback.showToast(`更新完成：成功 ${this.batchDone - this.batchFailCount} 个，失败 ${this.batchFailCount} 个`);
      }
    } finally {
      this.isBatchRunning = false;
      await this.reloadSubscriptions();
    }
  }

  private async runBatchItem(gate: AsyncSemaphore, sub: RuleSubscription, pendingSources: BookSource[],
    pendingConvert: RuleSubscription[]): Promise<void> {
    const acquired = await gate.acquire(() => false);
    if (!acquired) return;
    this.syncingIds = this.syncingIds.concat([`${sub.id}`]);
    try {
      const silent = sub.silentUpdate;
      const result = await this.performSync(sub, false);
      if (result.status === RuleSubscriptionSyncStatus.NeedConfirm) {
        if (sub.type === RULE_SUB_TYPE_REPLACE_RULE) {
          pendingConvert.push(sub);
        } else {
          for (const source of result.pendingSources) pendingSources.push(source);
          sub.lastSyncTime = Date.now();
          sub.lastSyncCount = result.pendingSources.length;
          sub.lastSyncError = '';
          sub.updateAt = Date.now();
          this.batchDone++;
        }
        return;
      }
      await this.applyResult(sub, result, silent);
    } catch (e) {
      this.batchFailCount++;
      sub.lastSyncTime = Date.now();
      sub.lastSyncError = this.errorText(e as Object);
    } finally {
      this.syncingIds = this.syncingIds.filter((id: string) => id !== `${sub.id}`);
      gate.release();
    }
  }

  private async performSync(sub: RuleSubscription, allowConvert: boolean): Promise<RuleSubscriptionSyncResult> {
    const context = getContext(this) as common.UIAbilityContext;
    if (sub.type === RULE_SUB_TYPE_REPLACE_RULE) {
      return RuleSubscriptionSync.syncReplaceRuleSubscription(context, sub, allowConvert);
    }
    return RuleSubscriptionSync.syncBookSourceSubscription(context, sub, sub.silentUpdate);
  }

  private async applyResult(sub: RuleSubscription, result: RuleSubscriptionSyncResult,
    silentApplied: boolean = false): Promise<void> {
    sub.lastSyncTime = Date.now();
    if (result.status === RuleSubscriptionSyncStatus.Ok || silentApplied) {
      sub.updateAt = Date.now();
      sub.lastSyncCount = result.newCount + result.updateCount;
      sub.lastSyncError = '';
    } else if (result.status === RuleSubscriptionSyncStatus.NoChange) {
      sub.updateAt = Date.now();
      sub.lastSyncError = '';
    } else {
      sub.lastSyncError = result.message || '更新失败';
    }
    await this.saveSubscriptions();
    await this.reloadSubscriptions();
    if (result.status === RuleSubscriptionSyncStatus.Ok && result.message) {
      HdsFeedback.showToast(result.message);
    } else if (result.status === RuleSubscriptionSyncStatus.Error) {
      HdsFeedback.showToast(`更新失败：${sub.lastSyncError}`);
    } else if (result.status === RuleSubscriptionSyncStatus.NoChange) {
      HdsFeedback.showToast(result.message || '已是最新版本');
    }
  }

  /** 后台静默更新：只跑开了自动更新且到点的订阅，失败不打扰用户。 */
  async runAutoUpdate(): Promise<void> {
    if (this.isBatchRunning) return;
    const due = this.subs.filter((sub: RuleSubscription) =>
      sub.silentUpdate && RuleSubscriptionSync.shouldAutoUpdate(sub));
    if (due.length === 0) return;
    this.isBatchRunning = true;
    try {
      for (const sub of due) {
        try {
          const result = await this.performSync(sub, true);
          sub.lastSyncTime = Date.now();
          sub.updateAt = Date.now();
          if (result.status === RuleSubscriptionSyncStatus.Ok) {
            sub.lastSyncCount = result.newCount + result.updateCount;
            sub.lastSyncError = '';
          } else if (result.status === RuleSubscriptionSyncStatus.Error) {
            sub.lastSyncError = result.message;
          } else {
            sub.lastSyncError = '';
          }
        } catch (_) {
        }
      }
      await this.saveSubscriptions();
      await this.reloadSubscriptions();
    } finally {
      this.isBatchRunning = false;
    }
  }

  async confirmConvert(message: string): Promise<boolean> {
    const result = await promptAction.showDialog({
      title: '需要转换',
      message: `${message}。转换后按本应用格式导入。`,
      buttons: [
        { text: '取消', color: this.subTextColor() },
        { text: '转换并导入', color: this.buttonColor() }
      ]
    });
    return result.index === 1;
  }

  // ---------- 增删改 ----------

  openAddMenu(): void {
    this.showAddMenu = true;
  }

  openNewSubscription(type: number): void {
    this.showAddMenu = false;
    this.editingId = 0;
    const draft = RuleSubscriptionStore.newSubscription('', type);
    this.draftName = '';
    this.draftUrl = '';
    this.draftType = type;
    this.draftAutoUpdate = draft.autoUpdate;
    this.draftSilentUpdate = draft.silentUpdate;
    this.draftInterval = `${draft.updateIntervalHours}`;
    this.showEditDialog = true;
    this.editingDialogSession.open(this.getUIContext(), (): void => {
      this.editDialogContent();
    }, {
      autoCancel: true,
      maskColor: this.appDarkMode ? '#99000000' : '#33000000',
      warnTag: '显示订阅编辑弹窗失败:'
    });
  }

  openEditSubscription(sub: RuleSubscription): void {
    this.editingId = sub.id;
    this.draftName = sub.name;
    this.draftUrl = sub.url;
    this.draftType = sub.type;
    this.draftAutoUpdate = sub.autoUpdate;
    this.draftSilentUpdate = sub.silentUpdate;
    this.draftInterval = `${sub.updateIntervalHours}`;
    this.showEditDialog = true;
    this.editingDialogSession.open(this.getUIContext(), (): void => {
      this.editDialogContent();
    }, {
      autoCancel: true,
      maskColor: this.appDarkMode ? '#99000000' : '#33000000',
      warnTag: '显示订阅编辑弹窗失败:'
    });
  }

  closeEditDialog(): void {
    this.showEditDialog = false;
  }

  async saveDraft(): Promise<void> {
    const url = this.draftUrl.trim();
    if (!url) {
      HdsFeedback.showToast('请输入订阅地址');
      return;
    }
    if (!RuleSubscriptionStore.isValidUrl(url)) {
      HdsFeedback.showToast('地址需以 http:// 或 https:// 开头');
      return;
    }
    const existing = RuleSubscriptionStore.findByUrl(this.subs, url, this.draftType);
    if (existing && existing.id !== this.editingId) {
      HdsFeedback.showToast('该地址已在订阅列表中');
      return;
    }
    const intervalValue = Number.parseInt(this.draftInterval, 10);
    const interval = Number.isFinite(intervalValue) ?
      Math.min(RULE_SUB_MAX_INTERVAL_HOURS, Math.max(RULE_SUB_MIN_INTERVAL_HOURS, intervalValue)) :
      RULE_SUB_DEFAULT_INTERVAL_HOURS;
    const next = this.subs.map((sub: RuleSubscription) => RuleSubscriptionStore.cloneSubscription(sub));
    const name = this.draftName.trim() || RuleSubscriptionStore.hostOf(url);
    let target: RuleSubscription | null = null;
    if (this.editingId > 0) {
      const index = next.findIndex((sub: RuleSubscription) => sub.id === this.editingId);
      if (index >= 0) target = next[index];
    }
    if (!target) {
      target = RuleSubscriptionStore.newSubscription(url, this.draftType);
    }
    target.name = name;
    target.url = url;
    target.type = this.draftType;
    target.autoUpdate = this.draftAutoUpdate;
    target.silentUpdate = this.draftSilentUpdate;
    target.updateIntervalHours = interval;
    this.subs = this.editingId > 0 ? next : RuleSubscriptionStore.upsert(next, target);
    await this.saveSubscriptions();
    await this.reloadSubscriptions();
    this.showEditDialog = false;
    HdsFeedback.showToast(this.editingId > 0 ? '订阅已保存' : '已添加订阅');
  }

  async deleteSubscription(sub: RuleSubscription): Promise<void> {
    const result = await promptAction.showDialog({
      title: '删除订阅',
      message: `确定删除「${sub.name}」吗？已导入的内容会保留。`,
      buttons: [
        { text: '取消', color: this.subTextColor() },
        { text: '删除', color: this.dangerColor() }
      ]
    });
    if (result.index !== 1) return;
    this.subs = this.subs.filter((item: RuleSubscription) => item.id !== sub.id);
    await this.saveSubscriptions();
    await this.reloadSubscriptions();
    HdsFeedback.showToast('已删除订阅');
  }

  async showSubscriptionActions(sub: RuleSubscription): Promise<void> {
    const result = await promptAction.showDialog({
      title: sub.name || '订阅',
      message: sub.url,
      buttons: [
        { text: '取消', color: this.subTextColor() },
        { text: '编辑', color: this.buttonColor() },
        { text: '删除', color: this.dangerColor() }
      ]
    });
    if (result.index === 1) {
      this.openEditSubscription(sub);
    } else if (result.index === 2) {
      await this.deleteSubscription(sub);
    }
  }

  // ---------- 待确认导入 ----------

  openConfirmDialog(title: string, message: string, sources: BookSource[]): void {
    this.confirmTitle = title;
    this.confirmMessage = message;
    this.pendingSources = sources;
    this.pendingSelectedUrls = sources.map((source: BookSource) => source.bookSourceUrl);
    this.showConfirmDialog = true;
    this.confirmDialogSession.open(this.getUIContext(), (): void => {
      this.confirmDialogContent();
    }, {
      autoCancel: true,
      maskColor: this.appDarkMode ? '#99000000' : '#33000000',
      warnTag: '显示订阅更新确认弹窗失败:'
    });
  }

  closeConfirmDialog(): void {
    this.showConfirmDialog = false;
  }

  togglePendingSource(url: string): void {
    if (this.pendingSelectedUrls.includes(url)) {
      this.pendingSelectedUrls = this.pendingSelectedUrls.filter((item: string) => item !== url);
    } else {
      this.pendingSelectedUrls = this.pendingSelectedUrls.concat([url]);
    }
  }

  async applyPendingSources(): Promise<void> {
    const selected = this.pendingSources.filter((source: BookSource) =>
      this.pendingSelectedUrls.includes(source.bookSourceUrl));
    this.showConfirmDialog = false;
    if (selected.length === 0) {
      HdsFeedback.showToast('没有选择任何书源');
      return;
    }
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(getContext(this) as common.UIAbilityContext);
      const applied = await RuleSubscriptionSync.applyBookSources(selected);
      if (applied.importedSources.length === 0) {
        HdsFeedback.showToast(applied.lastErrorMessage || '写入书源失败');
        return;
      }
      const parts: string[] = [`已导入 ${applied.importedSources.length} 个书源`];
      if (applied.lockedCount > 0) parts.push(`${applied.lockedCount} 个已锁定未覆盖`);
      if (applied.failedCount > 0) parts.push(`${applied.failedCount} 个失败`);
      HdsFeedback.showToast(parts.join('，'));
      await this.reloadSubscriptions();
    } catch (e) {
      console.error('导入订阅书源失败:', e);
      HdsFeedback.showToast('导入失败');
    }
  }

  // ---------- 排序 ----------

  async moveSubscription(from: number, to: number): Promise<void> {
    const list = this.visibleSubs();
    if (from < 0 || to < 0 || from >= list.length || to >= list.length || from === to) return;
    const moved = list[from];
    const others = this.subs.filter((sub: RuleSubscription) => sub.id !== moved.id);
    const anchorId = list[to].id;
    const anchorIndex = others.findIndex((sub: RuleSubscription) => sub.id === anchorId);
    if (anchorIndex < 0) return;
    const insertAt = from < to ? anchorIndex + 1 : anchorIndex;
    const next: RuleSubscription[] = [];
    for (let index = 0; index < others.length; index++) {
      if (index === insertAt) next.push(RuleSubscriptionStore.cloneSubscription(moved));
      next.push(others[index]);
    }
    if (next.length === others.length) next.push(RuleSubscriptionStore.cloneSubscription(moved));
    this.subs = next;
    await this.saveSubscriptions();
    await this.reloadSubscriptions();
  }

  // ---------- 视图 ----------

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackgroundLayer()
      Column() {
        SettingsTitleBar({
          title: '规则订阅',
          appDarkMode: this.appDarkMode,
          statusBarHeight: this.statusBarHeight,
          trailingContent: (): void => {
            this.titleBarTrailing();
          }
        })

        this.filterBar()

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(36).height(36)
            Text('加载中...').fontSize(14).fontColor(this.subTextColor()).margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.visibleSubs().length === 0) {
          this.emptyView()
        } else {
          this.subscriptionList()
        }
      }
      .width('100%')
      .height('100%')

      this.addButton()

      if (this.showAddMenu) {
        this.addMenuOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageColorBehind())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  titleBarTrailing() {
    Row({ space: 4 }) {
      if (this.isBatchRunning) {
        Text(`${this.batchDone}/${this.batchTotal}`)
          .fontSize(12)
          .fontColor(this.subTextColor())
      }
      Text(this.isBatchRunning ? '更新中' : '全部更新')
        .fontSize(14)
        .fontColor(this.isBatchRunning || this.subs.length === 0 ? this.disabledTextColor() : this.buttonColor())
        .height(40)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          if (!this.isBatchRunning && this.subs.length > 0) this.syncAllSubscriptions();
        })
    }
    .height(56)
  }

  /**
   * chip 的文案与 key 都按当前 subs 实时算：@Builder 的按值参数首帧后不会刷新，
   * 所以这里把结果塞进 ForEach 的 key，订阅增删时 key 变化，chip 才会重建。
   */
  filterChipSpecs(): FilterChipSpec[] {
    const specs: FilterChipSpec[] = [];
    const labels: string[] = ['全部', '书源', '替换规则'];
    const types: number[] = [FILTER_ALL, RULE_SUB_TYPE_BOOK_SOURCE, RULE_SUB_TYPE_REPLACE_RULE];
    for (let i = 0; i < types.length; i++) {
      const type: number = types[i];
      const count: number = type === FILTER_ALL ? this.subs.length : this.countOfType(type);
      const spec = new FilterChipSpec();
      spec.name = labels[i];
      spec.type = type;
      spec.text = count > 0 ? `${labels[i]} ${count}` : labels[i];
      spec.key = `${type}:${count}:${this.filterType === type ? 1 : 0}`;
      specs.push(spec);
    }
    return specs;
  }

  @Builder
  filterBar() {
    Row({ space: 8 }) {
      ForEach(this.filterChipSpecs(), (spec: FilterChipSpec) => {
        this.filterChip(spec)
      }, (spec: FilterChipSpec) => spec.key)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 8 })
  }

  @Builder
  filterChip(spec: FilterChipSpec) {
    Text(spec.text)
      .fontSize(13)
      .fontColor(this.filterType === spec.type ? '#FFFFFF' : this.primaryTextColor())
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(this.filterType === spec.type ? this.buttonColor() : this.cardColor())
      .onClick(() => {
        this.filterType = spec.type;
      })
      .accessibilityText(`筛选${spec.name}`)
  }

  @Builder
  emptyView() {
    Column() {
      Text(this.subs.length === 0 ? '还没有订阅' : '该分类下暂无订阅')
        .fontSize(16)
        .fontColor(this.subTextColor())
      Text('订阅地址会定期拉取更新，书源与替换规则都能订阅')
        .fontSize(13)
        .fontColor(this.subTextColor())
        .margin({ top: 8 })
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  subscriptionList() {
    List({ space: 8 }) {
      ForEach(this.visibleSubs(), (sub: RuleSubscription, index: number) => {
        ListItem() {
          this.subscriptionCard(sub, index)
        }
      }, (sub: RuleSubscription) => this.subscriptionKey(sub))

      ListItem() {
        Row().height(Math.max(20, this.navBarHeight + 96))
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
      this.draggingIndex = itemIndex;
      return this.subscriptionDragPreview;
    })
    .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
      if (isSuccess) this.moveSubscription(itemIndex, insertIndex);
      this.draggingIndex = -1;
    })
  }

  @Builder
  subscriptionCard(sub: RuleSubscription, index: number) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.typeLabel(sub.type))
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(6)
          .backgroundColor(this.typeColor(sub.type))

        Text(sub.name || RuleSubscriptionStore.hostOf(sub.url))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.isSyncing(sub)) {
          LoadingProgress().width(18).height(18)
        } else {
          // 右上角是「更多操作」入口，必须自己吃掉点击：否则会冒泡到整卡的刷新。
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.more'))
              .fontSize(16)
              .fontColor([this.subTextColor()])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .hitTestBehavior(HitTestMode.Block)
          .accessibilityText(`更多操作：${sub.name}`)
          .onClick(() => {
            // 当前 SDK 的 ClickEvent 没有 stopPropagation，只能让整卡的点按自己让路：
            // 子节点 onClick 先于父节点触发，用时间戳把紧随其后的整卡点击吃掉。
            this.suppressCardClickUntil = Date.now() + 600;
            this.showSubscriptionActions(sub);
          })
        }
      }
      .width('100%')

      Text(sub.url)
        .fontSize(12)
        .fontColor(this.subTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.statusText(sub))
        .fontSize(11)
        .fontColor(sub.lastSyncError ? this.dangerColor() : this.subTextColor())
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.metaText(sub)) {
        Text(this.metaText(sub))
          .fontSize(11)
          .fontColor(this.subTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.cardColor())
    .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel') })
    .onClick(() => {
      // 右上角「更多操作」刚点过就不要再把这次点击算成刷新。
      if (Date.now() < this.suppressCardClickUntil) return;
      if (!this.isBatchRunning) this.syncSubscription(sub);
    })
    .gesture(LongPressGesture({ repeat: false }).onAction(() => {
      this.showSubscriptionActions(sub);
    }))
    .accessibilityText(`${this.typeLabel(sub.type)}订阅 ${sub.name}，${this.statusText(sub)}，点按更新，长按更多操作`)
  }

  @Builder
  subscriptionDragPreview() {
    Row({ space: 8 }) {
      Text(this.draggingIndex >= 0 && this.draggingIndex < this.visibleSubs().length ?
        this.typeLabel(this.visibleSubs()[this.draggingIndex].type) : '')
        .fontSize(11)
        .fontColor('#FFFFFF')
        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        .borderRadius(6)
        .backgroundColor(ThemeRuntime.accentColor(this.appDarkMode))
      Text(this.draggingIndex >= 0 && this.draggingIndex < this.visibleSubs().length ?
        this.visibleSubs()[this.draggingIndex].name : '')
        .fontSize(15)
        .fontColor(this.primaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(260)
    .padding(12)
    .backgroundColor(this.cardColor())
    .borderRadius(12)
    .shadow({ radius: 12, color: this.appDarkMode ? '#66000000' : '#22000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  addButton() {
    Text('+')
      .fontSize(26)
      .fontColor('#FFFFFF')
      .width(52)
      .height(52)
      .textAlign(TextAlign.Center)
      .borderRadius(26)
      .backgroundColor(ThemeRuntime.dropdownPanelColor(this.appDarkMode, '', 'button'))
      .backdropBlur(ThemeRuntime.glassBlur('button', 18))
      .border({
        width: ThemeRuntime.glassBorderWidth('button'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'button')
      })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('button'),
        color: ThemeRuntime.glassShadowColor(this.appDarkMode, 'button'),
        offsetX: ThemeRuntime.glassShadowOffsetX('button'),
        offsetY: ThemeRuntime.glassShadowOffsetY('button')
      })
      .position({ right: 22, bottom: this.navBarHeight + 30 })
      .onClick(() => {
        this.showAddMenu = !this.showAddMenu;
      })
      .accessibilityText('新增订阅')
  }

  @Builder
  addMenuOverlay() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column()
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.showAddMenu = false;
        })

      Column() {
        this.addMenuItem('书源订阅', RULE_SUB_TYPE_BOOK_SOURCE, true)
        this.addMenuItem('替换规则订阅', RULE_SUB_TYPE_REPLACE_RULE, false)
      }
      .width(184)
      .padding({ left: 6, right: 6, top: 6, bottom: 6 })
      .backgroundColor(ThemeRuntime.glassPanelColor(this.appDarkMode, '', 'panel'))
      .borderRadius(ThemeRuntime.glassCornerRadius(16, 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({
        width: ThemeRuntime.glassBorderWidth('panel'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel')
      })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('panel'),
        color: ThemeRuntime.glassShadowColor(this.appDarkMode, 'panel'),
        offsetX: ThemeRuntime.glassShadowOffsetX('panel'),
        offsetY: ThemeRuntime.glassShadowOffsetY('panel')
      })
      .margin({ right: 22, bottom: this.navBarHeight + 92 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  addMenuItem(label: string, type: number, showDivider: boolean) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontColor(this.primaryTextColor())
        .width('100%')
        .padding({ left: 12, right: 12, top: 11, bottom: 11 })
      if (showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color(ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel'))
          .margin({ left: 12, right: 12 })
      }
    }
    .width('100%')
    .onClick(() => {
      this.openNewSubscription(type);
    })
  }

  // ---------- 编辑弹窗 ----------

  @Builder
  editDialogContent() {
    Column({ space: 12 }) {
      Text(this.editingId > 0 ? '编辑订阅' : '新增订阅')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .width('100%')

      Row({ space: 8 }) {
        this.typeOption('书源', RULE_SUB_TYPE_BOOK_SOURCE)
        this.typeOption('替换规则', RULE_SUB_TYPE_REPLACE_RULE)
      }
      .width('100%')

      TextInput({ placeholder: '订阅地址，https:// 开头', text: this.draftUrl })
        .width('100%')
        .height(42)
        .borderRadius(8)
        .backgroundColor(ThemeRuntime.inputColor(this.appDarkMode))
        .fontColor(this.primaryTextColor())
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.draftUrl = value;
        })

      TextInput({ placeholder: '名称（可留空，默认用域名）', text: this.draftName })
        .width('100%')
        .height(42)
        .borderRadius(8)
        .backgroundColor(ThemeRuntime.inputColor(this.appDarkMode))
        .fontColor(this.primaryTextColor())
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.draftName = value;
        })

      Row() {
        Text('自动更新')
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)
        AdaptiveSwitch({
          isOn: this.draftAutoUpdate,
          selectedColor: ThemeRuntime.buttonColor(this.appDarkMode),
          accessibilityLabel: '自动更新',
          onChange: (isOn: boolean) => {
            this.draftAutoUpdate = isOn;
          }
        })
      }
      .width('100%')

      if (this.draftAutoUpdate) {
        Row({ space: 8 }) {
          Text('更新间隔')
            .fontSize(14)
            .fontColor(this.primaryTextColor())
          TextInput({ text: this.draftInterval })
            .type(InputType.Number)
            .width(72)
            .height(36)
            .borderRadius(8)
            .textAlign(TextAlign.Center)
            .backgroundColor(ThemeRuntime.inputColor(this.appDarkMode))
            .fontColor(this.primaryTextColor())
            .onChange((value: string) => {
              this.draftInterval = value;
            })
          Text(`小时（${RULE_SUB_MIN_INTERVAL_HOURS}-${RULE_SUB_MAX_INTERVAL_HOURS}）`)
            .fontSize(12)
            .fontColor(this.subTextColor())
            .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Column() {
            Text('静默更新')
              .fontSize(14)
              .fontColor(this.primaryTextColor())
            Text('不弹确认，直接写入，失败也不提示')
              .fontSize(11)
              .fontColor(this.subTextColor())
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          AdaptiveSwitch({
            isOn: this.draftSilentUpdate,
            selectedColor: ThemeRuntime.buttonColor(this.appDarkMode),
            accessibilityLabel: '静默更新',
            onChange: (isOn: boolean) => {
              this.draftSilentUpdate = isOn;
            }
          })
        }
        .width('100%')
      }

      Row({ space: 10 }) {
        Button('取消', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(42)
          .borderRadius(10)
          .backgroundColor(ThemeRuntime.cardColor(this.appDarkMode))
          .fontColor(this.primaryTextColor())
          .onClick(() => {
            this.closeEditDialog();
          })
        Button('保存', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(42)
          .borderRadius(10)
          .backgroundColor(this.buttonColor())
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.saveDraft();
          })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .constraintSize({ maxWidth: 460 })
    .padding(20)
  }

  @Builder
  typeOption(label: string, type: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.draftType === type ? '#FFFFFF' : this.primaryTextColor())
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(this.draftType === type ? this.buttonColor() : ThemeRuntime.inputColor(this.appDarkMode))
      .onClick(() => {
        this.draftType = type;
      })
  }

  // ---------- 待确认弹窗 ----------

  @Builder
  confirmDialogContent() {
    Column({ space: 12 }) {
      Text(this.confirmTitle)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(`${this.confirmMessage}（已选 ${this.pendingSelectedUrls.length}/${this.pendingSources.length}）`)
        .fontSize(12)
        .fontColor(this.subTextColor())
        .width('100%')
        .textAlign(TextAlign.Center)

      Row({ space: 8 }) {
        Text('全选')
          .fontSize(13)
          .fontColor(this.buttonColor())
          .onClick(() => {
            this.pendingSelectedUrls = this.pendingSelectedUrls.length === this.pendingSources.length ? [] :
              this.pendingSources.map((source: BookSource) => source.bookSourceUrl);
          })
        Blank()
      }
      .width('100%')

      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.pendingSources, (source: BookSource) => {
            Row({ space: 8 }) {
              Text(this.pendingSelectedUrls.includes(source.bookSourceUrl) ? '☑' : '☐')
                .fontSize(16)
                .fontColor(this.buttonColor())
                .width(22)
              Column() {
                Text(source.bookSourceName || '未命名书源')
                  .fontSize(13)
                  .fontColor(this.primaryTextColor())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(source.bookSourceUrl)
                  .fontSize(11)
                  .fontColor(this.subTextColor())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(8)
            .borderRadius(8)
            .backgroundColor(ThemeRuntime.inputColor(this.appDarkMode))
            .onClick(() => {
              this.togglePendingSource(source.bookSourceUrl);
            })
          }, (source: BookSource) => source.bookSourceUrl)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 320 })
      .scrollBar(BarState.Auto)

      Row({ space: 10 }) {
        Button('取消', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(42)
          .borderRadius(10)
          .backgroundColor(ThemeRuntime.cardColor(this.appDarkMode))
          .fontColor(this.primaryTextColor())
          .onClick(() => {
            this.closeConfirmDialog();
          })
        Button('导入所选', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(42)
          .borderRadius(10)
          .backgroundColor(this.buttonColor())
          .fontColor('#FFFFFF')
          .enabled(this.pendingSelectedUrls.length > 0)
          .onClick(() => {
            this.applyPendingSources();
          })
      }
      .width('100%')
    }
    .constraintSize({ maxWidth: 520 })
    .padding(20)
  }

  // ---------- 颜色 ----------

  pageColor(): string {
    return ThemeRuntime.pageColor(this.appDarkMode);
  }

  pageColorBehind(): string {
    return ThemeRuntime.pageColorBehind(this.appDarkMode);
  }

  cardColor(): string {
    return ThemeRuntime.cardColorBehind(this.appDarkMode);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  disabledTextColor(): string {
    return this.appDarkMode ? '#5D626B' : '#C0C4CC';
  }

  buttonColor(): string {
    return ThemeRuntime.buttonColor(this.appDarkMode);
  }

  dangerColor(): string {
    return ThemeRuntime.dangerColor(this.appDarkMode);
  }

  errorText(error: Object): string {
    if (error instanceof Error && error.message) return error.message;
    return `${error}`;
  }

  syncBars(): void {
    syncSystemBars(getContext(this), this.appDarkMode, this.pageColor());
  }
}

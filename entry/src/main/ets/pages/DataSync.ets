import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { CloudSyncOutcome, CloudSyncService } from '../utils/CloudSyncService';
import { ImmersiveBackButton } from '../components/ImmersiveBackButton';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { syncSystemBars } from '../utils/SystemBars';
import { HdsFeedback } from '../utils/HdsFeedback';

@Entry
@Component
struct DataSyncPage {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageLink(CloudSyncService.STORAGE_SUPPORTED) cloudSyncSupported: boolean = false;
  @StorageLink(CloudSyncService.STORAGE_LINKED) cloudSyncLinked: boolean = false;
  @StorageLink(CloudSyncService.STORAGE_STATUS) syncStatus: string = CloudSyncService.STATUS_IDLE;
  @StorageLink(CloudSyncService.STORAGE_MESSAGE) syncMessage: string = '';
  @StorageLink(CloudSyncService.STORAGE_LAST_SUCCESS_AT) syncLastSuccessAt: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State syncing: boolean = false;
  @State syncSizeText: string = '';

  aboutToAppear(): void {
    // 按钮的“正在同步”只跟随手动点击的生命周期，不跟随后台自动同步：
    // 自动同步由前后台切换触发，若按钮绑定全局状态，自动同步结束的瞬间
    // isSyncing() 尚未清除，按钮会永久停在“正在同步”。
    this.syncBars();
    this.refreshSyncSizeText();
  }

  onPageShow(): void {
    this.syncBars();
  }

  private refreshSyncSizeText(): void {
    CloudSyncService.estimateSyncTableSizes().then((sizes) => {
      const nameMap: Record<string, string> = {
        'books': '书籍',
        'book_sources': '书源',
        'book_groups': '分组',
        'search_keywords': '搜索历史',
        'sync_heartbeats': '同步心跳'
      };
      let total = 0;
      let biggestTable = '';
      let biggestBytes = 0;
      const tables = Object.keys(sizes);
      for (const table of tables) {
        total += sizes[table];
        if (sizes[table] > biggestBytes) {
          biggestBytes = sizes[table];
          biggestTable = table;
        }
      }
      if (total <= 0) {
        this.syncSizeText = '';
        return;
      }
      const biggestName = nameMap[biggestTable] ? nameMap[biggestTable] : biggestTable;
      this.syncSizeText =
        `共约 ${CloudSyncService.formatBytes(total)}，其中${biggestName}约 ${CloudSyncService.formatBytes(biggestBytes)}`;
    }).catch(() => {
      this.syncSizeText = '';
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column() {
          Row()
            .height(56 + this.statusBarHeight)

          this.statusCard()

          this.sectionTitle('同步内容')
          Column() {
            this.infoItem('在线书架与分组', '书籍信息、阅读进度、分组与排序', true)
            this.infoItem('书源', '书源配置、分组、排序与启用状态', true)
            this.infoItem('搜索历史', '搜索过的关键词记录', this.syncSizeText !== '')
            if (this.syncSizeText !== '') {
              this.infoItem('同步数据量', this.syncSizeText, false)
            }
          }
          .width('calc(100% - 24vp)')
          .margin({ left: 12, right: 12 })
          .borderRadius(16)
          .clip(true)
          .backgroundColor(this.cardColor())

          this.sectionTitle('管理')
          Column() {
            this.actionItem('WebDAV 备份', '通过 WebDAV 服务器手动备份与恢复全部数据', true, () => {
              router.pushUrl({ url: 'pages/WebDav' });
            })
            this.actionItem('同步问题', this.syncIssueDescription(), false, () => {
              HdsFeedback.showToast(this.syncIssueDescription());
            })
          }
          .width('calc(100% - 24vp)')
          .margin({ left: 12, right: 12 })
          .borderRadius(16)
          .clip(true)
          .backgroundColor(this.cardColor())

          Text('云空间同步需要 HarmonyOS 6.1.0 及以上版本、设备已登录华为账号，并在“设置-云空间”中开启本应用的同步开关，仅支持中国大陆。本地书文件、正文缓存以及阅读偏好不参与云同步，可使用 WebDAV 备份。')
            .fontSize(12)
            .fontColor(this.subTextColor())
            .lineHeight(18)
            .width('calc(100% - 32vp)')
            .margin({ left: 16, right: 16, top: 14, bottom: 32 + this.navBarHeight })
        }
        .width('100%')
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)

      this.titleBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageColor())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  statusCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('云空间同步')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Text(this.syncSummary())
            .fontSize(13)
            .fontColor(this.statusColor())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.syncing) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.accentColor())
        } else {
          Text(this.cloudBadgeText())
            .fontSize(12)
            .fontColor(this.cloudBadgeColor())
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor(this.softColor())
        }
      }
      .width('100%')

      Text(this.statusDescription())
        .fontSize(13)
        .fontColor(this.subTextColor())
        .lineHeight(20)
        .width('100%')

      if (this.cloudSyncSupported) {
        Button(this.syncing ? '正在同步' : '立即同步')
          .width('100%')
          .height(42)
          .enabled(!this.syncing)
          .fontColor(Color.White)
          .backgroundColor(this.accentColor())
          .onClick(() => {
            this.syncNow();
          })
      }
      Button('前往“设置-云空间”')
        .width('100%')
        .height(42)
        .fontColor(this.primaryTextColor())
        .backgroundColor(this.softColor())
        .onClick(() => {
          this.openCloudSettings();
        })
    }
    .width('calc(100% - 24vp)')
    .padding(16)
    .margin({ left: 12, right: 12, top: 12 })
    .borderRadius(16)
    .backgroundColor(this.cardColor())
  }

  @Builder
  infoItem(title: string, desc: string, showDivider: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor(this.primaryTextColor())
        Text(desc)
          .fontSize(12)
          .fontColor(this.subTextColor())
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('calc(100% - 32vp)')
    .constraintSize({ minHeight: 64 })
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 16, right: 16 })
    .border({ width: { bottom: showDivider ? 0.5 : 0 },
      color: this.dividerColor() })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  actionItem(title: string, desc: string, showDivider: boolean, onClick: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor(this.primaryTextColor())
        Text(desc)
          .fontSize(12)
          .fontColor(this.subTextColor())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([this.subTextColor()])
    }
    .width('calc(100% - 32vp)')
    .constraintSize({ minHeight: 64 })
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 16, right: 16 })
    .border({ width: { bottom: showDivider ? 0.5 : 0 },
      color: this.dividerColor() })
    .alignItems(VerticalAlign.Center)
    .onClick(onClick)
  }

  async syncNow(): Promise<void> {
    if (this.syncing) {
      return;
    }
    this.syncing = true;
    try {
      const outcome: CloudSyncOutcome = await CloudSyncService.syncNow(true);
      if (outcome.status === CloudSyncService.STATUS_PENDING) {
        // 结果未知：数据已提交，后台验证器数分钟内出最终结论。
        HdsFeedback.showToast('已提交同步，正在后台确认云连接');
      } else {
        HdsFeedback.showToast('已与云空间同步');
      }
    } catch (e) {
      HdsFeedback.showToast(`同步失败：${e instanceof Error ? e.message : String(e)}`);
    } finally {
      // 不能用 CloudSyncService.isSyncing()：手动同步上传后常触发云端变更通知，
      // 唤起一次后台自动同步，isSyncing() 会立刻变回 true，按钮将永远停在“正在同步”。
      this.syncing = false;
    }
  }

  openCloudSettings(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: 'hicloud://cloudDrive/getInfo?path=MainActivity'
    };
    context.startAbility(want).catch(() => {
      HdsFeedback.showToast('未能打开云空间设置，请手动前往“设置-云空间”');
    });
  }

  syncSummary(): string {
    return CloudSyncService.summary(this.syncStatus, this.syncLastSuccessAt);
  }

  cloudBadgeText(): string {
    if (!this.cloudSyncSupported) {
      return '不可用';
    }
    if (this.syncStatus === CloudSyncService.STATUS_ERROR) {
      return '未连接';
    }
    if (this.syncStatus === CloudSyncService.STATUS_PENDING) {
      return '确认中';
    }
    // supported 只说明系统版本支持该 API，不代表云链路已连通：
    // 从未确认连通时显示“待连接”，避免长期误导为“可用”。
    return this.cloudSyncLinked ? '可用' : '待连接';
  }

  cloudBadgeColor(): string {
    if (!this.cloudSyncSupported) {
      return this.subTextColor();
    }
    if (this.syncStatus === CloudSyncService.STATUS_ERROR) {
      return '#E5484D';
    }
    if (this.syncStatus === CloudSyncService.STATUS_PENDING) {
      return '#E6A23C';
    }
    return this.accentColor();
  }

  statusDescription(): string {
    if (!this.cloudSyncSupported) {
      return '当前设备系统版本不支持端云同步，可使用下方 WebDAV 备份数据。';
    }
    if (this.syncStatus === CloudSyncService.STATUS_PENDING) {
      return '已提交同步：系统正在后台上传并确认云连接，数分钟内自动更新状态，无需反复点击。';
    }
    if (this.syncStatus === CloudSyncService.STATUS_SYNCING && this.syncMessage) {
      return this.syncMessage;
    }
    if (this.syncStatus === CloudSyncService.STATUS_ERROR && this.syncMessage) {
      return `上次同步出现问题：${this.syncMessage}`;
    }
    if (!this.cloudSyncLinked) {
      // 从未确认过连通：不能声称“设备间保持一致”。
      return '尚未确认云空间连接：请在“设置-云空间”中登录华为账号并开启本应用的同步开关，随后点击上方“立即同步”验证。';
    }
    return '书架、书源与搜索历史通过华为云空间同步：应用在启动、回到前台或云端数据变化时自动合并上传，登录同一华为账号的设备间保持一致。';
  }

  syncIssueDescription(): string {
    if (this.syncStatus === CloudSyncService.STATUS_ERROR && this.syncMessage) {
      return this.syncMessage;
    }
    return '当前没有需要处理的同步问题';
  }

  statusColor(): string {
    if (this.syncStatus === CloudSyncService.STATUS_ERROR) {
      return '#E5484D';
    }
    if (this.syncStatus === CloudSyncService.STATUS_PENDING) {
      return '#E6A23C';
    }
    if (this.syncStatus === CloudSyncService.STATUS_UNSUPPORTED) {
      return this.subTextColor();
    }
    return this.accentColor();
  }

  pageColor(): string {
    return ThemeRuntime.pageColor(this.appDarkMode);
  }

  cardColor(): string {
    return ThemeRuntime.cardColor(this.appDarkMode);
  }

  softColor(): string {
    return ThemeRuntime.inputColor(this.appDarkMode);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  accentColor(): string {
    return ThemeRuntime.accentColor(this.appDarkMode);
  }

  dividerColor(): string {
    return this.appDarkMode ? '#24FFFFFF' : '#14000000';
  }

  syncBars(): void {
    syncSystemBars(getContext(this), this.appDarkMode, this.pageColor());
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.subTextColor())
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 8 })
  }

  @Builder
  titleBar() {
    Row() {
      ImmersiveBackButton({ iconColor: this.primaryTextColor(), darkMode: this.appDarkMode,
        buttonSize: 40, containerWidth: 56, materialScale: 0.83, compactLayout: true,
        onBack: () => router.back() })
      Text('数据同步')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)
    }
    .width('100%')
    .height(56 + this.statusBarHeight)
    .padding({ top: this.statusBarHeight })
    .backgroundColor(ThemeRuntime.topBarColor(this.appDarkMode))
    .backdropBlur(ThemeRuntime.topBarBlur())
    .alignItems(VerticalAlign.Center)
  }
}

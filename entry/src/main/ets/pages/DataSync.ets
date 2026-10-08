import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { CloudSyncService } from '../utils/CloudSyncService';
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
  @StorageLink(CloudSyncService.STORAGE_STATUS) syncStatus: string = CloudSyncService.STATUS_IDLE;
  @StorageLink(CloudSyncService.STORAGE_MESSAGE) syncMessage: string = '';
  @StorageLink(CloudSyncService.STORAGE_REVISION) @Watch('onSyncStateChanged') syncRevision: number = 0;
  @StorageLink(CloudSyncService.STORAGE_LAST_SUCCESS_AT) syncLastSuccessAt: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State syncing: boolean = false;

  aboutToAppear(): void {
    this.syncing = CloudSyncService.isSyncing();
    this.syncBars();
  }

  onPageShow(): void {
    this.syncBars();
  }

  onSyncStateChanged(): void {
    this.syncing = CloudSyncService.isSyncing();
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
            this.infoItem('搜索历史', '搜索过的关键词记录', false)
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
          Text(this.cloudSyncSupported ? '可用' : '不可用')
            .fontSize(12)
            .fontColor(this.cloudSyncSupported ? this.accentColor() : this.subTextColor())
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
      await CloudSyncService.syncNow();
      HdsFeedback.showToast('已与云空间同步');
    } catch (e) {
      HdsFeedback.showToast(`同步失败：${e instanceof Error ? e.message : String(e)}`);
    } finally {
      this.syncing = CloudSyncService.isSyncing();
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

  statusDescription(): string {
    if (!this.cloudSyncSupported) {
      return '当前设备系统版本不支持端云同步，可使用下方 WebDAV 备份数据。';
    }
    if (this.syncStatus === CloudSyncService.STATUS_ERROR && this.syncMessage) {
      return `上次同步出现问题：${this.syncMessage}`;
    }
    return '书架、书源与搜索历史通过华为云空间自动同步，登录同一华为账号的设备间保持一致。';
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

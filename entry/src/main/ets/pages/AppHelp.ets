import { router } from '@kit.ArkUI';
import { syncSystemBars } from '../utils/SystemBars';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { AppBackgroundLayer } from '../components/AppBackgroundLayer';
import { ImmersiveBackButton } from '../components/ImmersiveBackButton';

@Entry
@Component
struct AppHelpPage {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  aboutToAppear(): void {
    this.syncBars();
  }

  onPageShow(): void {
    this.syncBars();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackgroundLayer()
      Scroll() {
        Column() {
          this.helpCard('书源与导入',
            '在「我的 - 书源管理」中导入 JSON 格式的书源规则，支持分组、排序、启用/停用与调试。本地 txt/epub 书籍可在书架页直接导入；通过搜索或发现页找到书籍后加入书架即可阅读。')

          this.helpCard('书架管理',
            '书架支持多分组管理与置顶；下拉刷新更新最新章节，长按书籍进入多选操作（置顶、分组、移除、清空缓存等）。')

          this.helpCard('阅读与排版',
            '阅读页支持上下滚动、左右翻页等多种翻页方式；字号、行距、段距、边距与正文对齐可在「阅读设置」中调整，并支持自定义字体、页眉页脚与阅读背景。还提供音量键翻页、快速下拉书签、亮屏时间等辅助功能。')

          this.helpCard('语音朗读',
            '正文页点击朗读开始听书，支持系统音色与自定义音色；支持后台与锁屏续播，通知栏或悬浮胶囊可直接控制播放、暂停、上一章/下一章与语速。摘下耳机或断开蓝牙会自动暂停，重新连接后需手动继续。')

          this.helpCard('主题与外观',
            '在「我的 - 主题」中切换内置主题或创建自定义主题方案，可设置强调色、开机图、主界面背景、玻璃效果与圆角风格；深浅色模式可跟随系统。')

          this.helpCard('数据同步与备份',
            '书架、书源、阅读进度与偏好设置可通过系统云空间在设备间同步（在系统设置的用户与帐户中开启）；也可使用 WebDAV 或本地备份进行整机备份与恢复。')

          this.helpCard('换源与净化',
            '书籍详情页提供换源功能，切换不同书源继续阅读；「阅读设置 - 净化规则」可按正则替换或过滤正文内容。')
        }
        .width('100%')
        .padding({ top: 56 + this.statusBarHeight })
        .alignItems(HorizontalAlign.Center)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')

      Row() {
        ImmersiveBackButton({ iconColor: this.primaryTextColor(), darkMode: this.appDarkMode,
          buttonSize: 40, containerWidth: 56, materialScale: 0.83, compactLayout: true,
          onBack: () => router.back() })

        Text('使用帮助')
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
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageColorBehind())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  helpCard(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .width('100%')
      Text(content)
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('calc(100% - 32vp)')
    .padding(16)
    .backgroundColor(this.cardColor())
    .borderRadius(10)
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  pageColor(): string {
    return ThemeRuntime.pageColor(this.appDarkMode);
  }

  // 背景铺到全部页面时，页面底色改为半透明，让底层的主题背景图透出来。
  pageColorBehind(): string {
    return ThemeRuntime.pageColorBehind(this.appDarkMode);
  }

  cardColor(): string {
    return ThemeRuntime.cardColorBehind(this.appDarkMode);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  secondaryTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  syncBars(): void {
    syncSystemBars(getContext(this), this.appDarkMode, this.pageColor());
  }
}

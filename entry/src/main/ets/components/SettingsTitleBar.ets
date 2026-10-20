import { router } from '@kit.ArkUI';
import { ImmersiveBackButton } from './ImmersiveBackButton';
import { ThemeRuntime } from '../theme/ThemeRuntime';

/**
 * 设置类页面统一标题栏：返回按钮 + 标题 + 可选右侧内容。
 * 取代各页面手工复制的 titleBar() @Builder，保证状态栏安全区、
 * 顶部材质底色与模糊、字号行高的一致性。
 */
@Component
export struct SettingsTitleBar {
  @Prop title: string = '';
  @Prop appDarkMode: boolean = false;
  @Prop statusBarHeight: number = 0;
  /** 自定义标题栏底色；留空时使用 ThemeRuntime.topBarColor。 */
  @Prop surfaceColor: string = '';
  /** 右侧内边距（个别页面需要为右侧内容留白）。 */
  @Prop rightPadding: number = 0;
  /** 悬浮固定式标题栏（position + zIndex），标题栏覆盖在滚动内容之上时使用。 */
  @Prop pinned: boolean = false;
  /** 是否叠加顶部材质模糊；个别页面（如调试页）不需要。 */
  @Prop showBlur: boolean = true;
  /** 副标题；非空时标题降为 18fp 并在下方渲染 12fp 副标题。 */
  @Prop subtitle: string = '';
  /** 自定义返回逻辑；缺省执行 router.back()。 */
  onBack: () => void = (): void => {
    router.back();
  };
  @BuilderParam trailingContent: () => void = this.emptyTrailing;

  @Builder
  emptyTrailing() {
  }

  build() {
    if (this.pinned) {
      Row() {
        this.barContent()
      }
      .width('100%')
      .height(56 + this.statusBarHeight)
      .padding({ top: this.statusBarHeight, right: this.rightPadding })
      .backgroundColor(this.barSurfaceColor())
      .backdropBlur(this.showBlur ? ThemeRuntime.topBarBlur() : 0)
      .alignItems(VerticalAlign.Center)
      .position({ x: 0, y: 0 })
      .zIndex(3)
    } else {
      Row() {
        this.barContent()
      }
      .width('100%')
      .height(56 + this.statusBarHeight)
      .padding({ top: this.statusBarHeight, right: this.rightPadding })
      .backgroundColor(this.barSurfaceColor())
      .backdropBlur(this.showBlur ? ThemeRuntime.topBarBlur() : 0)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  barContent() {
    ImmersiveBackButton({ iconColor: ThemeRuntime.primaryTextColor(this.appDarkMode),
      darkMode: this.appDarkMode, buttonSize: 40, containerWidth: 56, materialScale: 0.83,
      compactLayout: true, onBack: () => this.onBack() })
    if (this.subtitle !== '') {
      Column() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeRuntime.primaryTextColor(this.appDarkMode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitle)
          .fontSize(12)
          .fontColor(ThemeRuntime.subTextColor(this.appDarkMode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    } else {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeRuntime.primaryTextColor(this.appDarkMode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    this.trailingContent()
  }

  private barSurfaceColor(): string {
    return this.surfaceColor !== '' ? this.surfaceColor : ThemeRuntime.topBarColor(this.appDarkMode);
  }
}

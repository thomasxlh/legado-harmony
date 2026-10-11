import { ThemeIds } from '../theme/ThemeModels';
import { ThemeRuntime } from '../theme/ThemeRuntime';

/**
 * 主题背景层：铺在页面最底层，先垫一层页面底色，再用不透明度把背景图混合上去，
 * 这样半透明时不会露出窗口的黑底。
 *
 * 背景图跟随自定义主题方案存储，浅色与深色各一张。书架主界面始终展示；其余页面
 * 只有在方案里打开「应用到全部页面」时才展示，由 always 参数区分。
 */
@Component
export struct AppBackgroundLayer {
  // 主界面（书架）恒显示背景，不受全局开关影响。
  @Prop always: boolean = false;
  @StorageLink('appThemeId') appThemeId: string = '';
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('appMainBackgroundGlobal') mainBackgroundGlobal: boolean = true;
  @StorageLink('appCustomLightMainBackgroundImagePath') customLightMainBackgroundImagePath: string = '';
  @StorageLink('appCustomDarkMainBackgroundImagePath') customDarkMainBackgroundImagePath: string = '';
  @StorageLink('appCustomLightMainBackgroundOpacity') customLightMainBackgroundOpacity: number = 100;
  @StorageLink('appCustomDarkMainBackgroundOpacity') customDarkMainBackgroundOpacity: number = 100;

  build() {
    Stack() {
      if (this.usesBackground()) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(ThemeRuntime.pageColor(this.appDarkMode))
          .hitTestBehavior(HitTestMode.None)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        Image(this.resolvedBackgroundImage())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.resolvedBackgroundOpacity() / 100)
          .hitTestBehavior(HitTestMode.None)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .draggable(false)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  usesBackground(): boolean {
    if (this.appThemeId !== ThemeIds.CUSTOM) return false;
    if (!this.resolvedBackgroundImage()) return false;
    return this.always ? true : this.mainBackgroundGlobal !== false;
  }

  // 注意：不能叫 backgroundImage / backgroundOpacity，这两个名字与 ArkUI 内置
  // 属性重名，会被编译器判定为覆写 CustomComponent 的属性而报类型不匹配。
  resolvedBackgroundImage(): string {
    return this.appDarkMode ? this.customDarkMainBackgroundImagePath :
      this.customLightMainBackgroundImagePath;
  }

  resolvedBackgroundOpacity(): number {
    const value = this.appDarkMode ? this.customDarkMainBackgroundOpacity :
      this.customLightMainBackgroundOpacity;
    const numeric = typeof value === 'number' && Number.isFinite(value) ? value : 100;
    return Math.max(10, Math.min(100, Math.round(numeric)));
  }
}

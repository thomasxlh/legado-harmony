import { BuiltinThemeRegistry } from '../theme/BuiltinThemeRegistry';
import { ThemeIds, ThemePack, ThemeVariant } from '../theme/ThemeModels';

@Component
export struct ThemeStartupCover {
  @Prop themeId: string = ThemeIds.PLAIN_DEFAULT;
  @Prop darkMode: boolean = false;
  @Prop compact: boolean = false;
  @Prop animated: boolean = false;
  @Prop customImagePath: string = '';
  @Prop titleOverride: string = '';
  @Prop subtitleOverride: string = '';
  @Prop explicitText: boolean = false;
  @State artScale: number = 1;
  @State contentOpacity: number = 1;
  @State viewportHeight: number = 0;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    if (!this.animated || !this.usesBusinessCover()) return;
    this.artScale = 1.04;
    this.contentOpacity = 0;
    this.entranceTimer = setTimeout(() => {
      this.entranceTimer = -1;
      animateTo({ duration: 520, curve: Curve.EaseOut }, () => {
        this.artScale = 1;
        this.contentOpacity = 1;
      });
    }, 24);
  }

  aboutToDisappear(): void {
    if (this.entranceTimer >= 0) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.usesBusinessCover()) {
        // 仅在主题设置的预览框中展示系统启动页的 App 图标。
        // 默认主题真实冷启动由 EntryAbility 直接加载首页，不绘制业务启动页。
        if (this.compact) {
          Image($r('app.media.icon'))
            .width(48)
            .height(48)
            .objectFit(ImageFit.Contain)
            .draggable(false)
        }
      } else {
        // 自定义主题上传的独立启动封面插画。
        if (this.customImagePath) {
          Image(this.customImagePath)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .opacity(this.contentOpacity * (this.darkMode ? 0.62 : 1))
            .scale({ x: this.artScale, y: this.artScale })
            .draggable(false)
        }

        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.darkMode ? '#42000000' : '#0AFFFFFF')
          .opacity(this.contentOpacity)

        // Keep the fade attached to the current viewport bottom. A percentage
        // y-position plus a fixed height leaves a bright strip above the
        // navigation indicator on tall screens and after a fold-state change.
        Column() {
          Blank()
            .layoutWeight(1)

          Column()
            .width('100%')
            .height(this.bottomFadeHeight())
            .linearGradient({
              angle: 180,
              colors: [['#00000000', 0], [this.darkMode ? '#CC000000' : '#8F000000', 1]]
            })
            // The startup page is edge-to-edge. Expanding the fade itself is
            // required; expanding only the page does not expand child layout.
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        }
        .width('100%')
        .height('100%')
        .opacity(this.contentOpacity)
        .hitTestBehavior(HitTestMode.None)

        Column() {
          Blank()
          Row({ space: this.compact ? 7 : 0 }) {
            Column() {
              if (this.coverTitle()) {
                Text(this.coverTitle())
                  .fontSize(this.compact ? 11 : 21)
                  .fontWeight(FontWeight.Medium)
                  .fontFamily(this.theme().typography.appFontFamily)
                  .fontColor('#FFFFFF')
                  .letterSpacing(this.compact ? 1.2 : 4)
                  .textAlign(TextAlign.Center)
                  .opacity(this.contentOpacity * 0.94)
              }
              if (this.coverSubtitle()) {
                Text(this.coverSubtitle())
                  .fontSize(this.compact ? 7 : 12)
                  .fontFamily(this.theme().typography.appFontFamily)
                  .fontColor('#D9FFFFFF')
                  .letterSpacing(this.compact ? 0.3 : 1.2)
                  .textAlign(TextAlign.Center)
                  .margin({ top: this.compact ? 2 : 8 })
                  .opacity(this.contentOpacity)
              }
            }
            .alignItems(HorizontalAlign.Center)
            .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: this.compact ? 8 : 34 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.variant().colors.pageColor)
    // Full-screen children may expand into system safe areas; previews still
    // need clipping for their rounded-card bounds.
    .clip(this.compact)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const height = this.areaDimension(newValue.height);
      if (height > 0 && Math.abs(height - this.viewportHeight) >= 1) {
        this.viewportHeight = height;
      }
    })
  }

  bottomFadeHeight(): number {
    if (this.compact) return 58;
    if (this.viewportHeight <= 0) return 190;
    // Use the live ArkUI viewport rather than a device model or cached display
    // size. It is recalculated for outer/inner fold displays and multi-window.
    return Math.max(168, Math.min(300, this.viewportHeight * 0.26));
  }

  areaDimension(value: Length): number {
    if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  usesBusinessCover(): boolean {
    // 内置主题已精简为默认主题，只有自定义主题上传的封面或文案才绘制业务启动页。
    return !!this.customImagePath ||
      (this.explicitText && (!!this.titleOverride || !!this.subtitleOverride));
  }

  resolvedThemeId(): string {
    return BuiltinThemeRegistry.normalizeBuiltinId(this.themeId);
  }

  theme(): ThemePack {
    return BuiltinThemeRegistry.findById(this.resolvedThemeId());
  }

  variant(): ThemeVariant {
    const theme = this.theme();
    return this.darkMode ? theme.dark : theme.light;
  }

  coverTitle(): string {
    return this.titleOverride;
  }

  coverSubtitle(): string {
    return this.subtitleOverride;
  }
}

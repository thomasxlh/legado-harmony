/**
 * 阅读页第三批状态块：漫画边界续页提示、眼动校准设置行、自定义主题删除确认。
 *
 * 与前面几批一致：颜色/文案/开关这类**值**用 @Prop 传，点击行为用回调传，
 * 组件内部不持有 page 引用。
 */
@Component
export struct ReaderComicBoundaryHintContent {
  @Prop hintText: string = '';
  @Prop accentColor: string = '#2F6BFF';
  @Prop textColor: string = '#000000';
  @Prop dark: boolean = false;
  @Prop boundaryDirection: number = 0;
  @Prop pullDistance: number = 0;
  @Prop ready: boolean = false;
  @Prop chapterSwitching: boolean = false;

  build() {
    Row({ space: 8 }) {
      if (this.chapterSwitching) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor)
      } else {
        SymbolGlyph(this.boundaryDirection < 0 ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_up'))
          .fontSize(17)
          .fontColor([this.ready ? this.accentColor : this.textColor])
      }
      Text(this.hintText)
        .fontSize(13)
        .fontWeight(this.ready || this.chapterSwitching ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.ready || this.chapterSwitching ? this.accentColor : this.textColor)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .borderRadius(18)
    .backgroundColor(this.dark ? '#E61B1D20' : '#E6FFFFFF')
    .shadow({ radius: 10, color: this.dark ? '#66000000' : '#26000000', offsetY: 3 })
    .opacity(this.chapterSwitching ? 1 : Math.min(1, 0.35 + this.pullDistance / 56))
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderEyeCalibrationSettingItem {
  @Prop textColor: string = '#000000';
  @Prop subTextColor: string = '#888888';
  @Prop accentColor: string = '#2F6BFF';
  @Prop autoCalibrated: boolean = false;
  @Prop landscape: boolean = false;
  @Prop statusText: string = '';
  @Prop calibrated: boolean = false;
  onConfigure: () => void = (): void => {};

  build() {
    Row() {
      Column() {
        Text('眼动校准')
          .fontSize(15)
          .fontColor(this.textColor)
        Text(this.autoCalibrated ? 'AR 自动校准 · 无需手动校准' :
          `${this.landscape ? '横屏' : '竖屏'} · ${this.statusText}`)
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (!this.autoCalibrated) {
        // AR Engine gaze needs no per-device calibration; only the camera fallback does.
        Button(this.calibrated ? '重新校准' : '开始校准')
          .height(36)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.accentColor)
          .onClick((): void => this.onConfigure())
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct ReaderCustomThemeDeleteConfirm {
  @Prop textColor: string = '#000000';
  @Prop subTextColor: string = '#888888';
  @Prop dangerColor: string = '#D94841';
  @Prop chipIdleColor: string = '#F5F5F5';
  @Prop themeName: string = '';
  onCancel: () => void = (): void => {};
  onDelete: () => void = (): void => {};

  build() {
    Column() {
      Text('删除自定义主题')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })
      Text(`确定删除「${this.themeName}」吗？此操作无法撤销。`)
        .fontSize(14)
        .fontColor(this.subTextColor)
        .width('100%')
        .margin({ bottom: 16 })
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor(this.chipIdleColor)
          .fontColor(this.textColor)
          .onClick((): void => this.onCancel())
        Button('删除')
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor(this.dangerColor)
          .fontColor('#FFFFFF')
          .onClick((): void => this.onDelete())
      }
      .width('100%')
    }
    .width('calc(100% - 32vp)')
    .constraintSize({ maxWidth: 360 })
    .padding({ left: 20, right: 20, top: 22, bottom: 20 })
  }
}

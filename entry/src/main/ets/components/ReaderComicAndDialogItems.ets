/**
 * 阅读页第三批状态块：漫画边界续页提示、眼动校准设置行、自定义主题删除确认。
 *
 * 与前面几批一致：颜色/文案/开关这类**值**用 @Prop 传，点击行为用回调传，
 * 组件内部不持有 page 引用。
 */
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { parseAreaDimension } from '../reader/ReaderPureUtils';
import { READER_EYE_CALIBRATION_PHASE_COUNT } from '../reader/ReaderConstants';

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

/**
 * 眼动翻页三步校准覆盖层：说明卡片 + 预览框 + 目标圆点。
 * 原为 ReadBook.ets 的 @Builder readerEyeCalibrationPanel()，抽出后不持有 page 引用；
 * 覆盖层尺寸变化通过 onOverlaySizeChange 回传页面（页面仍持有 overlay 宽高状态）。
 */
@Component
export struct ReaderEyeCalibrationPanel {
  @Prop sessionActive: boolean = false;
  @Prop capturing: boolean = false;
  @Prop step: number = 0;
  @Prop progress: number = 0;
  @Prop instruction: string = '';
  @Prop targetLabel: string = '';
  @Prop statusText: string = '';
  @Prop previewHint: string = '';
  @Prop previewWidth: number = 0;
  @Prop previewHeight: number = 0;
  @Prop previewLeft: number = 0;
  @Prop previewTop: number = 0;
  @Prop targetTop: number = 0;
  @Prop overlayWidth: number = 0;
  @Prop overlayHeight: number = 0;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop panelColor: ResourceColor = '#F2FFFFFF';
  @Prop glassBorderColor: ResourceColor = '#33FFFFFF';
  @Prop scrimColor: ResourceColor = '#66000000';
  onCancel: () => void = (): void => {
  };
  onBegin: () => void = (): void => {
  };
  onSample: () => void = (): void => {
  };
  onOverlaySizeChange: (width: number, height: number) => void = (width: number, height: number): void => {
  };

  build() {
      Stack({ alignContent: Alignment.Center }) {
        Column({ space: 18 }) {
          Row() {
            Text('眼动翻页校准')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
            Blank()
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(18)
                .fontColor([this.textColor])
            }
            .width(38)
            .height(38)
            .responseRegion({ x: -3, y: -3, width: 44, height: 44 })
            .backgroundColor(this.darkMode ? '#28FFFFFF' : '#12000000')
            .onClick((): void => this.onCancel())
          }
          .width('100%')

          Text(this.instruction)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textColor)
            .textAlign(TextAlign.Center)

          Text('头部和手机保持稳定，只用眼睛跟随圆点缓慢移动。请不要提前看向圆点将要到达的位置。')
            .fontSize(13)
            .fontColor(this.subTextColor)
            .textAlign(TextAlign.Center)
            .lineHeight(20)

          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(6)
            .color(this.accentColor)
          Text(this.statusText)
            .fontSize(12)
            .fontColor(this.subTextColor)
            .textAlign(TextAlign.Center)
          if (!this.sessionActive) {
            Button('开始三步校准')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accentColor)
              .onClick((): void => this.onBegin())
          } else {
            Button(this.capturing ? '采样中…' :
              `开始采样（${this.targetLabel}）`)
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor(this.capturing ?
                (this.darkMode ? '#33FFFFFF' : '#33000000') : this.accentColor)
              .enabled(!this.capturing)
              .onClick((): void => this.onSample())
          }
        }
        .width('calc(100% - 48vp)')
        .constraintSize({ maxWidth: 480 })
        .padding(24)
        .borderRadius(28)
        .backgroundColor(this.panelColor)
        .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
        .border({ width: 1, color: this.glassBorderColor })
        .margin({ bottom: 24 })

        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(this.previewWidth * 0.48)
            .height(this.previewHeight * 0.76)
            .borderRadius(999)
            .border({ width: 2, color: this.accentColor, style: BorderStyle.Dashed })

          Column() {
            Blank()
            Text(this.previewHint)
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(12)
              .backgroundColor('#88000000')
              .margin({ bottom: 8 })
          }
          .height('100%')
        }
        .width(this.previewWidth)
        .height(this.previewHeight)
        .position({
          x: this.previewLeft,
          y: this.previewTop
        })
        .borderRadius(20)
        .border({ width: 1, color: '#70FFFFFF' })
        .hitTestBehavior(HitTestMode.None)

        if (this.sessionActive && this.step >= 0 &&
          this.step < READER_EYE_CALIBRATION_PHASE_COUNT) {
          Row()
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor(this.accentColor)
            .border({ width: 4, color: this.darkMode ? '#A0FFFFFF' : '#D0FFFFFF' })
            .shadow({ radius: 16, color: this.accentColor, offsetX: 0, offsetY: 0 })
            .position({
              x: Math.max(0, (this.overlayWidth - 24) / 2),
              y: this.targetTop
            })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.scrimColor)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .zIndex(4)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.onOverlaySizeChange(parseAreaDimension(newArea.width), parseAreaDimension(newArea.height));
      })
      .onClick((): void => {})
  }
}

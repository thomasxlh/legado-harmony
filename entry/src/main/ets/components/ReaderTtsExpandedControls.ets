import * as LeafFns from '../reader/ReaderLeafFns';
import { ReaderTtsMediaSymbolControl, ReaderTtsMediaSpeedControl } from './ReaderSettingItems';
import { ReaderTtsTimerControl } from './ReaderStatusItems';

/**
 * 朗读展开控制条（不支持沉浸材质的兼容分支）：定时 / 上一章 / 播放暂停 / 下一章 / 倍速 / 关闭。
 *
 * 原先 82 行 @Builder、读 16 个页面状态。提取后播放态、可跳章、倍速文本等值走 @Prop，
 * 六个按钮统一回调 `onControl(index)` 交回页面分发（与 HdsTabs 版本共用同一个处理器）。
 */
@Component
export struct ReaderTtsExpandedControlsCompat {
  @Prop timerMinutes: number = 0;
  @Prop remainingSeconds: number = 0;
  @Prop speaking: boolean = false;
  @Prop paused: boolean = false;
  @Prop canPlayPrevious: boolean = false;
  @Prop canPlayNext: boolean = false;
  @Prop speedText: string = '1.0x';
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#8A8A8A';
  @Prop accentColor: string = '#3B82F6';
  @Prop panelColor: string = '#FFFFFF';
  @Prop glassBorderColor: string = '#1A000000';
  @Prop glassShadowColor: string = '#33000000';
  @Prop controlLeft: number = 0;
  @Prop overlayOffset: number = 0;
  onControl: (index: number) => void = (index: number): void => {
  };

  build() {
    Row() {
      Stack() {
        ReaderTtsTimerControl({
          timerMinutes: this.timerMinutes,
          remainingSeconds: this.remainingSeconds,
          textColor: this.textColor,
          accentColor: this.accentColor
        })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(0))

      Stack() {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.arrow_left'),
          controlEnabled: this.canPlayPrevious,
          accessibilityLabel: '上一章',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(1))

      Stack() {
        ReaderTtsMediaSymbolControl({
          icon: this.speaking && !this.paused ? $r('sys.symbol.pause') : $r('sys.symbol.play'),
          controlEnabled: true,
          accessibilityLabel: this.speaking && !this.paused ? '暂停朗读' : '播放朗读',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(2))

      Stack() {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.arrow_right'),
          controlEnabled: this.canPlayNext,
          accessibilityLabel: '下一章',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(3))

      Stack() {
        ReaderTtsMediaSpeedControl({ speedText: this.speedText, textColor: this.textColor })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(4))

      Stack() {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.xmark'),
          controlEnabled: true,
          accessibilityLabel: '关闭朗读控制',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        })
      }
      .layoutWeight(1)
      .onClick(() => this.onControl(5))
    }
    .width(LeafFns.readerTtsExpandedControlWidth())
    .height(56)
    .padding({ left: 4, right: 4 })
    .position({ x: this.controlLeft, y: '100%' })
    .translate({ y: -this.overlayOffset })
    .borderRadius(28)
    .backgroundColor(this.panelColor)
    .backdropBlur(22)
    .border({ width: 1, color: this.glassBorderColor })
    .shadow({ radius: 10, color: this.glassShadowColor, offsetX: 0, offsetY: 3 })
  }
}

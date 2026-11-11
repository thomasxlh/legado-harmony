import { HdsTabs } from '@kit.UIDesignKit';
import * as LeafFns from '../reader/ReaderLeafFns';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';
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

/**
 * 朗读展开控制条（沉浸材质分支，基于 HdsTabs）。
 *
 * 与兼容分支同一组六个按钮，但使用悬浮 TabBar + 系统材质。主题 key、面板色、六项可用态、
 * 播放态与倍速文本都走 @Prop；点击统一回调 `onControl(index)`，由页面按索引分发。
 */
@Component
export struct ReaderTtsExpandedControlsBar {
  @Prop timerMinutes: number = 0;
  @Prop remainingSeconds: number = 0;
  @Prop speaking: boolean = false;
  @Prop paused: boolean = false;
  @Prop canPlayPrevious: boolean = false;
  @Prop canPlayNext: boolean = false;
  @Prop speedText: string = '1.0x';
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#6B7280';
  @Prop accentColor: string = '#3B82F6';
  @Prop panelColor: string = '#FFFFFF';
  @Prop themeKey: string = '';
  @Prop controlLeft: number = 0;
  @Prop overlayOffset: number = 0;
  onControl: (index: number) => void = (): void => {
  };

  build() {
    HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsTimerControl({
          timerMinutes: this.timerMinutes,
          remainingSeconds: this.remainingSeconds,
          textColor: this.textColor,
          accentColor: this.accentColor
        });
      })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.arrow_left'),
          controlEnabled: this.canPlayPrevious,
          accessibilityLabel: '上一章',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        });
      })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsMediaSymbolControl({
          icon: this.speaking && !this.paused ? $r('sys.symbol.pause') : $r('sys.symbol.play'),
          controlEnabled: true,
          accessibilityLabel: this.speaking && !this.paused ? '暂停朗读' : '播放朗读',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        });
      })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.arrow_right'),
          controlEnabled: this.canPlayNext,
          accessibilityLabel: '下一章',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        });
      })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsMediaSpeedControl({
          speedText: this.speedText,
          textColor: this.textColor
        });
      })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => {
        ReaderTtsMediaSymbolControl({
          icon: $r('sys.symbol.xmark'),
          controlEnabled: true,
          accessibilityLabel: '关闭朗读控制',
          textColor: this.textColor,
          subTextColor: this.subTextColor
        });
      })
    }
    .key(this.themeKey)
    .barBackgroundColor(this.panelColor)
    .barMode(BarMode.Fixed)
    .barHeight(48)
    .barOverlap(true)
    .barFloatingStyle({
      barWidth: {
        smallWidth: LeafFns.readerTtsExpandedControlWidth(),
        mediumWidth: LeafFns.readerTtsExpandedControlWidth(),
        largeWidth: LeafFns.readerTtsExpandedControlWidth()
      },
      systemMaterialEffect: {
        materialType: ImmersiveMaterialRuntime.materialType(),
        materialLevel: ImmersiveMaterialRuntime.materialLevel()
      },
      barSideMargin: 0,
      barBottomMargin: 4,
      gradientMask: {
        maskColor: '#00000000',
        maskHeight: 56
      },
      adaptToHandedness: false,
      thermoCtrl: true,
      barOpacity: 1
    })
    .scrollable(false)
    .onContentWillChange(() => false)
    .onTabBarClick((index: number) => {
      this.onControl(index);
    })
    .width(LeafFns.readerTtsExpandedControlWidth())
    .height(56)
    .position({ x: this.controlLeft, y: '100%' })
    .translate({
      y: -this.overlayOffset
    })
  }
}

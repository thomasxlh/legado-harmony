import { ReaderSliderStepButton } from './ReaderOverlayItems';
import { ReaderTtsSpeedChip, ReaderTtsSleepTimerChip } from './ReaderOverlayItems';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';

/**
 * 朗读设置面板的「快捷设置」区块：倍速滑杆 + 倍速 chip + 音色入口 + 定时 chip + 开始/停止朗读。
 *
 * 原 @Builder `ttsQuickSettingsPanel` 只有 18 个成员依赖，且全是「颜色 / 当前值 / 三个动作」，
 * 因此整体提为组件：状态值经 @Prop 传入，动作经回调回传，避免穿透 page 引用。
 */
@Component
export struct ReaderTtsQuickSettingsPanel {
  @Prop ttsSpeed: number = 1;
  @Prop textColor: string = '#000000';
  @Prop subTextColor: string = '#888888';
  @Prop iconColor: ResourceColor = Color.Black;
  @Prop accentColor: string = '#3B82F6';
  @Prop chipIdleColor: string = '#F0F0F0';
  @Prop darkMode: boolean = false;
  @Prop voicesLoading: boolean = false;
  @Prop selectedVoiceTitle: string = '';
  @Prop sleepTimerMinutes: number = 0;
  @Prop sleepTimerRemainingSeconds: number = 0;
  @Prop dangerColor: string = '#D94841';
  @Prop buttonColor: string = '#3B82F6';
  @Prop speaking: boolean = false;
  onApplySpeed: (value: number) => void = () => {};
  onSetSleepTimer: (minutes: number) => void = () => {};
  onToggleVoiceDropdown: () => void = () => {};
  onToggleReading: () => void = () => {};

  private remainingLabel(): string {
    return this.sleepTimerMinutes > 0 ?
      `剩余 ${Math.max(1, Math.ceil(this.sleepTimerRemainingSeconds / 60))} 分钟` : '未设置';
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('朗读倍速')
          .fontSize(15)
          .fontColor(this.textColor)
          .layoutWeight(1)
        Text(`${this.ttsSpeed.toFixed(1)}x`)
          .fontSize(14)
          .fontColor(this.subTextColor)
      }
      .width('100%')

      Row({ space: 10 }) {
        ReaderSliderStepButton({
          icon: $r('sys.symbol.minus'),
          accessibilityLabel: '降低朗读倍速',
          controlEnabled: this.ttsSpeed > 0.5,
          action: (): void => {
            this.onApplySpeed(this.ttsSpeed - 0.1);
          },
          iconColor: this.iconColor,
          disabledIconColor: this.subTextColor,
          darkMode: this.darkMode
        })
        Slider({ value: this.ttsSpeed, min: 0.5, max: 3, step: 0.1 })
          .layoutWeight(1)
          .showTips(true)
          .selectedColor(this.accentColor)
          .sliderInteractionMode(ImmersiveMaterialRuntime.supportsHds() ?
            SliderInteraction.SLIDE_AND_CLICK_UP : SliderInteraction.SLIDE_ONLY)
          .onChange((value: number) => {
            this.onApplySpeed(value);
          })
        ReaderSliderStepButton({
          icon: $r('sys.symbol.plus'),
          accessibilityLabel: '提高朗读倍速',
          controlEnabled: this.ttsSpeed < 3,
          action: (): void => {
            this.onApplySpeed(this.ttsSpeed + 0.1);
          },
          iconColor: this.iconColor,
          disabledIconColor: this.subTextColor,
          darkMode: this.darkMode
        })
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach([0.8, 1.0, 1.5, 2.0, 3.0], (speedValue: number) => {
          ReaderTtsSpeedChip({
            value: speedValue,
            selected: Math.abs(this.ttsSpeed - speedValue) < 0.01,
            textColor: this.textColor,
            accentColor: this.accentColor,
            idleColor: this.chipIdleColor,
            onSelect: (): void => {
              this.onApplySpeed(speedValue);
            }
          })
        }, (speedValue: number) => `speed_${speedValue}`)
      }
      .width('100%')

      Row() {
        Text('朗读音色')
          .fontSize(15)
          .fontColor(this.textColor)
          .layoutWeight(1)
        if (this.voicesLoading) {
          Text('加载中')
            .fontSize(12)
            .fontColor(this.subTextColor)
        }
      }
      .width('100%')

      Row() {
        Text(this.selectedVoiceTitle)
          .fontSize(14)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([this.subTextColor])
          .margin({ left: 10 })
      }
      .width('100%')
      .height(44)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.chipIdleColor)
      .borderRadius(8)
      .onClick(() => {
        this.onToggleVoiceDropdown();
      })

      Row() {
        Text('朗读定时')
          .fontSize(15)
          .fontColor(this.textColor)
          .layoutWeight(1)
        Text(this.remainingLabel())
          .fontSize(12)
          .fontColor(this.subTextColor)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach([15, 30, 60, 90, 120], (minutes: number) => {
          ReaderTtsSleepTimerChip({
            minutes: minutes,
            selected: this.sleepTimerMinutes === minutes,
            textColor: this.textColor,
            accentColor: this.accentColor,
            idleColor: this.chipIdleColor,
            onToggle: (): void => {
              this.onSetSleepTimer(this.sleepTimerMinutes === minutes ? 0 : minutes);
            }
          })
        }, (minutes: number) => `timer_${minutes}`)
      }
      .width('100%')

      Button(this.speaking ? '停止朗读' : '开始朗读')
        .width('100%')
        .height(40)
        .backgroundColor(this.speaking ? this.dangerColor : this.buttonColor)
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.onToggleReading();
        })
    }
    .width('100%')
  }
}

import { ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { ThemeRuntime } from '../theme/ThemeRuntime';

const AUTO_PAGE_TURN_PRESET_INTERVALS: number[] = [5, 10, 15, 20, 30, 45, 60, 90, 120];

/**
 * 自动翻页间隔设置内容（配合系统自定义对话框使用，表面材质由系统渲染）。
 * 档位秒数 + 自定义输入（3~300 秒）；编辑结果经 AppStorage 同步并持久化随云同步。
 */
@Component
export struct AutoPageTurnIntervalDialogContent {
  @StorageLink('readerAutoPageTurnIntervalSec') autoPageTurnIntervalSec: number = 15;
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @State customIntervalDraft: string = '';
  onDone: () => void = (): void => {
  };

  isPresetSelected(sec: number): boolean {
    return this.autoPageTurnIntervalSec === sec;
  }

  applyInterval(sec: number): void {
    const normalized = ReaderSettingsStore.normalizeAutoPageTurnInterval(sec);
    this.autoPageTurnIntervalSec = normalized;
    this.customIntervalDraft = '';
    ReaderSettingsStore.saveAutoPageTurnInterval(getContext(this), normalized).catch((e: Error) => {
      console.error('保存自动翻页间隔失败:', e);
    });
  }

  applyCustomDraft(): void {
    const parsed = Number(this.customIntervalDraft);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return;
    }
    this.applyInterval(parsed);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  inputColor(): string {
    return ThemeRuntime.inputColor(this.appDarkMode);
  }

  buttonColor(): string {
    return ThemeRuntime.buttonColor(this.appDarkMode);
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('自动翻页间隔')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([this.primaryTextColor()])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .accessibilityText('关闭')
        .onClick(() => {
          this.onDone();
        })
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)

      Text('选择自动翻页的时间间隔，也可输入 3~300 秒的自定义值')
        .fontSize(12)
        .fontColor(this.subTextColor())
        .width('100%')

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(AUTO_PAGE_TURN_PRESET_INTERVALS, (sec: number) => {
          Text(`${sec} 秒`)
            .fontSize(14)
            .fontWeight(this.isPresetSelected(sec) ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.isPresetSelected(sec) ? '#FFFFFF' : this.primaryTextColor())
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(18)
            .backgroundColor(this.isPresetSelected(sec) ? this.buttonColor() : this.inputColor())
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.applyInterval(sec);
            })
        }, (sec: number) => `preset_${sec}`)
      }
      .width('100%')

      Row({ space: 10 }) {
        TextInput({ text: this.customIntervalDraft, placeholder: `当前 ${this.autoPageTurnIntervalSec} 秒，输入 3~300` })
          .type(InputType.Number)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .height(40)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.inputColor())
          .borderRadius(12)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.customIntervalDraft = value;
          })
          .onSubmit(() => {
            this.applyCustomDraft();
          })

        Button('应用')
          .height(40)
          .fontSize(14)
          .backgroundColor(this.buttonColor())
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.applyCustomDraft();
          })
      }
      .width('100%')

      Button('完成')
        .width('100%')
        .height(42)
        .fontSize(15)
        .backgroundColor(this.inputColor())
        .fontColor(this.primaryTextColor())
        .onClick(() => {
          this.onDone();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: 420 })
    .padding(18)
  }
}

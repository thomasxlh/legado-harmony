import { SelectMenuMaterialModifier } from './SelectMenuMaterialModifier';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import * as LeafFns from '../reader/ReaderLeafFns';

/**
 * 阅读设置面板里的「行」组件。
 *
 * 从 ReadBookPage 的 @Builder 提出，原因见 CODE_MAP.md 的 P1 蓝图：
 * 每行原本都要 read 5~9 个页面 @State 才能画出自己，提成组件后用 @Prop 把值显式传进来。
 * 这些行都不含 ArkUI 命令式调用（animateTo / 路由 / 弹窗），只做渲染与回调，因此提取安全。
 */

@Component
export struct ReaderSelectSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop options: SelectOption[] = [];
  @Prop selected: number = 0;
  @Prop controlId: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  onSelect: (index: number) => void = (index: number): void => {
  };

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(15)
          .fontColor(this.textColor)
        Text(this.description)
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Select(this.options)
        .id(this.controlId)
        .selected(this.selected)
        .value(LeafFns.readerSelectOptionValue(this.options, this.selected))
        .font({ size: 14 })
        .fontColor(this.subTextColor)
        .backgroundColor(Color.Transparent)
        .arrowPosition(ArrowPosition.END)
        .padding({ left: 0, right: 0 })
        // Keep the hit area rectangular, but soften its corners to match the rounded settings cards.
        .borderRadius(16)
        .border({ width: 0 })
        .optionBgColor(Color.Transparent)
        .divider(null)
        .optionFontColor(this.textColor)
        .selectedOptionFontColor(this.accentColor)
        .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.darkMode))
        .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.darkMode, this.panelColor))
        .menuBackgroundBlurStyle(BlurStyle.NONE)
        .attributeModifier(new SelectMenuMaterialModifier())
        .onSelect((index: number) => {
          this.onSelect(index);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}

/**
 * 朗读音色下拉里的一个选项行。
 * 原 @Builder 直接写 this.ttsVoiceRowPressedKey，提成组件后改成 pressed + onPressedChange 两个参数，
 * 让按下态由页面持有，避免组件内出现状态写入。
 */
@Component
export struct ReaderTtsVoiceOption {
  @Prop title: string = '';
  @Prop selected: boolean = false;
  @Prop pressed: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop selectedBackgroundColor: ResourceColor = Color.Transparent;
  onPressedChange: (pressed: boolean) => void = (pressed: boolean): void => {
  };
  onAction: () => void = (): void => {
  };

  build() {
    Row() {
      Text(this.title)
        .fontSize(14)
        .fontColor(this.textColor)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.selected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([this.accentColor])
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(8)
    .backgroundColor(this.pressed ?
      (this.darkMode ? '#14FFFFFF' : '#0F000000') :
      (this.selected ? this.selectedBackgroundColor : Color.Transparent))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.onPressedChange(true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onPressedChange(false);
      }
    })
    .onClick(() => {
      this.onAction();
    })
  }
}

/** 「点击区域动作」设置行：左侧标题 + 摘要，右侧「配置」按钮。 */
@Component
export struct ReaderTapZoneSettingItem {
  @Prop summaryText: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop buttonColor: ResourceColor = '#3B82F6';
  onConfigure: () => void = (): void => {
  };

  build() {
    Row() {
      Column() {
        Text('点击区域动作')
          .fontSize(15)
          .fontColor(this.textColor)
        Text(this.summaryText)
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('配置')
        .height(34)
        .fontSize(13)
        .backgroundColor(this.buttonColor)
        .fontColor('#FFFFFF')
        .margin({ left: 12 })
        .onClick(() => {
          this.onConfigure();
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}

/** 「自动翻页间隔」设置行。 */
@Component
export struct ReaderAutoPageTurnIntervalSettingItem {
  @Prop intervalSec: number = 15;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop fieldColor: ResourceColor = '#F2F2F2';
  onOpen: () => void = (): void => {
  };

  build() {
    Row() {
      Column() {
        Text('自动翻页间隔')
          .fontSize(15)
          .fontColor(this.textColor)
        Text('自动翻到下一页前等待的秒数，随阅读设置云同步')
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(`${this.intervalSec} 秒`)
        .height(36)
        .fontSize(13)
        .backgroundColor(this.fieldColor)
        .fontColor(this.textColor)
        .onClick((): void => {
          this.onOpen();
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}

/** TXT 字符集选择面板里的一个选项。 */
@Component
export struct ReaderTxtCharsetOptionRow {
  @Prop label: string = '';
  @Prop description: string = '';
  @Prop selected: boolean = false;
  @Prop rowEnabled: boolean = true;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  onPick: () => void = (): void => {
  };

  build() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.label)
          .fontSize(16)
          .fontColor(this.textColor)
        Text(this.description)
          .fontSize(12)
          .fontColor(this.subTextColor)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(22)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .borderRadius(14)
    .backgroundColor(this.selected ?
      ThemeRuntime.accentSurfaceColor(this.darkMode) : Color.Transparent)
    .enabled(this.rowEnabled)
    .onClick(() => {
      this.onPick();
    })
  }
}

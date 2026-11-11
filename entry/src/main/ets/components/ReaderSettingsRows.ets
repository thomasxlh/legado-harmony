import { SelectMenuMaterialModifier } from './SelectMenuMaterialModifier';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import * as LeafFns from '../reader/ReaderLeafFns';
import { ImmersiveBackButton } from './ImmersiveBackButton';
import { ReaderLayoutElementToggle, ReaderSwitchSettingItem } from './ReaderSettingItems';
import { ReaderTxtCharsetOption } from '../core/reader/ReaderSettingsModels';
import { TtsVoiceOption } from '../utils/SystemTtsReader';
import { HdsFeedback } from '../utils/HdsFeedback';

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

@Component
export struct ReaderLayoutElementSettingsDialog {
  @Prop textColor: ResourceColor;
  @Prop subTextColor: ResourceColor;
  @Prop accentColor: ResourceColor;
  @Prop dark: boolean = false;
  @Prop panelColor: ResourceColor;
  @Prop glassBorderColor: ResourceColor;
  @Prop shadowColor: ResourceColor;
  @Prop dialogWidth: number = 420;
  @Prop useTtsQuickAction: boolean = true;
  @Prop ttsQuickActionLeft: boolean = false;
  @Prop useChapterQuickJump: boolean = true;
  onClose: () => void = () => {};
  onToggleTtsQuickAction: (enabled: boolean) => void = () => {};
  onToggleTtsQuickActionSide: (left: boolean) => void = () => {};
  onToggleChapterQuickJump: (enabled: boolean) => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.dark ? '#52000000' : '#26000000')
        .backdropBlur(ThemeRuntime.glassBlur('overlay', 18))
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 4 }) {
        Row() {
          Text('布局元素设置')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
          ImmersiveBackButton({
            icon: $r('sys.symbol.xmark'),
            iconOffsetX: 0,
            iconColor: this.textColor,
            darkMode: this.dark,
            buttonSize: 38,
            containerWidth: 38,
            containerHeight: 38,
            startInset: 0,
            compactLayout: true,
            accessibilityLabel: '关闭布局元素设置',
            onBack: () => {
              this.onClose();
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('控制点击阅读页后出现的快捷组件')
          .fontSize(13)
          .fontColor(this.subTextColor)
          .width('100%')
          .margin({ bottom: 8 })

        ReaderLayoutElementToggle({
          title: '使用快速朗读组件',
          description: '显示朗读快捷按钮与展开控制条',
          isOn: this.useTtsQuickAction,
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          dark: this.dark,
          onChange: (enabled: boolean): void => {
            this.onToggleTtsQuickAction(enabled);
          }
        })
        if (this.useTtsQuickAction) {
          ReaderLayoutElementToggle({
            title: '朗读按钮靠左',
            description: '把听书播放按钮放到屏幕左下角',
            isOn: this.ttsQuickActionLeft,
            textColor: this.textColor,
            subTextColor: this.subTextColor,
            accentColor: this.accentColor,
            dark: this.dark,
            onChange: (left: boolean): void => {
              this.onToggleTtsQuickActionSide(left);
            }
          })
        }
        ReaderLayoutElementToggle({
          title: '使用章节快速跳转组件',
          description: '显示章节滑杆与上一章、下一章按钮',
          isOn: this.useChapterQuickJump,
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          dark: this.dark,
          onChange: (enabled: boolean): void => {
            this.onToggleChapterQuickJump(enabled);
          }
        })
      }
      .width(Math.max(1, Math.min(420, this.dialogWidth)))
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .borderRadius(ThemeRuntime.glassCornerRadius(24, 'overlay'))
      .backgroundColor(this.panelColor)
      .backdropBlur(ThemeRuntime.glassBlur('overlay', 24))
      .border({ width: ThemeRuntime.glassBorderWidth('overlay'), color: this.glassBorderColor })
      .shadow({ radius: ThemeRuntime.glassShadowRadius('overlay'), color: this.shadowColor,
        offsetX: ThemeRuntime.glassShadowOffsetX('overlay'), offsetY: ThemeRuntime.glassShadowOffsetY('overlay') })
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 页眉 / 页脚设置块。
 * 原来是一个 72 行的 @Builder，读了 6 个页面 @State 与 4 个选择项索引；
 * 提成组件后所有值由调用点显式传入，回调用事件回抛。
 */
@Component
export struct ReaderHeaderFooterSettingsPanel {
  @Prop headerEnabled: boolean = true;
  @Prop headerContentSelected: number = 0;
  @Prop footerEnabled: boolean = true;
  @Prop footerLeftSelected: number = 0;
  @Prop footerProgressSelected: number = 0;
  @Prop footerShowProgressBar: boolean = true;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop switchColor: ResourceColor = '#4F8F86';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  onToggleHeader: (enabled: boolean) => void = (_enabled: boolean): void => {
  };
  onSelectHeaderContent: (index: number) => void = (_index: number): void => {
  };
  onToggleFooter: (enabled: boolean) => void = (_enabled: boolean): void => {
  };
  onSelectFooterLeft: (index: number) => void = (_index: number): void => {
  };
  onSelectFooterProgress: (index: number) => void = (_index: number): void => {
  };
  onToggleFooterProgressBar: (enabled: boolean) => void = (_enabled: boolean): void => {
  };

  build() {
    Column({ space: 4 }) {
      ReaderSwitchSettingItem({
        title: '显示页眉',
        description: '在正文顶部显示书名或当前章节标题',
        isOn: this.headerEnabled,
        onChange: (checked: boolean): void => {
          this.onToggleHeader(checked);
        },
        textColor: this.textColor,
        subTextColor: this.subTextColor,
        switchColor: this.switchColor
      })

      if (this.headerEnabled) {
        ReaderSelectSettingItem({
          title: '页眉内容',
          description: '选择页眉中显示的信息',
          options: LeafFns.readerHeaderContentOptions(),
          selected: this.headerContentSelected,
          controlId: 'reader_header_content_select',
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          darkMode: this.darkMode,
          panelColor: this.panelColor,
          onSelect: (index: number): void => {
            this.onSelectHeaderContent(index);
          }
        })
      }

      ReaderSwitchSettingItem({
        title: '显示页脚',
        description: '显示章节信息和阅读进度',
        isOn: this.footerEnabled,
        onChange: (checked: boolean): void => {
          this.onToggleFooter(checked);
        },
        textColor: this.textColor,
        subTextColor: this.subTextColor,
        switchColor: this.switchColor
      })

      if (this.footerEnabled) {
        ReaderSelectSettingItem({
          title: '页脚左侧',
          description: '选择页脚左侧显示的信息',
          options: LeafFns.readerFooterLeftOptions(),
          selected: this.footerLeftSelected,
          controlId: 'reader_footer_left_select',
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          darkMode: this.darkMode,
          panelColor: this.panelColor,
          onSelect: (index: number): void => {
            this.onSelectFooterLeft(index);
          }
        })

        ReaderSelectSettingItem({
          title: '阅读进度',
          description: '选择页脚右侧显示的进度类型',
          options: LeafFns.readerFooterProgressOptions(),
          selected: this.footerProgressSelected,
          controlId: 'reader_footer_progress_select',
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          darkMode: this.darkMode,
          panelColor: this.panelColor,
          onSelect: (index: number): void => {
            this.onSelectFooterProgress(index);
          }
        })

        ReaderSwitchSettingItem({
          title: '显示进度条',
          description: '在页脚上方显示本章阅读进度',
          isOn: this.footerShowProgressBar,
          onChange: (checked: boolean): void => {
            this.onToggleFooterProgressBar(checked);
          },
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          switchColor: this.switchColor
        })
      }
    }
    .width('100%')
    .padding({ bottom: 8 })
  }
}

/**
 * TXT 字符编码选择弹窗内容。
 * 原 @Builder 81 行，读 5 个页面 @State + 2 个动作方法；提成组件后值走 @Prop、动作走回调。
 */
@Component
export struct ReaderTxtCharsetDialogContent {
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop controlIconColor: ResourceColor = '#18191C';
  @Prop darkMode: boolean = false;
  @Prop currentCharsetLabel: string = '自动识别';
  @Prop draftCharset: string = '';
  @Prop applying: boolean = false;
  @Prop listHeight: number = 320;
  onClose: () => void = (): void => {
  };
  onPick: (value: string) => void = (_value: string): void => {
  };
  onCancel: () => void = (): void => {
  };
  onApply: () => void = (): void => {
  };

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('选择字符编码')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
          Text(`当前解析：${this.currentCharsetLabel}`)
            .fontSize(12)
            .fontColor(this.subTextColor)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        ImmersiveBackButton({
          icon: $r('sys.symbol.xmark'),
          iconOffsetX: 0,
          iconColor: this.controlIconColor,
          darkMode: this.darkMode,
          buttonSize: 38,
          containerWidth: 38,
          containerHeight: 38,
          startInset: 0,
          compactLayout: true,
          accessibilityLabel: '关闭字符编码选择',
          onBack: (): void => {
            this.onClose();
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 4 }) {
          ForEach(LeafFns.txtCharsetOptions(), (option: ReaderTxtCharsetOption) => {
            ReaderTxtCharsetOptionRow({
              label: option.label,
              description: option.description,
              selected: this.draftCharset === option.value,
              rowEnabled: !this.applying,
              textColor: this.textColor,
              subTextColor: this.subTextColor,
              accentColor: this.accentColor,
              darkMode: this.darkMode,
              onPick: (): void => {
                this.onPick(option.value);
              }
            })
          }, (option: ReaderTxtCharsetOption) => option.value || 'auto')
        }
        .width('100%')
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height(this.listHeight)
      .scrollBar(BarState.Auto)

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontColor(this.textColor)
          .backgroundColor(this.darkMode ? '#24FFFFFF' : '#10000000')
          .enabled(!this.applying)
          .onClick((): void => {
            this.onCancel();
          })
        Button(this.applying ? '正在重新解析…' : '应用')
          .layoutWeight(1)
          .height(42)
          .fontColor('#FFFFFF')
          .backgroundColor(this.accentColor)
          .enabled(!this.applying)
          .onClick((): void => {
            this.onApply();
          })
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: 440 })
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
  }
}

/**
 * 朗读音色下拉里的一个「系统音色」行。
 * 比 ReaderTtsVoiceOption 多三种右侧状态：下载中 / 已选中 / 可下载，以及不可用时的降透明度与 toast。
 */
@Component
export struct ReaderSystemTtsVoiceOption {
  @Prop title: string = '';
  @Prop availableState: number = 0;
  @Prop downloadable: boolean = false;
  @Prop downloading: boolean = false;
  @Prop selected: boolean = false;
  @Prop pressed: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop pressedBackgroundColor: ResourceColor = '#0F000000';
  @Prop selectedBackgroundColor: ResourceColor = Color.Transparent;
  onPressedChange: (pressed: boolean) => void = (pressed: boolean): void => {
  };
  onAction: (available: boolean, downloadable: boolean) => void =
    (_available: boolean, _downloadable: boolean): void => {
    };

  private get usable(): boolean {
    return this.availableState !== 0 || this.downloadable;
  }

  build() {
    Row() {
      Text(this.title)
        .fontSize(14)
        .fontColor(this.usable ? this.textColor : this.subTextColor)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.downloading) {
        Text('下载中')
          .fontSize(11)
          .fontColor(this.accentColor)
          .margin({ left: 10 })
      } else if (this.selected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([this.accentColor])
          .margin({ left: 10 })
      } else if (this.availableState === 0 && this.downloadable) {
        Text('下载')
          .fontSize(12)
          .fontColor(this.accentColor)
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(8)
    .backgroundColor(this.pressed ? this.pressedBackgroundColor :
      (this.selected ? this.selectedBackgroundColor : Color.Transparent))
    .opacity(this.usable ? 1 : 0.5)
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.onPressedChange(true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onPressedChange(false);
      }
    })
    .onClick((): void => {
      this.onAction(this.availableState !== 0, this.downloadable);
    })
  }
}

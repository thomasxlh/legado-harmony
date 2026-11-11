import { ThemeRuntime } from '../theme/ThemeRuntime';
import { AdaptiveColorPicker } from './AdaptiveColorPicker';
import { SelectMenuMaterialModifier } from './SelectMenuMaterialModifier';

/**
 * 阅读设置 → 自定义阅读方案编辑器（仅当当前主题为「自定义」时渲染）。
 *
 * 原 `readerQuickSettingsPanel` 里这一段有 150 行、20+ 个状态读写，属于独立职责域
 * （方案选择 / 重命名 / 背景色或背景图 / 文字颜色），因此整块提为组件：
 * 状态值经 @Prop 传入，写操作经回调回传，避免穿透 page 引用。
 */
@Component
export struct ReaderCustomThemeEditor {
  @Prop schemeName: string = '';
  @Prop nameDraft: string = '';
  @Prop selectedIndex: number = 0;
  @Prop options: SelectOption[] = [];
  @Prop backgroundTypeIndex: number = 0;
  @Prop surfaceColor: string = '';
  @Prop backgroundImageUri: string = '';
  @Prop imageFitIndex: number = 0;
  @Prop textColorValue: string = '';
  @Prop textColor: string = '#000000';
  @Prop fieldColor: string = '#F0F0F0';
  @Prop accentColor: string = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop appDarkMode: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  onSelectScheme: (index: number) => void = () => {};
  onAdd: () => void = () => {};
  onDelete: () => void = () => {};
  onNameDraftChange: (value: string) => void = () => {};
  onCommitName: (value: string) => void = () => {};
  onBackgroundTypeChange: (index: number) => void = () => {};
  onBackgroundColorChange: (value: string) => void = () => {};
  onChooseImage: () => void = () => {};
  onClearImage: () => void = () => {};
  onImageFitChange: (index: number) => void = () => {};
  onTextColorChange: (value: string) => void = () => {};

  private imageFitLabels(): string[] {
    return ['裁剪填充', '完整显示', '拉伸铺满'];
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Select(this.options)
          .selected(this.selectedIndex)
          .value(this.schemeName)
          .font({ size: 14 })
          .fontColor(this.textColor)
          .backgroundColor(this.fieldColor)
          .borderRadius(16)
          .border({ width: 0 })
          .layoutWeight(1)
          .divider(null)
          .optionBgColor(Color.Transparent)
          .optionFontColor(this.textColor)
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.darkMode))
          .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.darkMode, this.panelColor))
          .menuBackgroundBlurStyle(BlurStyle.NONE)
          .attributeModifier(new SelectMenuMaterialModifier())
          .onSelect((index: number) => {
            this.onSelectScheme(index);
          })
        Button('新增')
          .height(36)
          .fontSize(13)
          .backgroundColor(this.accentColor)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.onAdd();
          })
        Button('删除')
          .height(36)
          .fontSize(13)
          .backgroundColor(this.fieldColor)
          .fontColor(this.textColor)
          .onClick(() => {
            this.onDelete();
          })
      }
      .width('100%')

      TextInput({ text: this.nameDraft, placeholder: '输入方案名称' })
        .fontSize(14)
        .fontColor(this.textColor)
        .height(36)
        .padding({ left: 10, right: 10 })
        .backgroundColor(this.fieldColor)
        .borderRadius(8)
        .onChange((value: string) => {
          this.onNameDraftChange(value.substring(0, 20));
        })
        .onSubmit(() => {
          this.onCommitName(this.nameDraft);
        })
        .onBlur(() => {
          this.onCommitName(this.nameDraft);
        })

      Row() {
        Text('背景设置')
          .fontSize(14)
          .fontColor(this.textColor)
        Blank()
        Select([{ value: '背景色' }, { value: '背景图片' }])
          .selected(this.backgroundTypeIndex)
          .value(this.backgroundTypeIndex === 1 ? '背景图片' : '背景色')
          .font({ size: 14 })
          .fontColor(this.textColor)
          .backgroundColor(this.fieldColor)
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
            this.onBackgroundTypeChange(index);
          })
      }
      .width('100%')

      if (this.backgroundTypeIndex === 0) {
        AdaptiveColorPicker({
          value: this.surfaceColor,
          placeholder: this.surfaceColor,
          appDarkMode: this.appDarkMode,
          accentColor: this.accentColor,
          optionTitle: '背景颜色',
          onColorChange: (value: string) => {
            this.onBackgroundColorChange(value);
          }
        })
      } else {
        Row({ space: 8 }) {
          Button(this.backgroundImageUri ? '更换背景图片' : '选择背景图片')
            .height(36)
            .fontSize(13)
            .backgroundColor(this.accentColor)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.onChooseImage();
            })
          if (this.backgroundImageUri) {
            Button('移除图片')
              .height(36)
              .fontSize(13)
              .backgroundColor(this.fieldColor)
              .fontColor(this.textColor)
              .onClick(() => {
                this.onClearImage();
              })
            Select([{ value: '裁剪填充' }, { value: '完整显示' }, { value: '拉伸铺满' }])
              .selected(this.imageFitIndex)
              .value(this.imageFitLabels()[this.imageFitIndex])
              .font({ size: 13 })
              .fontColor(this.textColor)
              .backgroundColor(this.fieldColor)
              .borderRadius(16)
              .border({ width: 0 })
              .layoutWeight(1)
              .divider(null)
              .optionBgColor(Color.Transparent)
              .optionFontColor(this.textColor)
              .selectedOptionFontColor(this.accentColor)
              .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.darkMode))
              .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.darkMode, this.panelColor))
              .menuBackgroundBlurStyle(BlurStyle.NONE)
              .attributeModifier(new SelectMenuMaterialModifier())
              .onSelect((index: number) => {
                this.onImageFitChange(index);
              })
          }
        }
        .width('100%')
      }

      AdaptiveColorPicker({
        value: this.textColorValue,
        placeholder: this.textColorValue,
        appDarkMode: this.appDarkMode,
        accentColor: this.accentColor,
        optionTitle: '文字颜色',
        onColorChange: (value: string) => {
          this.onTextColorChange(value);
        }
      })
    }
    .width('100%')
  }
}

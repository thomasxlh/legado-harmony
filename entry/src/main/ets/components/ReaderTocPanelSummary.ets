/**
 * 目录面板顶部摘要栏：章节数 / 快速跳转输入 / 倒序切换 / 刷新 / 搜索。
 *
 * 与前面几批一致：状态值与颜色用 @Prop 传，交互用回调传，组件内部不持有 page 引用。
 */
import { ImmersiveBackButton } from './ImmersiveBackButton';

@Component
export struct ReaderTocPanelSummary {
  @Prop chapterCount: number = 0;
  @Prop quickJumpInputVisible: boolean = false;
  @Prop quickJumpDraft: string = '';
  @Prop quickJumpArmed: boolean = false;
  @Prop searchActive: boolean = false;
  @Prop searchMatchCount: number = 0;
  @Prop reverseOrder: boolean = false;
  @Prop searchVisible: boolean = false;
  @Prop searchQuery: string = '';
  @Prop searchLoading: boolean = false;
  @Prop textColor: string = '#1A1A1A';
  @Prop subTextColor: string = '#666666';
  @Prop accentColor: string = '#2F6BFF';
  @Prop iconColor: string = '#1A1A1A';
  @Prop darkMode: boolean = false;
  onQuickJumpDraftChange: (value: string) => void = (_value: string): void => {
  };
  onSubmitQuickJump: () => void = (): void => {
  };
  onCurrentPositionClick: () => void = (): void => {
  };
  onToggleOrder: () => void = (): void => {
  };
  onRefreshToc: () => void = (): void => {
  };
  onToggleSearch: () => void = (): void => {
  };
  onSearchQueryChange: (value: string) => void = (_value: string): void => {
  };
  onClearSearch: () => void = (): void => {
  };

  build() {
    Column({ space: 8 }) {
      Row() {
        if (this.quickJumpInputVisible && !this.searchActive) {
          TextInput({ text: this.quickJumpDraft, placeholder: `1-${this.chapterCount}` })
            .type(InputType.Normal)
            .enterKeyType(EnterKeyType.Go)
            .key('tocQuickJumpChapterInput')
            .defaultFocus(true)
            .fontSize(13)
            .fontColor(this.textColor)
            .textAlign(TextAlign.Center)
            .width(92)
            .height(34)
            .padding({ left: 8, right: 8 })
            .borderRadius(17)
            .backgroundColor(this.darkMode ? '#2BFFFFFF' : '#14000000')
            .accessibilityText('输入目标章节序号，按回车定位')
            .onChange((value: string) => {
              this.onQuickJumpDraftChange(value.replace(/[^0-9]/g, '').substring(0, 6));
            })
            .onSubmit(() => {
              this.onSubmitQuickJump();
            })
        } else if (this.searchActive) {
          Text(`找到 ${this.searchMatchCount} 章`)
            .fontSize(14)
            .fontColor(this.subTextColor)
            .margin({ left: 6 })
        } else {
          Text(`共 ${this.chapterCount} 章`)
            .fontSize(14)
            .fontColor(this.subTextColor)
            .margin({ left: 6 })
            .padding({ left: 8, right: 8 })
            .height(34)
            .textAlign(TextAlign.Center)
            .responseRegion({ x: 0, y: -5, width: '100%', height: 44 })
            .accessibilityText(this.quickJumpArmed ? '再次点击输入目标章节' : '点击回到当前章节')
            .onClick(() => {
              this.onCurrentPositionClick();
            })
        }
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 0 }) {
            SymbolGlyph($r('sys.symbol.chevron_up'))
              .fontSize(11)
              .fontColor([this.reverseOrder ? this.accentColor : this.textColor])
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(11)
              .fontColor([this.reverseOrder ? this.accentColor : this.textColor])
          }
          .alignItems(HorizontalAlign.Center)
        }
          .width(34)
          .height(34)
          .responseRegion({ x: -5, y: -5, width: 44, height: 44 })
          .borderRadius(17)
          .backgroundColor(this.reverseOrder ?
            (this.darkMode ? '#24384A' : '#E8F1FF') :
            (this.darkMode ? '#1FFFFFFF' : '#0D000000'))
          .accessibilityText(this.reverseOrder ? '切换为正序目录' : '切换为倒序目录')
          .onClick(() => this.onToggleOrder())
          .margin({ left: 4 })
        Blank()
          .layoutWeight(1)
        if (this.searchActive) {
          Text(`匹配 ${this.searchMatchCount}`)
            .fontSize(12)
            .fontColor(this.textColor)
            .height(34)
            .padding({ left: 12, right: 12 })
            .textAlign(TextAlign.Center)
            .borderRadius(16)
            .backgroundColor(this.darkMode ? '#1FFFFFFF' : '#0D000000')
        }
        ImmersiveBackButton({
          icon: $r('sys.symbol.arrow_clockwise'),
          iconOffsetX: 0,
          iconColor: this.iconColor,
          darkMode: this.darkMode,
          buttonSize: 34,
          containerWidth: 34,
          containerHeight: 34,
          startInset: 0,
          materialScale: 0.7,
          compactLayout: true,
          accessibilityLabel: '刷新目录',
          onBack: () => {
            this.onRefreshToc();
          }
        })
          .margin({ left: 8 })
        ImmersiveBackButton({
          icon: $r('sys.symbol.magnifyingglass'),
          iconOffsetX: 0,
          iconColor: this.searchVisible ? this.accentColor : this.textColor,
          darkMode: this.darkMode,
          buttonSize: 34,
          containerWidth: 34,
          containerHeight: 34,
          startInset: 0,
          materialScale: 0.7,
          compactLayout: true,
          accessibilityLabel: '搜索目录',
          onBack: () => {
            this.onToggleSearch();
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.searchVisible) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor([this.subTextColor])
          TextInput({ text: this.searchQuery,
            placeholder: this.searchLoading ? '正在载入完整目录…' : '搜索章节名称' })
            .key('tocChapterSearchInput')
            .defaultFocus(true)
            .fontSize(14)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .height(38)
            .padding({ left: 0, right: 0 })
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search)
            .onChange((value: string) => {
              this.onSearchQueryChange(value);
            })
            .onSubmit(() => {
              this.onSubmitQuickJump();
            })
          if (this.searchQuery) {
            Text('×')
              .fontSize(22)
              .fontColor(this.subTextColor)
              .width(32)
              .height(38)
              .textAlign(TextAlign.Center)
              .accessibilityText('清空目录搜索')
              .onClick(() => {
                this.onClearSearch();
                setTimeout(() => focusControl.requestFocus('tocChapterSearchInput'), 30);
              })
          }
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 8 })
        .borderRadius(20)
        .backgroundColor(this.darkMode ? '#2BFFFFFF' : '#14000000')
      }
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 18, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }
}

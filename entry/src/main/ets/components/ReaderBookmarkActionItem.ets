/**
 * 书签右键菜单里的单个操作项（图标 + 文本 + 点击回调）。
 *
 * 原先它是 ReadBookPage 里的 @Builder，只读形参、完全不碰 `this`，
 * 因此可以安全提成独立 @Component：没有共享 @State，也就没有
 * ArkUI V1 隐式联动可被切断。
 */
@Component
export struct ReaderBookmarkActionItem {
  @Prop icon: Resource = $r('sys.symbol.circle');
  @Prop label: string = '';
  @Prop color: string = '#1F1F1F';
  action: () => void = (): void => {
  };

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.icon)
        .fontSize(21)
        .fontColor([this.color])
        .width(26)
      Text(this.label)
        .fontSize(15)
        .fontColor(this.color)
        .layoutWeight(1)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(this.action)
  }
}

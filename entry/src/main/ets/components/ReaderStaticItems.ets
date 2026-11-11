/**
 * 阅读页里几个「小图标 + 文字」的静态展示项。
 *
 * 共同点：只读传入的形参、最多读一两个颜色/尺寸方法，没有自己的可变状态。
 * 提成 @Component 时把颜色/尺寸算好当 @Prop 传进来，组件内部零 page 依赖，
 * 也就不会切断 ArkUI V1 的隐式联动。
 */

@Component
export struct ReaderCommentPanelDragHandle {
  @Prop dark: boolean = false;
  @Prop handleHeight: number = 0;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.dark ? '#52000000' : '#26000000')
        .hitTestBehavior(HitTestMode.None)

      Row()
        .width(34)
        .height(3)
        .borderRadius(1.5)
        .borderWidth(0)
        .backgroundColor(this.dark ? '#66FFFFFF' : '#33000000')
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(this.handleHeight)
    .borderWidth(0)
    .zIndex(2)
    .accessibilityText('上滑展开评论面板')
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderFontEntryItem {
  @Prop textColor: string = '';
  @Prop subTextColor: string = '';
  onOpen: () => void = (): void => {
  };

  build() {
    Row() {
      Column() {
        Text('阅读字体')
          .fontSize(15)
          .fontColor(this.textColor)
        Text('正文 / 标题 / 正则样式设置')
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([this.subTextColor])
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onOpen();
    })
  }
}

@Component
export struct ReaderBookmarkDeleteAction {
  onClickAction: () => void = (): void => {
  };

  build() {
    Column({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(22)
        .fontColor(['#FFFFFF'])
      Text('删除')
        .fontSize(11)
        .fontColor('#FFFFFF')
    }
    .width(64)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#D94841')
    .onClick(() => {
      this.onClickAction();
    })
  }
}

@Component
export struct ReaderBookmarkMultiSelectAction {
  @Prop accent: string = '';
  onClickAction: () => void = (): void => {
  };

  build() {
    Column({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(22)
        .fontColor(['#FFFFFF'])
      Text('多选')
        .fontSize(11)
        .fontColor('#FFFFFF')
    }
    .width(64)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.accent)
    .onClick(() => {
      this.onClickAction();
    })
  }
}

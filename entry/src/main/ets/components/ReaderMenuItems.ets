/**
 * 阅读页菜单项：左上角 HDS/浮动图标按钮、右侧「更多操作」列表项、替换净化入口、
 * 评论面板拖拽热区。
 *
 * 与前面几批一致：颜色/是否显示角标这类**值**用 @Prop 传，点击行为用回调传，
 * 组件内部不持有 page 引用。
 */
import * as LeafFns from '../reader/ReaderLeafFns';

@Component
export struct ReaderHdsMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop showAddBadge: boolean = false;
  @Prop menuEnabled: boolean = true;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.iconColor])

        if (this.showAddBadge) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor([this.iconColor])
            .position({ x: 20, y: 0 })
        }
      }
      .width(32)
      .height(32)
    }
    .width('100%')
    .height(48)
    .opacity(this.menuEnabled ? 1 : 0.32)
    .enabled(this.menuEnabled)
    .translate({ y: -2 })
  }
}

@Component
export struct ReaderFloatingIconMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop showAddBadge: boolean = false;
  @Prop menuEnabled: boolean = true;
  onMenuClick: () => void = (): void => {
  };

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.iconColor])

        if (this.showAddBadge) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor([this.iconColor])
            .position({ x: 20, y: 0 })
        }
      }
      .width(32)
      .height(32)
    }
    // 注意：自定义组件根节点不会把 layoutWeight 作用到组件自身（V1 下组件节点尺寸由内容决定），
    // 因此撑满与均分交给调用点的 Row().layoutWeight(1) 包装，这里只负责填满该包装。
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(28)
    .opacity(this.menuEnabled ? 1 : 0.32)
    .enabled(this.menuEnabled)
    .onClick(() => {
      this.onMenuClick();
    })
  }
}

@Component
export struct ReaderActionMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop label: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop dividerColor: ResourceColor = '#E5E5E5';
  @Prop menuEnabled: boolean = true;
  @Prop showDivider: boolean = true;
  onMenuClick: () => void = (): void => {
  };
  dismissMenu: () => void = (): void => {
  };

  build() {
    Column() {
      Row({ space: 12 }) {
        SymbolGlyph(this.icon)
          .fontSize(21)
          .fontColor([this.textColor])
          .width(24)

        Text(this.label)
          .fontSize(16)
          .fontColor(this.textColor)
          .maxLines(1)
          .layoutWeight(1)
      }
      .width('100%')
      .height(46)
      .padding({ left: 10, right: 10 })

      if (this.showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color(this.dividerColor)
          .margin({ left: 46, right: 8 })
      }
    }
    .width('100%')
    .opacity(this.menuEnabled ? 1 : 0.38)
    .enabled(this.menuEnabled)
    .onClick(() => {
      if (!this.menuEnabled) {
        return;
      }
      this.dismissMenu();
      this.onMenuClick();
    })
  }
}

@Component
export struct ReaderReplaceRulesEntryItem {
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  onOpen: () => void = (): void => {
  };

  build() {
    Row() {
      Column() {
        Text('替换净化')
          .fontSize(15)
          .fontColor(this.textColor)
        Text('管理正文与章节标题的替换规则')
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
export struct ReaderCommentPanelDragOverlay {
  onDragTouch: (event: TouchEvent) => void = (event: TouchEvent): void => {
  };

  build() {
    Row()
      .width('100%')
      .height(LeafFns.readerCommentPanelDragHandleHeight())
      .backgroundColor('#00000000')
      .zIndex(50)
      .accessibilityText('上滑展开评论面板')
      .hitTestBehavior(HitTestMode.Block)
      .onTouch((event: TouchEvent) => {
        this.onDragTouch(event);
      })
  }
}

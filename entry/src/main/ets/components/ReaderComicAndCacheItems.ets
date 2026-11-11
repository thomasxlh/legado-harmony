import { ReaderCacheActionItem } from './ReaderSettingItems';
import { ReaderComicBoundaryHintContent } from './ReaderComicAndDialogItems';

/**
 * 漫画模式的交互层与边界提示，以及「缓存」弹窗的内容区。
 *
 * 三者原先都是 ReadBookPage 的 @Builder：交互层与边界提示只做手势转发，
 * 缓存弹窗只渲染四个动作行 + 状态文案，因此把值用 @Prop 传入、行为用回调传回，
 * 组件内部不持有 page 引用。
 */

@Component
export struct ReaderComicInteractionLayer {
  @Prop panDistance: number = 8;
  onLayerClick: () => void = (): void => {
  };
  onPanStart: () => void = (): void => {
  };
  onPanUpdate: (event: GestureEvent) => void = (): void => {
  };
  onPanEnd: (event: GestureEvent) => void = (): void => {
  };
  onPanCancel: () => void = (): void => {
  };

  build() {
    Blank()
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onLayerClick();
      })
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: this.panDistance })
          .onActionStart(() => {
            this.onPanStart();
          })
          .onActionUpdate((event: GestureEvent) => {
            this.onPanUpdate(event);
          })
          .onActionEnd((event: GestureEvent) => {
            this.onPanEnd(event);
          })
          .onActionCancel(() => {
            this.onPanCancel();
          })
      )
  }
}

@Component
export struct ReaderComicBoundaryHint {
  @Prop hintText: string = '';
  @Prop accentColor: string = '#3B82F6';
  @Prop textColor: string = '#18191C';
  @Prop dark: boolean = false;
  @Prop boundaryDirection: number = 0;
  @Prop pullDistance: number = 0;
  @Prop ready: boolean = false;
  @Prop chapterSwitching: boolean = false;
  @Prop topPadding: number = 0;

  build() {
    Column() {
      if (this.boundaryDirection < 0) {
        ReaderComicBoundaryHintContent({
          hintText: this.hintText,
          accentColor: this.accentColor,
          textColor: this.textColor,
          dark: this.dark,
          boundaryDirection: this.boundaryDirection,
          pullDistance: this.pullDistance,
          ready: this.ready,
          chapterSwitching: this.chapterSwitching
        })
      }
      Blank()
        .layoutWeight(1)
      if (this.boundaryDirection > 0) {
        ReaderComicBoundaryHintContent({
          hintText: this.hintText,
          accentColor: this.accentColor,
          textColor: this.textColor,
          dark: this.dark,
          boundaryDirection: this.boundaryDirection,
          pullDistance: this.pullDistance,
          ready: this.ready,
          chapterSwitching: this.chapterSwitching
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding, bottom: 54 })
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderCacheDialogContent {
  @Prop bookName: string = '';
  @Prop statusText: string = '';
  @Prop fullTextCaching: boolean = false;
  @Prop rangeCaching: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#6B7280';
  @Prop dangerColor: string = '#D94841';
  @Prop dark: boolean = false;
  onToggleFullTextCache: () => void = (): void => {
  };
  onCacheToLatest: () => void = (): void => {
  };
  onOpenChapterRange: () => void = (): void => {
  };
  onClearCachedChapters: () => void = (): void => {
  };
  onClose: () => void = (): void => {
  };

  build() {
    Column() {
      Text(`缓存《${this.bookName || '当前书籍'}》`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      if (this.statusText) {
        Text(this.statusText)
          .fontSize(13)
          .fontColor(this.subTextColor)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 8 })
      }

      ReaderCacheActionItem({
        label: this.fullTextCaching ? '取消缓存' : '缓存全文',
        disabled: this.rangeCaching,
        color: this.fullTextCaching ? this.dangerColor : '',
        dark: this.dark,
        textColor: this.textColor,
        action: (): void => {
          this.onToggleFullTextCache();
        }
      })
      ReaderCacheActionItem({
        label: '缓存当前章到最新章',
        disabled: this.fullTextCaching || this.rangeCaching,
        dark: this.dark,
        textColor: this.textColor,
        action: (): void => {
          this.onCacheToLatest();
        }
      })
      ReaderCacheActionItem({
        label: '缓存指定章节',
        disabled: this.fullTextCaching || this.rangeCaching,
        dark: this.dark,
        textColor: this.textColor,
        action: (): void => {
          this.onOpenChapterRange();
        }
      })
      ReaderCacheActionItem({
        label: '清除已缓存章节',
        disabled: this.fullTextCaching || this.rangeCaching,
        color: this.dangerColor,
        dark: this.dark,
        textColor: this.textColor,
        action: (): void => {
          this.onClearCachedChapters();
        }
      })

      Button('取消')
        .width('100%')
        .height(44)
        .margin({ top: 10 })
        .backgroundColor(this.dark ? '#24272D' : '#F5F5F5')
        .fontColor(this.textColor)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('calc(100% - 32vp)')
    .constraintSize({ maxWidth: 520 })
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
  }
}

import { BookChapter } from '../model/data/Book';
import { ReaderTocVirtualScrollbar } from './ReaderPanelChromeItems';

/**
 * 目录面板中的章节列表（102 行 @Builder）。
 *
 * 章节数据、当前章、排序版本、主题色全部走 @Prop / 参数；索引换算、标题、标题色、
 * 滚动条几何与跳转都回给页面（页面持有 tocGlobalIndex / getChapterTitle / tocOrderRevision
 * 等分页与排序状态），因此组件本身无任何阅读页状态。
 */
@Component
export struct ReaderTocChapterList {
  @Prop chapters: BookChapter[] = [];
  @Prop currentChapterIndex: number = 0;
  @Prop searchActive: boolean = false;
  @Prop orderRevision: number = 0;
  @Prop showCacheBadge: boolean = false;
  @Prop darkMode: boolean = false;
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#6B7280';
  @Prop accentColor: string = '#3B82F6';
  @Prop selectedBackgroundColor: string = '#14000000';
  @Prop cacheBadgeTextColor: string = '#7CC7A0';
  @Prop cacheBadgeBackgroundColor: string = '#24382F';
  @Prop dividerColor: string = '#1FFFFFFF';
  @Prop scrollbarVisible: boolean = false;
  @Prop scrollbarDragging: boolean = false;
  @Prop scrollbarThumbLength: number = 0;
  @Prop scrollbarThumbOffset: number = 0;
  @Prop viewportHeight: number = 0;
  scroller: Scroller = new Scroller();
  resolveGlobalIndex: (localIndex: number) => number = (localIndex: number): number => localIndex;
  chapterTitleOf: (globalIndex: number) => string = (globalIndex: number): string => '';
  titleColorOf: (chapter: BookChapter, globalIndex: number) => string = (): string => this.textColor;
  onSelectChapter: (globalIndex: number) => void = (): void => {
  };
  onListScrollIndex: (start: number, end: number) => void = (): void => {
  };
  onListReachStart: () => void = (): void => {
  };
  onListReachEnd: () => void = (): void => {
  };
  onListViewportChange: (height: number) => void = (): void => {
  };
  onThumbDragStart: (event: GestureEvent) => void = (): void => {
  };
  onThumbDragUpdate: (event: GestureEvent) => void = (): void => {
  };
  onThumbDragEnd: (event: GestureEvent) => void = (): void => {
  };
  onThumbDragCancel: () => void = (): void => {
  };
  onThumbTapJump: (event: GestureEvent) => void = (): void => {
  };

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      List({ space: 0, scroller: this.scroller }) {
        if (this.searchActive && this.chapters.length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(28)
                .fontColor([this.subTextColor])
              Text('未找到匹配章节')
                .fontSize(14)
                .fontColor(this.subTextColor)
            }
            .width('100%')
            .padding({ top: 44, bottom: 44 })
          }
        }
        ForEach(this.chapters, (chapter: BookChapter, localIndex: number) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(this.resolveGlobalIndex(localIndex) === this.currentChapterIndex ? '•' : '·')
                .fontSize(this.resolveGlobalIndex(localIndex) === this.currentChapterIndex ? 22 : 18)
                .fontColor(this.resolveGlobalIndex(localIndex) === this.currentChapterIndex ?
                  this.accentColor : this.subTextColor)
                .width(18)
                .textAlign(TextAlign.Center)

              Text(this.chapterTitleOf(this.resolveGlobalIndex(localIndex)))
                .fontSize(15)
                .fontWeight(this.resolveGlobalIndex(localIndex) === this.currentChapterIndex ?
                  FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.titleColorOf(chapter, this.resolveGlobalIndex(localIndex)))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (this.showCacheBadge && chapter.cacheDate > 0) {
                Text('已缓存')
                  .fontSize(12)
                  .fontColor(this.cacheBadgeTextColor)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(this.cacheBadgeBackgroundColor)
                  .borderRadius(10)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 16, top: 14, bottom: 14 })
            .backgroundColor(this.resolveGlobalIndex(localIndex) === this.currentChapterIndex ?
              this.selectedBackgroundColor : Color.Transparent)
            .border({ width: { bottom: 0.5 }, color: this.dividerColor })
            .onClick(() => {
              const targetChapterIndex = this.resolveGlobalIndex(localIndex);
              this.onSelectChapter(targetChapterIndex);
            })
          }
        }, (chapter: BookChapter, localIndex: number) =>
          `${this.orderRevision}_${this.resolveGlobalIndex(localIndex)}_${chapter.url || chapter.title}_${chapter.cacheDate > 0 ? 1 : 0}`)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onScrollIndex((start: number, end: number) => {
        this.onListScrollIndex(start, end);
      })
      .onReachStart(() => this.onListReachStart())
      .onReachEnd(() => this.onListReachEnd())

      if (this.scrollbarVisible) {
        ReaderTocVirtualScrollbar({
          darkMode: this.darkMode,
          viewportHeight: this.viewportHeight,
          dragging: this.scrollbarDragging,
          thumbLength: this.scrollbarThumbLength,
          thumbOffset: this.scrollbarThumbOffset,
          onThumbDragStart: (event: GestureEvent): void => {
            this.onThumbDragStart(event);
          },
          onThumbDragUpdate: (event: GestureEvent): void => {
            this.onThumbDragUpdate(event);
          },
          onThumbDragEnd: (event: GestureEvent): void => {
            this.onThumbDragEnd(event);
          },
          onThumbDragCancel: (): void => {
            this.onThumbDragCancel();
          },
          onTapJump: (event: GestureEvent): void => {
            this.onThumbTapJump(event);
          }
        })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.onListViewportChange(Number(newValue.height));
    })
  }
}

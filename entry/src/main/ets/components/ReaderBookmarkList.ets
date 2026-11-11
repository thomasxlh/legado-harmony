import deviceInfo from '@ohos.deviceInfo';
import { HdsListItem, HdsSwipeActionOptions } from '@kit.UIDesignKit';
import { Bookmark } from '../model/data/Book';
import { ReaderBookmarkSwipeCard } from './ReaderPageFrameItems';
import { ReaderBookmarkDeleteAction, ReaderBookmarkMultiSelectAction } from './ReaderStaticItems';

/**
 * 目录面板中的书签列表（89 行 @Builder + 17 行旧系统侧滑兜底）。
 *
 * 书签数据与选中 URL 集走 @Prop；跳转/多选切换/长按浮层/删除全部以回调交还页面。
 * API 26+ 走 HdsListItem 单侧滑面板，旧系统走原生 ListItem + swipeAction 兜底，
 * 兜底面板（多选/删除双按钮）随本组件内聚，页面不再感知系统分支。
 */
@Component
export struct ReaderBookmarkList {
  @Prop bookmarks: Bookmark[] = [];
  @Prop selectedUrls: string[] = [];
  @Prop accentColor: string = '#3B82F6';
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#6B7280';
  @Prop selectedBackgroundColor: string = '#14000000';
  @Prop dividerColor: string = '#1FFFFFFF';
  @Prop scrollBarColor: string = '#66808080';
  scroller: ListScroller = new ListScroller();
  swipeActionsOf: (bookmark: Bookmark) => HdsSwipeActionOptions =
    (): HdsSwipeActionOptions => ({ icons: [] });
  onPrimaryAction: (bookmark: Bookmark) => void = (): void => {
  };
  onLongPressAction: (bookmark: Bookmark, event: GestureEvent) => void = (): void => {
  };
  onDeleteBookmark: (bookmark: Bookmark) => void = (): void => {
  };
  onEnterMultiSelect: (bookmarkUrl: string) => void = (): void => {
  };

  private isBookmarkSelected(bookmarkUrl: string): boolean {
    return this.selectedUrls.indexOf(bookmarkUrl) >= 0;
  }

  @Builder
  private bookmarkSwipeCard(bookmark: Bookmark) {
    ReaderBookmarkSwipeCard({
      bookmark: bookmark,
      selected: this.isBookmarkSelected(bookmark.bookmarkUrl),
      accentColor: this.accentColor,
      textColor: this.textColor,
      subTextColor: this.subTextColor,
      selectedBackgroundColor: this.selectedBackgroundColor,
      dividerColor: this.dividerColor,
      onPrimaryAction: (): void => {
        this.onPrimaryAction(bookmark);
      },
      onLongPressAction: (event: GestureEvent): void => {
        this.onLongPressAction(bookmark, event);
      }
    })
  }

  @Builder
  private bookmarkFallbackSwipeActions(bookmark: Bookmark) {
    Row() {
      ReaderBookmarkMultiSelectAction({
        accent: this.accentColor,
        onClickAction: (): void => {
          this.onEnterMultiSelect(bookmark.bookmarkUrl);
        }
      })
      ReaderBookmarkDeleteAction({
        onClickAction: (): void => {
          this.onDeleteBookmark(bookmark);
        }
      })
    }
    .height('100%')
  }

  build() {
    if (this.bookmarks.length === 0) {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bookmark'))
          .fontSize(34)
          .fontColor([this.subTextColor])
        Text('暂无书签')
          .fontSize(15)
          .fontColor(this.subTextColor)
        Text('可使用底栏最右侧按钮添加当前阅读位置')
          .fontSize(12)
          .fontColor(this.subTextColor)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List({ space: 0, scroller: this.scroller }) {
        ForEach(this.bookmarks, (bookmark: Bookmark) => {
          if (deviceInfo.sdkApiVersion >= 26) {
            // API 26+ uses one left-swipe action panel. Keep multi-select and
            // delete together instead of exposing multi-select on right swipe.
            HdsListItem({
              customItemBuilder: () => {
                this.bookmarkSwipeCard(bookmark)
              },
              swipeActionOptions: this.swipeActionsOf(bookmark)
            })
          } else {
            // Older systems use the native ListItem fallback with the same
            // two-button left-swipe action panel.
            ListItem() {
              this.bookmarkSwipeCard(bookmark)
            }
            .width('100%')
            .clip(true)
            .swipeAction({
              end: {
                builder: () => {
                  this.bookmarkFallbackSwipeActions(bookmark)
                },
                actionAreaDistance: 128,
                onAction: () => this.onDeleteBookmark(bookmark)
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }
        }, (bookmark: Bookmark) => `${bookmark.bookmarkUrl}`)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .layoutWeight(1)
      .width('100%')
      .clip(true)
      .scrollBar(BarState.Auto)
      .scrollBarColor(this.scrollBarColor)
    }
  }
}

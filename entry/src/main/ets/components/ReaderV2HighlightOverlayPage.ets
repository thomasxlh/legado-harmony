import { ReaderV2HighlightRect } from '../core/reader/ReaderPageModels';
import { ReaderV2PageHighlightOverlay } from './ReaderV2PageHighlightOverlay';
import { READER_DOUBLE_PAGE_DIVIDER_WIDTH } from '../reader/ReaderConstants';

/**
 * V2 正文的整页高亮层（含双页拆分）。
 *
 * 原 `readerCurrentV2SelectionOverlay` / `readerCurrentV2TtsOverlay` 两个 @Builder 只差
 * 「矩形数据来源 + 底色组件」，其余（双页拆分、分隔条、顶部内边距、翻页位移、透明度）
 * 完全一致，因此合并为一个组件，用 kind 选择底色组件。矩形数组由页面算好后传入。
 */
@Component
export struct ReaderV2HighlightOverlayPage {
  @Prop currentRects: ReaderV2HighlightRect[] = [];
  @Prop secondaryRects: ReaderV2HighlightRect[] = [];
  @Prop doublePage: boolean = false;
  @Prop columnWidth: number = 0;
  @Prop contentTopPadding: number = 0;
  @Prop translateX: number = 0;
  @Prop translateY: number = 0;
  @Prop layerOpacity: number = 1;
  @Prop kind: string = 'tts';

  build() {
    Column() {
      if (this.doublePage) {
        Row() {
          ReaderV2PageHighlightOverlay({
            rects: this.currentRects,
            halfWidth: true,
            columnWidth: this.columnWidth,
            kind: this.kind
          })
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('100%')
          ReaderV2PageHighlightOverlay({
            rects: this.secondaryRects,
            halfWidth: true,
            columnWidth: this.columnWidth,
            kind: this.kind
          })
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        ReaderV2PageHighlightOverlay({
          rects: this.currentRects,
          columnWidth: this.columnWidth,
          kind: this.kind
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.contentTopPadding })
    .translate({ x: this.translateX, y: this.translateY })
    .opacity(this.layerOpacity)
    .hitTestBehavior(HitTestMode.None)
  }
}

import { ReaderV2HighlightRect } from '../core/reader/ReaderPageModels';
import { ReaderV2TtsHighlightRect, ReaderV2SelectionHighlightRect } from './ReaderV2HighlightRects';

/**
 * V2 正文的逐句高亮 / 选区高亮矩形层（单页）。
 *
 * 两处原 @Builder 只差「用哪套矩形数据 + 用哪种底色组件」，其余完全一致，
 * 因此合并成一个组件，用 kind 决定渲染哪个矩形组件。矩形数组由页面算好传入，
 * 半页宽度也由页面按双页/单页算好。
 */
@Component
export struct ReaderV2PageHighlightOverlay {
  @Prop rects: ReaderV2HighlightRect[] = [];
  @Prop halfWidth: boolean = false;
  @Prop columnWidth: number = 0;
  @Prop kind: string = 'tts';

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.rects, (rect: ReaderV2HighlightRect) => {
        if (this.kind === 'selection') {
          ReaderV2SelectionHighlightRect({
            rectLeftPx: rect.leftPx,
            rectTopPx: rect.topPx,
            rectWidthPx: rect.widthPx,
            rectHeightPx: rect.heightPx
          })
        } else {
          ReaderV2TtsHighlightRect({
            rectLeftPx: rect.leftPx,
            rectTopPx: rect.topPx,
            rectWidthPx: rect.widthPx,
            rectHeightPx: rect.heightPx
          })
        }
      }, (rect: ReaderV2HighlightRect) => rect.key)
    }
    .width(this.halfWidth ? this.columnWidth : '100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}

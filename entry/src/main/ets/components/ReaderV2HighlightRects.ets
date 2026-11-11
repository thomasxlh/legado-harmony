/**
 * V2 分页的 TTS 逐句高亮色块。
 *
 * 原先为 ReadBookPage 里的 @Builder，只读传入的 rect，不碰 `this`；
 * 提成 @Component 后由调用方把 rect 拆成 4 个标量 @Prop 传入——
 * 标量 @Prop 走值同步，不会因对象整体替换而重建子树。
 */
@Component
export struct ReaderV2TtsHighlightRect {
  @Prop rectLeftPx: number = 0;
  @Prop rectTopPx: number = 0;
  @Prop rectWidthPx: number = 0;
  @Prop rectHeightPx: number = 0;

  build() {
    Row() {
    }
    .width(px2vp(this.rectWidthPx))
    .height(px2vp(this.rectHeightPx))
    .backgroundColor(0x55FFE58A)
    .position({ x: px2vp(this.rectLeftPx), y: px2vp(this.rectTopPx) })
    .zIndex(1)
    .hitTestBehavior(HitTestMode.None)
  }
}

/**
 * V2 分页的选区高亮色块。与 TTS 高亮同构，仅颜色与 zIndex 不同。
 */
@Component
export struct ReaderV2SelectionHighlightRect {
  @Prop rectLeftPx: number = 0;
  @Prop rectTopPx: number = 0;
  @Prop rectWidthPx: number = 0;
  @Prop rectHeightPx: number = 0;

  build() {
    Row() {
    }
    .width(px2vp(this.rectWidthPx))
    .height(px2vp(this.rectHeightPx))
    .backgroundColor(0x663B82F6)
    .position({ x: px2vp(this.rectLeftPx), y: px2vp(this.rectTopPx) })
    .zIndex(2)
    .hitTestBehavior(HitTestMode.None)
  }
}

/**
 * 仿真翻页的半页纸张底纹：从一整幅主题背景里裁出左/右半边。
 *
 * 与前面几批一致：组件不持有 page 引用，尺寸/主题值全部由调用点传入。
 */
import { ReaderThemeBackground } from './ReaderThemeBackground';

@Component
export struct ReaderSimulationHalfPaperBackground {
  @Prop rightHalf: boolean = false;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop backgroundAssetId: string = '';
  @Prop customImage: ResourceStr = '';
  @Prop customImageFit: ImageFit = ImageFit.Cover;
  @Prop viewportWidthHint: number = 0;
  @Prop viewportHeightHint: number = 0;
  @Prop rightOrigin: number = 0;

  build() {
    Stack() {
      ReaderThemeBackground({
        surfaceColor: this.surfaceColor,
        backgroundAssetId: this.backgroundAssetId,
        customImage: this.customImage,
        customImageFit: this.customImageFit,
        viewportWidthHint: this.viewportWidthHint,
        viewportHeightHint: this.viewportHeightHint
      })
        .width(this.viewportWidthHint)
        .height('100%')
        .position({ x: this.rightHalf ? -this.rightOrigin : 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}

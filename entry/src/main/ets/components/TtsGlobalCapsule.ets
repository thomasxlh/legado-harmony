import { ReaderTtsFloatingSession } from '../utils/ReaderTtsFloatingSession';
import { ThemeRuntime } from '../theme/ThemeRuntime';

/**
 * 全局朗读浮标胶囊：阅读页、书架等宿主共用同一组件，保证展示与交互一致。
 * 布局：左侧圆形播放/暂停按钮 + 状态文本（点击打开朗读目录）+ 可选“回到阅读页”
 * 书本按钮（仅非当前朗读页展示）+ 关闭按钮。播放/暂停与停止统一走
 * ReaderTtsFloatingSession 路由到当前会话宿主。
 */
@Component
export struct TtsGlobalCapsule {
  @Prop darkMode: boolean = false;
  @Prop accentColor: string = '#007DFF';
  @Prop showOpenReader: boolean = true;
  @Prop viewportWidth: number = 360;
  @Prop viewportHeight: number = 720;
  @Prop topInset: number = 0;
  @Prop bottomInset: number = 0;
  @StorageLink('globalTtsPaused') paused: boolean = false;
  @StorageLink('globalTtsMode') mode: string = '';
  @StorageLink('globalTtsChapterProgress') chapterProgress: string = '';
  @StorageLink('globalTtsCapsulePositionX') positionX: number = 16;
  @StorageLink('globalTtsCapsulePositionY') positionY: number = -1;
  onOpenCatalog: () => void = () => {};
  onOpenReader: () => void = () => {};
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;

  capsuleWidth(): number {
    return this.showOpenReader ? 184 : 150;
  }

  capsuleLeft(): number {
    const minLeft = 8;
    const maxLeft = Math.max(minLeft, this.viewportWidth - this.capsuleWidth() - 8);
    return Math.max(minLeft, Math.min(this.positionX, maxLeft));
  }

  capsuleTop(): number {
    const defaultTop = this.viewportHeight - this.bottomInset - 118;
    const minTop = this.topInset + 8;
    const maxTop = Math.max(minTop, this.viewportHeight - this.bottomInset - 110);
    return Math.max(minTop, Math.min(this.positionY < 0 ? defaultTop : this.positionY, maxTop));
  }

  capsuleTransition(): TransitionEffect {
    const appear = TransitionEffect.scale({ x: 0.84, y: 0.84, centerX: '50%', centerY: '50%' })
      .combine(TransitionEffect.opacity(0))
      .animation({ duration: 240, curve: Curve.Friction });
    const disappear = TransitionEffect.scale({ x: 0.9, y: 0.9, centerX: '50%', centerY: '50%' })
      .combine(TransitionEffect.opacity(0))
      .animation({ duration: 170, curve: Curve.EaseIn });
    return TransitionEffect.asymmetric(appear, disappear);
  }

  build() {
    Row({ space: 7 }) {
      Row({ space: 7 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle().width(30).height(30).fill(this.accentColor)
          SymbolGlyph(this.paused ? $r('sys.symbol.play') : $r('sys.symbol.pause'))
            .fontSize(14)
            .fontColor(['#FFFFFF'])
        }
        .onClick(() => {
          ReaderTtsFloatingSession.toggle().catch((error: Error) => {
            console.warn('切换朗读播放状态失败:', error);
          });
        })
        Column({ space: 1 }) {
          Text(this.paused ? '已暂停' : (this.mode === 'audio' ? '听书中' : '朗读中'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeRuntime.primaryTextColor(this.darkMode))
          Text(this.chapterProgress || (this.mode === 'audio' ? '后台听书' : '后台朗读'))
            .fontSize(11)
            .fontColor(ThemeRuntime.subTextColor(this.darkMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => this.onOpenCatalog())
      if (this.showOpenReader) {
        SymbolGlyph($r('sys.symbol.book'))
          .fontSize(16)
          .fontColor([ThemeRuntime.primaryTextColor(this.darkMode)])
          .width(28)
          .height(34)
          .onClick(() => this.onOpenReader())
      }
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(14)
        .fontColor([ThemeRuntime.subTextColor(this.darkMode)])
        .width(24)
        .height(34)
        .onClick(() => ReaderTtsFloatingSession.stop())
    }
    .width(this.capsuleWidth())
    .height(46)
    .padding({ left: 8, right: 5 })
    .borderRadius(23)
    .clip(true)
    .backgroundColor(ThemeRuntime.cardColor(this.darkMode))
    .border({ width: 0.5, color: this.darkMode ? '#30FFFFFF' : '#18000000' })
    .shadow({ radius: 18, color: this.darkMode ? '#50000000' : '#26000000', offsetY: 6 })
    .position({ x: 0, y: 0 })
    .translate({
      x: this.capsuleLeft(),
      y: this.capsuleTop()
    })
    .parallelGesture(
      PanGesture({ direction: PanDirection.All, distance: 4 })
        .onActionStart(() => {
          this.dragOriginX = this.capsuleLeft();
          this.dragOriginY = this.capsuleTop();
        })
        .onActionUpdate((event: GestureEvent) => {
          this.positionX = this.dragOriginX + event.offsetX;
          this.positionY = this.dragOriginY + event.offsetY;
        })
    )
    .transition(this.capsuleTransition())
  }
}

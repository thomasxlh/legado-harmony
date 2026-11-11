import { webview } from '@kit.ArkWeb';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ReaderCommentPanelDragHandle } from './ReaderStaticItems';
import { ReaderCommentPanelDragOverlay } from './ReaderMenuItems';
import * as LeafFns from '../reader/ReaderLeafFns';

/**
 * 段评面板：遮罩 + 拖拽把手 + Web 评论页 + 加载态 + 拖拽热区。
 *
 * 原先 82 行 @Builder、读 15 个页面状态。提取后 Web 控制器由页面传入，
 * 加载/重试时机仍由页面决定（onControllerAttached / onPageBegin / onPageEnd 三个回调）。
 */
@Component
export struct ReaderCommentPanel {
  @Prop panelUrl: string = '';
  @Prop panelHeightValue: number = 0;
  @Prop contentHeight: number = 0;
  @Prop loading: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  @Prop textColor: string = '#18191C';
  @Prop accentColor: string = '#3B82F6';
  @Prop darkMode: boolean = false;
  @Prop appDarkMode: boolean = false;
  @Prop scrimColor: string = '#26000000';
  controller: webview.WebviewController | null = null;
  onClose: () => void = (): void => {
  };
  onDragTouch: (event: TouchEvent) => void = (event: TouchEvent): void => {
  };
  onControllerAttached: () => void = (): void => {
  };
  onPageBegin: () => void = (): void => {
  };
  onPageEnd: () => void = (): void => {
  };

  build() {
    Column() {
      Row()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.scrimColor)
        .onClick(() => {
          this.onClose();
        })

      Stack() {
        Column() {
          ReaderCommentPanelDragHandle({
            dark: this.darkMode,
            handleHeight: LeafFns.readerCommentPanelDragHandleHeight()
          })
          Stack() {
            Web({ src: this.panelUrl, controller: this.controller })
              .width('100%')
              .height(Math.max(1, this.panelHeightValue - LeafFns.readerCommentPanelDragHandleHeight()))
              .monopolizeEvents(true)
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .onlineImageAccess(true)
              .imageAccess(true)
              .darkMode(this.appDarkMode ? WebDarkMode.On : WebDarkMode.Off)
              .forceDarkAccess(this.appDarkMode)
              .onControllerAttached(() => {
                this.onControllerAttached();
              })
              .onPageBegin(() => {
                this.onPageBegin();
              })
              .onPageEnd(() => {
                this.onPageEnd();
              })

            if (this.loading) {
              Column({ space: 10 }) {
                LoadingProgress()
                  .width(38)
                  .height(38)
                  .color(this.accentColor)
                Text('评论加载中…')
                  .fontSize(13)
                  .fontColor(this.textColor)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.panelColor)
            }
          }
          .width('100%')
          .height(this.contentHeight)
          .backgroundColor(this.panelColor)
          .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
          .borderRadius({
            topLeft: ThemeRuntime.glassCornerRadius(28, 'panel'),
            topRight: ThemeRuntime.glassCornerRadius(28, 'panel')
          })
          .clip(true)
        }
        .width('100%')
        .backgroundColor('#00000000')
        .height(this.panelHeightValue)

        ReaderCommentPanelDragOverlay({
          onDragTouch: (event: TouchEvent): void => {
            this.onDragTouch(event);
          }
        })
      }
      .width('100%')
      .height(this.panelHeightValue)
      .alignContent(Alignment.Top)
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 阅读页的两层「点击空白处关闭」蒙层。
 *
 * 原先都是 ReadBookPage 的 @Builder，各自只碰 1~2 个成员方法
 * （hideReaderPanels / closeSettingsPanelKeepMenu / readerSettingsPanelHeight）。
 * 这里把「要做什么」改成回调、把「面板高度」改成 @Prop 传进来，
 * 组件本身不再持有任何阅读页状态，因此不存在被切断的 V1 隐式联动。
 */

@Component
export struct ReaderMenuDismissLayer {
  onDismiss: () => void = (): void => {
  };

  build() {
    Blank()
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onDismiss();
      })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionStart(() => {
            this.onDismiss();
          })
      )
  }
}

@Component
export struct ReaderSettingsDismissLayer {
  @Prop panelHeight: number = 0;
  onDismiss: () => void = (): void => {
  };

  build() {
    Column() {
      Blank()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => {
          this.onDismiss();
        })
      Blank()
        .width('100%')
        .height(this.panelHeight)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

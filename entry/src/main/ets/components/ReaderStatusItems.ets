/**
 * 阅读页状态类小块：加载中面板、漫画解析进度、书签下拉提示、朗读定时按钮、
 * 正文内「打开」书源动作按钮、正则气泡左右端帽。
 *
 * 与前面几批一致：颜色/文案/进度这类**值**用 @Prop 传，交互用回调传，
 * 组件内部不持有 page 引用。
 */
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ReaderActionMarker } from '../core/book/ReaderActionMarker';

@Component
export struct ReaderLoadingPanel {
  @Prop accentColor: string = '#2F6BFF';
  @Prop panelColor: ResourceColor = '#FFFFFF';
  @Prop loadingText: string = '正在加载';
  @Prop dark: boolean = false;
  @Prop slow: boolean = false;
  onCancel: () => void = (): void => {};

  build() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.accentColor)
      Text(this.loadingText)
        .fontSize(14)
        .fontColor(this.dark ? '#AEB4BE' : '#777777')
        .margin({ top: 10 })
      if (this.slow) {
        Text('等待时间较长？可停止等待后换源或重试')
          .fontSize(12)
          .fontColor(this.dark ? '#858B94' : '#999999')
          .margin({ top: 18 })
        Button('不再等待')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.accentColor)
          .borderRadius(16)
          .height(32)
          .padding({ left: 18, right: 18 })
          .margin({ top: 10 })
          .onClick((): void => this.onCancel())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.panelColor)
  }
}

@Component
export struct ReaderComicPaginationPanel {
  @Prop accentColor: string = '#2F6BFF';
  @Prop panelColor: ResourceColor = '#FFFFFF';
  @Prop textColor: string = '#000000';
  @Prop dark: boolean = false;
  @Prop parsedPages: number = 0;
  @Prop totalPages: number = 0;

  build() {
    Column({ space: 10 }) {
      LoadingProgress()
        .width(44)
        .height(44)
        .color(this.accentColor)
      Text('正在解析漫画')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
      Text(`已解析 ${this.parsedPages} / ${this.totalPages} 页`)
        .fontSize(13)
        .fontColor(this.dark ? '#AEB4BE' : '#777777')
      Progress({
        value: this.parsedPages,
        total: Math.max(1, this.totalPages),
        type: ProgressType.Linear
      })
        .width(196)
        .height(4)
        .color(this.accentColor)
        .backgroundColor(this.dark ? '#3A3D43' : '#DDD8D0')
      Text('解析完成后自动开始阅读')
        .fontSize(12)
        .fontColor(this.dark ? '#858B94' : '#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.panelColor)
  }
}

@Component
export struct ReaderBookmarkPullHint {
  @Prop hintText: string = '';
  @Prop hintColor: string = '#000000';
  @Prop ready: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  @Prop glassBorderColor: string = '#00000000';
  @Prop shadowColor: string = '#00000000';
  @Prop topSafePadding: number = 0;
  @Prop pullOffsetY: number = 0;

  build() {
    Row() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.bookmark'))
          .fontSize(19)
          .fontColor([this.hintColor])
        Text(this.hintText)
          .fontSize(14)
          .fontWeight(this.ready ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.hintColor)
      }
      .height(40)
      .padding({ left: 14, right: 14 })
      .borderRadius(20)
      .backgroundColor(this.panelColor)
      .border({ width: ThemeRuntime.glassBorderWidth(), color: this.glassBorderColor })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius(),
        color: this.shadowColor,
        offsetX: ThemeRuntime.glassShadowOffsetX(),
        offsetY: ThemeRuntime.glassShadowOffsetY()
      })
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: 0 })
    .translate({ y: this.topSafePadding + 8 })
    .opacity(Math.min(1, this.pullOffsetY / 36))
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderTtsTimerControl {
  @Prop timerMinutes: number = 0;
  @Prop remainingSeconds: number = 0;
  @Prop textColor: string = '#000000';
  @Prop accentColor: string = '#2F6BFF';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.timer'))
        .fontSize(22)
        .fontColor([this.textColor])

      if (this.timerMinutes > 0) {
        Text(`${this.remainingMinutes()}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(16)
          .height(16)
          .borderRadius(8)
          .backgroundColor(this.accentColor)
          .position({ x: 25, y: 2 })
      }
    }
    .width('100%')
    .height(48)
    .accessibilityText(this.timerMinutes > 0 ?
      `朗读定时剩余 ${this.remainingMinutes()} 分钟` : '设置朗读定时')
    .translate({ y: -2 })
  }

  private remainingMinutes(): number {
    return Math.max(1, Math.ceil(this.remainingSeconds / 60));
  }
}

@Component
export struct ReaderSourceActionButton {
  @Prop marker: string = '';
  @Prop textColor: string = '#000000';
  @Prop fontSize: number = 16;
  @Prop label: string = '打开';
  onAreaChanged: (area: Area) => void = (): void => {};
  onActivate: () => void = (): void => {};

  build() {
    Row({ space: 5 }) {
      SymbolGlyph($r('sys.symbol.arrow_right_up_and_square'))
        .fontSize(13)
        .fontColor([this.textColor])
      Text(this.label)
        .fontSize(Math.max(11, this.fontSize - 3))
        .fontColor(this.textColor)
        .maxLines(1)
    }
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .border({ width: 1, color: this.textColor })
    .borderRadius(14)
    .opacity(0.72)
    .hitTestBehavior(HitTestMode.Block)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.onAreaChanged(newValue);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down || event.type === TouchType.Move || event.type === TouchType.Up) {
        this.onActivate();
      }
    })
    .onClick(() => {
      this.onActivate();
    })
    .priorityGesture(
      TapGesture().onAction(() => {
        this.onActivate();
      }),
      GestureMask.IgnoreInternal
    )
    .monopolizeEvents(true)
  }
}

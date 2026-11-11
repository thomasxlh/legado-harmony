/**
 * 阅读页框架类小块：底部信息栏、顶部悬浮菜单、目录虚拟滚动条、书签面板摘要、
 * 预缓存设置行。
 *
 * 与前面几批一致：颜色/文案/开关/进度这类**值**用 @Prop 传，交互用回调传，
 * 组件内部不持有 page 引用（探针已证明持有 page 引用不会建立 ArkUI V1 依赖）。
 */
import { AdaptiveSwitch } from './AdaptiveSwitch';
import { ImmersiveBackButton } from './ImmersiveBackButton';
import { ReaderRoundMenuButton } from './ReaderSettingItems';
import { ReaderSelectSettingItem } from './ReaderSettingsRows';
import * as LeafFns from '../reader/ReaderLeafFns';

@Component
export struct ReaderBottomInfoBar {
  @Prop accentColor: string = '#2F6BFF';
  @Prop trackColor: string = '#E5E7EB';
  @Prop subTextColor: string = '#888888';
  @Prop showProgressBar: boolean = false;
  @Prop progressValue: number = 0;
  @Prop leftText: string = '';
  @Prop progressText: string = '';
  @Prop visualOffsetY: number = 0;
  onHeightChange: (area: Area) => void = (area: Area): void => {
  };

  build() {
    Column({ space: 3 }) {
      if (this.showProgressBar) {
        Progress({ value: this.progressValue, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color(this.accentColor)
          .backgroundColor(this.trackColor)
      }
      Row() {
        if (this.leftText) {
          Text(this.leftText)
            .fontSize(12)
            .fontColor(this.subTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        } else {
          Blank().layoutWeight(1)
        }

        if (this.progressText) {
          Text(this.progressText)
            .fontSize(12)
            .fontColor(this.subTextColor)
            .textAlign(TextAlign.End)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 12 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 28, right: 28, top: 0, bottom: 0 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
    .translate({ y: this.visualOffsetY })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.onHeightChange(newValue);
    })
  }
}

@Component
export struct ReaderFloatingTopMenu {
  @Prop iconColor: string = '#18191C';
  @Prop darkMode: boolean = false;
  @Prop safeTopPadding: number = 0;
  @Prop canRefreshChapter: boolean = false;
  @Prop canChangeSource: boolean = false;
  onBack: () => void = (): void => {
  };
  onRefreshChapter: () => void = (): void => {
  };
  onChangeSource: () => void = (): void => {
  };
  onToggleActionMenu: () => void = (): void => {
  };

  build() {
    Row() {
      ImmersiveBackButton({
        iconColor: this.iconColor,
        darkMode: this.darkMode,
        buttonSize: 40,
        containerWidth: 40,
        containerHeight: 56,
        startInset: 0,
        materialScale: 0.83,
        compactLayout: true,
        onBack: () => this.onBack()
      })

      Blank()
        .layoutWeight(1)

      Row({ space: 6 }) {
        if (this.canRefreshChapter) {
          ReaderRoundMenuButton({
            icon: $r('sys.symbol.arrow_clockwise'),
            accessibilityLabel: '刷新本章',
            onBack: () => {
              this.onRefreshChapter();
            },
            iconColor: this.iconColor,
            darkMode: this.darkMode
          })
        }
        if (this.canChangeSource) {
          ReaderRoundMenuButton({
            icon: $r('sys.symbol.arrow_left_arrow_right'),
            accessibilityLabel: '换源',
            onBack: () => {
              this.onChangeSource();
            },
            iconColor: this.iconColor,
            darkMode: this.darkMode
          })
        }
        ReaderRoundMenuButton({
          icon: $r('sys.symbol.more'),
          accessibilityLabel: '更多操作',
          onBack: () => {
            this.onToggleActionMenu();
          },
          iconColor: this.iconColor,
          darkMode: this.darkMode
        })
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: this.safeTopPadding + 10 })
    .position({ x: 0, y: 0 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct ReaderTocVirtualScrollbar {
  @Prop darkMode: boolean = false;
  @Prop viewportHeight: number = 0;
  @Prop dragging: boolean = false;
  @Prop thumbLength: number = 0;
  @Prop thumbOffset: number = 0;
  onThumbDragStart: (event: GestureEvent) => void = (event: GestureEvent): void => {
  };
  onThumbDragUpdate: (event: GestureEvent) => void = (event: GestureEvent): void => {
  };
  onThumbDragEnd: (event: GestureEvent) => void = (event: GestureEvent): void => {
  };
  onThumbDragCancel: () => void = (): void => {
  };
  onTapJump: (event: GestureEvent) => void = (event: GestureEvent): void => {
  };

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column()
        .width(3)
        .height(this.viewportHeight)
        .borderRadius(2)
        .backgroundColor(this.darkMode ? '#18FFFFFF' : '#14000000')
        .margin({ right: 3 })
        .hitTestBehavior(HitTestMode.None)
      Column()
        .width(this.dragging ? 6 : 4)
        .height(this.thumbLength)
        .borderRadius(3)
        .backgroundColor(this.darkMode ? '#BFD5D8DE' : '#A87A6F63')
        .margin({ right: 2 })
        .translate({ y: this.thumbOffset })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(24)
    .height(this.viewportHeight)
    .zIndex(10)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture({ direction: PanDirection.Vertical, distance: 1 })
          .onActionStart((event: GestureEvent) => this.onThumbDragStart(event))
          .onActionUpdate((event: GestureEvent) => this.onThumbDragUpdate(event))
          .onActionEnd((event: GestureEvent) => this.onThumbDragEnd(event))
          .onActionCancel(() => this.onThumbDragCancel()),
        TapGesture().onAction((event: GestureEvent) => this.onTapJump(event))
      )
    )
  }
}

@Component
export struct ReaderBookmarkPanelSummary {
  @Prop multiSelectMode: boolean = false;
  @Prop selectedCount: number = 0;
  @Prop totalCount: number = 0;
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#888888';
  @Prop accentColor: string = '#2F6BFF';
  @Prop dangerColor: string = '#D94841';
  onToggleSelectAll: () => void = (): void => {
  };
  onDeleteSelected: () => void = (): void => {
  };
  onCancelMultiSelect: () => void = (): void => {
  };

  build() {
    if (this.multiSelectMode) {
      Row({ space: 16 }) {
        Text(`已选 ${this.selectedCount} 项`)
          .fontSize(14)
          .fontColor(this.textColor)
          .layoutWeight(1)
        Text(this.selectedCount === this.totalCount ? '取消全选' : '全选')
          .fontSize(13)
          .fontColor(this.accentColor)
          .onClick(() => {
            this.onToggleSelectAll();
          })
        Text('删除')
          .fontSize(13)
          .fontColor(this.selectedCount > 0 ? this.dangerColor : this.subTextColor)
          .enabled(this.selectedCount > 0)
          .onClick(() => {
            this.onDeleteSelected();
          })
        Text('取消')
          .fontSize(13)
          .fontColor(this.subTextColor)
          .onClick(() => {
            this.onCancelMultiSelect();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)
    } else {
      Row() {
        Text(`${this.totalCount} 条书签`)
          .fontSize(14)
          .fontColor(this.subTextColor)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 10 })
    }
  }
}

@Component
export struct ReaderPreloadSettingItem {
  @Prop preloadEnabled: boolean = false;
  @Prop preloadChapterCount: number = 3;
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#888888';
  @Prop accentColor: string = '#2F6BFF';
  @Prop switchColor: string = '#2F6BFF';
  @Prop darkMode: boolean = false;
  @Prop panelColor: string = '#FFFFFF';
  onToggleEnabled: (enabled: boolean) => void = (enabled: boolean): void => {
  };
  onSelectChapterCount: (count: number) => void = (count: number): void => {
  };

  build() {
    // Keep the dependent chapter-count selector separated from the toggle by the
    // same spacing used between the other reading settings.
    Column({ space: 14 }) {
      Row() {
        Column() {
          Text('预缓存设置')
            .fontSize(15)
            .fontColor(this.textColor)
          Text(this.preloadEnabled ? '阅读过程中提前缓存后续章节' : '已关闭自动预缓存')
            .fontSize(12)
            .fontColor(this.subTextColor)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AdaptiveSwitch({
          isOn: this.preloadEnabled,
          selectedColor: this.switchColor,
          onChange: (value: boolean) => {
            this.onToggleEnabled(value);
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.preloadEnabled) {
        ReaderSelectSettingItem({
          title: '下一章节数',
          description: '选择自动预缓存的后续章节数量',
          options: LeafFns.readerPreloadChapterOptions(),
          selected: this.preloadChapterCount - 1,
          controlId: 'reader_preload_chapter_count_select',
          textColor: this.textColor,
          subTextColor: this.subTextColor,
          accentColor: this.accentColor,
          darkMode: this.darkMode,
          panelColor: this.panelColor,
          onSelect: (index: number) => this.onSelectChapterCount(index + 1)
        })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
  }
}
@Component
export struct ReaderTtsQuickActionButton {
  @Prop iconColor: ResourceColor;
  @Prop accentColor: ResourceColor;
  @Prop surfaceColor: ResourceColor;
  @Prop darkMode: boolean = false;
  @Prop speaking: boolean = false;
  @Prop offsetX: number = 0;
  @Prop offsetY: number = 0;
  onActivate: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ImmersiveBackButton({
        icon: $r('sys.symbol.play'),
        iconOffsetX: 0,
        iconColor: this.iconColor,
        darkMode: this.darkMode,
        buttonSize: 48,
        containerWidth: 48,
        containerHeight: 48,
        startInset: 0,
        compactLayout: true,
        accessibilityLabel: '开始朗读',
        onBack: () => {
          this.onActivate();
        }
      })
      if (this.speaking) {
        Circle()
          .width(9)
          .height(9)
          .fill(this.accentColor)
          .stroke(this.surfaceColor)
          .strokeWidth(2)
          .position({ x: 38, y: 3 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(48)
    .height(48)
    .position({ x: this.offsetX, y: '100%' })
    .translate({ y: this.offsetY })
  }
}

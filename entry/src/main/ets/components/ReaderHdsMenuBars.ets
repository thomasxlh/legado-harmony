import { HdsTabs } from '@kit.UIDesignKit';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';
import { ReaderChapterSliderBar } from './ReaderPanelChromeItems';
import { ReaderHdsMenuItem } from './ReaderMenuItems';
import { ReaderHdsDayNightMenuItem } from './ReaderPageFrameItems';

/**
 * HDS 沉浸材质菜单栏族（7 个 @Builder，约 200 行）拆分为两个组件。
 *
 * ReaderHdsBottomMenu：正文菜单态的浮动底栏 = 章节快捷跳转条（可选）+ 操作页签栏；
 * ReaderHdsFloatingActionBar：目录/设置面板打开时的独立浮动操作页签栏。
 *
 * 页签项仅是图标占位（目录/设置/排版/日夜），真实动作经 onTabBarClick /
 * onDayNightActivate 回调交还页面分发；材质参数（materialType/Level）由
 * ImmersiveMaterialRuntime 提供，与页面保持同源。
 */
@Component
export struct ReaderHdsBottomMenu {
  @Prop useChapterQuickJump: boolean = false;
  @Prop chapterSliderValue: number = 0;
  @Prop chapterSliderMax: number = 0;
  @Prop canGoPrevChapter: boolean = false;
  @Prop canGoNextChapter: boolean = false;
  @Prop chapterTooltipVisible: boolean = false;
  @Prop chapterTooltipTitle: string = '';
  @Prop chapterTooltipProgress: string = '';
  @Prop chapterTooltipWidth: number = 0;
  @Prop chapterTooltipLeft: number = 0;
  @Prop settingsTabEnabled: boolean = false;
  @Prop typographyTabEnabled: boolean = false;
  @Prop dayNightIcon: Resource = $r('sys.symbol.moon');
  @Prop themeRevision: number = 0;
  @Prop darkMode: boolean = false;
  @Prop barWidth: number = 0;
  @Prop overlayHeight: number = 0;
  @Prop bottomMargin: number = 0;
  @Prop translateX: number = 0;
  @Prop textColor: string = '#18191C';
  @Prop subTextColor: string = '#6B7280';
  @Prop accentColor: string = '#3B82F6';
  @Prop trackColor: string = '#66808080';
  @Prop blockColor: string = '#FFFFFF';
  @Prop glassPanelColor: string = '#CCFFFFFF';
  @Prop iconColor: string = '#18191C';
  onPrevChapter: () => void = (): void => {
  };
  onNextChapter: () => void = (): void => {
  };
  onChapterSliderChange: (value: number, mode: SliderChangeMode) => void = (): void => {
  };
  onActionTabClick: (index: number) => void = (): void => {
  };
  onDayNightActivate: () => void = (): void => {
  };
  onDayNightLongPress: () => void = (): void => {
  };

  @Builder
  private chapterBarTab() {
    ReaderChapterSliderBar({
      sliderValue: this.chapterSliderValue,
      sliderMax: this.chapterSliderMax,
      textColor: this.textColor,
      subTextColor: this.subTextColor,
      accentColor: this.accentColor,
      trackColor: this.trackColor,
      blockColor: this.blockColor,
      canGoPrevious: this.canGoPrevChapter,
      canGoNext: this.canGoNextChapter,
      onPrevious: (): void => {
        this.onPrevChapter();
      },
      onNext: (): void => {
        this.onNextChapter();
      },
      onSliderChange: (value: number, mode: SliderChangeMode): void => {
        this.onChapterSliderChange(value, mode);
      }
    })
  }

  @Builder
  private chapterTabBar() {
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          Column()
        }
        .height(56)
        .tabBar(this.chapterBarTab())
      }
      .key(`reader_hds_chapter_bar_${this.themeRevision}_${this.darkMode ? 'dark' : 'light'}`)
      .barBackgroundColor(this.glassPanelColor)
      .barMode(BarMode.Fixed)
      .barHeight(48)
      .barOverlap(true)
      .barFloatingStyle({
        barWidth: {
          smallWidth: this.barWidth,
          mediumWidth: this.barWidth,
          largeWidth: this.barWidth
        },
        systemMaterialEffect: {
          materialType: ImmersiveMaterialRuntime.materialType(),
          materialLevel: ImmersiveMaterialRuntime.materialLevel()
        },
        barSideMargin: 0,
        barBottomMargin: 4,
        gradientMask: {
          maskColor: '#00000000',
          maskHeight: 56
        },
        adaptToHandedness: false,
        thermoCtrl: true,
        barOpacity: 1
      })
      .scrollable(false)
      .width('100%')
      .height(56)

      if (this.chapterTooltipVisible) {
        Column({ space: 2 }) {
          Text(this.chapterTooltipTitle)
            .fontSize(12)
            .fontColor('#FFFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.chapterTooltipProgress)
            .fontSize(11)
            .fontColor('#CCFFFFFF')
        }
        .width(this.chapterTooltipWidth)
        .height(44)
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.darkMode ? '#E63A3C40' : '#D94B4D52')
        .shadow({ radius: 10, color: '#50000000', offsetX: 0, offsetY: 3 })
        .position({ x: this.chapterTooltipLeft, y: -48 })
      }
    }
    .width('100%')
    .height(56)
  }

  build() {
    Column({ space: 4 }) {
      if (this.useChapterQuickJump) {
        this.chapterTabBar()
      }
      ReaderHdsActionBar({
        settingsTabEnabled: this.settingsTabEnabled,
        typographyTabEnabled: this.typographyTabEnabled,
        dayNightIcon: this.dayNightIcon,
        themeRevision: this.themeRevision,
        darkMode: this.darkMode,
        barWidth: this.barWidth,
        glassPanelColor: this.glassPanelColor,
        iconColor: this.iconColor,
        fromToc: false,
        fromSettings: false,
        onTabBarClick: (index: number): void => {
          this.onActionTabClick(index);
        },
        onDayNightActivate: (): void => {
          this.onDayNightActivate();
        },
        onDayNightLongPress: (): void => {
          this.onDayNightLongPress();
        }
      })
    }
    .width('100%')
    .height(this.overlayHeight)
    .padding({ bottom: this.bottomMargin })
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .position({ x: 0, y: '100%' })
    .translate({
      x: this.translateX,
      y: -this.overlayHeight
    })
  }
}

@Component
export struct ReaderHdsFloatingActionBar {
  @Prop settingsTabEnabled: boolean = false;
  @Prop typographyTabEnabled: boolean = false;
  @Prop dayNightIcon: Resource = $r('sys.symbol.moon');
  @Prop themeRevision: number = 0;
  @Prop darkMode: boolean = false;
  @Prop barWidth: number = 0;
  @Prop overlayHeight: number = 0;
  @Prop bottomMargin: number = 0;
  @Prop translateX: number = 0;
  @Prop glassPanelColor: string = '#CCFFFFFF';
  @Prop iconColor: string = '#18191C';
  fromToc: boolean = false;
  fromSettings: boolean = false;
  onTabBarClick: (index: number) => void = (): void => {
  };
  onDayNightActivate: () => void = (): void => {
  };
  onDayNightLongPress: () => void = (): void => {
  };

  build() {
    Column() {
      ReaderHdsActionBar({
        settingsTabEnabled: this.settingsTabEnabled,
        typographyTabEnabled: this.typographyTabEnabled,
        dayNightIcon: this.dayNightIcon,
        themeRevision: this.themeRevision,
        darkMode: this.darkMode,
        barWidth: this.barWidth,
        glassPanelColor: this.glassPanelColor,
        iconColor: this.iconColor,
        fromToc: this.fromToc,
        fromSettings: this.fromSettings,
        onTabBarClick: (index: number): void => {
          this.onTabBarClick(index);
        },
        onDayNightActivate: (): void => {
          this.onDayNightActivate();
        },
        onDayNightLongPress: (): void => {
          this.onDayNightLongPress();
        }
      })
    }
    .width('100%')
    .height(this.overlayHeight)
    .padding({ bottom: this.bottomMargin })
    .justifyContent(FlexAlign.End)
    .position({ x: 0, y: '100%' })
    .translate({
      x: this.translateX,
      y: -this.overlayHeight
    })
  }
}

@Component
struct ReaderHdsActionBar {
  @Prop settingsTabEnabled: boolean = false;
  @Prop typographyTabEnabled: boolean = false;
  @Prop dayNightIcon: Resource = $r('sys.symbol.moon');
  @Prop themeRevision: number = 0;
  @Prop darkMode: boolean = false;
  @Prop barWidth: number = 0;
  @Prop glassPanelColor: string = '#CCFFFFFF';
  @Prop iconColor: string = '#18191C';
  fromToc: boolean = false;
  fromSettings: boolean = false;
  onTabBarClick: (index: number) => void = (): void => {
  };
  onDayNightActivate: () => void = (): void => {
  };
  onDayNightLongPress: () => void = (): void => {
  };

  @Builder
  private tabMenuItem(icon: Resource, menuEnabled: boolean) {
    Row() {
      ReaderHdsMenuItem({
        icon: icon,
        iconColor: this.iconColor,
        showAddBadge: false,
        menuEnabled: menuEnabled,
      })
    }
    .layoutWeight(1)
    .height(56)
  }

  @Builder
  private dayNightTab() {
    ReaderHdsDayNightMenuItem({
      icon: this.dayNightIcon,
      iconColor: this.iconColor,
      onActivate: (): void => {
        this.onDayNightActivate();
      },
      onLongPress: (): void => {
        this.onDayNightLongPress();
      }
    })
  }

  build() {
    HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.tabMenuItem($r('sys.symbol.list_bullet'), true))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.tabMenuItem($r('sys.symbol.gearshape'), this.settingsTabEnabled))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.tabMenuItem($r('sys.symbol.textformat'), this.typographyTabEnabled))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.dayNightTab())
    }
    .key(`reader_hds_action_bar_${this.themeRevision}_${this.darkMode ? 'dark' : 'light'}`)
    .barBackgroundColor(this.glassPanelColor)
    .barMode(BarMode.Fixed)
    .barHeight(48)
    .barOverlap(true)
    .barFloatingStyle({
      barWidth: {
        smallWidth: this.barWidth,
        mediumWidth: this.barWidth,
        largeWidth: this.barWidth
      },
      systemMaterialEffect: {
        materialType: ImmersiveMaterialRuntime.materialType(),
        materialLevel: ImmersiveMaterialRuntime.materialLevel()
      },
      barSideMargin: 0,
      barBottomMargin: 4,
      gradientMask: {
        maskColor: '#00000000',
        maskHeight: 56
      },
      adaptToHandedness: false,
      thermoCtrl: true,
      barOpacity: 1
    })
    .scrollable(false)
    .onContentWillChange(() => false)
    .onTabBarClick((index: number) => {
      this.onTabBarClick(index);
    })
    .width('100%')
    .height(56)
  }
}

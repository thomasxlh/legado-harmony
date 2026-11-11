import { Bookmark } from '../model/data/Book';
import { ReaderThemeBackground } from './ReaderThemeBackground';
import { ReaderFloatingIconMenuItem, ReaderHdsMenuItem } from './ReaderMenuItems';
import * as LeafFns from '../reader/ReaderLeafFns';

/**
 * 阅读页里的「昼夜切换按钮」「书签卡」「仿真纸张底纹」「段间距」四类小构件。
 *
 * 与前几批一致：组件只读 @Prop 传进来的值，点击/长按通过回调交回页面，
 * 组件内部不持有 page 引用（page 引用不会建立 ArkUI V1 依赖，见 CODE_MAP.md P1 记录）。
 */

@Component
export struct ReaderHdsDayNightMenuItem {
  @Prop icon: Resource = $r('sys.symbol.sun_max');
  @Prop iconColor: ResourceColor = '#18191C';
  onActivate: () => void = (): void => {
  };
  onLongPress: () => void = (): void => {
  };

  build() {
    Stack() {
      ReaderHdsMenuItem({
        icon: this.icon,
        iconColor: this.iconColor,
        showAddBadge: false,
        menuEnabled: true,
      })
    }
    .width('100%')
    .height(48)
    .onClick(() => {
      this.onActivate();
    })
    .gesture(
      LongPressGesture({ duration: 600, repeat: false })
        .onAction(() => {
          this.onLongPress();
        })
    )
  }
}

@Component
export struct ReaderFloatingDayNightMenuItem {
  @Prop icon: Resource = $r('sys.symbol.sun_max');
  @Prop iconColor: ResourceColor = '#18191C';
  onActivate: () => void = (): void => {
  };
  onLongPress: () => void = (): void => {
  };

  build() {
    Row() {
      ReaderFloatingIconMenuItem({
        icon: this.icon,
        iconColor: this.iconColor,
        showAddBadge: false,
        menuEnabled: true,
        onMenuClick: () => {
        },
      })
    }
    .layoutWeight(1)
    .height(56)
    .onClick(() => {
      this.onActivate();
    })
    .gesture(
      LongPressGesture({ duration: 600, repeat: false })
        .onAction(() => {
          this.onLongPress();
        })
    )
  }
}

@Component
export struct ReaderBookmarkSwipeCard {
  @Prop bookmark: Bookmark;
  @Prop selected: boolean = false;
  @Prop accentColor: ResourceColor = '#3B82F6';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#6B7280';
  @Prop selectedBackgroundColor: ResourceColor = Color.Transparent;
  @Prop dividerColor: ResourceColor = '#0D000000';
  onPrimaryAction: () => void = (): void => {
  };
  onLongPressAction: (event: GestureEvent) => void = (): void => {
  };

  build() {
    Column({ space: 5 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.bookmark'))
          .fontSize(18)
          .fontColor([this.accentColor])
          .width(26)
        Text(this.bookmark.chapterName || `第 ${this.bookmark.chapterIndex + 1} 章`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`第 ${this.bookmark.pageIndex + 1} 页`)
          .fontSize(11)
          .fontColor(this.subTextColor)
      }

      Text(this.bookmark.content || '已保存阅读位置')
        .fontSize(12)
        .fontColor(this.subTextColor)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(LeafFns.formatBookmarkTime(this.bookmark.createTime))
        .fontSize(12)
        .fontColor(this.subTextColor)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selected ? this.selectedBackgroundColor : Color.Transparent)
    .border({ width: { bottom: 0.5 }, color: this.dividerColor })
    .onClick(() => {
      this.onPrimaryAction();
    })
    .gesture(LongPressGesture({ repeat: false }).onAction((event: GestureEvent) => {
      this.onLongPressAction(event);
    }))
  }
}

@Component
export struct ReaderSimulationPaperBackground {
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop backgroundAssetId: string = '';
  @Prop customImage: ResourceStr = '';
  @Prop customImageFit: ImageFit = ImageFit.Cover;
  @Prop viewportWidthHint: number = 0;
  @Prop viewportHeightHint: number = 0;

  build() {
    ReaderThemeBackground({
      surfaceColor: this.surfaceColor,
      backgroundAssetId: this.backgroundAssetId,
      customImage: this.customImage,
      customImageFit: this.customImageFit,
      viewportWidthHint: this.viewportWidthHint,
      viewportHeightHint: this.viewportHeightHint
    })
      .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderParagraphGap {
  @Prop gapHeight: number = 0;

  build() {
    Blank()
      .height(this.gapHeight)
      .width('100%')
  }
}

/**
 * 阅读页的点击 / 手势热区层。
 *
 * 原 @Builder 172 行、三个分支（自定义九宫格 / 左右或上下翻页 / 单击唤菜单），
 * 读 17 个页面成员。提成组件后分支判定与阈值走 @Prop，动作全部走回调；
 * 只有「这次点击是否该被吞掉」是即时判定，保留为同步回调 shouldIgnoreTap。
 */
@Component
export struct ReaderTapLayer {
  /** 0 = 左右/上下翻页，1 = 单击唤菜单，2 = 自定义九宫格 */
  @Prop pageTurnMode: number = 1;
  @Prop tapSlop: number = 12;
  @Prop verticalPageTurn: boolean = false;
  @Prop menuVisible: boolean = false;
  @Prop tocVisible: boolean = false;
  @Prop settingsVisible: boolean = false;
  shouldIgnoreTap: () => boolean = (): boolean => false;
  onTapZone: (zone: number) => void = (_zone: number): void => {
  };
  onPrevPage: () => void = (): void => {
  };
  onNextPage: () => void = (): void => {
  };
  onShowMenu: () => void = (): void => {
  };
  onLayerAreaChange: (area: Area) => void = (_area: Area): void => {
  };
  onLayerTouch: (event: TouchEvent) => void = (_event: TouchEvent): void => {
  };
  onPanStart: (event: GestureEvent) => void = (_event: GestureEvent): void => {
  };
  onPanUpdate: (event: GestureEvent) => void = (_event: GestureEvent): void => {
  };
  onPanEnd: (event: GestureEvent) => void = (_event: GestureEvent): void => {
  };
  onPanCancel: () => void = (): void => {
  };
  onLongPress: (event: GestureEvent) => void = (_event: GestureEvent): void => {
  };

  private tapIgnored(): boolean {
    return this.shouldIgnoreTap();
  }

  build() {
    if (this.pageTurnMode === 2) {
      Column() {
        ForEach([0, 1, 2], (row: number) => {
          Row() {
            ForEach([0, 1, 2], (column: number) => {
              Blank()
                .height('100%')
                .layoutWeight(1)
                .onClick((): void => {
                  if (this.tapIgnored()) {
                    return;
                  }
                  this.onTapZone(row * 3 + column);
                })
            }, (column: number) => `${row}_${column}`)
          }
          .width('100%')
          .layoutWeight(1)
        }, (row: number) => `${row}`)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.onLayerAreaChange(newValue);
      })
      .onTouch((event: TouchEvent): void => {
        this.onLayerTouch(event);
      })
      .parallelGesture(
        GestureGroup(GestureMode.Exclusive,
          PanGesture({ direction: PanDirection.All, distance: this.tapSlop })
            .onActionStart((event: GestureEvent): void => {
              this.onPanStart(event);
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.onPanUpdate(event);
            })
            .onActionEnd((event: GestureEvent): void => {
              this.onPanEnd(event);
            })
            .onActionCancel((): void => {
              this.onPanCancel();
            }),
          LongPressGesture({ duration: 600 })
            .onAction((event: GestureEvent): void => {
              this.onLongPress(event);
            })
        )
      )
    } else if (this.pageTurnMode === 0) {
      Column() {
        Blank()
          .width('100%')
          .layoutWeight(3)
          .onClick((): void => {
            if (this.tapIgnored()) {
              return;
            }
            this.onPrevPage();
          })

        Row() {
          Blank()
            .height('100%')
            .layoutWeight(1)
            .onClick((): void => {
              if (this.tapIgnored()) {
                return;
              }
              this.onPrevPage();
            })
          Blank()
            .height('100%')
            .layoutWeight(1)
            .onClick((): void => {
              if (this.tapIgnored()) {
                return;
              }
              this.onShowMenu();
            })
          Blank()
            .height('100%')
            .layoutWeight(1)
            .onClick((): void => {
              if (this.tapIgnored()) {
                return;
              }
              this.onNextPage();
            })
        }
        .width('100%')
        .layoutWeight(4)

        Blank()
          .width('100%')
          .layoutWeight(3)
          .onClick((): void => {
            if (this.tapIgnored()) {
              return;
            }
            this.onNextPage();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.onLayerAreaChange(newValue);
      })
      .onTouch((event: TouchEvent): void => {
        this.onLayerTouch(event);
      })
      .parallelGesture(
        GestureGroup(GestureMode.Exclusive,
          PanGesture({
            direction: this.verticalPageTurn ? PanDirection.Vertical : PanDirection.Horizontal,
            distance: this.tapSlop
          })
            .onActionStart((event: GestureEvent): void => {
              this.onPanStart(event);
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.onPanUpdate(event);
            })
            .onActionEnd((event: GestureEvent): void => {
              this.onPanEnd(event);
            })
            .onActionCancel((): void => {
              this.onPanCancel();
            }),
          LongPressGesture({ duration: 600 })
            .onAction((event: GestureEvent): void => {
              this.onLongPress(event);
            })
        )
      )
    } else {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          this.onLayerAreaChange(newValue);
        })
        .onClick((): void => {
          if (this.tapIgnored()) {
            return;
          }
          if (!this.menuVisible && !this.tocVisible && !this.settingsVisible) {
            this.onShowMenu();
          }
        })
        .onTouch((event: TouchEvent): void => {
          this.onLayerTouch(event);
        })
        .parallelGesture(
          GestureGroup(GestureMode.Exclusive,
            PanGesture({ direction: PanDirection.All, distance: this.tapSlop })
              .onActionStart((event: GestureEvent): void => {
                this.onPanStart(event);
              })
              .onActionUpdate((event: GestureEvent): void => {
                this.onPanUpdate(event);
              })
              .onActionEnd((event: GestureEvent): void => {
                this.onPanEnd(event);
              })
              .onActionCancel((): void => {
                this.onPanCancel();
              }),
            LongPressGesture({ duration: 600 })
              .onAction((event: GestureEvent): void => {
                this.onLongPress(event);
              })
          )
        )
    }
  }
}

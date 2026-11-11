/**
 * 阅读页菜单项：左上角 HDS/浮动图标按钮、右侧「更多操作」列表项、替换净化入口、
 * 评论面板拖拽热区。
 *
 * 与前面几批一致：颜色/是否显示角标这类**值**用 @Prop 传，点击行为用回调传，
 * 组件内部不持有 page 引用。
 */
import * as LeafFns from '../reader/ReaderLeafFns';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ReaderBookmarkActionItem } from './ReaderBookmarkActionItem';

@Component
export struct ReaderHdsMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop showAddBadge: boolean = false;
  @Prop menuEnabled: boolean = true;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.iconColor])

        if (this.showAddBadge) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor([this.iconColor])
            .position({ x: 20, y: 0 })
        }
      }
      .width(32)
      .height(32)
    }
    .width('100%')
    .height(48)
    .opacity(this.menuEnabled ? 1 : 0.32)
    .enabled(this.menuEnabled)
    .translate({ y: -2 })
  }
}

@Component
export struct ReaderFloatingIconMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop showAddBadge: boolean = false;
  @Prop menuEnabled: boolean = true;
  onMenuClick: () => void = (): void => {
  };

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.iconColor])

        if (this.showAddBadge) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor([this.iconColor])
            .position({ x: 20, y: 0 })
        }
      }
      .width(32)
      .height(32)
    }
    // 注意：自定义组件根节点不会把 layoutWeight 作用到组件自身（V1 下组件节点尺寸由内容决定），
    // 因此撑满与均分交给调用点的 Row().layoutWeight(1) 包装，这里只负责填满该包装。
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(28)
    .opacity(this.menuEnabled ? 1 : 0.32)
    .enabled(this.menuEnabled)
    .onClick(() => {
      this.onMenuClick();
    })
  }
}

@Component
export struct ReaderActionMenuItem {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop label: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop dividerColor: ResourceColor = '#E5E5E5';
  @Prop menuEnabled: boolean = true;
  @Prop showDivider: boolean = true;
  onMenuClick: () => void = (): void => {
  };
  dismissMenu: () => void = (): void => {
  };

  build() {
    Column() {
      Row({ space: 12 }) {
        SymbolGlyph(this.icon)
          .fontSize(21)
          .fontColor([this.textColor])
          .width(24)

        Text(this.label)
          .fontSize(16)
          .fontColor(this.textColor)
          .maxLines(1)
          .layoutWeight(1)
      }
      .width('100%')
      .height(46)
      .padding({ left: 10, right: 10 })

      if (this.showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color(this.dividerColor)
          .margin({ left: 46, right: 8 })
      }
    }
    .width('100%')
    .opacity(this.menuEnabled ? 1 : 0.38)
    .enabled(this.menuEnabled)
    .onClick(() => {
      if (!this.menuEnabled) {
        return;
      }
      this.dismissMenu();
      this.onMenuClick();
    })
  }
}

@Component
export struct ReaderReplaceRulesEntryItem {
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  onOpen: () => void = (): void => {
  };

  build() {
    Row() {
      Column() {
        Text('替换净化')
          .fontSize(15)
          .fontColor(this.textColor)
        Text('管理正文与章节标题的替换规则')
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([this.subTextColor])
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onOpen();
    })
  }
}

@Component
export struct ReaderCommentPanelDragOverlay {
  onDragTouch: (event: TouchEvent) => void = (event: TouchEvent): void => {
  };

  build() {
    Row()
      .width('100%')
      .height(LeafFns.readerCommentPanelDragHandleHeight())
      .backgroundColor('#00000000')
      .zIndex(50)
      .accessibilityText('上滑展开评论面板')
      .hitTestBehavior(HitTestMode.Block)
      .onTouch((event: TouchEvent) => {
        this.onDragTouch(event);
      })
  }
}


/**
 * 「更多操作」悬浮菜单面板：12 个菜单项，全部状态值化后由页面传入。
 * 原为 ReadBook.ets 的 @Builder readerActionMenu()，抽出后按 P1 约定不持有 page 引用。
 */
@Component
export struct ReaderActionMenuPanel {
  @Prop bookmarkLabel: string = '添加书签';
  @Prop firstDivider: boolean = true;
  @Prop showCacheItem: boolean = false;
  @Prop ttsIcon: Resource = $r('sys.symbol.play');
  @Prop ttsLabel: string = '开始朗读';
  @Prop comicMode: boolean = false;
  @Prop sourceNeedsLogin: boolean = false;
  @Prop canRetry: boolean = false;
  @Prop canSelectTxtCharset: boolean = false;
  @Prop txtCharsetLabel: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop dividerColor: ResourceColor = '#E5E5E5';
  @Prop panelColor: ResourceColor = '#F2FFFFFF';
  @Prop glassBorderColor: ResourceColor = '#33FFFFFF';
  @Prop shadowColor: ResourceColor = '#22000000';
  @Prop topOffset: number = 0;
  onToggleBookmark: () => void = (): void => {
  };
  onOpenCache: () => void = (): void => {
  };
  onToggleTts: () => void = (): void => {
  };
  onOpenLogin: () => void = (): void => {
  };
  onRetry: () => void = (): void => {
  };
  onOpenSettings: () => void = (): void => {
  };
  onOpenTtsSettings: () => void = (): void => {
  };
  onOpenTxtCharset: () => void = (): void => {
  };
  onToggleComic: () => void = (): void => {
  };
  onOpenLayoutElement: () => void = (): void => {
  };
  onOpenReplaceRules: () => void = (): void => {
  };
  onDismiss: () => void = (): void => {
  };

  build() {
    Column() {
      ReaderActionMenuItem({
        icon: $r('sys.symbol.bookmark'),
        label: this.bookmarkLabel,
        textColor: this.textColor,
        dividerColor: this.dividerColor,
        menuEnabled: true,
        showDivider: this.firstDivider,
        onMenuClick: (): void => {
          this.onToggleBookmark();
        },
        dismissMenu: (): void => {
          this.onDismiss();
        },
      })
      if (this.showCacheItem) {
        ReaderActionMenuItem({
          icon: $r('sys.symbol.download'),
          label: '缓存',
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onOpenCache();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      if (!this.comicMode) {
        ReaderActionMenuItem({
          icon: this.ttsIcon,
          label: this.ttsLabel,
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onToggleTts();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      if (this.sourceNeedsLogin) {
        ReaderActionMenuItem({
          icon: $r('sys.symbol.checkmark_shield'),
          label: '登录',
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onOpenLogin();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      if (this.canRetry) {
        ReaderActionMenuItem({
          icon: $r('sys.symbol.exclamationmark_circle'),
          label: '重试',
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onRetry();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      if (!this.comicMode) {
        ReaderActionMenuItem({
          icon: $r('sys.symbol.gearshape'),
          label: '阅读设置',
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onOpenSettings();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
        ReaderActionMenuItem({
          icon: $r('sys.symbol.speaker_wave_3'),
          label: '朗读设置',
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onOpenTtsSettings();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      if (this.canSelectTxtCharset) {
        ReaderActionMenuItem({
          icon: $r('sys.symbol.textformat'),
          label: `字符编码 · ${this.txtCharsetLabel}`,
          textColor: this.textColor,
          dividerColor: this.dividerColor,
          menuEnabled: true,
          showDivider: true,
          onMenuClick: (): void => {
            this.onOpenTxtCharset();
          },
          dismissMenu: (): void => {
            this.onDismiss();
          },
        })
      }
      ReaderActionMenuItem({
        icon: this.comicMode ? $r('sys.symbol.book') : $r('sys.symbol.rectangle_3_group'),
        label: this.comicMode ? '切换为普通阅读' : '切换为漫画阅读',
        textColor: this.textColor,
        dividerColor: this.dividerColor,
        menuEnabled: true,
        showDivider: true,
        onMenuClick: (): void => {
          this.onToggleComic();
        },
        dismissMenu: (): void => {
          this.onDismiss();
        },
      })
      ReaderActionMenuItem({
        icon: $r('sys.symbol.square_grid_2x2'),
        label: '布局元素设置',
        textColor: this.textColor,
        dividerColor: this.dividerColor,
        menuEnabled: true,
        showDivider: true,
        onMenuClick: (): void => {
          this.onOpenLayoutElement();
        },
        dismissMenu: (): void => {
          this.onDismiss();
        },
      })
      ReaderActionMenuItem({
        icon: $r('sys.symbol.arrow_left_arrow_right'),
        label: '替换净化配置',
        textColor: this.textColor,
        dividerColor: this.dividerColor,
        menuEnabled: true,
        showDivider: false,
        onMenuClick: (): void => {
          this.onOpenReplaceRules();
        },
        dismissMenu: (): void => {
          this.onDismiss();
        },
      })
    }
    .width(220)
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor(this.panelColor)
    .borderRadius(ThemeRuntime.glassCornerRadius(22, 'panel'))
    .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
    .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.glassBorderColor })
    .shadow({ radius: ThemeRuntime.glassShadowRadius('panel'), color: this.shadowColor, offsetX: ThemeRuntime.glassShadowOffsetX('panel'), offsetY: ThemeRuntime.glassShadowOffsetY('panel') })
    .position({ x: '100%', y: 0 })
    .translate({ x: -232, y: this.topOffset })
    .onClick(() => {
    })
  }
}

/**
 * 书签长按后的操作浮层：遮罩 + 「多选 / 删除」两项。
 *
 * 原先 50 行 @Builder、读 12 个页面状态。提取后遮罩色、面板色、位置、待处理书签的空/非空
 * 都走 @Prop，两个动作按钮的点击回给页面（页面负责关闭浮层并分发到多选/删除）。
 */
@Component
export struct ReaderBookmarkActionMenu {
  @Prop menuLeft: number = 0;
  @Prop menuTop: number = 0;
  @Prop hasPendingBookmark: boolean = false;
  @Prop textColor: string = '#18191C';
  @Prop dangerColor: string = '#D94841';
  @Prop scrimColor: string = '#26FFFFFF';
  @Prop panelColor: string = '#FFFFFF';
  @Prop glassBorderColor: string = '#1A000000';
  @Prop glassShadowColor: string = '#33000000';
  onDismiss: () => void = (): void => {
  };
  onMultiSelect: () => void = (): void => {
  };
  onDelete: () => void = (): void => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.scrimColor)
        .backdropBlur(ThemeRuntime.glassBlur('popover', 18))
        .onClick(() => {
          this.onDismiss();
        })

      Column() {
        ReaderBookmarkActionItem({
          icon: $r('sys.symbol.checkmark_circle'),
          label: '多选',
          color: this.textColor,
          action: (): void => {
            if (this.hasPendingBookmark) {
              this.onMultiSelect();
            }
          }
        })
        ReaderBookmarkActionItem({
          icon: $r('sys.symbol.trash'),
          label: '删除',
          color: this.dangerColor,
          action: (): void => {
            if (this.hasPendingBookmark) {
              this.onDelete();
            }
          }
        })
      }
      .width(148)
      .padding({ top: 6, bottom: 6 })
      .backgroundColor(this.panelColor)
      .borderRadius(ThemeRuntime.glassCornerRadius(14, 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.glassBorderColor })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('panel'),
        color: this.glassShadowColor,
        offsetX: ThemeRuntime.glassShadowOffsetX('panel'),
        offsetY: ThemeRuntime.glassShadowOffsetY('panel')
      })
      .position({ x: this.menuLeft, y: this.menuTop })
    }
    .width('100%')
    .height('100%')
  }
}

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

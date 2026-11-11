/**
 * 阅读页里更多「只读少量状态」的展示型 @Builder。
 *
 * 迁移原则与批次 1~3 一致：把颜色/尺寸/是否选中这类**值**用 @Prop 传进来，
 * 把点击后的行为用回调传回，组件内部不再持有 page 引用。
 */
import { ImmersiveBackButton } from './ImmersiveBackButton';

@Component
export struct ReaderEyeTurnPrompt {
  @Prop visible: boolean = false;
  @Prop promptTop: number = 0;

  build() {
    if (this.visible) {
      Row() {
        Text('向上看，翻下一页')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F8FFFFFF')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor('#B35C7569')
          .shadow({ radius: 12, color: '#45000000', offsetX: 0, offsetY: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: this.promptTop })
      // Above the reader settings panel (zIndex 90) so the prompt stays visible while the
      // eye-turn settings status is being watched.
      .zIndex(95)
      .hitTestBehavior(HitTestMode.None)
    }
  }
}

@Component
export struct ReaderHeaderInfoBar {
  @Prop infoText: string = '';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop barHeight: number = 0;
  @Prop topInset: number = 0;

  build() {
    Row() {
      Text(this.infoText)
        .fontSize(12)
        .fontColor(this.subTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .height(this.barHeight)
    .padding({ top: this.topInset, left: 28, right: 28 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderSliderStepButton {
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop accessibilityLabel: string = '';
  @Prop controlEnabled: boolean = true;
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop disabledIconColor: ResourceColor = '#999999';
  @Prop darkMode: boolean = false;
  action: () => void = (): void => {
  };

  build() {
    // 按钮视觉保持 34，点击热区由组件自身 responseRegion 扩到 44：
    // onClick 走按钮单一路径（onBack 直连 action），避免外层转发被子组件点击消费导致失灵。
    ImmersiveBackButton({
      icon: this.icon,
      accessibilityLabel: this.accessibilityLabel,
      iconColor: this.iconColor,
      disabledIconColor: this.disabledIconColor,
      darkMode: this.darkMode,
      buttonEnabled: this.controlEnabled,
      buttonSize: 34,
      containerWidth: 44,
      containerHeight: 44,
      hitAreaSize: 44,
      compactLayout: true,
      onBack: (): void => {
        if (this.controlEnabled) {
          this.action();
        }
      }
    })
  }
}

@Component
export struct ReaderCurrentPageBookmarkMarker {
  @Prop accentColor: ResourceColor = '#4F8F86';
  @Prop translateY: number = 0;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      SymbolGlyph($r('sys.symbol.bookmark_fill'))
        .fontSize(32)
        .fontColor([this.accentColor])
    }
    .width(46)
    .height(40)
    .position({ x: '100%', y: 0 })
    .translate({ x: -62, y: this.translateY })
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct ReaderTtsSleepTimerChip {
  @Prop minutes: number = 0;
  @Prop selected: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop accentColor: ResourceColor = '#4F8F86';
  @Prop idleColor: ResourceColor = '#F0F0F0';
  onToggle: () => void = (): void => {
  };

  build() {
    Text(`${this.minutes}分`)
      .fontSize(13)
      .fontColor(this.selected ? '#FFFFFF' : this.textColor)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(32)
      .borderRadius(16)
      .backgroundColor(this.selected ? this.accentColor : this.idleColor)
      .accessibilityText(this.selected ? `关闭 ${this.minutes} 分钟朗读定时` : `设置 ${this.minutes} 分钟朗读定时`)
      .onClick(() => {
        this.onToggle();
      })
  }
}

@Component
export struct ReaderTtsSpeedChip {
  @Prop value: number = 1;
  @Prop selected: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop accentColor: ResourceColor = '#4F8F86';
  @Prop idleColor: ResourceColor = '#F0F0F0';
  onSelect: () => void = (): void => {
  };

  build() {
    Text(`${this.value.toFixed(1)}x`)
      .fontSize(13)
      .fontColor(this.selected ? '#FFFFFF' : this.textColor)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(32)
      .borderRadius(16)
      .backgroundColor(this.selected ? this.accentColor : this.idleColor)
      .onClick(() => {
        this.onSelect();
      })
  }
}

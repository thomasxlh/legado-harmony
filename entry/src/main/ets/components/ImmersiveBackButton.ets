import { HdsTabs } from '@kit.UIDesignKit';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';

@Component
export struct ImmersiveBackButton {
  @Prop icon: Resource = $r('sys.symbol.chevron_left');
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop labelText: string = '';
  @Prop labelFontSize: number = 21;
  @Prop iconSize: number = 22;
  @Prop iconOffsetX: number = -1;
  @Prop darkMode: boolean = false;
  @Prop buttonSize: number = 38;
  @Prop containerWidth: number = 52;
  @Prop containerHeight: number = 56;
  @Prop startInset: number = 16;
  @Prop materialScale: number = 1;
  @Prop compactLayout: boolean = false;
  @Prop accessibilityLabel: string = '返回';
  @Prop buttonEnabled: boolean = true;
  @Prop disabledIconColor: ResourceColor = '#999999';
  /** 触控热区边长：>0 时按钮 onClick 响应区域扩到该尺寸（视觉尺寸不变），保持单一点击路径。 */
  @Prop hitAreaSize: number = 0;
  @State private pressed: boolean = false;
  onBack: () => void = () => {};

  build() {
    Stack() {
      if (ImmersiveMaterialRuntime.supportsHdsTabs()) {
        this.linkedSystemMaterialButton()
      } else {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          this.buttonContent(false)
        }
        .width(this.materialButtonSize())
        .height(this.materialButtonSize())
        .padding(0)
        .enabled(this.buttonEnabled)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.accessibilityLabel)
        .responseRegion(this.overlayHitRegion())
        .onClick(() => this.onBack())
      }
    }
    .width(this.effectiveContainerWidth())
    .height(this.containerHeight)
    .alignContent(ImmersiveMaterialRuntime.supportsHdsTabs() ? Alignment.Start : Alignment.Center)
  }

  @Builder
  linkedSystemMaterialButton() {
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          Column()
        }
        .height(this.materialButtonSize())
        .tabBar(this.nativeMaterialTabContent())
      }
      .barMode(BarMode.Fixed)
      .barHeight(this.materialButtonSize())
      .barOverlap(true)
      .barFloatingStyle({
        barWidth: {
          smallWidth: this.materialButtonSize(),
          mediumWidth: this.materialButtonSize(),
          largeWidth: this.materialButtonSize()
        },
        systemMaterialEffect: {
          materialType: ImmersiveMaterialRuntime.materialType(),
          materialLevel: ImmersiveMaterialRuntime.materialLevel()
        },
        barSideMargin: 0,
        barBottomMargin: 0,
        gradientMask: {
          maskColor: '#00000000',
          maskHeight: this.materialButtonSize()
        },
        adaptToHandedness: false,
        thermoCtrl: true,
        barOpacity: 1
      })
      .scrollable(false)
      .onContentWillChange(() => false)
      .width(this.materialButtonSize())
      .height(this.materialButtonSize())

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        this.buttonContent(true)
      }
      .width(this.materialButtonSize())
      .height(this.materialButtonSize())
      .padding(0)
      .enabled(this.buttonEnabled)
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)
      .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
      .opacity(this.pressed ? 0.7 : 1)
      .accessibilityText(this.accessibilityLabel)
      .onTouch((event: TouchEvent) => this.handlePressedTouch(event))
      .responseRegion(this.overlayHitRegion())
      .onClick(() => this.onBack())
    }
    .width(this.materialButtonSize())
    .height(this.materialButtonSize())
    .borderRadius(this.materialButtonSize() / 2, RenderStrategy.OFFSCREEN)
    .clip(true)
    .translate({ x: this.startInset * this.normalizedMaterialScale() })
  }

  @Builder
  nativeMaterialTabContent() {
    Stack()
      .width('100%')
      .height('100%')
  }

  @Builder
  buttonContent(useMaterialScale: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.labelText) {
        Text(this.labelText)
          .fontSize(this.labelFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.iconColor)
      } else {
        SymbolGlyph(this.icon)
          .fontSize(this.iconSize)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.buttonEnabled ? this.iconColor : this.disabledIconColor])
          .translate({ x: this.iconOffsetX })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  effectiveContainerWidth(): number {
    if (this.compactLayout) {
      return Math.max(this.containerWidth,
        ImmersiveMaterialRuntime.supportsHdsTabs() ? this.materialButtonSize() : this.buttonSize);
    }
    return Math.max(this.containerWidth, 64 * this.normalizedMaterialScale());
  }

  normalizedMaterialScale(): number {
    return Math.max(0.6, Math.min(this.materialScale, 1));
  }

  materialButtonSize(): number {
    return Math.max(36, this.buttonSize * this.normalizedMaterialScale());
  }

  /**
   * 点击热区：hitAreaSize>0 时扩到该边长（视觉按钮尺寸不变，区域以按钮中心对称外扩）；
   * 否则与按钮自身等大，行为同未设置 responseRegion。
   */
  overlayHitRegion(): Rectangle {
    const size = this.materialButtonSize();
    const hit = this.hitAreaSize > 0 ? Math.max(this.hitAreaSize, size) : size;
    const inset = (size - hit) / 2;
    return { x: inset, y: inset, width: hit, height: hit };
  }

  private handlePressedTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressed = true;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressed = false;
    }
  }
}

/**
 * 阅读页/朗读面板里的「图标按钮 / 开关行 / 小标题」等纯展示项。
 *
 * 这些原先都是 ReadBookPage 的 @Builder，只读形参和一两个颜色方法。
 * 提成 @Component 后颜色作为 @Prop 传入，组件内部不再访问 page，
 * 因此不会切断 ArkUI V1 的隐式联动。
 */
import { AdaptiveSwitch } from './AdaptiveSwitch';
import { ImmersiveBackButton } from './ImmersiveBackButton';
import * as LeafFns from '../reader/ReaderLeafFns';

@Component
export struct ReaderTtsMediaSymbolControl {
  @Prop icon: Resource = $r('sys.symbol.circle');
  @Prop controlEnabled: boolean = true;
  @Prop accessibilityLabel: string = '';
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(this.icon)
        .fontSize(22)
        .fontColor([this.controlEnabled ? this.textColor : this.subTextColor])
    }
    .width('100%')
    .height(48)
    .opacity(this.controlEnabled ? 1 : 0.45)
    .accessibilityText(this.accessibilityLabel)
    .translate({ y: -2 })
  }
}

@Component
export struct ReaderTtsMediaSpeedControl {
  @Prop speedText: string = '';
  @Prop textColor: ResourceColor = '#18191C';

  build() {
    Text(this.speedText)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textColor)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(48)
      .translate({ y: -2 })
  }
}

@Component
export struct ReaderTtsVoiceSectionTitle {
  @Prop title: string = '';
  @Prop subTextColor: ResourceColor = '#8A8A8A';

  build() {
    Text(this.title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.subTextColor)
      .width('100%')
      .padding({ left: 10, right: 10, top: 12, bottom: 6 })
  }
}

@Component
export struct ReaderCacheActionItem {
  @Prop label: string = '';
  @Prop disabled: boolean = false;
  @Prop color: string = '';
  @Prop dark: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  action: () => void = (): void => {
  };

  build() {
    Button(this.label)
      .width('100%')
      .height(44)
      .margin({ top: 6 })
      .backgroundColor(this.dark ? '#24272D' : '#F5F5F5')
      .fontColor(this.color.length > 0 ? this.color : this.textColor)
      .enabled(!this.disabled)
      .opacity(this.disabled ? 0.5 : 1)
      .onClick(this.action)
  }
}

@Component
export struct ReaderEpubImage {
  @Prop marker: string = '';
  @Prop imageHeight: number = 0;

  build() {
    Image(LeafFns.getReaderEpubImageUri(this.marker))
      .width('100%')
      .height(this.imageHeight)
      // sourceSize 同时指定宽高会在解码阶段把漫画压成屏幕比例，
      // 这里交给 ImageFit.Contain 按原始宽高比缩放。
      .objectFit(ImageFit.Contain)
      .draggable(false)
      .clip(true)
  }
}

@Component
export struct ReaderRoundMenuButton {
  @Prop icon: Resource = $r('sys.symbol.more');
  @Prop accessibilityLabel: string = '';
  @Prop iconColor: ResourceColor = '#18191C';
  @Prop darkMode: boolean = false;
  onBack: () => void = (): void => {
  };

  build() {
    ImmersiveBackButton({
      icon: this.icon,
      iconOffsetX: 0,
      iconColor: this.iconColor,
      darkMode: this.darkMode,
      buttonSize: 40,
      containerWidth: 40,
      containerHeight: 56,
      startInset: 0,
      materialScale: 0.83,
      compactLayout: true,
      accessibilityLabel: this.accessibilityLabel,
      onBack: this.onBack
    })
  }
}

@Component
export struct ReaderSwitchSettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop isOn: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop switchColor: ResourceColor = '#4F8F86';
  onChange: (isOn: boolean) => void = (_isOn: boolean): void => {
  };

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(15)
          .fontColor(this.textColor)
        Text(this.description)
          .fontSize(12)
          .fontColor(this.subTextColor)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      AdaptiveSwitch({
        isOn: this.isOn,
        selectedColor: this.switchColor,
        onChange: (value: boolean): void => {
          this.onChange(value);
        }
      })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct ReaderLayoutElementToggle {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop isOn: boolean = false;
  @Prop textColor: ResourceColor = '#18191C';
  @Prop subTextColor: ResourceColor = '#8A8A8A';
  @Prop accentColor: ResourceColor = '#4F8F86';
  @Prop dark: boolean = false;
  onChange: (isOn: boolean) => void = (_isOn: boolean): void => {
  };

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.textColor)
        Text(this.description)
          .fontSize(12)
          .fontColor(this.subTextColor)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      AdaptiveSwitch({
        isOn: this.isOn,
        selectedColor: this.accentColor,
        onChange: (value: boolean): void => {
          this.onChange(value);
        }
      })
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ left: 12, right: 8 })
    .borderRadius(14)
    .backgroundColor(this.dark ? '#1FFFFFFF' : '#0D000000')
    .alignItems(VerticalAlign.Center)
  }
}

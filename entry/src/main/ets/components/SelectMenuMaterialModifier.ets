import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';

/**
 * Sets the API 26 Select menu material via attributeModifier instead of the
 * chained menuSystemMaterial call: on devices below API 26 the attribute
 * method does not exist in the ArkUI runtime, and calling it directly crashes
 * with "is not callable" when the page builds. The modifier callback only
 * runs the call after the device capability check passes.
 */
export class SelectMenuMaterialModifier implements AttributeModifier<SelectAttribute> {
  applyNormalAttribute(instance: SelectAttribute): void {
    const material = ImmersiveMaterialRuntime.selectMenuMaterial();
    if (material !== undefined) {
      instance.menuSystemMaterial(material);
    }
  }
}

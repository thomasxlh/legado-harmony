import { webview } from '@kit.ArkWeb';

/**
 * ArkWeb 运行时探测。DevEco 预览器与缺少 Web 系统能力的设备不会注册 Web 组件的
 * onControllerAttached 等事件属性，此时构建 Web 节点会抛 "undefined is not callable"
 * 并导致整页白屏。所有常驻 Web 宿主挂载前必须先通过此门控。
 */
export class WebRuntimeAvailability {
  private static cachedResult: boolean | null = null;

  static isAvailable(): boolean {
    if (WebRuntimeAvailability.cachedResult !== null) {
      return WebRuntimeAvailability.cachedResult;
    }
    let available = false;
    if (canIUse('SystemCapability.Web.Webview.Core')) {
      try {
        webview.WebviewController.setWebDebuggingAccess(false);
        available = true;
      } catch (_) {
        available = false;
      }
    }
    WebRuntimeAvailability.cachedResult = available;
    return available;
  }
}

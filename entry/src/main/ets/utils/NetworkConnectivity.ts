import { connection } from '@kit.NetworkKit';

/**
 * 离线检测：当前是否存在可用的默认网络连接（蜂窝 / WiFi / 以太网）。
 * 用于让“打开书籍 / 刷新目录 / 校验 WebDAV 书籍”在无网时跳过联网步骤，直接复用本地缓存，
 * 而不是卡在联网超时或把本地目录清空。任何探测异常一律按离线处理，避免把异常误判为在线。
 */
export function isNetworkAvailable(): boolean {
  try {
    const netHandle = connection.hasDefaultNetSync();
    return !!netHandle;
  } catch (error) {
    // 极少数老版本 SDK 不提供同步接口时，保守按离线处理，交由上层走本地缓存。
    console.warn('[NetworkConnectivity] sync check failed, assume offline:', error);
    return false;
  }
}

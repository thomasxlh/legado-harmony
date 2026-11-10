/**
 * 阅读页顶层常量与分页高度比例缓存 —— 从 ReadBook.ets 头部原样抽离（P0 第一步）。
 * 无任何 @State / 页面状态依赖；改动前先读仓库根 CODE_MAP.md「头部区」契约。
 * 仅供 ReadBook.ets import；保持值、注释、行为与抽离前完全一致。
 */

// Three-point fixation calibration: centre, then the bottom turn zone, then the top turn
// zone. Sampling each zone with the gaze held still (instead of a moving dot the iris
// estimator cannot follow) gives a far larger and steadier top/bottom separation.
const READER_EYE_CALIBRATION_SETTLE_MS: number = 600;
export const READER_EYE_CALIBRATION_HOLD_MS: number = 1500;
const READER_EYE_CALIBRATION_PHASE_MS: number =
  READER_EYE_CALIBRATION_SETTLE_MS + READER_EYE_CALIBRATION_HOLD_MS;
export const READER_EYE_CALIBRATION_PHASE_COUNT: number = 3;
const READER_EYE_CALIBRATION_TOTAL_MS: number =
  READER_EYE_CALIBRATION_PHASE_MS * READER_EYE_CALIBRATION_PHASE_COUNT;
export const READER_EYE_CALIBRATION_TICK_MS: number = 60;
export const READER_EYE_CALIBRATION_MIN_PHASE_SAMPLES: number = 5;
export const READER_EYE_CALIBRATION_MIN_DELTA: number = 0.005;
// AR Engine gaze values are already normalized, so a fixed centre/top/bottom mapping is all the zone mapper needs.
export const AR_EYE_CALIBRATION_RAW: string = '-1,0,1';
// Used when no calibration has been stored: the iris channel with a plausible physical
// span and a neutral centre. The runtime baseline then centres it per reader, so the
// feature works without forcing a manual calibration first.
export const DEFAULT_EYE_CALIBRATION_RAW: string = 'v3,0,0,0,0.5,-0.04,0.04,0,1';
// AR Engine face tracking never leaves PAUSED when its ARView is hosted through a
// BuilderNode: faces are detected but getBlendShapes() always reports
// "AnimojiBlendShape is nullptr". Until the view can live in a real window, the
// runtime uses the camera pipeline and the AR code below stays dormant.
export const READER_EYE_TURN_AR_ENABLED: boolean = false;

export const TOC_WINDOW_PAGE_SIZE = 72;
export const TOC_SCROLLBAR_DRAG_UPDATE_INTERVAL_MS = 90;
export const FULL_TEXT_CACHE_NOTIFICATION_INTERVAL_MS = 5000;
export const READER_CURRENT_PAGINATION_AHEAD_PAGE_COUNT = 4;
export const READER_ADJACENT_PAGINATION_PREVIEW_PAGE_COUNT = 2;
export const READER_PAGINATION_BATCH_DELAY_MS = 64;
export const READER_INTERACTIVE_PAGINATION_BATCH_DELAY_MS = 56;
export const READER_PAGINATION_BUSY_RETRY_DELAY_MS = 48;
// 书源取文/目录链可能因书源脚本或 WebView 运行时挂起而永不返回；
// 限时兜底把它转成可操作的失败态，避免阅读器永远停在"正在打开书籍…"遮罩上且无法交互。
export const READER_OPEN_FETCH_TIMEOUT_MS = 60000;
export const READER_CONTENT_FETCH_TIMEOUT_MS = 45000;
// 章节衔接兜底：onFinished 之后朗读器已停、下一章迟迟没有接上（加载/续播链路卡死）时，
// 超过该时长仍未恢复则自动结束朗读，避免悬浮面板停在"正在定位当前朗读内容"且无法操作。
// 需大于章内续播最坏耗时（正文加载 45s 超时 + 回滚重载 45s + 引擎重建）。
export const TTS_CONTINUATION_WATCHDOG_MS = 150000;
/** 加载超过该时长仍未完成时，在遮罩上浮出"不再等待"逃生口，慢书源可停止等待后换源/重试。 */
export const READER_LOADING_SLOW_HINT_MS = 5000;
export const READER_DOUBLE_PAGE_DIVIDER_WIDTH = 1;
// 正文选中菜单里的自定义"替换"项 ID，用于与系统菜单项（复制/全选/翻译等）区分。
export const READER_REPLACE_MENU_ITEM_ID: string = 'reader_replace_rule';
// Page-curl textures are transient animation rasters, not the settled正文 surface. Capturing a full 2080x3120
// page and sampling it through every mesh triangle can block the ArkUI thread for several seconds on tablets.
// A 0.42 raster remains sharp while moving on high-density screens and reduces texture fill by another 29%
// compared with the previous half-resolution capture. This matters most on dialogue-heavy pages.
export const READER_PAGE_CURL_SNAPSHOT_SCALE = 0.42;

/** 模块级单例缓存：ReadBook.ets 直接 .get/.has 读取，故 export 同一引用，语义不变。 */
export const READER_PAGINATION_HEIGHT_SCALE_CACHE: Map<string, number> = new Map<string, number>();
const READER_PAGINATION_HEIGHT_SCALE_CACHE_LIMIT: number = 64;

export function cacheReaderPaginationHeightScale(key: string, value: number): void {
  if (!key) return;
  if (READER_PAGINATION_HEIGHT_SCALE_CACHE.has(key)) READER_PAGINATION_HEIGHT_SCALE_CACHE.delete(key);
  while (READER_PAGINATION_HEIGHT_SCALE_CACHE.size >= READER_PAGINATION_HEIGHT_SCALE_CACHE_LIMIT) {
    const keys: string[] = Array.from(READER_PAGINATION_HEIGHT_SCALE_CACHE.keys());
    const oldest: string = keys[0] || '';
    if (!oldest) break;
    READER_PAGINATION_HEIGHT_SCALE_CACHE.delete(oldest);
  }
  READER_PAGINATION_HEIGHT_SCALE_CACHE.set(key, value);
}

import { Book, BookSource, SearchBook } from '../model/data/Book';
import { AppDatabase } from '../model/data/AppDatabase';
import { SearchCoordinator, SearchProgress, SearchSourceResult } from '../core/book/SearchCoordinator';
import { WebBookService } from '../core/book/WebBookService';
import { ChapterMeasureTarget, ChapterWordCountMeasurer } from '../core/book/ChapterWordCountMeasurer';
import { ChangeSourceCacheData, ChangeSourceResultCache } from '../utils/ChangeSourceResultCache';
import { ChangeSourceOptionsStore } from '../utils/ChangeSourceOptionsStore';
import { SearchExploreSettingsStore } from '../utils/SearchExploreSettingsStore';
import { SearchBookShelfHelper } from '../utils/SearchBookShelfHelper';
import { SearchResultSorter } from '../utils/SearchResultSorter';
import { BookFieldSanitizer } from '../utils/BookFieldSanitizer';
import { CoverUrlNormalizer } from '../utils/CoverUrlNormalizer';
import { WordCountFormatter } from '../utils/WordCountFormatter';
import { HdsFeedback } from '../utils/HdsFeedback';
import { router } from '@kit.ArkUI';
import { ThemeRuntime } from '../theme/ThemeRuntime';

/**
 * 换源面板（书架长按"换源"与书籍详情页"换源"共用）。
 * 打开后先读历史结果（上次被中断的搜索会自动续搜剩余书源），再按书名全词匹配并校验作者搜索其它书源；
 * 点刷新会清空历史结果与磁盘缓存后从头重搜；
 * 尝试切换某个书源时后台搜索继续运行，切换失败可直接从列表换下一个，已搜到的结果不会丢失。
 * 选中结果后拉取详情与目录并切换；目标书在书库中已存在时提交换源并保留阅读进度与临时书标记；
 * 仅存在于搜索结果（未入库）时只把结果交给宿主页面，不落库。
 */
const PERSIST_INTERVAL_MS = 3000;
/** 全量字数测量并发数（搜索结束/停止后）：12 路让字数快速补齐，含 JS 书源（实际被 3 槽 ArkWeb 收窄），
 *  各候选源互不相同，每源突发仍由 BookSourceRateLimiter 的 concurrentRate 兜底。 */
const MEASURE_WORKER_COUNT = 12;
/** 搜索进行中的早期测量并发：只测纯本地规则源（不占 ArkWeb 宿主池），3 路足够让置顶/靠前结果
 *  字数随 delta 持续出齐；HTTP 在飞上限 128、每候选源已结束搜索（与在搜源不共享同源自令牌）。
 *  搜索结束后由全量轮次（12 路，含 JS 源）接管。 */
const EARLY_MEASURE_WORKER_COUNT = 3;
/** 单条测量限时：慢书源（详情/目录/两章正文串行）在 30s 内拿不到会被误判"获取失败"，
 *  测量已与搜索解耦不再争抢资源，放宽到 45s 给慢源一次出字机会，死源仍按时释放 worker。 */
const MEASURE_ITEM_TIMEOUT_MS = 45000;
/** 单步切换请求限时：详情/目录取链可能长时间不返回，超时按切换失败处理；等待期间仍可改选其它书源。 */
const SWITCH_FETCH_TIMEOUT_MS = 60000;

@Component
export struct BookChangeSourceDialog {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageLink('appLightButtonColor') appLightButtonColor: string = '#007DFF';
  @StorageLink('appDarkButtonColor') appDarkButtonColor: string = '#3F8CFF';
  targetBook: Book | null = null;
  onSwitched: (book: Book) => void = (_book: Book): void => {
  };
  onClosed: () => void = (): void => {
  };
  /** 切换提交前回调（宿主可先落盘阅读进度），完成后再开始切换。 */
  onBeforeSwitch: (() => Promise<void>) | null = null;
  /** 阅读器换源时标记阅读状态变量，避免章节 0/页 0 的切换被书架视为未读。 */
  markReadOnSwitch: boolean = false;

  @State results: SearchBook[] = [];
  @State status: string = '';
  @State searching: boolean = false;
  /** 还有未搜的书源（手动停止 / 被中断的历史结果），显示"继续搜索"；一轮搜完所有书源时为 false。 */
  @State canResumeSearch: boolean = false;
  @State switching: boolean = false;
  @State switchingBook: SearchBook | null = null;
  @State failedBookUrls: string[] = [];
  @State loadWordCount: boolean = false;
  @State measuring: boolean = false;
  /** 置顶书源 URL 集合（换源时优先搜索）。 */
  @State pinnedSourceUrls: Set<string> = new Set<string>();
  /** 待验证网页地址：与 AppStorage 双向同步，VerifyWeb 验证完成后被清空，按钮自动消失。 */
  @StorageLink('pendingVerificationUrl') verificationUrl: string = '';
  @StorageProp('pendingVerificationTitle') verificationTitle: string = '网页验证';
  private sessionId: number = 0;
  private switchToken: number = 0;
  private measureSessionId: number = 0;
  private activeCoordinator: SearchCoordinator | null = null;
  private searchedSourceUrls: Set<string> = new Set<string>();
  private resumeBaseDone: number = 0;
  private lastPersistAt: number = 0;
  private persistTimer: number = -1;
  private destroyed: boolean = false;

  aboutToAppear(): void {
    if (!this.targetBook) {
      this.onClosed();
      return;
    }
    // 加载置顶书源列表到 AppStorage + 本地状态，下次搜索会优先搜。
    ChangeSourceOptionsStore.getPinnedSourceUrls(getContext(this)).then((urls: string[]) => {
      ChangeSourceOptionsStore.syncPinnedToStorage(urls);
      this.pinnedSourceUrls = new Set(urls);
    }).catch(() => {});
    ChangeSourceOptionsStore.getLoadWordCount(getContext(this))
      .then((value: boolean): void => {
        if (this.destroyed) return;
        this.loadWordCount = value;
        this.startSession();
      })
      .catch((): void => {
        if (this.destroyed) return;
        this.startSession();
      });
  }

  /** 关闭前先触发持久化再作废会话：节流窗口内未保存的 delta 会在关闭时丢失。 */
  aboutToDisappear(): void {
    this.destroyed = true;
    // 先捕获搜索是否仍在进行再作废状态：只有被中断的搜索才落盘 partial（重开时自动续搜）；
    // 已完成的搜索保留结果且不自动续搜，切换成功后重开面板直接显示历史结果。
    const searchInterrupted = this.searching;
    this.sessionId++;
    this.switchToken++;
    this.measureSessionId++;
    this.measuring = false;
    this.searching = false;
    this.clearPersistTimer();
    // 先持久化再取消：cancelActiveSearch 内部的 persistResultsNow 已经是 fire-and-forget，
    // 这里显式先调一次，确保 aboutToDisappear 的 grace period 内文件 IO 能完成。
    this.persistResultsNow(searchInterrupted);
    this.cancelActiveSearch(searchInterrupted);
  }

  startSession(): void {
    if (!this.targetBook) return;
    this.cancelActiveSearch();
    this.results = [];
    this.searchedSourceUrls = new Set<string>();
    this.failedBookUrls = [];
    this.status = '正在读取历史换源结果...';
    this.searching = true;
    this.canResumeSearch = false;
    this.switching = false;
    this.switchingBook = null;
    const sessionId = ++this.sessionId;
    this.loadHistoryThenSearch(sessionId);
  }

  async loadHistoryThenSearch(sessionId: number): Promise<void> {
    const book = this.targetBook;
    if (!book) return;
    try {
      const cached = await ChangeSourceResultCache.load(getContext(this), book.name, book.author,
        this.currentChapterIndex());
      if (!this.isSessionActive(sessionId)) return;
      if (cached && cached.results.length > 0) {
        // 禁用的书源不参与换源：丢弃历史结果里来自已禁用书源的条目（条数随过滤结果展示）。
        const enabledUrls = await this.loadEnabledSourceUrls();
        if (!this.isSessionActive(sessionId)) return;
        const usableResults = enabledUrls === null ? cached.results.slice() :
          cached.results.filter((item: SearchBook): boolean => enabledUrls.has(item.origin || ''));
        if (usableResults.length > 0) {
          this.updateResults(usableResults);
          for (const item of this.results) {
            item.author = BookFieldSanitizer.cleanAuthor(item.author);
            item.latestChapterTitle = BookFieldSanitizer.cleanChapterTitle(item.latestChapterTitle);
            item.wordCount = BookFieldSanitizer.cleanWordCount(item.wordCount);
          }
          this.searchedSourceUrls = new Set<string>();
          // 续搜计数基数只统计启用书源：历史会话可能积累后来被禁用的书源 URL，
          // 不过滤会导致"已搜索 x/总数"的 x 虚高（如 100 启用 + 100 禁用 = x/200）。
          for (const url of cached.searchedSourceUrls) {
            if (url && (enabledUrls === null || enabledUrls.has(url))) {
              this.searchedSourceUrls.add(url);
            }
          }
          if (cached.partial) {
            this.status = '已恢复上次搜索结果，正在继续搜索剩余书源...';
            this.search(sessionId, true);
            return;
          }
          this.searching = false;
          // 剩余书源 = 启用可搜索源 - 上次已搜源（上面已按启用集求过交集）；
          // 全部搜完则不再展示"可继续搜索剩余书源"和续搜按钮。
          const remainingSources = enabledUrls === null ? -1 :
            enabledUrls.size - this.searchedSourceUrls.size;
          if (remainingSources === 0) {
            this.canResumeSearch = false;
            this.status = `已显示历史结果，共 ${this.results.length} 个`;
          } else {
            this.canResumeSearch = true;
            this.status = `已显示历史结果，共 ${this.results.length} 个；可继续搜索剩余书源或清空重搜`;
          }
          if (this.loadWordCount) {
            this.startMeasureChapterWordCounts();
          }
          return;
        }
      }
    } catch (e) {
      console.warn('读取换源历史结果失败:', e);
    }
    if (this.isSessionActive(sessionId)) {
      this.search(sessionId, false);
    }
  }

  /** 启用书源 URL 集合；读取失败返回 null（跳过过滤，保持旧结果可用）。 */
  async loadEnabledSourceUrls(): Promise<Set<string> | null> {
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(getContext(this));
      const urls = await db.getEnabledBookSourceUrls();
      const enabled = new Set<string>();
      for (const url of urls) {
        if (url) enabled.add(url);
      }
      return enabled;
    } catch (e) {
      console.warn('读取启用书源失败:', e);
      return null;
    }
  }

  /**
   * 清空历史结果与磁盘缓存后从头重新搜索。
   * 旧结果可能残留已失效书源，合并保留没有意义，因此刷新即彻底重开。
   */
  async refreshResults(): Promise<void> {
    const target = this.targetBook;
    if (!target) return;
    if (this.switching) {
      this.cancelSwitch();
    }
    const sessionId = ++this.sessionId;
    this.clearPersistTimer();
    this.results = [];
    this.searchedSourceUrls = new Set<string>();
    this.failedBookUrls = [];
    this.measureSessionId++;
    this.measuring = false;
    this.cancelActiveSearch();
    this.searching = true;
    this.canResumeSearch = false;
    this.status = '已清空历史结果，正在重新搜索...';
    try {
      await ChangeSourceResultCache.clear(getContext(this), target.name, target.author);
    } catch (e) {
      console.warn('清空换源缓存失败:', e);
    }
    if (!this.isSessionActive(sessionId)) return;
    this.search(sessionId, false);
  }

  /** 手动停止前强制持久化，避免节流窗口内已到的 delta 丢失。 */
  stopSearch(): void {
    if (!this.searching) return;
    this.sessionId++;
    this.clearPersistTimer();
    this.persistResultsNow();
    this.cancelActiveSearch();
    this.searching = false;
    this.canResumeSearch = true;
    this.status = this.results.length > 0 ?
      `已停止搜索，共 ${this.results.length} 个结果，可继续搜索或清空重搜` :
      '已停止搜索，未找到可切换书源，可继续搜索或清空重搜';
    // 停止后搜索完成路径不会再执行，已搜到的部分结果要在这里补测量。
    this.startMeasureChapterWordCounts();
  }

  resumeSearch(): void {
    if (!this.targetBook || this.searching || this.switching) return;
    this.canResumeSearch = false;
    // 与 refreshResults 对齐：续搜会用新结果重排列表，旧的失败标记可能指向
    // 已不存在的条目，留着会误导用户跳过其实可用的书源。
    this.failedBookUrls = [];
    const sessionId = ++this.sessionId;
    this.search(sessionId, true);
  }

  requestClose(): void {
    // 切换中也允许关闭：下方 token 会作废在飞切换（未提交即静默中止）。
    this.sessionId++;
    this.switchToken++;
    this.measureSessionId++;
    this.measuring = false;
    this.clearPersistTimer();
    this.persistResultsNow();
    this.cancelActiveSearch();
    this.onClosed();
  }

  async search(sessionId: number, resume: boolean): Promise<void> {
    const target = this.targetBook;
    if (!target) return;
    const cacheBookName = target.name;
    const coordinator = new SearchCoordinator(SearchExploreSettingsStore.getSearchConcurrency());
    this.activeCoordinator = coordinator;
    this.searching = true;
    this.canResumeSearch = false;
    let finalTemporaryErrorCount = 0;
    if (!resume) {
      this.searchedSourceUrls = new Set<string>();
    }
    // 续搜是对"剩余书源"新建的搜索，done/total 从 0 计起；
    // 记录本次续搜前已搜过的书源数，把进度折算成累计值展示。
    this.resumeBaseDone = resume ? this.searchedSourceUrls.size : 0;
    if (!this.switching) {
      this.status = resume ?
        `已搜索 ${this.resumeBaseDone} 个书源，正在继续搜索剩余书源...` : '正在搜索可用书源...';
    }
    // 当前书源也参与搜索与展示（打"当前"徽标）：置顶当前源的用户期望在列表里看到它，
    // 点击切换等同刷新该源详情与目录，进度保留。
    const excludeSourceUrls: string[] = this.snapshotSearchedUrls();
    try {
      const results = await coordinator.search(target.name, (progress: SearchProgress) => {
        if (!this.isSessionActive(sessionId)) return;
        if (progress.finished) {
          this.updateResults(this.results.concat(progress.results));
        } else if (progress.deltaResults && progress.deltaResults.length > 0) {
          this.updateResults(this.results.concat(progress.deltaResults));
          this.persistResultsSoon();
          // 字数是用户判断书源可用性的首要依据：delta 到达即启动早期低优测量（3 路、仅纯本地规则源，
          // 不碰与 JS 搜索共享的 ArkWeb 宿主池）；置顶/靠前结果的字数不必再等几千个源全部搜完。
          // JS 源与早期失败项由搜索结束后的全量轮次（12 路）补齐/重试。
          this.startEarlyMeasureChapterWordCounts();
        }
        if (!this.switching) {
          this.status = resume ? this.applyResumeProgressOffset(progress) : progress.status;
        }
        if (progress.finished) {
          this.searching = false;
          finalTemporaryErrorCount = progress.temporaryErrorCount;
          // 一轮搜索覆盖全部启用书源时 done === total；但其中部分源可能是临时超时/失败，
          // 它们没真正搜到，"继续搜索"应该重搜这些源，所以 done === total 时也要允许续搜。
          this.canResumeSearch = progress.total > 0 &&
            (progress.done < progress.total || progress.temporaryErrorCount > 0);
        }
      }, {
        exactMatch: true,
        authorKeyword: target.author,
        leanResult: true,
        excludeSourceUrls: excludeSourceUrls,
        maxResultsPerSource: 2,
        maxTotalResults: 60,
        // 提前收工阈值走全局设置（默认 0 = 搜完全部启用书源，不提前收工）：
        // 非 0 时攒够该数量结果就收工，"搜索完成"之外会出现"继续搜索"补搜剩余书源。
        stopAfterResults: SearchExploreSettingsStore.getStopAfterResults(),
        maxCandidatesPerSource: 32,
        onSourceComplete: (source: BookSource, result: SearchSourceResult): Promise<void> => {
          const url = source.bookSourceUrl || '';
          // 临时错误（超时/网络波动）的源不标记为已搜，续搜时可以重试；
          // 其他状态（搜到结果/搜完无结果/规则失败/需要验证）都算真正搜过。
          if (url && result.validationStatus !== BookSource.VALIDATION_TEMPORARY_ERROR) {
            this.searchedSourceUrls.add(url);
          }
          return Promise.resolve();
        }
      });
      if (!this.isSessionActive(sessionId)) return;
      this.updateResults(this.results.concat(results));
      if (!this.switching) {
        const partialMsg = finalTemporaryErrorCount > 0 ?
          `，${finalTemporaryErrorCount} 个源超时或失败，可继续搜索重试` : '';
        if (this.canResumeSearch) {
          const partialSuffix = finalTemporaryErrorCount > 0 ? partialMsg : '，仍有书源未搜索';
          this.status = this.results.length > 0 ?
            `已找到 ${this.results.length} 个可切换书源${partialSuffix}` :
            `未找到可切换书源${partialSuffix}`;
        } else {
          this.status = this.results.length > 0 ?
            `搜索完成，找到 ${this.results.length} 个可切换书源` : '搜索完成，未找到可切换书源';
        }
      }
      try {
        // 搜索已正常结束：partial 只表示"被中断"，完成态落盘 false，
        // 重开面板直接展示历史结果。
        await ChangeSourceResultCache.save(getContext(this), cacheBookName, this.results, target.author,
          this.snapshotSearchedUrls(), false, this.currentChapterIndex());
      } catch (e) {
        console.warn('保存换源结果失败:', e);
      }
      if (this.loadWordCount) {
        this.startMeasureChapterWordCounts();
      }
    } catch (e) {
      if (!this.isSessionActive(sessionId)) return;
      console.error('搜索换源失败:', e);
      this.status = '搜索换源失败';
      // 失败前已完成的书源允许续搜，避免整轮重搜已搜过的书源。
      this.canResumeSearch = this.searchedSourceUrls.size > 0;
      // 搜索已终止：先复位 searching，测量启动门控才放行（finally 再赋一次无害）。
      this.searching = false;
      // 失败前 delta 已展示的结果同样需要测量。
      this.startMeasureChapterWordCounts();
    } finally {
      if (this.activeCoordinator === coordinator) {
        this.activeCoordinator = null;
      }
      if (this.isSessionActive(sessionId)) {
        this.searching = false;
      }
    }
  }

  /** 作废进行中的切换：未提交的切换在下一个校验点静默中止，状态立即回收供新切换接管。 */
  cancelSwitch(): void {
    this.switchToken++;
    this.switching = false;
    this.switchingBook = null;
  }

  /** 切换取链限时：慢/死书源可能长时间不返回，超时抛错按切换失败处理；等待期间可随时改选其它书源。 */
  async withSwitchTimeout<T>(task: Promise<T>, label: string): Promise<T> {
    let timerId = -1;
    const timeout = new Promise<T>((_resolve: (value: T) => void, reject: (reason: Error) => void) => {
      timerId = setTimeout((): void => {
        reject(new Error(`${label}超时`));
      }, SWITCH_FETCH_TIMEOUT_MS);
    });
    try {
      return await Promise.race([task, timeout]);
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  async switchSource(searchBook: SearchBook): Promise<void> {
    const target = this.targetBook;
    if (!target) return;
    if (this.switching) {
      // 慢/死书源不必干等：直接改选其它书源，作废当前切换（未提交即静默中止）后开始新切换。
      this.cancelSwitch();
    }
    const token = ++this.switchToken;
    this.switching = true;
    this.switchingBook = searchBook;
    this.status = '正在切换书源...';
    if (this.onBeforeSwitch) {
      // 放在 try 外 await，宿主回调抛异常会让 switching 永久为 true，堵死后续测量与切换。
      try {
        await this.onBeforeSwitch();
      } catch (e) {
        console.warn('切换前回调失败:', e);
      }
    }
    const oldBookUrl = target.bookUrl;
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(getContext(this));
      const oldBook = await db.getBook(oldBookUrl);
      const source = searchBook.origin ? await db.getBookSource(searchBook.origin) : null;
      if (!source) {
        HdsFeedback.showToast('书源不存在或已删除');
        return;
      }
      if (!source.enabled) {
        HdsFeedback.showToast('该书源已禁用，请在书源管理中启用后再切换');
        return;
      }
      if (token !== this.switchToken) return;

      const nextBook = this.buildSourceBook(searchBook, oldBook || target);
      const service = new WebBookService();
      const fullBook = await this.withSwitchTimeout(service.getBookInfo(source, nextBook), '获取书籍详情');
      if (token !== this.switchToken) return;
      this.preserveSourceBookState(fullBook, nextBook, oldBook || target);
      const chapters = await this.withSwitchTimeout(service.getChapterList(source, fullBook, 0, false), '获取目录');
      if (token !== this.switchToken) return;
      if (chapters.length === 0) throw new Error('新书源目录为空，已保留原书源');
      fullBook.totalChapterNum = chapters.length;
      const safeIndex = Math.max(0, Math.min((oldBook || target).durChapterIndex, chapters.length - 1));
      fullBook.durChapterIndex = safeIndex;
      fullBook.durChapterTitle = chapters[safeIndex].title;
      fullBook.latestChapterTitle = chapters[chapters.length - 1].title;

      // 只有书库中已存在该书的持久化行时才提交换源；纯搜索结果只把新源书籍交还宿主展示。
      if (oldBook) {
        await db.commitBookSourceSwitch(oldBookUrl, fullBook, chapters);
        AppStorage.setOrCreate('shelfUpdateTime', Date.now());
        // 提交落库期间用户可能已改选其它书源或关闭面板：切换已生效，收尾交由接管方，避免二次关闭。
        if (token !== this.switchToken) return;
      }

      HdsFeedback.showToast(`已切换至 ${fullBook.originName || searchBook.originName}`);
      // 新书源的书名/作者可能与原书不同（作者名差异最常见，如"天蚕土豆"vs"天蚕土豆 著"）。
      // 换源结果缓存按 书名+作者 取键：若不迁移身份，关闭面板后旧键缓存读不到，
      // 再次打开换源会缓存 miss 而整轮从头搜索。先把目标切到新书身份再落盘，并清掉旧键。
      const previousIdentityName = target.name;
      const previousIdentityAuthor = target.author;
      const identityChanged = fullBook.name !== previousIdentityName ||
        fullBook.author !== previousIdentityAuthor;
      this.targetBook = fullBook;
      this.switchToken++;
      this.sessionId++;
      this.clearPersistTimer();
      // 取消在搜轮次并按新身份落盘（partial 跟随 searching，重开面板可续搜剩余书源）。
      if (this.activeCoordinator) {
        this.activeCoordinator.cancel();
        this.activeCoordinator = null;
        this.persistResultsNow();
      }
      if (identityChanged) {
        // writeChain 串行保证"新键保存"先于"旧键删除"，不会误删新条目。
        ChangeSourceResultCache.clear(getContext(this), previousIdentityName, previousIdentityAuthor)
          .catch((): void => {});
      }
      this.onSwitched(fullBook);
      this.onClosed();
    } catch (e) {
      if (token !== this.switchToken) return;
      console.error('切换书源失败:', e);
      if (!this.failedBookUrls.includes(searchBook.bookUrl)) {
        this.failedBookUrls.push(searchBook.bookUrl);
      }
      HdsFeedback.showToast('切换失败，可继续尝试其它书源');
    } finally {
      if (token === this.switchToken) {
        this.switching = false;
        this.switchingBook = null;
        if (!this.searching) {
          this.status = this.results.length > 0 ?
            `共 ${this.results.length} 个可切换书源` : '未找到可切换书源，可点击刷新重新搜索';
        }
        // 切换期间完成的搜索会因 switching 守卫错过测量启动，切换结束后补启动：
        // 搜索已结束走全量轮次，搜索仍在进行则恢复早期低优轮次（等下一波 delta 也行，主动拉起更快）。
        if (this.searching) {
          this.startEarlyMeasureChapterWordCounts();
        } else {
          this.startMeasureChapterWordCounts();
        }
      }
    }
  }

  isSessionActive(sessionId: number): boolean {
    return sessionId === this.sessionId;
  }

  cancelActiveSearch(interrupted?: boolean): void {
    if (this.activeCoordinator) {
      this.activeCoordinator.cancel();
      this.activeCoordinator = null;
      this.persistResultsNow(interrupted);
    }
  }

  toggleLoadWordCount(): void {
    this.loadWordCount = !this.loadWordCount;
    ChangeSourceOptionsStore.setLoadWordCount(getContext(this), this.loadWordCount)
      .catch((): void => {
      });
    if (this.loadWordCount) {
      // 开启后切换为实测本章字数优先排序；搜索进行中直接拉起早期低优轮次（3 路、纯本地规则源），
      // 搜索 finished/停止分支再升级为 12 路全量轮次。
      this.sortResults();
      if (this.searching) {
        this.startEarlyMeasureChapterWordCounts();
      } else {
        this.startMeasureChapterWordCounts();
      }
    } else {
      this.measureSessionId++;
      this.measuring = false;
      // 关闭后回到最新章节号优先排序。
      this.sortResults();
    }
  }

  /** 切换书源置顶：置顶后立即排到列表最前，下次换源也优先搜索。 */
  togglePinnedSource(sourceUrl: string): void {
    ChangeSourceOptionsStore.togglePinnedSource(getContext(this), sourceUrl).then((pinned: string[]) => {
      this.pinnedSourceUrls = new Set(pinned);
      this.sortResults();
    }).catch(() => {});
  }

  isSourcePinned(sourceUrl: string): boolean {
    return this.pinnedSourceUrls.has(sourceUrl || '');
  }

  /** 目标书当前阅读章节序号：缓存的"当前章节字数"与测量都以它为准，换源前先刷新阅读进度。 */
  currentChapterIndex(): number {
    const target = this.targetBook;
    return target ? Math.max(0, target.durChapterIndex) : -1;
  }

  /** 全量测量轮次：搜索结束/停止/历史结果加载后运行（12 路，含 JS 书源）。 */
  startMeasureChapterWordCounts(): void {
    // 切换中不测；搜索中由 startEarlyMeasureChapterWordCounts 的低优早期轮次接管，
    // finished/stop 分支在 searching 复位后调用本方法升级为全量轮次。
    if (!this.loadWordCount || this.switching || this.searching) return;
    // 每次调用都重启一轮测量并作废在飞的旧会话：
    // 旧会话若因失败项重测不退出，measuring 会一直为 true，把后续新结果的测量全部挡掉。
    this.measureSessionId++;
    this.measuring = true;
    this.measureChapterWordCounts(this.measureSessionId, false);
  }

  /**
   * 搜索进行中的早期低优测量：3 路并发，且只测不占用 ArkWeb 宿主的纯本地规则源。
   * 候选源都已完成自己的搜索（同源自令牌不冲突），HTTP 在飞上限 128 有余量；
   * JS 源留给搜索结束后的全量轮次，从根上避免抢占 3 槽宿主导致在搜 JS 源限流/超时。
   */
  startEarlyMeasureChapterWordCounts(): void {
    if (!this.loadWordCount || this.switching || !this.searching) return;
    // 早期轮次已在跑就不重启：外循环每轮重新收集 pending，后续 delta 会自然纳入。
    if (this.measuring) return;
    this.measureSessionId++;
    this.measuring = true;
    this.measureChapterWordCounts(this.measureSessionId, true);
  }

  /** 早期轮次专用：从待测项筛出纯本地规则源；JS 源/失效源标记 attempted 让本轮收敛退出，
   *  全量轮次会用全新 attempted 集合重新纳入 JS 源。书源对象本地缓存，避免每轮重复查库。 */
  async filterEarlyMeasurable(pending: SearchBook[], attempted: Set<string>,
    sourceCache: Map<string, BookSource | undefined>): Promise<SearchBook[]> {
    const db = AppDatabase.getInstance();
    await db.initWithContext(getContext(this));
    const measurable: SearchBook[] = [];
    for (const item of pending) {
      const key = `${item.origin || ''}\n${item.bookUrl}`;
      const sourceUrl = item.origin || '';
      let source: BookSource | undefined = sourceCache.get(sourceUrl);
      if (source === undefined && !sourceCache.has(sourceUrl)) {
        source = (sourceUrl ? await db.getBookSource(sourceUrl) : null) ?? undefined;
        sourceCache.set(sourceUrl, source);
      }
      if (source && !WebBookService.measurementRequiresStage(source, !item.tocUrl)) {
        measurable.push(item);
      } else {
        attempted.add(key);
      }
    }
    return measurable;
  }

  /** 未测(-1)与测量失败(0)都收集（最新章节或当前阅读章节任一字段未完成即待测）；
   *  本会话已尝试过的跳过，避免失败项让测量循环永不退出。
   *  "未收录"(reached=false)是确定性结论：最新章字数已测清即视为完成，避免每次重开面板都为落后源
   *  重新拉取整本长目录（目录追更由 24h 缓存过期或清空重搜兜底）。 */
  collectPendingMeasurements(attempted: Set<string>): SearchBook[] {
    const pending: SearchBook[] = [];
    for (const item of this.results) {
      const currentSettled = item.currentChapterWordCount > 0 || item.currentChapterReached === false;
      if (item.chapterWordCount > 0 && currentSettled) continue;
      const key = `${item.origin || ''}\n${item.bookUrl}`;
      if (attempted.has(key)) continue;
      pending.push(item);
    }
    return pending;
  }

  /**
   * 测量主循环。earlyMode=true（搜索进行中）：3 路、仅纯本地规则源；剩余项全为 JS 源时本轮退出，
   * 不空转占资源，新 delta 到达会再起一轮。搜索结束时 finish/stop 分支 bump 会话并以
   * earlyMode=false 重启（12 路，全部源），在飞早期测量通过 shouldAbort 在检查点静默收工。
   */
  async measureChapterWordCounts(measureSession: number, earlyMode: boolean): Promise<void> {
    let measuredAny = false;
    const attempted = new Set<string>();
    const sourceCache: Map<string, BookSource | undefined> = new Map();
    try {
      while (this.loadWordCount && !this.switching &&
        measureSession === this.measureSessionId) {
        // 早期轮次只存活于搜索中；搜索结束由全量轮次接管。
        if (earlyMode && !this.searching) break;
        const pendingAll = this.collectPendingMeasurements(attempted);
        if (pendingAll.length === 0) break;
        let pending: SearchBook[] = pendingAll;
        if (earlyMode) {
          pending = await this.filterEarlyMeasurable(pendingAll, attempted, sourceCache);
          if (measureSession !== this.measureSessionId) return;
          if (pending.length === 0) break;
        }
        let nextIndex = 0;
        const worker = async (): Promise<void> => {
          while (this.loadWordCount && !this.switching &&
            measureSession === this.measureSessionId) {
            if (earlyMode && !this.searching) return;
            const index = nextIndex++;
            if (index >= pending.length) break;
            const candidate = pending[index];
            const changed = await this.measureOneWithTimeout(candidate, measureSession);
            if (measureSession !== this.measureSessionId) return;
            attempted.add(`${candidate.origin || ''}\n${candidate.bookUrl}`);
            if (changed) {
              measuredAny = true;
              this.sortResults();
            }
          }
        };
        const workers: Promise<void>[] = [];
        const workerCount = earlyMode ? EARLY_MEASURE_WORKER_COUNT : MEASURE_WORKER_COUNT;
        for (let i = 0; i < workerCount; i++) {
          workers.push(worker());
        }
        await Promise.all(workers);
        if (measureSession !== this.measureSessionId) return;
      }
    } catch (e) {
      // 与 Index.ets 搜索页的同构实现对齐：测量链路 reject 不能无人处理。
      console.warn(earlyMode ? '换源早期字数测量失败:' : '换源字数测量失败:', e);
    } finally {
      this.sortResults();
      if (measureSession === this.measureSessionId) {
        this.measuring = false;
      }
      const target = this.targetBook;
      // destroyed 后交由 aboutToDisappear 的持久化收尾（其 partial 状态才正确），避免迟到的覆写。
      if (measuredAny && !this.destroyed && !this.switching && target && this.results.length > 0) {
        try {
          await ChangeSourceResultCache.save(getContext(this), target.name, this.results, target.author,
            this.snapshotSearchedUrls(), this.searching, this.currentChapterIndex());
        } catch (e) {
          console.warn('保存换源字数结果失败:', e);
        }
      }
    }
  }

  /** 单条测量限时包装：超时置失败并释放 worker；迟到的实测值仍会写入对象，由会话收尾的排序触发刷新。 */
  async measureOneWithTimeout(candidate: SearchBook, measureSession: number): Promise<boolean> {
    let timerId = -1;
    let timedOut = false;
    const timeout = new Promise<boolean>((resolve: (value: boolean) => void) => {
      timerId = setTimeout((): void => {
        timedOut = true;
        resolve(false);
      }, MEASURE_ITEM_TIMEOUT_MS);
    });
    try {
      const changed = await Promise.race([this.measureOneChapterWordCount(candidate, measureSession), timeout]);
      if (timedOut && measureSession === this.measureSessionId && !this.switching) {
        // 两个字数都置失败，防止任一字段残留 -1 让待测收集永远选中该条。
        candidate.chapterWordCount = 0;
        candidate.currentChapterWordCount = 0;
        return true;
      }
      return changed;
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  async measureOneChapterWordCount(candidate: SearchBook, measureSession: number): Promise<boolean> {
    const db = AppDatabase.getInstance();
    await db.initWithContext(getContext(this));
    // 同时测量目标书当前阅读章节的字数：换源最关心的量（不同源同一章的内容完整度）。
    const target = this.targetBook;
    const currentChapter = new ChapterMeasureTarget();
    if (target) {
      currentChapter.index = target.durChapterIndex;
      currentChapter.title = target.durChapterTitle || '';
    }
    return ChapterWordCountMeasurer.measureOne(db, candidate, (): boolean =>
      measureSession !== this.measureSessionId || this.switching, currentChapter);
  }

  /** 章节标题过长会挤掉徽标里的字数，截断到固定长度保证字数可见。 */
  truncateChipTitle(title: string): string {
    const max = 12;
    return title.length > max ? `${title.substring(0, max)}…` : title;
  }

  /**
   * 当前章字数的状态：与失败态显式分开。
   * 目录未收录阅读章节是该源"落后于阅读进度"的正常情况（排序时单独沉底），
   * 不是错误，不能与网络/解析失败共用一种红色文案。
   */
  currentChapterWordCountText(book: SearchBook): string {
    if (!book.currentChapterReached) {
      return '未收录';
    }
    return this.wordCountText(book.currentChapterWordCount);
  }

  /** 当前章徽标：字数放最前（省略号只截尾部，字数永远可见），章节标题截断后放括号里。 */
  currentChipText(book: SearchBook): string {
    const target = this.targetBook;
    const title = target ? (target.durChapterTitle || '').trim() : '';
    const chapterText = title ? ` （${this.truncateChipTitle(title)}）` :
      (target ? ` （第${target.durChapterIndex + 1}章）` : '');
    return `当前：${this.currentChapterWordCountText(book)}${chapterText}`;
  }

  /** 最新章徽标：复用搜索结果已有的最新章标题，字数放最前保证可见。 */
  latestChipText(book: SearchBook): string {
    const title = (book.latestChapterTitle || '').trim();
    const chapterText = title ? ` （${this.truncateChipTitle(title)}）` :
      (book.latestChapterIndex >= 0 ? ` （第${book.latestChapterIndex + 1}章）` : '');
    return `最新：${this.wordCountText(book.chapterWordCount)}${chapterText}`;
  }

  wordCountText(count: number): string {
    if (count > 0) {
      return WordCountFormatter.formatWithUnit(count);
    }
    if (count === 0) {
      return '获取失败';
    }
    // -1 是"从未测过"：只有开启字数优先才会去测，关着的时候说"测量中"是假状态。
    return this.loadWordCount ? '测量中' : '未测量';
  }

  /**
   * 当前章徽标配色：区分"未收录"与"真失败"。
   * 未收录是排序用的中性信息（该源只到较早章节），用次级文字色；
   * 只有实测失败/超时才用错误红。
   */
  currentChipTextColor(book: SearchBook): string {
    if (!book.currentChapterReached) {
      return this.subTextColor();
    }
    if (book.currentChapterWordCount > 0) {
      return this.primaryTextColor();
    }
    if (book.currentChapterWordCount === 0) {
      return this.errorColor();
    }
    return this.subTextColor();
  }

  /** 最新章徽标配色：无"未收录"状态，实测失败才标红。 */
  latestChipTextColor(book: SearchBook): string {
    if (book.chapterWordCount > 0) {
      return this.primaryTextColor();
    }
    if (book.chapterWordCount === 0) {
      return this.errorColor();
    }
    return this.subTextColor();
  }

  /** 错误色：统一走主题的 dangerColor，跟随深色模式与用户自定义主题。 */
  errorColor(): string {
    return ThemeRuntime.dangerColor(this.appDarkMode);
  }

  snapshotSearchedUrls(): string[] {
    const urls: string[] = [];
    this.searchedSourceUrls.forEach((url: string) => {
      urls.push(url);
    });
    return urls;
  }

  /**
   * 续搜时把协调器"0/剩余数"的进度折算为累计进度（已搜 + 本次）。
   * 只替换状态串开头的"已搜索 x/y，"，格式不匹配时原样返回。
   */
  applyResumeProgressOffset(progress: SearchProgress): string {
    const status = progress.status || '';
    if (!status) return status;
    const done = this.resumeBaseDone + progress.done;
    const total = this.resumeBaseDone + progress.total;
    return status.replace(/^已搜索 \d+\/\d+，/, `已搜索 ${done}/${total}，`);
  }

  persistResultsSoon(): void {
    if (this.results.length === 0) return;
    const now = Date.now();
    if (now - this.lastPersistAt >= PERSIST_INTERVAL_MS) {
      this.persistResultsNow();
      return;
    }
    if (this.persistTimer === -1) {
      this.persistTimer = setTimeout(() => {
        this.persistTimer = -1;
        this.persistResultsNow();
      }, PERSIST_INTERVAL_MS - (now - this.lastPersistAt));
    }
  }

  /** 持久化当前结果；partial 仅在搜索仍在进行（被关闭/切换中断）时为 true，重开面板可自动续搜；
   *  已完成的搜索落盘为非 partial，重开时直接展示历史结果，不再自动续搜。 */
  async persistResultsNow(interrupted?: boolean): Promise<void> {
    this.lastPersistAt = Date.now();
    const target = this.targetBook;
    if (!target || this.results.length === 0) return;
    const partial = interrupted !== undefined ? interrupted : this.searching;
    try {
      await ChangeSourceResultCache.save(getContext(this), target.name, this.results, target.author,
        this.snapshotSearchedUrls(), partial, this.currentChapterIndex());
    } catch (e) {
      console.warn('暂存换源结果失败:', e);
    }
  }

  clearPersistTimer(): void {
    if (this.persistTimer !== -1) {
      clearTimeout(this.persistTimer);
      this.persistTimer = -1;
    }
  }

  /** 打开网页验证页；验证完成返回后 pendingVerificationUrl 被清空，"去验证"按钮自动消失。 */
  openVerification(): void {
    const url = this.verificationUrl || AppStorage.get<string>('pendingVerificationUrl') || '';
    if (!url) {
      HdsFeedback.showToast('暂无需要验证的网页');
      return;
    }
    router.pushUrl({
      url: 'pages/VerifyWeb',
      params: {
        url: url,
        title: this.verificationTitle || '网页验证'
      }
    });
  }

  /** 过滤 + 排序后整体替换结果列表；排序规则见 SearchResultSorter：
   *  开启本章字数时按实测字数从大到小优先（主键当前阅读章节字数，相同再按最新章节字数、最新章节号），
   *  关闭时最新章节号从大到小优先（相同再按字数），实测失败沉底；
   *  置顶书源始终排在最前（组内仍按上述规则排序），点击置顶立即生效。 */
  updateResults(raw: SearchBook[]): void {
    const target = this.targetBook;
    if (!target) return;
    this.results = this.sortWithPinnedFirst(this.filterResults(raw));
  }

  sortResults(): void {
    this.results = this.sortWithPinnedFirst(this.results.slice());
  }

  sortWithPinnedFirst(list: SearchBook[]): SearchBook[] {
    if (this.pinnedSourceUrls.size === 0) {
      return SearchResultSorter.sort(list, this.loadWordCount);
    }
    const pinned: SearchBook[] = [];
    const rest: SearchBook[] = [];
    for (const item of list) {
      if (this.isSourcePinned(item.origin || '')) {
        pinned.push(item);
      } else {
        rest.push(item);
      }
    }
    return SearchResultSorter.sort(pinned, this.loadWordCount)
      .concat(SearchResultSorter.sort(rest, this.loadWordCount));
  }

  filterResults(results: SearchBook[]): SearchBook[] {
    const filtered: SearchBook[] = [];
    const seen = new Set<string>();
    for (const result of results) {
      // 当前书本身（同源同地址）保留展示并打"当前"徽标，不再过滤。
      if (!result.bookUrl || SearchBookShelfHelper.isNavigationResult(result)) continue;
      const key = `${result.origin || ''}\n${result.bookUrl}`;
      if (seen.has(key)) continue;
      seen.add(key);
      filtered.push(result);
    }
    return filtered;
  }

  isCurrentSourceResult(book: SearchBook): boolean {
    const target = this.targetBook;
    return !!target && book.bookUrl === target.bookUrl && book.origin === target.origin;
  }

  buildSourceBook(searchBook: SearchBook, oldBook: Book): Book {
    const book = new Book();
    book.bookUrl = searchBook.bookUrl;
    book.tocUrl = searchBook.tocUrl;
    book.origin = searchBook.origin;
    book.originName = searchBook.originName;
    book.name = searchBook.name || oldBook.name;
    book.author = searchBook.author || oldBook.author;
    book.kind = BookFieldSanitizer.prefer(searchBook.kind, oldBook.kind);
    book.status = BookFieldSanitizer.prefer(searchBook.status, oldBook.status);
    book.coverUrl = CoverUrlNormalizer.prefer(searchBook.coverUrl, oldBook.coverUrl);
    book.customCoverUrl = oldBook.customCoverUrl;
    book.intro = BookFieldSanitizer.prefer(searchBook.intro, oldBook.intro);
    book.customIntro = oldBook.customIntro;
    book.latestChapterTitle = BookFieldSanitizer.prefer(searchBook.latestChapterTitle, oldBook.latestChapterTitle);
    book.updateTime = BookFieldSanitizer.prefer(searchBook.updateTime, oldBook.updateTime);
    book.wordCount = BookFieldSanitizer.prefer(searchBook.wordCount, oldBook.wordCount);
    book.variable = searchBook.variable || '';
    book.group = oldBook.group;
    book.isPinned = oldBook.isPinned;
    book.order = oldBook.order;
    book.originOrder = oldBook.originOrder;
    book.readConfig = oldBook.readConfig;
    book.canUpdate = oldBook.canUpdate;
    book.type = oldBook.type;
    book.durChapterIndex = oldBook.durChapterIndex;
    book.durChapterPos = oldBook.durChapterPos;
    book.durChapterTitle = oldBook.durChapterTitle;
    book.durChapterTime = oldBook.durChapterTime;
    book.pendingAddToShelf = oldBook.pendingAddToShelf;
    if (this.markReadOnSwitch) {
      book.putVariable('readStarted', '1');
      book.putVariable('lastReadTime', `${Date.now()}`);
    }
    return book;
  }

  preserveSourceBookState(target: Book, source: Book, oldBook: Book): void {
    target.origin = source.origin;
    target.originName = source.originName;
    target.coverUrl = CoverUrlNormalizer.prefer(source.coverUrl, target.coverUrl);
    target.group = oldBook.group;
    target.isPinned = oldBook.isPinned;
    target.order = oldBook.order;
    target.originOrder = oldBook.originOrder;
    target.customCoverUrl = oldBook.customCoverUrl;
    target.customIntro = oldBook.customIntro;
    target.readConfig = oldBook.readConfig;
    target.canUpdate = oldBook.canUpdate;
    target.durChapterIndex = oldBook.durChapterIndex;
    target.durChapterPos = oldBook.durChapterPos;
    target.durChapterTitle = oldBook.durChapterTitle;
    target.durChapterTime = oldBook.durChapterTime;
    target.syncTime = oldBook.syncTime;
    target.pendingAddToShelf = oldBook.pendingAddToShelf;
    if (this.markReadOnSwitch) {
      target.putVariable('readStarted', '1');
      target.putVariable('lastReadTime', `${Date.now()}`);
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.requestClose();
        })

      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('换源')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryTextColor())
            Text(`《${this.targetBook?.name || ''}》`)
              .fontSize(12)
              .fontColor(this.subTextColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.searching) {
            LoadingProgress()
              .width(22)
              .height(22)
              .margin({ right: 2 })
            Button('停止')
              .height(30)
              .fontSize(13)
              .borderRadius(15)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.buttonColor())
              .fontColor('#FFFFFF')
              .margin({ right: 6 })
              .onClick(() => this.stopSearch())
          }
          // 字数优先开关常驻：搜索中也能随时开关，不再随搜索状态隐藏；
          // 关闭时灰色显示"字数优先"，开启时高亮显示，保持排序选项始终可见。
          Button('字数优先')
            .height(30)
            .fontSize(12)
            .borderRadius(15)
            .padding({ left: 10, right: 10 })
            .fontColor(this.loadWordCount ? '#FFFFFF' : this.subTextColor())
            .backgroundColor(this.loadWordCount ? this.buttonColor() : this.inputColor())
            .margin({ right: 4 })
            .onClick(() => this.toggleLoadWordCount())
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(21)
            .fontColor([this.primaryTextColor()])
            .width(40)
            .height(40)
            .margin({ right: 4 })
            .onClick(() => {
              this.refreshResults();
            })
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([this.primaryTextColor()])
            .width(40)
            .height(40)
            .onClick(() => {
              this.requestClose();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(this.status || '将使用当前书名进行全词匹配搜索')
            .fontSize(13)
            .fontColor(this.subTextColor())
            .layoutWeight(1)
          if (this.canResumeSearch && !this.searching && !this.switching) {
            Button('继续搜索')
              .height(28)
              .fontSize(12)
              .borderRadius(14)
              .padding({ left: 10, right: 10 })
              .backgroundColor(this.buttonColor())
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
              .onClick(() => this.resumeSearch())
          }
          if (this.verificationUrl && !this.switching) {
            Button('去验证')
              .height(28)
              .fontSize(12)
              .borderRadius(14)
              .padding({ left: 10, right: 10 })
              .backgroundColor(this.buttonColor())
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
              .onClick(() => this.openVerification())
          }
        }
        .width('100%')
        .margin({ top: 8, bottom: 10 })

        if (this.searching && this.results.length === 0) {
          Column({ space: 10 }) {
            LoadingProgress().width(36).height(36)
            Text('正在搜索可用书源...')
              .fontSize(13)
              .fontColor(this.subTextColor())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.results.length === 0) {
          Text('暂无可切换书源')
            .fontSize(15)
            .fontColor(this.subTextColor())
            .width('100%')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.results, (book: SearchBook) => {
              ListItem() {
                Column({ space: 4 }) {
                  Row({ space: 4 }) {
                    Text(book.originName || book.origin)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    if (this.isCurrentSourceResult(book)) {
                      Text('当前')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .borderRadius(6)
                        .backgroundColor('#2196F3')
                    }
                    if (this.isSourcePinned(book.origin || '')) {
                      Text('置顶')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .borderRadius(6)
                        .backgroundColor('#FF9800')
                    }
                    SymbolGlyph(this.isSourcePinned(book.origin || '') ?
                      $r('sys.symbol.pin_fill') : $r('sys.symbol.pin'))
                      .fontSize(18)
                      .fontColor([this.isSourcePinned(book.origin || '') ? '#FF9800' : this.subTextColor()])
                      .width(28)
                      .height(28)
                      .onClick(() => this.togglePinnedSource(book.origin || ''))
                    Button(this.switching && this.switchingBook === book ? '切换中' : '切换')
                      .width(72)
                      .height(32)
                      .fontSize(13)
                      .borderRadius(16)
                      .backgroundColor(this.buttonColor())
                      .fontColor('#FFFFFF')
                      // 切换中不锁其它书源：慢/死书源可直接改选，避免只能等待或退出。
                      .onClick(() => this.switchSource(book))
                  }
                  .width('100%')
                  Text(`作者：${book.author || '未知'} · 最新：${book.latestChapterTitle || '书源未提供'}`)
                    .fontSize(12)
                    .fontColor(this.subTextColor())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  // 当前章与最新章字数分两行常驻展示：未测/测不到时显示"测量中/获取失败"，
                  // 不隐藏——行数恒定，横向对比各源时不会因数据缺失而错位。
                  Column({ space: 4 }) {
                    Text(this.currentChipText(book))
                      .fontSize(11)
                      .fontColor(this.currentChipTextColor(book))
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(9)
                      .backgroundColor(this.chipColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(this.latestChipText(book))
                      .fontSize(11)
                      .fontColor(this.latestChipTextColor(book))
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(9)
                      .backgroundColor(this.chipColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                  .width('100%')
                  if (this.failedBookUrls.includes(book.bookUrl)) {
                    Text('该源切换失败，建议尝试其它书源')
                      .fontSize(11)
                      .fontColor(this.errorColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(12)
                .backgroundColor(this.inputColor())
                .borderRadius(10)
              }
            }, (book: SearchBook) => `${book.origin}|${book.bookUrl}|${book.chapterWordCount}|${book.currentChapterWordCount}|${book.latestChapterIndex}|${book.currentChapterReached}|${book.latestChapterTitle}|${this.isSourcePinned(book.origin || '') ? 'p' : 'np'}`)

            if (this.searching) {
              ListItem() {
                Row({ space: 8 }) {
                  LoadingProgress().width(20).height(20)
                  Text('继续加载中...').fontSize(13).fontColor(this.subTextColor())
                }
                .width('100%')
                .height(42)
                .justifyContent(FlexAlign.Center)
              }
            } else if (this.measuring) {
              ListItem() {
                Row({ space: 8 }) {
                  LoadingProgress().width(20).height(20)
                  Text('正在测量章节字数...').fontSize(13).fontColor(this.subTextColor())
                }
                .width('100%')
                .height(42)
                .justifyContent(FlexAlign.Center)
              }
            }
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('90%')
      .height('75%')
      .padding(20)
      .borderRadius(ThemeRuntime.glassCornerRadius(14, 'panel'))
      .clip(true)
      .backgroundColor(ThemeRuntime.glassPanelColor(this.appDarkMode, '', 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({ width: ThemeRuntime.glassBorderWidth('panel'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel') })
    }
    .width('100%')
    .height('100%')
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  buttonColor(): string {
    return ThemeRuntime.buttonColor(this.appDarkMode);
  }

  inputColor(): string {
    return ThemeRuntime.inputColor(this.appDarkMode);
  }

  /** 字数徽标底色：卡片背景是 inputColor，徽标用半透明叠加色区分层级。 */
  chipColor(): string {
    return this.appDarkMode ? '#24FFFFFF' : '#14000000';
  }
}

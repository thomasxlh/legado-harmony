import { Book, BookSource, SearchBook } from '../model/data/Book';
import { AppDatabase } from '../model/data/AppDatabase';
import { SearchCoordinator, SearchProgress, SearchSourceResult } from '../core/book/SearchCoordinator';
import { WebBookService } from '../core/book/WebBookService';
import { ChapterWordCountMeasurer } from '../core/book/ChapterWordCountMeasurer';
import { ChangeSourceCacheData, ChangeSourceResultCache } from '../utils/ChangeSourceResultCache';
import { ChangeSourceOptionsStore } from '../utils/ChangeSourceOptionsStore';
import { SearchExploreSettingsStore } from '../utils/SearchExploreSettingsStore';
import { SearchBookShelfHelper } from '../utils/SearchBookShelfHelper';
import { SearchResultSorter } from '../utils/SearchResultSorter';
import { BookFieldSanitizer } from '../utils/BookFieldSanitizer';
import { CoverUrlNormalizer } from '../utils/CoverUrlNormalizer';
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
/** 字数测量并发数：结果边到边测，太低会让新结果长时间排在前一批慢书源后面。 */
const MEASURE_WORKER_COUNT = 6;
/** 单条测量限时：慢/死书源整条链可达 60-80s，超时按失败释放 worker，迟到的实测值由会话收尾排序兜底。 */
const MEASURE_ITEM_TIMEOUT_MS = 30000;
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
  /** 还有未搜的书源（手动停止 / 提前达标结束 / 历史结果），显示"继续搜索"。 */
  @State canResumeSearch: boolean = false;
  @State switching: boolean = false;
  @State switchingBook: SearchBook | null = null;
  @State failedBookUrls: string[] = [];
  @State loadWordCount: boolean = false;
  @State measuring: boolean = false;
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

  aboutToAppear(): void {
    if (!this.targetBook) {
      this.onClosed();
      return;
    }
    ChangeSourceOptionsStore.getLoadWordCount(getContext(this))
      .then((value: boolean): void => {
        this.loadWordCount = value;
        this.startSession();
      })
      .catch((): void => {
        this.startSession();
      });
  }

  aboutToDisappear(): void {
    this.sessionId++;
    this.switchToken++;
    this.measureSessionId++;
    this.clearPersistTimer();
    this.cancelActiveSearch();
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
      const cached = await ChangeSourceResultCache.load(getContext(this), book.name, book.author);
      if (!this.isSessionActive(sessionId)) return;
      if (cached && cached.results.length > 0) {
        this.updateResults(cached.results);
        for (const item of this.results) {
          item.author = BookFieldSanitizer.cleanAuthor(item.author);
          item.latestChapterTitle = BookFieldSanitizer.cleanChapterTitle(item.latestChapterTitle);
          item.wordCount = BookFieldSanitizer.cleanWordCount(item.wordCount);
        }
        this.searchedSourceUrls = new Set<string>();
        for (const url of cached.searchedSourceUrls) {
          if (url) this.searchedSourceUrls.add(url);
        }
        if (this.results.length > 0 && cached.partial) {
          this.status = '已恢复上次搜索结果，正在继续搜索剩余书源...';
          this.search(sessionId, true);
          return;
        }
        if (this.results.length > 0) {
          this.searching = false;
          // 历史结果无法区分是搜完还是提前达标结束，一律允许续搜；
          // 若上次已搜完全部书源，续搜会立即空跑完成并自动隐藏按钮。
          this.canResumeSearch = true;
          this.status = `已显示历史结果，共 ${this.results.length} 个；可继续搜索剩余书源或清空重搜`;
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

  stopSearch(): void {
    if (!this.searching) return;
    this.sessionId++;
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
    const excludeSourceUrls: string[] = [target.origin].concat(this.snapshotSearchedUrls());
    try {
      const results = await coordinator.search(target.name, (progress: SearchProgress) => {
        if (!this.isSessionActive(sessionId)) return;
        if (progress.finished) {
          this.updateResults(this.results.concat(progress.results));
        } else if (progress.deltaResults && progress.deltaResults.length > 0) {
          this.updateResults(this.results.concat(progress.deltaResults));
          this.persistResultsSoon();
          // 搜索进行中就让已到的结果边搜边测，不必等整轮搜索完成；
          // 已在测量时不能重启会话（会作废在飞测量），运行中的循环每轮会自动捡起新到的未测项。
          if (!this.measuring) {
            this.startMeasureChapterWordCounts();
          }
        }
        if (!this.switching) {
          this.status = resume ? this.applyResumeProgressOffset(progress) : progress.status;
        }
        if (progress.finished) {
          this.searching = false;
          // 提前达标（stopAfterResults）结束时 done < total，剩余书源可继续搜。
          this.canResumeSearch = progress.total > 0 && progress.done < progress.total;
        }
      }, {
        exactMatch: true,
        authorKeyword: target.author,
        leanResult: true,
        excludeSourceUrls: excludeSourceUrls,
        maxResultsPerSource: 2,
        maxTotalResults: 60,
        stopAfterResults: 24,
        maxCandidatesPerSource: 32,
        onSourceComplete: (source: BookSource, result: SearchSourceResult): Promise<void> => {
          const url = source.bookSourceUrl || '';
          if (url) {
            this.searchedSourceUrls.add(url);
          }
          return Promise.resolve();
        }
      });
      if (!this.isSessionActive(sessionId)) return;
      this.updateResults(this.results.concat(results));
      if (!this.switching) {
        if (this.results.length > 0) {
          this.status = this.canResumeSearch ?
            `搜索完成，找到 ${this.results.length} 个可切换书源，可继续搜索剩余书源` :
            `搜索完成，找到 ${this.results.length} 个可切换书源`;
        } else {
          this.status = this.canResumeSearch ?
            '搜索完成，未找到可切换书源，可继续搜索剩余书源' : '搜索完成，未找到可切换书源';
        }
      }
      try {
        await ChangeSourceResultCache.save(getContext(this), cacheBookName, this.results, target.author,
          this.snapshotSearchedUrls(), false);
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
      this.switchToken++;
      this.sessionId++;
      this.clearPersistTimer();
      this.cancelActiveSearch();
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
        // 切换期间完成的搜索会因 switching 守卫错过测量启动，切换结束后补启动。
        this.startMeasureChapterWordCounts();
      }
    }
  }

  isSessionActive(sessionId: number): boolean {
    return sessionId === this.sessionId;
  }

  cancelActiveSearch(): void {
    if (this.activeCoordinator) {
      this.activeCoordinator.cancel();
      this.activeCoordinator = null;
      this.persistResultsNow();
    }
  }

  toggleLoadWordCount(): void {
    this.loadWordCount = !this.loadWordCount;
    ChangeSourceOptionsStore.setLoadWordCount(getContext(this), this.loadWordCount)
      .catch((): void => {
      });
    if (this.loadWordCount) {
      this.startMeasureChapterWordCounts();
    } else {
      this.measureSessionId++;
      this.measuring = false;
    }
  }

  startMeasureChapterWordCounts(): void {
    if (!this.loadWordCount || this.switching) return;
    // 每次调用都重启一轮测量并作废在飞的旧会话：
    // 旧会话若因失败项重测不退出，measuring 会一直为 true，把后续新结果的测量全部挡掉。
    this.measureSessionId++;
    this.measuring = true;
    this.measureChapterWordCounts(this.measureSessionId);
  }

  /** 未测(-1)与测量失败(0)都收集；本会话已尝试过的跳过，避免失败项让测量循环永不退出。 */
  collectPendingMeasurements(attempted: Set<string>): SearchBook[] {
    const pending: SearchBook[] = [];
    for (const item of this.results) {
      if (item.chapterWordCount > 0) continue;
      const key = `${item.origin || ''}\n${item.bookUrl}`;
      if (attempted.has(key)) continue;
      pending.push(item);
    }
    return pending;
  }

  async measureChapterWordCounts(measureSession: number): Promise<void> {
    let measuredAny = false;
    const attempted = new Set<string>();
    try {
      while (this.loadWordCount && !this.switching && measureSession === this.measureSessionId) {
        const pending = this.collectPendingMeasurements(attempted);
        if (pending.length === 0) break;
        let nextIndex = 0;
        const worker = async (): Promise<void> => {
          while (this.loadWordCount && !this.switching && measureSession === this.measureSessionId) {
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
        for (let i = 0; i < MEASURE_WORKER_COUNT; i++) {
          workers.push(worker());
        }
        await Promise.all(workers);
        if (measureSession !== this.measureSessionId) return;
      }
    } finally {
      this.sortResults();
      if (measureSession === this.measureSessionId) {
        this.measuring = false;
      }
      const target = this.targetBook;
      if (measuredAny && !this.switching && target && this.results.length > 0) {
        try {
          await ChangeSourceResultCache.save(getContext(this), target.name, this.results, target.author,
            this.snapshotSearchedUrls(), false);
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
        candidate.chapterWordCount = 0;
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
    return ChapterWordCountMeasurer.measureOne(db, candidate, (): boolean =>
      measureSession !== this.measureSessionId || this.switching);
  }

  chapterWordCountText(book: SearchBook): string {
    if (book.chapterWordCount > 0) {
      return `${book.chapterWordCount}`;
    }
    if (book.chapterWordCount === 0) {
      return '获取失败';
    }
    return '测量中...';
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

  async persistResultsNow(): Promise<void> {
    this.lastPersistAt = Date.now();
    const target = this.targetBook;
    if (!target || this.results.length === 0) return;
    try {
      await ChangeSourceResultCache.save(getContext(this), target.name, this.results, target.author,
        this.snapshotSearchedUrls(), true);
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

  /** 过滤 + 排序后整体替换结果列表；排序规则见 SearchResultSorter（最新章节从大到小，相同则字数从大到小，实测失败沉底）。 */
  updateResults(raw: SearchBook[]): void {
    const target = this.targetBook;
    if (!target) return;
    this.results = SearchResultSorter.sort(this.filterResults(raw, target.bookUrl, target.origin));
  }

  sortResults(): void {
    this.results = SearchResultSorter.sort(this.results.slice());
  }

  filterResults(results: SearchBook[], currentBookUrl: string, currentOrigin: string): SearchBook[] {
    const filtered: SearchBook[] = [];
    const seen = new Set<string>();
    for (const result of results) {
      if (!result.bookUrl || SearchBookShelfHelper.isNavigationResult(result) ||
        (result.bookUrl === currentBookUrl && result.origin === currentOrigin)) continue;
      const key = `${result.origin || ''}\n${result.bookUrl}`;
      if (seen.has(key)) continue;
      seen.add(key);
      filtered.push(result);
    }
    return filtered;
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
          Text(this.loadWordCount ? '字数:开' : '字数:关')
            .fontSize(11)
            .fontColor(this.loadWordCount ? '#FFFFFF' : this.subTextColor())
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(11)
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
          .height(260)
          .justifyContent(FlexAlign.Center)
        } else if (this.results.length === 0) {
          Text('暂无可切换书源')
            .fontSize(15)
            .fontColor(this.subTextColor())
            .width('100%')
            .height(260)
            .textAlign(TextAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.results, (book: SearchBook) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(book.originName || book.origin)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`作者：${book.author || '未知'}`)
                      .fontSize(12)
                      .fontColor(this.subTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 8 }) {
                      Text(`最新：${book.latestChapterTitle || '书源未提供'}`)
                        .fontSize(12)
                        .fontColor(this.subTextColor())
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (this.loadWordCount) {
                        Text(`字数：${this.chapterWordCountText(book)}`)
                          .fontSize(12)
                          .fontColor(this.subTextColor())
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                    }
                    .width('100%')
                    if (this.failedBookUrls.includes(book.bookUrl)) {
                      Text('该源切换失败，建议尝试其它书源')
                        .fontSize(11)
                        .fontColor('#D94838')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Button(this.switching && this.switchingBook === book ? '切换中' : '切换')
                    .width(68)
                    .height(32)
                    .fontSize(13)
                    .borderRadius(16)
                    .backgroundColor(this.buttonColor())
                    .fontColor('#FFFFFF')
                    // 切换中不锁其它书源：慢/死书源可直接改选，避免只能等待或退出。
                    .onClick(() => this.switchSource(book))
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.inputColor())
                .borderRadius(10)
              }
            }, (book: SearchBook) => `${book.origin}|${book.bookUrl}|${book.chapterWordCount}|${book.latestChapterTitle}`)

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
                  Text('正在测量最新章节字数...').fontSize(13).fontColor(this.subTextColor())
                }
                .width('100%')
                .height(42)
                .justifyContent(FlexAlign.Center)
              }
            }
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .width('100%')
          // 高度随结果数自适应：结果少不留白，结果多时封顶滚动。
          .constraintSize({ maxHeight: 340 })
        }
      }
      .width('90%')
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
}

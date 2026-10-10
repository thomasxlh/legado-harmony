import relationalStore from '@ohos.data.relationalStore';
import { Book, BookChapter, BookSource, BookGroup, Bookmark, SearchKeyword, ExploreRule, TocRule, ContentRule } from './Book';
import { Context } from '@kit.AbilityKit';
import { BookIdentity } from '../../utils/BookIdentity';
import { CloudSyncService } from '../../utils/CloudSyncService';

interface ColumnMigration {
  table: string;
  column: string;
  definition: string;
}

/** 分组 ID 迁移时的临时记录：旧自增 ID 与其分组名。 */
class LegacyGroupId {
  groupId: number = 0;
  groupName: string = '';
}

/** 书源的本机数据：登录凭据与原始 JSON 副本，不参与端云同步。 */
export class BookSourceLocal {
  bookSourceUrl: string = '';
  loginHeader: string = '';
  loginInfo: string = '';
  rawSourceJson: string = '';
}

/**
 * 书籍 variable 中"只对本机有意义"的键。这些键留在 books 行里会随端云同步上传：
 * 本地绝对路径在另一台设备上不存在，WebDAV 引用指向本机配置，登录态属于凭据。
 */
class LocalBookVariableKeys {
  /**
   * 名字像本机键、但必须上云的例外。本地书用内容指纹在设备间匹配同一本书
   * 的阅读进度（见 BookIdentity.cloudIdentityValue 与 getBookByLocalContentHash）：
   * 没有它，本地书的进度就无法跨设备同步。
   * 优先级高于后缀与前缀匹配，否则会被下面的 'local' 前缀误判为本机键。
   */
  static readonly CLOUD_SHARED: string[] = ['localContentHash'];

  /** 本地导入产生、跨设备无意义的键（绝对路径、解析状态、WebDAV 引用）。 */
  static readonly DEVICE_LOCAL: string[] = [
    'localFilePath', 'localExtractRoot', 'localSourceUri', 'localFormat',
    'localParserVersion', 'localSourceMtime', 'localSourceSize',
    'localContentIntroVersion', 'localMetadataCustomized', 'localCustomName',
    'localCustomAuthor', 'localCharsetOverride', 'bookAddTime',
    'storageKind', 'webdavConnectionId', 'webdavRemotePath', 'webdavETag',
    'webdavLastModified', 'webdavRemoteSize', 'webdavCachedAt', 'webdavCheckedAt'
  ];

  /** 键前缀：书源运行时按前缀批量生成的键也要留在本机。 */
  static readonly DEVICE_LOCAL_PREFIXES: string[] = ['local', 'webdav'];

  static isLocal(key: string): boolean {
    // 例外优先：内容指纹要上云，不能让 'local' 前缀把它吃掉。
    if (LocalBookVariableKeys.CLOUD_SHARED.includes(key)) {
      return false;
    }
    if (LocalBookVariableKeys.DEVICE_LOCAL.includes(key)) {
      return true;
    }
    const lower = key.toLowerCase();
    for (const prefix of LocalBookVariableKeys.DEVICE_LOCAL_PREFIXES) {
      if (lower.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }
}

export class ReaderPaginationCacheRecord {
  starts: number[] = [];
  ends: number[] = [];
}

class ReaderPaginationCacheWrite {
  bookUrl: string = '';
  chapterIndex: number = 0;
  layoutKey: string = '';
  starts: number[] = [];
  ends: number[] = [];

  constructor(bookUrl: string, chapterIndex: number, layoutKey: string, starts: number[], ends: number[]) {
    this.bookUrl = bookUrl;
    this.chapterIndex = chapterIndex;
    this.layoutKey = layoutKey;
    this.starts = [...starts];
    this.ends = [...ends];
  }
}

class BookLifecycleMigrationRecord {
  bookUrl: string = '';
  identityKey: string = '';
  variable: string = '{}';
  pendingAddToShelf: boolean = false;
  shelfModifiedTime: number = 0;
}

/** 书架"继续阅读"卡的本设备快照。分页随设备变化，不参与云同步。 */
export class BookShelfSnapshot {
  bookUrl: string = '';
  pageText: string = '';
  pageImage: string = '';
}

export class AppDatabase {
  private static readonly BATCH_INSERT_CHUNK_SIZE: number = 400;
  static readonly MAX_SEARCH_KEYWORDS: number = 200;
  private static instance: AppDatabase | null = null;
  private store: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;
  private initPromise: Promise<void> | null = null;
  private readerPaginationPendingWrites: Map<string, ReaderPaginationCacheWrite> =
    new Map<string, ReaderPaginationCacheWrite>();
  private readerPaginationWriteTasks: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private bookProgressWriteTasks: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private latestBookProgressWriteTimes: Map<string, number> = new Map<string, number>();
  private readonly DATABASE_NAME = 'legado.db';
  private readonly SCHEMA_VERSION = 22;
  /** 派生分组 ID 的起始值：2^30。见 groupIdFromName 与 migrateBookGroupRandomIds。 */
  private static readonly DERIVED_GROUP_ID_BASE: number = 0x40000000;
  private cloudDeviceId: string = '';

  private constructor() {}

  static getInstance(): AppDatabase {
    if (!AppDatabase.instance) {
      AppDatabase.instance = new AppDatabase();
    }
    return AppDatabase.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.initialized && this.store) {
      return;
    }
    if (this.initPromise) {
      await this.initPromise;
      return;
    }

    this.initPromise = this.initInternal(context);
    try {
      await this.initPromise;
    } finally {
      this.initPromise = null;
    }
  }

  private async initInternal(context: Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: this.DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    this.store = await relationalStore.getRdbStore(context, config);
    await this.createTables();
    const cloudDeviceId = await this.getOrCreateCloudDeviceId();
    await CloudSyncService.configure(this.store, cloudDeviceId);
    await this.initDefaultData();
    this.initialized = true;
  }

  async initWithContext(context: Context): Promise<void> {
    await this.init(context);
  }

  private async createTables(): Promise<void> {
    if (!this.store) return;

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS books (
        bookUrl TEXT PRIMARY KEY,
        tocUrl TEXT DEFAULT '',
        origin TEXT DEFAULT 'local',
        originName TEXT DEFAULT '',
        name TEXT DEFAULT '',
        author TEXT DEFAULT '',
        kind TEXT,
        status TEXT DEFAULT '',
        customTag TEXT,
        coverUrl TEXT,
        customCoverUrl TEXT,
        intro TEXT,
        customIntro TEXT,
        charset TEXT,
        type INTEGER DEFAULT 0,
        groupId INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        latestChapterTitle TEXT,
        updateTime TEXT DEFAULT '',
        latestChapterTime INTEGER DEFAULT 0,
        lastCheckTime INTEGER DEFAULT 0,
        lastCheckCount INTEGER DEFAULT 0,
        totalChapterNum INTEGER DEFAULT 0,
        durChapterTitle TEXT,
        durChapterIndex INTEGER DEFAULT 0,
        durChapterPos INTEGER DEFAULT 0,
        durChapterTime INTEGER DEFAULT 0,
        wordCount TEXT,
        canUpdate INTEGER DEFAULT 1,
        bookOrder INTEGER DEFAULT 0,
        originOrder INTEGER DEFAULT 0,
        variable TEXT,
        readConfig TEXT,
        syncTime INTEGER DEFAULT 0,
        identityKey TEXT DEFAULT '',
        pendingAddToShelf INTEGER DEFAULT 0,
        shelfModifiedTime INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_sources (
        bookSourceUrl TEXT PRIMARY KEY,
        bookSourceName TEXT DEFAULT '',
        bookSourceType INTEGER DEFAULT 0,
        bookSourceGroup TEXT DEFAULT '',
        bookSourceComment TEXT DEFAULT '',
        loginUrl TEXT DEFAULT '',
        loginUi TEXT,
        loginCheckJs TEXT DEFAULT '',
        loginHeader TEXT DEFAULT '',
        loginInfo TEXT DEFAULT '',
        rawSourceJson TEXT DEFAULT '',
        bookUrlPattern TEXT DEFAULT '',
        searchUrl TEXT DEFAULT '',
        exploreUrl TEXT DEFAULT '',
        jsLib TEXT DEFAULT '',
        header TEXT DEFAULT '',
        bookListRule TEXT DEFAULT '{}',
        searchRule TEXT DEFAULT '{}',
        exploreRule TEXT DEFAULT '{}',
        bookInfoRule TEXT DEFAULT '{}',
        tocRule TEXT DEFAULT '{}',
        contentRule TEXT DEFAULT '{}',
        variableComment TEXT DEFAULT '',
        variable TEXT DEFAULT '',
        lastUpdateTime INTEGER DEFAULT 0,
        respondTime INTEGER DEFAULT 180000,
        customOrder INTEGER DEFAULT 0,
        customButton INTEGER DEFAULT 0,
        eventListener INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 1,
        enabledExplore INTEGER DEFAULT 1,
        isLocked INTEGER DEFAULT 0,
        validationStatus INTEGER DEFAULT 0,
        weight INTEGER DEFAULT 0,
        concurrentRate TEXT DEFAULT '',
        enabledCookieJar INTEGER DEFAULT 1
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_chapters (
        url TEXT PRIMARY KEY,
        title TEXT DEFAULT '',
        bookUrl TEXT DEFAULT '',
        chapterIndex INTEGER DEFAULT 0,
        isVip INTEGER DEFAULT 0,
        isPay INTEGER DEFAULT 0,
        resourceUrl TEXT DEFAULT '',
        tag TEXT DEFAULT '',
        startOffset INTEGER DEFAULT 0,
        endOffset INTEGER DEFAULT 0,
        variable TEXT DEFAULT ''
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_contents (
        bookUrl TEXT DEFAULT '',
        chapterIndex INTEGER DEFAULT 0,
        chapterUrl TEXT DEFAULT '',
        chapterName TEXT DEFAULT '',
        content TEXT DEFAULT '',
        cacheDate INTEGER DEFAULT 0,
        PRIMARY KEY (bookUrl, chapterIndex)
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_groups (
        groupId INTEGER PRIMARY KEY,
        groupName TEXT DEFAULT '',
        groupOrder INTEGER DEFAULT 0,
        show INTEGER DEFAULT 1,
        enableRefresh INTEGER DEFAULT 1
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS search_keywords (
        keyword TEXT PRIMARY KEY,
        usage INTEGER DEFAULT 0,
        lastUseTime INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS reader_pagination_cache (
        bookUrl TEXT DEFAULT '',
        chapterIndex INTEGER DEFAULT 0,
        layoutKey TEXT DEFAULT '',
        starts TEXT DEFAULT '[]',
        ends TEXT DEFAULT '[]',
        updateTime INTEGER DEFAULT 0,
        PRIMARY KEY (bookUrl, chapterIndex, layoutKey)
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookUrl TEXT DEFAULT '',
        bookName TEXT DEFAULT '',
        bookAuthor TEXT DEFAULT '',
        chapterIndex INTEGER DEFAULT 0,
        chapterName TEXT DEFAULT '',
        pageIndex INTEGER DEFAULT 0,
        startPos INTEGER DEFAULT 0,
        endPos INTEGER DEFAULT 0,
        content TEXT DEFAULT '',
        createTime INTEGER DEFAULT 0,
        UNIQUE(bookUrl, chapterIndex, pageIndex)
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_mutation_journal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT DEFAULT '',
        reason TEXT DEFAULT '',
        bookUrl TEXT DEFAULT '',
        identityKey TEXT DEFAULT '',
        pendingAddToShelf INTEGER DEFAULT 0,
        eventTime INTEGER DEFAULT 0,
        details TEXT DEFAULT ''
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_shelf_snapshots (
        bookUrl TEXT PRIMARY KEY,
        pageText TEXT DEFAULT '',
        pageImage TEXT DEFAULT '',
        updatedAt INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS sync_heartbeats (
        deviceId TEXT PRIMARY KEY,
        updatedAt INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS device_meta (
        key TEXT PRIMARY KEY,
        value TEXT DEFAULT ''
      )
    `);

    // 以下两张表刻意不加入 CloudSyncService.SYNC_TABLES：
    // 前者是书源的登录凭据与原始 JSON 副本，后者是书籍的本机文件/WebDAV 元数据。
    // 两者都只对当前设备有意义（或属于敏感凭据），随端云同步上传会浪费云空间、
    // 跨设备产生错误数据，因此与 book_shelf_snapshots 一样留在本机。
    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_source_local (
        bookSourceUrl TEXT PRIMARY KEY,
        loginHeader TEXT DEFAULT '',
        loginInfo TEXT DEFAULT '',
        rawSourceJson TEXT DEFAULT '',
        updatedAt INTEGER DEFAULT 0
      )
    `);

    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS book_local_meta (
        bookUrl TEXT PRIMARY KEY,
        variable TEXT DEFAULT '{}',
        updatedAt INTEGER DEFAULT 0
      )
    `);

    const schemaVersion = await this.getSchemaVersion();
    if (schemaVersion < this.SCHEMA_VERSION) {
      await this.migrateTables();
      if (schemaVersion < 9) {
        await this.resetLegacyBookSourceValidationFailures();
      }
      if (schemaVersion < 14) {
        await this.repairOversizedImportedBookData();
      }
      if (schemaVersion < 15) {
        await this.migrateBookLifecycleMetadata();
      }
      if (schemaVersion < 19) {
        await this.migrateBookShelfSnapshots();
      }
      if (schemaVersion < 20) {
        await this.migrateBookGroupRandomIds();
      }
      if (schemaVersion < 21) {
        await this.migrateLocalOnlyColumns();
      }
      if (schemaVersion < 22) {
        await this.restoreSharedContentHash();
      }
      await this.setSchemaVersion(this.SCHEMA_VERSION);
    }
    await this.createIndexes();
  }

  private async createIndexes(): Promise<void> {
    if (!this.store) return;
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_book_chapters_book_order ON book_chapters(bookUrl, chapterIndex)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_time ON bookmarks(bookUrl, createTime DESC)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_books_read_time ON books(durChapterTime DESC)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_books_identity_key ON books(identityKey)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_book_mutation_time ON book_mutation_journal(eventTime DESC)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_book_sources_enabled_order ON book_sources(enabled, isPinned DESC, customOrder)');
    await this.store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_book_sources_explore_order ON book_sources(enabled, enabledExplore, isPinned DESC, customOrder)');
  }

  private async getSchemaVersion(): Promise<number> {
    if (!this.store) return 0;

    try {
      const resultSet = await this.store.querySql(`SELECT value FROM schema_meta WHERE key = 'schema_version'`);
      try {
        if (resultSet.goToFirstRow()) {
          return resultSet.getLong(resultSet.getColumnIndex('value'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return 0;
  }

  private async setSchemaVersion(version: number): Promise<void> {
    if (!this.store) return;

    try {
      await this.store.executeSql(`DELETE FROM schema_meta WHERE key = 'schema_version'`);
      await this.store.executeSql(`INSERT INTO schema_meta (key, value) VALUES ('schema_version', ${version})`);
    } catch (e) {
      console.error(`保存数据库版本 ${version} 失败`, e);
      throw e;
    }
  }

  private async migrateTables(): Promise<void> {
    if (!this.store) return;

    const migrations: ColumnMigration[] = [
      { table: 'books', column: 'tocUrl', definition: "tocUrl TEXT DEFAULT ''" },
      { table: 'books', column: 'origin', definition: "origin TEXT DEFAULT 'local'" },
      { table: 'books', column: 'originName', definition: "originName TEXT DEFAULT ''" },
      { table: 'books', column: 'kind', definition: "kind TEXT DEFAULT ''" },
      { table: 'books', column: 'status', definition: "status TEXT DEFAULT ''" },
      { table: 'books', column: 'customTag', definition: "customTag TEXT DEFAULT ''" },
      { table: 'books', column: 'coverUrl', definition: "coverUrl TEXT DEFAULT ''" },
      { table: 'books', column: 'customCoverUrl', definition: "customCoverUrl TEXT DEFAULT ''" },
      { table: 'books', column: 'intro', definition: "intro TEXT DEFAULT ''" },
      { table: 'books', column: 'customIntro', definition: "customIntro TEXT DEFAULT ''" },
      { table: 'books', column: 'charset', definition: "charset TEXT DEFAULT ''" },
      { table: 'books', column: 'type', definition: 'type INTEGER DEFAULT 0' },
      { table: 'books', column: 'groupId', definition: 'groupId INTEGER DEFAULT 0' },
      { table: 'books', column: 'isPinned', definition: 'isPinned INTEGER DEFAULT 0' },
      { table: 'books', column: 'latestChapterTitle', definition: "latestChapterTitle TEXT DEFAULT ''" },
      { table: 'books', column: 'updateTime', definition: "updateTime TEXT DEFAULT ''" },
      { table: 'books', column: 'latestChapterTime', definition: 'latestChapterTime INTEGER DEFAULT 0' },
      { table: 'books', column: 'lastCheckTime', definition: 'lastCheckTime INTEGER DEFAULT 0' },
      { table: 'books', column: 'lastCheckCount', definition: 'lastCheckCount INTEGER DEFAULT 0' },
      { table: 'books', column: 'totalChapterNum', definition: 'totalChapterNum INTEGER DEFAULT 0' },
      { table: 'books', column: 'durChapterTitle', definition: "durChapterTitle TEXT DEFAULT ''" },
      { table: 'books', column: 'durChapterIndex', definition: 'durChapterIndex INTEGER DEFAULT 0' },
      { table: 'books', column: 'durChapterPos', definition: 'durChapterPos INTEGER DEFAULT 0' },
      { table: 'books', column: 'durChapterTime', definition: 'durChapterTime INTEGER DEFAULT 0' },
      { table: 'books', column: 'wordCount', definition: "wordCount TEXT DEFAULT ''" },
      { table: 'books', column: 'canUpdate', definition: 'canUpdate INTEGER DEFAULT 1' },
      { table: 'books', column: 'bookOrder', definition: 'bookOrder INTEGER DEFAULT 0' },
      { table: 'books', column: 'originOrder', definition: 'originOrder INTEGER DEFAULT 0' },
      { table: 'books', column: 'variable', definition: 'variable TEXT' },
      { table: 'books', column: 'readConfig', definition: 'readConfig TEXT' },
      { table: 'books', column: 'syncTime', definition: 'syncTime INTEGER DEFAULT 0' },
      { table: 'books', column: 'identityKey', definition: "identityKey TEXT DEFAULT ''" },
      { table: 'books', column: 'pendingAddToShelf', definition: 'pendingAddToShelf INTEGER DEFAULT 0' },
      { table: 'books', column: 'shelfModifiedTime', definition: 'shelfModifiedTime INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'searchUrl', definition: "searchUrl TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'exploreUrl', definition: "exploreUrl TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'jsLib', definition: "jsLib TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'bookSourceType', definition: 'bookSourceType INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'variable', definition: "variable TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'enabledCookieJar', definition: 'enabledCookieJar INTEGER DEFAULT 1' },
      { table: 'book_sources', column: 'loginHeader', definition: "loginHeader TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'loginInfo', definition: "loginInfo TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'rawSourceJson', definition: "rawSourceJson TEXT DEFAULT ''" },
      { table: 'book_sources', column: 'respondTime', definition: 'respondTime INTEGER DEFAULT 180000' },
      { table: 'book_sources', column: 'customButton', definition: 'customButton INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'eventListener', definition: 'eventListener INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'isLocked', definition: 'isLocked INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'isPinned', definition: 'isPinned INTEGER DEFAULT 0' },
      { table: 'book_sources', column: 'validationStatus', definition: 'validationStatus INTEGER DEFAULT 0' },
      { table: 'book_chapters', column: 'variable', definition: "variable TEXT DEFAULT ''" }
    ];

    for (const migration of migrations) {
      await this.addColumnIfMissing(migration);
    }
  }

  private async addColumnIfMissing(migration: ColumnMigration): Promise<void> {
    if (!this.store) return;

    try {
      const resultSet = await this.store.querySql(`PRAGMA table_info(${migration.table})`);
      try {
        const nameIndex = resultSet.getColumnIndex('name');
        while (resultSet.goToNextRow()) {
          if (resultSet.getString(nameIndex) === migration.column) {
            return;
          }
        }
      } finally {
        resultSet.close();
      }
      await this.store.executeSql(`ALTER TABLE ${migration.table} ADD COLUMN ${migration.definition}`);
    } catch (e) {
      console.error(`数据库迁移失败: ${migration.table}.${migration.column}`, e);
      throw e;
    }
  }

  private async resetLegacyBookSourceValidationFailures(): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.executeSql(
        `UPDATE book_sources SET validationStatus = ${BookSource.VALIDATION_UNCHECKED} ` +
        `WHERE validationStatus = ${BookSource.VALIDATION_FAILED}`
      );
    } catch (e) {
      console.warn('重置旧版书源校验失败状态失败:', e);
    }
  }

  private async repairOversizedImportedBookData(): Promise<void> {
    if (!this.store) return;
    try {
      // Android 阅读的 variable 可能包含正文/目录等运行时缓存。旧版导入器曾将其整段写入，
      // 书架启动时读取所有图书会因此长时间占用主线程。章节和页码进度已有独立列，清掉
      // 超大扩展字段不会丢失主要阅读位置；只处理网络书，避免影响本地图书路径元数据。
      await this.store.executeSql(
        `UPDATE books SET variable = '{}' ` +
        `WHERE origin NOT IN ('local', 'loc_book') AND LENGTH(COALESCE(variable, '')) > 65536`
      );
      await this.store.executeSql(
        `UPDATE books SET readConfig = NULL WHERE LENGTH(COALESCE(readConfig, '')) > 65536`
      );
      await this.store.executeSql(
        `UPDATE books SET intro = SUBSTR(intro, 1, 65536) WHERE LENGTH(COALESCE(intro, '')) > 65536`
      );
      await this.store.executeSql(
        `UPDATE books SET customIntro = SUBSTR(customIntro, 1, 65536) ` +
        `WHERE LENGTH(COALESCE(customIntro, '')) > 65536`
      );
    } catch (e) {
      console.warn('修复历史导入的超大书籍数据失败:', e);
    }
  }

  private async migrateBookLifecycleMetadata(): Promise<void> {
    if (!this.store) return;
    const legacyKey = 'searchExplorePendingAddToShelf';
    const records: BookLifecycleMigrationRecord[] = [];
    const resultSet = await this.store.querySql(
      'SELECT bookUrl, origin, variable, durChapterTime, lastCheckTime, latestChapterTime FROM books');
    try {
      while (resultSet.goToNextRow()) {
        const bookUrl = this.getStringColumn(resultSet, 'bookUrl');
        if (!bookUrl) continue;
        const book = new Book();
        book.bookUrl = bookUrl;
        book.origin = this.getStringColumn(resultSet, 'origin', 'local');
        const rawVariable = this.getStringColumn(resultSet, 'variable', '{}');
        let cleanedVariable = rawVariable;
        let pending = false;
        if (rawVariable.indexOf(legacyKey) >= 0) {
          try {
            const legacy = JSON.parse(rawVariable) as Record<string, string>;
            pending = String(legacy[legacyKey] || '') === 'true';
            const cleaned: Record<string, string> = {};
            for (const key of Object.keys(legacy)) {
              if (key !== legacyKey) cleaned[key] = legacy[key];
            }
            cleanedVariable = JSON.stringify(cleaned);
          } catch (_) {
          }
        }
        const modified = pending ? 0 : Math.max(
          this.getLongColumn(resultSet, 'durChapterTime'),
          this.getLongColumn(resultSet, 'lastCheckTime'),
          this.getLongColumn(resultSet, 'latestChapterTime'));
        const record = new BookLifecycleMigrationRecord();
        record.bookUrl = bookUrl;
        record.identityKey = BookIdentity.keyOfBook(book);
        record.variable = cleanedVariable;
        record.pendingAddToShelf = pending;
        record.shelfModifiedTime = modified;
        records.push(record);
      }
    } finally {
      resultSet.close();
    }
    for (const record of records) {
      const predicates = new relationalStore.RdbPredicates('books');
      predicates.equalTo('bookUrl', record.bookUrl);
      await this.store.update({
        identityKey: record.identityKey,
        pendingAddToShelf: record.pendingAddToShelf ? 1 : 0,
        shelfModifiedTime: record.shelfModifiedTime,
        variable: record.variable
      }, predicates);
    }
  }

  private async initDefaultData(): Promise<void> {
    if (!this.store) return;

    const resultSet = await this.store.querySql(`SELECT COUNT(*) as count FROM book_groups`);
    let shouldInsertDefaults = true;
    try {
      if (resultSet.goToFirstRow()) {
        shouldInsertDefaults = resultSet.getLong(resultSet.getColumnIndex('count')) === 0;
      }
    } finally {
      resultSet.close();
    }
    if (shouldInsertDefaults) {
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, show) 
        VALUES (${BookGroup.ID_ALL}, '全部', -10, 1)
      `);
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, enableRefresh, show) 
        VALUES (${BookGroup.ID_LOCAL}, '本地', -9, 0, 1)
      `);
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, show) 
        VALUES (${BookGroup.ID_AUDIO}, '音频', -8, 1)
      `);
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, show) 
        VALUES (${BookGroup.ID_NET_NONE}, '网络未分组', -7, 1)
      `);
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, show) 
        VALUES (${BookGroup.ID_LOCAL_NONE}, '本地未分组', -6, 0)
      `);
      await this.store.executeSql(`
        INSERT INTO book_groups (groupId, groupName, groupOrder, show) 
        VALUES (${BookGroup.ID_ERROR}, '更新失败', -1, 1)
      `);
    }
  }

  async insertBook(book: Book, reason: string = 'insert_book'): Promise<void> {
    if (!this.store) return;
    book.identityKey = BookIdentity.keyOfBook(book);
    if (!book.pendingAddToShelf && book.shelfModifiedTime <= 0) {
      book.shelfModifiedTime = Date.now();
    }
    // 云同步行只保留非本机键；本机片段（本地路径、WebDAV 引用）进 book_local_meta。
    const split = AppDatabase.splitBookVariable(book.variable);
    await this.saveBookLocalVariable(book.bookUrl, split.local);
    const bucket: relationalStore.ValuesBucket = {
      bookUrl: book.bookUrl,
      tocUrl: book.tocUrl,
      origin: book.origin,
      originName: book.originName,
      name: book.name,
      author: book.author,
      kind: book.kind,
      status: book.status,
      customTag: book.customTag,
      coverUrl: book.coverUrl,
      customCoverUrl: book.customCoverUrl,
      intro: book.intro,
      customIntro: book.customIntro,
      charset: book.charset,
      type: book.type,
      groupId: book.group,
      isPinned: book.isPinned ? 1 : 0,
      latestChapterTitle: book.latestChapterTitle,
      updateTime: book.updateTime,
      latestChapterTime: book.latestChapterTime,
      lastCheckTime: book.lastCheckTime,
      lastCheckCount: book.lastCheckCount,
      totalChapterNum: book.totalChapterNum,
      durChapterTitle: book.durChapterTitle,
      durChapterIndex: book.durChapterIndex,
      durChapterPos: book.durChapterPos,
      durChapterTime: book.durChapterTime,
      wordCount: book.wordCount,
      canUpdate: book.canUpdate ? 1 : 0,
      bookOrder: book.order,
      originOrder: book.originOrder,
      variable: split.cloud,
      readConfig: JSON.stringify(book.readConfig),
      syncTime: book.syncTime,
      identityKey: book.identityKey,
      pendingAddToShelf: book.pendingAddToShelf ? 1 : 0,
      shelfModifiedTime: book.shelfModifiedTime
    };

    await this.store.insert('books', bucket);
    await this.recordBookMutation('insert', reason, book);
  }

  async updateBook(book: Book, syncRelevant: boolean = true, reason: string = 'update_book'): Promise<void> {
    if (!this.store) return;
    book.identityKey = BookIdentity.keyOfBook(book);
    const split = AppDatabase.splitBookVariable(book.variable);
    await this.saveBookLocalVariable(book.bookUrl, split.local);
    const bucket: relationalStore.ValuesBucket = {
      tocUrl: book.tocUrl,
      origin: book.origin,
      originName: book.originName,
      name: book.name,
      author: book.author,
      kind: book.kind,
      status: book.status,
      customTag: book.customTag,
      coverUrl: book.coverUrl,
      customCoverUrl: book.customCoverUrl,
      intro: book.intro,
      customIntro: book.customIntro,
      charset: book.charset,
      type: book.type,
      groupId: book.group,
      isPinned: book.isPinned ? 1 : 0,
      latestChapterTitle: book.latestChapterTitle,
      updateTime: book.updateTime,
      latestChapterTime: book.latestChapterTime,
      lastCheckTime: book.lastCheckTime,
      lastCheckCount: book.lastCheckCount,
      totalChapterNum: book.totalChapterNum,
      durChapterTitle: book.durChapterTitle,
      durChapterIndex: book.durChapterIndex,
      durChapterPos: book.durChapterPos,
      durChapterTime: book.durChapterTime,
      wordCount: book.wordCount,
      canUpdate: book.canUpdate ? 1 : 0,
      bookOrder: book.order,
      originOrder: book.originOrder,
      variable: split.cloud,
      readConfig: JSON.stringify(book.readConfig),
      syncTime: book.syncTime,
      identityKey: book.identityKey,
      pendingAddToShelf: book.pendingAddToShelf ? 1 : 0,
      shelfModifiedTime: book.shelfModifiedTime
    };

    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('bookUrl', book.bookUrl);
    const affected = await this.store.update(bucket, predicates);
    if (affected <= 0) {
      await this.recordBookMutation('update_missed', reason, book, 'bookUrl 精确匹配未命中');
      console.warn(`更新书籍未命中数据库记录: ${book.bookUrl}`);
      return;
    }
    await this.recordBookMutation('update', reason, book);
  }

  async commitBookSourceSwitch(oldBookUrl: string, book: Book, chapters: BookChapter[]): Promise<void> {
    if (!this.store || !oldBookUrl || !book.bookUrl) return;
    book.identityKey = BookIdentity.keyOfBook(book);
    const split = AppDatabase.splitBookVariable(book.variable);
    const bookBucket: relationalStore.ValuesBucket = {
      bookUrl: book.bookUrl,
      tocUrl: book.tocUrl,
      origin: book.origin,
      originName: book.originName,
      name: book.name,
      author: book.author,
      kind: book.kind,
      status: book.status,
      customTag: book.customTag,
      coverUrl: book.coverUrl,
      customCoverUrl: book.customCoverUrl,
      intro: book.intro,
      customIntro: book.customIntro,
      charset: book.charset,
      type: book.type,
      groupId: book.group,
      isPinned: book.isPinned ? 1 : 0,
      latestChapterTitle: book.latestChapterTitle,
      updateTime: book.updateTime,
      latestChapterTime: book.latestChapterTime,
      lastCheckTime: book.lastCheckTime,
      lastCheckCount: book.lastCheckCount,
      totalChapterNum: book.totalChapterNum,
      durChapterTitle: book.durChapterTitle,
      durChapterIndex: book.durChapterIndex,
      durChapterPos: book.durChapterPos,
      durChapterTime: book.durChapterTime,
      wordCount: book.wordCount,
      canUpdate: book.canUpdate ? 1 : 0,
      bookOrder: book.order,
      originOrder: book.originOrder,
      variable: split.cloud,
      readConfig: JSON.stringify(book.readConfig),
      syncTime: book.syncTime,
      identityKey: book.identityKey,
      pendingAddToShelf: book.pendingAddToShelf ? 1 : 0,
      shelfModifiedTime: book.shelfModifiedTime
    };
    // 换源会改 bookUrl：本机元数据要跟到新主键上，否则本地书路径丢失。
    await this.saveBookLocalVariable(book.bookUrl, split.local);
    if (oldBookUrl !== book.bookUrl) {
      await this.deleteBookLocalVariable(oldBookUrl);
    }
    const chapterBuckets: relationalStore.ValuesBucket[] = [];
    for (const chapter of chapters) {
      chapterBuckets.push({
        url: chapter.url,
        title: chapter.title,
        bookUrl: book.bookUrl,
        chapterIndex: chapter.index,
        isVip: chapter.isVip ? 1 : 0,
        isPay: chapter.isPay ? 1 : 0,
        resourceUrl: chapter.resourceUrl,
        tag: chapter.tag,
        startOffset: chapter.start,
        endOffset: chapter.end,
        variable: chapter.variable
      });
    }

    const transaction = await this.store.createTransaction();
    try {
      if (oldBookUrl !== book.bookUrl) {
        const destinationBookmarks = new relationalStore.RdbPredicates('bookmarks');
        destinationBookmarks.equalTo('bookUrl', book.bookUrl);
        await transaction.delete(destinationBookmarks);

        const sourceBookmarks = new relationalStore.RdbPredicates('bookmarks');
        sourceBookmarks.equalTo('bookUrl', oldBookUrl);
        await transaction.update({
          bookUrl: book.bookUrl,
          bookName: book.name,
          bookAuthor: book.author
        }, sourceBookmarks);

        for (const table of ['book_chapters', 'book_contents', 'books']) {
          const oldPredicates = new relationalStore.RdbPredicates(table);
          oldPredicates.equalTo('bookUrl', oldBookUrl);
          await transaction.delete(oldPredicates);
          const destinationPredicates = new relationalStore.RdbPredicates(table);
          destinationPredicates.equalTo('bookUrl', book.bookUrl);
          await transaction.delete(destinationPredicates);
        }
        await transaction.insert('books', bookBucket);
      } else {
        const bookPredicates = new relationalStore.RdbPredicates('books');
        bookPredicates.equalTo('bookUrl', book.bookUrl);
        const updateBucket: relationalStore.ValuesBucket = { ...bookBucket };
        delete updateBucket.bookUrl;
        await transaction.update(updateBucket, bookPredicates);
        for (const table of ['book_chapters', 'book_contents']) {
          const predicates = new relationalStore.RdbPredicates(table);
          predicates.equalTo('bookUrl', book.bookUrl);
          await transaction.delete(predicates);
        }
      }
      for (let offset = 0; offset < chapterBuckets.length; offset += AppDatabase.BATCH_INSERT_CHUNK_SIZE) {
        await transaction.batchInsert('book_chapters',
          chapterBuckets.slice(offset, offset + AppDatabase.BATCH_INSERT_CHUNK_SIZE));
      }
      await transaction.commit();
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  }

  async updateBookReadingProgress(bookUrl: string, chapterTitle: string, chapterIndex: number,
    chapterPos: number, chapterTime: number, variable: string,
    syncRelevant: boolean = true): Promise<void> {
    if (!this.store || !bookUrl) return;
    const previousLatestTime = this.latestBookProgressWriteTimes.get(bookUrl) || 0;
    if (chapterTime < previousLatestTime) {
      console.info(`[ReaderProgress] skip stale snapshot before queue: ${bookUrl},` +
        `time=${chapterTime}<${previousLatestTime}`);
      return;
    }
    this.latestBookProgressWriteTimes.set(bookUrl, chapterTime);
    const previous = this.bookProgressWriteTasks.get(bookUrl) || Promise.resolve();
    const task = previous.catch((error: Error) => {
      console.warn(`[ReaderProgress] previous queued write failed: ${bookUrl}`, error);
    }).then(async (): Promise<void> => {
      const latestTime = this.latestBookProgressWriteTimes.get(bookUrl) || chapterTime;
      if (chapterTime < latestTime) {
        console.info(`[ReaderProgress] skip stale queued snapshot: ${bookUrl},` +
          `time=${chapterTime}<${latestTime}`);
        return;
      }
      await this.performBookReadingProgressUpdate(bookUrl, chapterTitle, chapterIndex,
        chapterPos, chapterTime, variable, syncRelevant);
    });
    this.bookProgressWriteTasks.set(bookUrl, task);
    try {
      await task;
    } finally {
      if (this.bookProgressWriteTasks.get(bookUrl) === task) {
        this.bookProgressWriteTasks.delete(bookUrl);
      }
    }
  }

  private async performBookReadingProgressUpdate(bookUrl: string, chapterTitle: string, chapterIndex: number,
    chapterPos: number, chapterTime: number, variable: string, syncRelevant: boolean): Promise<void> {
    if (!this.store || !bookUrl) return;
    const stripped = AppDatabase.stripShelfSnapshotKeys(variable);
    const split = AppDatabase.splitBookVariable(stripped);
    const bucket: relationalStore.ValuesBucket = {
      durChapterTitle: chapterTitle,
      durChapterIndex: chapterIndex,
      durChapterPos: chapterPos,
      durChapterTime: chapterTime,
      // 同步行只保留云端部分；本机键（本地路径/WebDAV）落在 book_local_meta。
      variable: split.cloud
    };
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('bookUrl', bookUrl);
    const affected = await this.store.update(bucket, predicates);
    if (affected <= 0) {
      const missing = new Book();
      missing.bookUrl = bookUrl;
      await this.recordBookMutation(
        'progress_update_missed', 'save_reading_progress', missing, 'bookUrl 精确匹配未命中');
      console.warn(`保存阅读进度未命中数据库记录: ${bookUrl}`);
      return;
    }
    // 进度写入频繁，本机片段也要同步落盘，否则本地书路径会被下一次写库覆盖丢失。
    await this.saveBookLocalVariable(bookUrl, split.local);
    // 进度落库即产生待上传的本地变更。自动同步是去抖的，被去抖丢弃的这轮
    // 变更需要有记录，否则 autoSync=false 下没有任何补偿路径。
    CloudSyncService.notifyLocalChange();
  }

  /**
   * 书架"继续阅读"正文片段只存本地快照表。这里是所有进度落库的必经点：
   * 无论变量来自阅读页、听书页还是局域网回传，都在写库前剥离这两个键，
   * 保证它们不再随 books 分布式行上云。
   */
  private static stripShelfSnapshotKeys(variable: string): string {
    if (!variable) {
      return variable;
    }
    const mentionsText = variable.indexOf('lastReadPageText') >= 0;
    const mentionsImage = variable.indexOf('lastReadPageImage') >= 0;
    if (!mentionsText && !mentionsImage) {
      return variable;
    }
    try {
      const parsed = JSON.parse(variable) as Record<string, Object>;
      if (!parsed || typeof parsed !== 'object') {
        return variable;
      }
      const clean: Record<string, Object> = {};
      const keys = Object.keys(parsed);
      for (const key of keys) {
        if (key !== 'lastReadPageText' && key !== 'lastReadPageImage') {
          clean[key] = parsed[key];
        }
      }
      return JSON.stringify(clean);
    } catch (_) {
      return variable;
    }
  }

  async deleteBook(bookUrl: string, reason: string = 'delete_book'): Promise<void> {
    if (!this.store) return;
    const existing = await this.getBook(bookUrl);
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('bookUrl', bookUrl);
    const affected = await this.store.delete(predicates);
    if (affected > 0) {
      await this.recordBookMutation('delete', reason, existing, '', bookUrl);
    } else {
      await this.recordBookMutation('delete_missed', reason, existing, 'bookUrl 精确匹配未命中', bookUrl);
    }
    await this.deleteBookChapters(bookUrl);
    await this.deleteBookCachedContent(bookUrl);
    await this.deleteBookBookmarks(bookUrl);
    await this.deleteBookLocalVariable(bookUrl);
  }

  private async recordBookMutation(operation: string, reason: string, book: Book | null,
    details: string = '', fallbackBookUrl: string = ''): Promise<void> {
    if (!this.store) return;
    try {
      const bookUrl = book?.bookUrl || fallbackBookUrl;
      const identityKey = book ? (book.identityKey || BookIdentity.keyOfBook(book)) : '';
      await this.store.insert('book_mutation_journal', {
        operation: operation,
        reason: reason,
        bookUrl: bookUrl,
        identityKey: identityKey,
        pendingAddToShelf: book?.pendingAddToShelf ? 1 : 0,
        eventTime: Date.now(),
        details: details
      });
      await this.store.executeSql(
        'DELETE FROM book_mutation_journal WHERE id NOT IN ' +
        '(SELECT id FROM book_mutation_journal ORDER BY id DESC LIMIT 500)');
    } catch (error) {
      console.warn('记录书架变更审计失败:', error);
    }
  }

  async insertBookmark(bookmark: Bookmark): Promise<number> {
    if (!this.store) return 0;
    const bucket: relationalStore.ValuesBucket = {
      bookUrl: bookmark.bookUrl,
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterName: bookmark.chapterName,
      pageIndex: bookmark.pageIndex,
      startPos: bookmark.startPos,
      endPos: bookmark.endPos,
      content: bookmark.content,
      createTime: bookmark.createTime
    };
    const id = await this.store.insert('bookmarks', bucket);
    return id;
  }

  async getBookmarks(bookUrl: string): Promise<Bookmark[]> {
    const bookmarks: Bookmark[] = [];
    if (!this.store || !bookUrl) return bookmarks;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, []);
    try {
      while (resultSet.goToNextRow()) {
        bookmarks.push(this.resultSetToBookmark(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return bookmarks;
  }

  async getAllBookmarks(): Promise<Bookmark[]> {
    const bookmarks: Bookmark[] = [];
    if (!this.store) return bookmarks;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.orderByDesc('createTime');
    const resultSet = await this.store.query(predicates, []);
    try {
      while (resultSet.goToNextRow()) {
        bookmarks.push(this.resultSetToBookmark(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return bookmarks;
  }

  async restoreBookmark(bookmark: Bookmark): Promise<void> {
    if (!this.store || !bookmark.bookUrl) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', bookmark.bookUrl);
    predicates.equalTo('chapterIndex', bookmark.chapterIndex);
    predicates.equalTo('pageIndex', bookmark.pageIndex);
    await this.store.delete(predicates);
    await this.store.insert('bookmarks', {
      bookUrl: bookmark.bookUrl,
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterName: bookmark.chapterName,
      pageIndex: bookmark.pageIndex,
      startPos: bookmark.startPos,
      endPos: bookmark.endPos,
      content: bookmark.content,
      createTime: bookmark.createTime
    });
  }

  async getBookmarkAt(bookUrl: string, chapterIndex: number, pageIndex: number): Promise<Bookmark | null> {
    if (!this.store || !bookUrl) return null;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('chapterIndex', chapterIndex);
    predicates.equalTo('pageIndex', pageIndex);
    const resultSet = await this.store.query(predicates, []);
    try {
      if (!resultSet.goToFirstRow()) return null;
      return this.resultSetToBookmark(resultSet);
    } finally {
      resultSet.close();
    }
  }

  async deleteBookmark(id: number): Promise<void> {
    if (!this.store || id <= 0) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('id', id);
    await this.store.delete(predicates);
  }

  async deleteBookmarks(ids: number[]): Promise<void> {
    if (!this.store || ids.length === 0) return;
    const validIds = ids.filter((id: number) => id > 0);
    if (validIds.length === 0) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.in('id', validIds);
    await this.store.delete(predicates);
  }

  async deleteBookBookmarks(bookUrl: string): Promise<void> {
    if (!this.store || !bookUrl) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', bookUrl);
    await this.store.delete(predicates);
  }

  async moveBookBookmarks(fromBookUrl: string, toBookUrl: string, bookName: string, bookAuthor: string): Promise<void> {
    if (!this.store || !fromBookUrl || !toBookUrl || fromBookUrl === toBookUrl) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', fromBookUrl);
    await this.store.update({
      bookUrl: toBookUrl,
      bookName: bookName,
      bookAuthor: bookAuthor
    }, predicates);
  }

  async updateBookBookmarkMetadata(bookUrl: string, bookName: string, bookAuthor: string): Promise<void> {
    if (!this.store || !bookUrl) return;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('bookUrl', bookUrl);
    await this.store.update({
      bookName: bookName,
      bookAuthor: bookAuthor
    }, predicates);
  }

  private resultSetToBookmark(resultSet: relationalStore.ResultSet): Bookmark {
    const bookmark = new Bookmark();
    bookmark.id = resultSet.getLong(resultSet.getColumnIndex('id'));
    bookmark.bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
    bookmark.bookName = resultSet.getString(resultSet.getColumnIndex('bookName'));
    bookmark.bookAuthor = resultSet.getString(resultSet.getColumnIndex('bookAuthor'));
    bookmark.chapterIndex = resultSet.getLong(resultSet.getColumnIndex('chapterIndex'));
    bookmark.chapterName = resultSet.getString(resultSet.getColumnIndex('chapterName'));
    bookmark.pageIndex = resultSet.getLong(resultSet.getColumnIndex('pageIndex'));
    bookmark.startPos = resultSet.getLong(resultSet.getColumnIndex('startPos'));
    bookmark.endPos = resultSet.getLong(resultSet.getColumnIndex('endPos'));
    bookmark.content = resultSet.getString(resultSet.getColumnIndex('content'));
    bookmark.createTime = resultSet.getLong(resultSet.getColumnIndex('createTime'));
    return bookmark;
  }

  async getBook(bookUrl: string): Promise<Book | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('bookUrl', bookUrl);
    const resultSet = await this.store.query(predicates, []);
    try {
      if (!resultSet.goToFirstRow()) return null;
      const book = this.resultSetToBook(resultSet);
      return await this.hydrateBookLocalVariable(book);
    } finally {
      resultSet.close();
    }
  }

  async getAllBooks(): Promise<Book[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.orderByDesc('durChapterTime');
    const resultSet = await this.store.query(predicates, []);
    const books: Book[] = [];
    try {
      while (resultSet.goToNextRow()) {
        books.push(this.resultSetToBook(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return await this.hydrateBooksLocalVariable(books);
  }

  async setBookPinned(bookUrl: string, pinned: boolean, modifiedTime: number = Date.now()): Promise<void> {
    if (!this.store || !bookUrl) return;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('bookUrl', bookUrl);
    const affected = await this.store.update({
      isPinned: pinned ? 1 : 0,
      shelfModifiedTime: modifiedTime
    }, predicates);
    if (affected <= 0) {
      throw new Error(`置顶书籍未命中数据库记录: ${bookUrl}`);
    }
  }

  async getBookByIdentityKey(identityKey: string): Promise<Book | null> {
    if (!this.store || !identityKey) return null;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('identityKey', identityKey);
    const resultSet = await this.store.query(predicates, []);
    try {
      if (!resultSet.goToFirstRow()) return null;
      const book = this.resultSetToBook(resultSet);
      return await this.hydrateBookLocalVariable(book);
    } finally {
      resultSet.close();
    }
  }

  /**
   * Local books use a content fingerprint for cross-device progress sync. The
   * fingerprint lives in the variable JSON rather than in the source-facing
   * schema, so older databases remain compatible.
   */
  async getBookByLocalContentHash(contentHash: string): Promise<Book | null> {
    const normalized = (contentHash || '').trim();
    if (!this.store || !normalized) return null;
    const books = await this.getAllBooks();
    for (const book of books) {
      if (book.origin === 'local' && book.getVariable('localContentHash') === normalized) {
        return book;
      }
    }
    return null;
  }

  async restoreBook(book: Book): Promise<void> {
    if (!this.store || !book.bookUrl) return;
    book.identityKey = BookIdentity.keyOfBook(book);
    const existing = await this.getBook(book.bookUrl) || await this.getBookByIdentityKey(book.identityKey);
    if (existing) {
      if (existing.bookUrl !== book.bookUrl) {
        book.bookUrl = existing.bookUrl;
      }
      await this.updateBook(book, true, 'cloud_restore_update');
    } else {
      await this.insertBook(book, 'cloud_restore_insert');
    }
  }

  async getCustomBookGroups(): Promise<BookGroup[]> {
    const groups: BookGroup[] = [];
    if (!this.store) return groups;
    const resultSet = await this.store.querySql(
      'SELECT groupId, groupName, groupOrder, show, enableRefresh FROM book_groups WHERE groupId > 0 ORDER BY groupOrder, groupId'
    );
    try {
      while (resultSet.goToNextRow()) {
        const group = new BookGroup();
        group.groupId = resultSet.getLong(resultSet.getColumnIndex('groupId'));
        group.groupName = resultSet.getString(resultSet.getColumnIndex('groupName'));
        group.order = resultSet.getLong(resultSet.getColumnIndex('groupOrder'));
        group.show = resultSet.getLong(resultSet.getColumnIndex('show')) === 1;
        group.enableRefresh = resultSet.getLong(resultSet.getColumnIndex('enableRefresh')) === 1;
        groups.push(group);
      }
    } finally {
      resultSet.close();
    }
    return groups;
  }

  async restoreBookGroup(group: BookGroup): Promise<void> {
    if (!this.store || group.groupId <= 0 || !group.groupName.trim()) return;
    const predicates = new relationalStore.RdbPredicates('book_groups');
    predicates.equalTo('groupId', group.groupId);
    const resultSet = await this.store.query(predicates, []);
    const bucket: relationalStore.ValuesBucket = {
      groupId: group.groupId,
      groupName: group.groupName,
      groupOrder: group.order,
      show: group.show ? 1 : 0,
      enableRefresh: group.enableRefresh ? 1 : 0
    };
    const exists = resultSet.rowCount > 0;
    resultSet.close();
    if (exists) {
      await this.store.update(bucket, predicates);
    } else {
      await this.store.insert('book_groups', bucket);
    }
  }

  async addBookGroup(groupName: string): Promise<BookGroup | null> {
    if (!this.store || !groupName.trim()) return null;
    const name = groupName.trim();
    const duplicate = await this.store.querySql('SELECT groupId FROM book_groups WHERE groupName = ?', [name]);
    const duplicateExists = duplicate.rowCount > 0;
    duplicate.close();
    if (duplicateExists) return null;
    const group = new BookGroup();
    // 不能用 MAX(groupId)+1：云同步下两台设备各自离线建组会算出同一个 ID，
    // 同步后按行互相覆盖，其中一个分组连同其书籍归属一起丢失。
    // 改为由分组名派生的 ID：同名分组在任意设备上都得到同一个 ID，于是
    // “各建一个同名分组”收敛为同一行（而不是互相覆盖后丢一个）；
    // 不同名的分组则几乎不可能碰撞（见 groupIdFromName）。
    group.groupId = this.groupIdFromName(name);
    group.groupName = name;
    group.order = await this.nextGroupOrder();
    await this.store.insert('book_groups', {
      groupId: group.groupId, groupName: group.groupName, groupOrder: group.order, show: 1, enableRefresh: 1
    });
    return group;
  }

  /**
   * 由分组名派生稳定 ID：正 63 位整数，与 BookGroup 的负数内置 ID 不冲突。
   * 同名分组跨设备一致，避免自增 ID 的覆盖冲突。
   */
  private groupIdFromName(name: string): number {
    // FNV-1a 64 位，取正 63 位；高低两段各自参与，降低截断后的碰撞概率。
    const text = name.normalize('NFC');
    let hashHigh = 0x811c9dc5;
    let hashLow = 0x01000193;
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      hashHigh = (hashHigh ^ code) >>> 0;
      hashHigh = (hashHigh + (hashHigh << 1) + (hashHigh << 4) +
        (hashHigh << 7) + (hashHigh << 8) + (hashHigh << 24)) >>> 0;
      hashLow = (hashLow ^ (code + i)) >>> 0;
      hashLow = (hashLow + (hashLow << 3) + (hashLow << 13)) >>> 0;
    }
    const mixed = (hashHigh ^ hashLow) >>> 0;
    // 云侧数据类型的 groupId 声明为 Integer，取值必须落在 32 位有符号正整数范围内。
    // 映射到 [2^30, 2^31-1]：既与历史小自增 ID 明显区分，又不超过 int32 上限。
    const base = AppDatabase.DERIVED_GROUP_ID_BASE;
    return base + (mixed % base);
  }

  /** 新分组排在末尾使用的排序值。 */
  private async nextGroupOrder(): Promise<number> {
    if (!this.store) return 0;
    let maxOrder = 0;
    try {
      const resultSet = await this.store.querySql(
        'SELECT IFNULL(MAX(groupOrder), 0) AS maxOrder FROM book_groups WHERE groupId > 0');
      try {
        if (resultSet.goToFirstRow()) {
          maxOrder = resultSet.getLong(resultSet.getColumnIndex('maxOrder'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      console.warn('读取分组排序失败:', e);
    }
    return Math.max(0, maxOrder) + 1;
  }

  /**
   * 把历史上按 MAX(groupId)+1 生成的小 ID 1、2、3… 换成由分组名派生的稳定 ID。
   * ID 必须由名字派生而非随机：否则两台设备各自迁移同一个分组会得到不同 ID，
   * 冲突只是被推迟而没有消除。同步迁移 books.groupId 的外键引用。
   */
  private async migrateBookGroupRandomIds(): Promise<void> {
    if (!this.store) return;
    try {
      const resultSet = await this.store.querySql(
        'SELECT groupId, groupName FROM book_groups WHERE groupId > 0 ORDER BY groupOrder, groupId');
      const legacy: LegacyGroupId[] = [];
      try {
        while (resultSet.goToNextRow()) {
          const record: LegacyGroupId = new LegacyGroupId();
          record.groupId = resultSet.getLong(resultSet.getColumnIndex('groupId'));
          record.groupName = resultSet.getString(resultSet.getColumnIndex('groupName'));
          legacy.push(record);
        }
      } finally {
        resultSet.close();
      }
      // 只有小 ID 才是历史自增生成的。派生 ID 落在 2^30 到 2^31 之间（见
      // groupIdFromName），因此以 2^30 为界区分"待迁移的旧 ID"与"已迁移的派生 ID"，
      // 既保证幂等，也不会误伤内置的负数 ID。
      const migrated: string[] = [];
      for (const entry of legacy) {
        const oldId = entry.groupId;
        const name = entry.groupName;
        if (oldId >= AppDatabase.DERIVED_GROUP_ID_BASE || !name) {
          continue;
        }
        const newId = this.groupIdFromName(name);
        try {
          await this.store.executeSql('UPDATE book_groups SET groupId = ? WHERE groupId = ?',
            [newId, oldId]);
          await this.store.executeSql('UPDATE books SET groupId = ? WHERE groupId = ?',
            [newId, oldId]);
          migrated.push(name);
        } catch (e) {
          console.warn('迁移分组 ID 失败:', e);
        }
      }
      // 改主键对端云同步等于"删旧行 + 插新行"。设备升级进度不一致时，云端可能同时
      // 存在同一分组的旧 ID 行与新 ID 行，同步后在界面上表现为重复分组。
      // 名字是派生 ID 的唯一输入，因此这里按 groupName 去重，保留派生 ID 那一行。
      await this.dedupeBookGroupsByName(migrated);
    } catch (e) {
      console.warn('迁移分组随机 ID 失败:', e);
    }
  }

  /** 删除 groupName 重复的行，保留 groupId 最大（即派生 ID）的那一行。 */
  private async dedupeBookGroupsByName(names: string[]): Promise<void> {
    if (!this.store || names.length === 0) return;
    for (const name of names) {
      try {
        // 保留 ID 最大的一行，并把被删行的书籍归属迁移过去。
        const keepResult = await this.store.querySql(
          'SELECT MAX(groupId) AS keepId FROM book_groups WHERE groupName = ?', [name]);
        let keepId = 0;
        try {
          if (keepResult.goToFirstRow()) {
            keepId = keepResult.getLong(keepResult.getColumnIndex('keepId'));
          }
        } finally {
          keepResult.close();
        }
        if (keepId <= 0) continue;
        await this.store.executeSql(
          'UPDATE books SET groupId = ? WHERE groupId IN ' +
          '(SELECT groupId FROM book_groups WHERE groupName = ? AND groupId != ?)',
          [keepId, name, keepId]);
        await this.store.executeSql(
          'DELETE FROM book_groups WHERE groupName = ? AND groupId != ?', [name, keepId]);
      } catch (e) {
        console.warn('按名称去重分组失败:', e);
      }
    }
  }

  /**
   * 把"不应上云"的既有数据从同步表搬到本地表：
   * 1. book_sources.loginHeader / loginInfo / rawSourceJson → book_source_local；
   * 2. books.variable 里的本机键 → book_local_meta。
   * 搬完后清空同步表的对应列，让云端已有的敏感/冗余副本随下一轮同步被覆盖为空。
   */
  private async migrateLocalOnlyColumns(): Promise<void> {
    if (!this.store) return;
    await this.migrateBookSourceLocalColumns();
    await this.migrateBookLocalVariableKeys();
  }

  private async migrateBookSourceLocalColumns(): Promise<void> {
    if (!this.store) return;
    try {
      const resultSet = await this.store.querySql(
        'SELECT bookSourceUrl, loginHeader, loginInfo, rawSourceJson FROM book_sources');
      const rows: BookSourceLocal[] = [];
      try {
        while (resultSet.goToNextRow()) {
          const url = resultSet.getString(resultSet.getColumnIndex('bookSourceUrl'));
          if (!url) continue;
          const record = new BookSourceLocal();
          record.bookSourceUrl = url;
          try {
            record.loginHeader = resultSet.getString(resultSet.getColumnIndex('loginHeader')) || '';
          } catch (_) {
            record.loginHeader = '';
          }
          try {
            record.loginInfo = resultSet.getString(resultSet.getColumnIndex('loginInfo')) || '';
          } catch (_) {
            record.loginInfo = '';
          }
          try {
            record.rawSourceJson = resultSet.getString(resultSet.getColumnIndex('rawSourceJson')) || '';
          } catch (_) {
            record.rawSourceJson = '';
          }
          rows.push(record);
        }
      } finally {
        resultSet.close();
      }
      for (const record of rows) {
        // 只在本机表为空时搬，避免重复迁移把后续新凭据覆盖回旧值。
        const existing = await this.getBookSourceLocal(record.bookSourceUrl);
        if (existing) continue;
        await this.saveBookSourceLocal(record);
      }
      // 清空同步表列：既减小同步体积，也让云端旧副本被覆盖。
      await this.store.executeSql(
        "UPDATE book_sources SET loginHeader = '', loginInfo = '', rawSourceJson = ''");
    } catch (e) {
      console.warn('迁移书源本机列失败:', e);
    }
  }

  private async migrateBookLocalVariableKeys(): Promise<void> {
    if (!this.store) return;
    try {
      const resultSet = await this.store.querySql('SELECT bookUrl, variable FROM books');
      const rows: Array<{ bookUrl: string, variable: string }> = [];
      try {
        while (resultSet.goToNextRow()) {
          const bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
          if (!bookUrl) continue;
          let variable = '';
          try {
            variable = resultSet.getString(resultSet.getColumnIndex('variable')) || '';
          } catch (_) {
            variable = '';
          }
          rows.push({ bookUrl: bookUrl, variable: variable });
        }
      } finally {
        resultSet.close();
      }
      for (const row of rows) {
        if (!row.variable) continue;
        const split = AppDatabase.splitBookVariable(row.variable);
        if (split.local === '{}') continue;
        // 本机表为空时才写入，避免重复迁移覆盖后续产生的新值。
        const existing = await this.getBookLocalVariable(row.bookUrl);
        if (!existing || existing === '{}') {
          await this.saveBookLocalVariable(row.bookUrl, split.local);
        }
        const predicates = new relationalStore.RdbPredicates('books');
        predicates.equalTo('bookUrl', row.bookUrl);
        await this.store.update({ variable: split.cloud }, predicates);
      }
    } catch (e) {
      console.warn('迁移书籍本机元数据失败:', e);
    }
  }

  /**
   * 修正 schema 21 的过度迁移：当时把 localContentHash 当成本机键挪进了
   * book_local_meta 并从同步行删除，导致本地书的阅读进度无法跨设备匹配
   * （见 BookIdentity.cloudIdentityValue）。现在该键改归云端，需要把它
   * 从本机表搬回 books.variable，让本地书进度重新可跨设备同步。
   */
  private async restoreSharedContentHash(): Promise<void> {
    if (!this.store) return;
    try {
      const resultSet = await this.store.querySql('SELECT bookUrl, variable FROM book_local_meta');
      const rows: Array<{ bookUrl: string, variable: string }> = [];
      try {
        while (resultSet.goToNextRow()) {
          const bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
          if (!bookUrl) continue;
          let variable = '';
          try {
            variable = resultSet.getString(resultSet.getColumnIndex('variable')) || '';
          } catch (_) {
            variable = '';
          }
          rows.push({ bookUrl: bookUrl, variable: variable });
        }
      } finally {
        resultSet.close();
      }
      for (const row of rows) {
        if (!row.variable || row.variable === '{}') continue;
        let parsed: Record<string, Object> = {};
        try {
          const value = JSON.parse(row.variable) as Record<string, Object>;
          if (value && typeof value === 'object') parsed = value;
        } catch (_) {
          continue;
        }
        const hash = parsed['localContentHash'];
        if (typeof hash !== 'string' || !hash) continue;
        // 从本机片段移除，交还给同步行。
        const remaining: Record<string, Object> = {};
        for (const key of Object.keys(parsed)) {
          if (key !== 'localContentHash') remaining[key] = parsed[key];
        }
        await this.saveBookLocalVariable(row.bookUrl, JSON.stringify(remaining));
        // 合并回 books.variable：同步行可能已有其它云端键，不能整块覆盖。
        const bookResult = await this.store.querySql(
          'SELECT variable FROM books WHERE bookUrl = ?', [row.bookUrl]);
        let cloudRaw = '';
        try {
          if (bookResult.goToFirstRow()) {
            cloudRaw = bookResult.getString(bookResult.getColumnIndex('variable')) || '';
          }
        } finally {
          bookResult.close();
        }
        if (!cloudRaw) continue;
        let cloud: Record<string, Object> = {};
        try {
          const value = JSON.parse(cloudRaw) as Record<string, Object>;
          if (value && typeof value === 'object') cloud = value;
        } catch (_) {
          cloud = {};
        }
        cloud['localContentHash'] = hash;
        const predicates = new relationalStore.RdbPredicates('books');
        predicates.equalTo('bookUrl', row.bookUrl);
        await this.store.update({ variable: JSON.stringify(cloud) }, predicates);
      }
    } catch (e) {
      console.warn('恢复本地书内容指纹失败:', e);
    }
  }

  async renameBookGroup(groupId: number, groupName: string): Promise<boolean> {
    if (!this.store || groupId <= 0 || !groupName.trim()) return false;
    const name = groupName.trim();
    const duplicate = await this.store.querySql(
      'SELECT groupId FROM book_groups WHERE groupName = ? AND groupId != ?', [name, groupId]
    );
    const duplicateExists = duplicate.rowCount > 0;
    duplicate.close();
    if (duplicateExists) return false;
    const predicates = new relationalStore.RdbPredicates('book_groups');
    predicates.equalTo('groupId', groupId);
    await this.store.update({ groupName: name }, predicates);
    return true;
  }

  async updateBooksGroup(bookUrls: string[], groupId: number): Promise<void> {
    if (!this.store || bookUrls.length === 0) return;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.in('bookUrl', bookUrls);
    await this.store.update({ groupId: groupId }, predicates);
  }

  async deleteBookGroup(groupId: number): Promise<void> {
    if (!this.store || groupId <= 0) return;
    const bookPredicates = new relationalStore.RdbPredicates('books');
    bookPredicates.equalTo('groupId', groupId);
    await this.store.update({ groupId: 0 }, bookPredicates);
    const groupPredicates = new relationalStore.RdbPredicates('book_groups');
    groupPredicates.equalTo('groupId', groupId);
    await this.store.delete(groupPredicates);
  }

  private resultSetToBook(resultSet: relationalStore.ResultSet): Book {
    const book = new Book();
    book.bookUrl = this.getStringColumn(resultSet, 'bookUrl');
    book.tocUrl = this.getStringColumn(resultSet, 'tocUrl');
    book.origin = this.getStringColumn(resultSet, 'origin', 'local');
    book.originName = this.getStringColumn(resultSet, 'originName');
    book.name = this.getStringColumn(resultSet, 'name');
    book.author = this.getStringColumn(resultSet, 'author');
    book.kind = this.getStringColumn(resultSet, 'kind');
    book.status = this.getStringColumn(resultSet, 'status');
    book.customTag = this.getStringColumn(resultSet, 'customTag');
    book.coverUrl = this.getStringColumn(resultSet, 'coverUrl');
    book.customCoverUrl = this.getStringColumn(resultSet, 'customCoverUrl');
    book.intro = this.getStringColumn(resultSet, 'intro');
    book.customIntro = this.getStringColumn(resultSet, 'customIntro');
    book.charset = this.getStringColumn(resultSet, 'charset');
    book.type = this.getLongColumn(resultSet, 'type');
    book.group = this.getLongColumn(resultSet, 'groupId');
    book.isPinned = this.getLongColumn(resultSet, 'isPinned') === 1;
    book.latestChapterTitle = this.getStringColumn(resultSet, 'latestChapterTitle');
    book.updateTime = this.getStringColumn(resultSet, 'updateTime');
    book.latestChapterTime = this.getLongColumn(resultSet, 'latestChapterTime');
    book.lastCheckTime = this.getLongColumn(resultSet, 'lastCheckTime');
    book.lastCheckCount = this.getLongColumn(resultSet, 'lastCheckCount');
    book.totalChapterNum = this.getLongColumn(resultSet, 'totalChapterNum');
    book.durChapterTitle = this.getStringColumn(resultSet, 'durChapterTitle');
    book.durChapterIndex = this.getLongColumn(resultSet, 'durChapterIndex');
    book.durChapterPos = this.getLongColumn(resultSet, 'durChapterPos');
    book.durChapterTime = this.getLongColumn(resultSet, 'durChapterTime');
    book.wordCount = this.getStringColumn(resultSet, 'wordCount');
    book.canUpdate = this.getLongColumn(resultSet, 'canUpdate', 1) === 1;
    book.order = this.getLongColumn(resultSet, 'bookOrder');
    book.originOrder = this.getLongColumn(resultSet, 'originOrder');
    book.variable = this.getStringColumn(resultSet, 'variable');
    const readConfigStr = this.getStringColumn(resultSet, 'readConfig');
    if (readConfigStr) {
      try {
        book.readConfig = JSON.parse(readConfigStr);
      } catch (e) {
        book.readConfig = null;
      }
    }
    book.syncTime = this.getLongColumn(resultSet, 'syncTime');
    book.identityKey = this.getStringColumn(resultSet, 'identityKey') || BookIdentity.keyOfBook(book);
    book.pendingAddToShelf = this.getLongColumn(resultSet, 'pendingAddToShelf') === 1;
    book.shelfModifiedTime = this.getLongColumn(resultSet, 'shelfModifiedTime');
    return book;
  }

  /**
   * 把 book_local_meta 中的本机片段合并回 Book.variable，让调用方看到的 variable
   * 与拆分前完全一致。同步表只存云端部分，本机部分单独存放，读取时再拼回来。
   */
  private async hydrateBookLocalVariable(book: Book): Promise<Book> {
    if (!book || !book.bookUrl) return book;
    const local = await this.getBookLocalVariable(book.bookUrl);
    if (!local || local === '{}') return book;
    let cloud: Record<string, Object> = {};
    try {
      const parsed = JSON.parse(book.variable || '{}') as Record<string, Object>;
      if (parsed && typeof parsed === 'object') cloud = parsed;
    } catch (_) {
      cloud = {};
    }
    let localMap: Record<string, Object> = {};
    try {
      const parsed = JSON.parse(local) as Record<string, Object>;
      if (parsed && typeof parsed === 'object') localMap = parsed;
    } catch (_) {
      localMap = {};
    }
    // 本机片段优先：它包含本地路径等无法从云端还原的信息。
    const merged: Record<string, Object> = { ...cloud, ...localMap };
    book.replaceVariable(JSON.stringify(merged));
    return book;
  }

  /** 批量合并本机片段，避免逐本查询。 */
  private async hydrateBooksLocalVariable(books: Book[]): Promise<Book[]> {
    if (!this.store || books.length === 0) return books;
    const urls = books.filter((book: Book): boolean => !!book.bookUrl)
      .map((book: Book): string => book.bookUrl);
    if (urls.length === 0) return books;
    const localMap: Map<string, string> = new Map();
    try {
      const placeholders = urls.map((): string => '?').join(', ');
      const resultSet = await this.store.querySql(
        `SELECT bookUrl, variable FROM book_local_meta WHERE bookUrl IN (${placeholders})`, urls);
      try {
        while (resultSet.goToNextRow()) {
          localMap.set(resultSet.getString(resultSet.getColumnIndex('bookUrl')),
            resultSet.getString(resultSet.getColumnIndex('variable')) || '{}');
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      console.warn('批量读取书籍本机元数据失败:', e);
      return books;
    }
    for (const book of books) {
      const local = localMap.get(book.bookUrl);
      if (!local || local === '{}') continue;
      let cloud: Record<string, Object> = {};
      try {
        const parsed = JSON.parse(book.variable || '{}') as Record<string, Object>;
        if (parsed && typeof parsed === 'object') cloud = parsed;
      } catch (_) {
        cloud = {};
      }
      let locals: Record<string, Object> = {};
      try {
        const parsed = JSON.parse(local) as Record<string, Object>;
        if (parsed && typeof parsed === 'object') locals = parsed;
      } catch (_) {
        locals = {};
      }
      book.replaceVariable(JSON.stringify({ ...cloud, ...locals }));
    }
    return books;
  }

  /** 把书源的本机凭据与原始 JSON 合并回 BookSource。 */
  private async hydrateBookSourceLocal(source: BookSource): Promise<BookSource> {
    if (!source || !source.bookSourceUrl) return source;
    const local = await this.getBookSourceLocal(source.bookSourceUrl);
    if (!local) return source;
    source.loginHeader = local.loginHeader;
    source.loginInfo = local.loginInfo;
    source.rawSourceJson = local.rawSourceJson;
    return source;
  }

  private async hydrateBookSourcesLocal(sources: BookSource[]): Promise<BookSource[]> {
    if (!this.store || sources.length === 0) return sources;
    const urls = sources.filter((source: BookSource): boolean => !!source.bookSourceUrl)
      .map((source: BookSource): string => source.bookSourceUrl);
    if (urls.length === 0) return sources;
    const localMap: Map<string, BookSourceLocal> = new Map();
    try {
      const placeholders = urls.map((): string => '?').join(', ');
      const resultSet = await this.store.querySql(
        `SELECT bookSourceUrl, loginHeader, loginInfo, rawSourceJson FROM book_source_local ` +
        `WHERE bookSourceUrl IN (${placeholders})`, urls);
      try {
        while (resultSet.goToNextRow()) {
          const record = new BookSourceLocal();
          record.bookSourceUrl = resultSet.getString(resultSet.getColumnIndex('bookSourceUrl'));
          record.loginHeader = resultSet.getString(resultSet.getColumnIndex('loginHeader')) || '';
          record.loginInfo = resultSet.getString(resultSet.getColumnIndex('loginInfo')) || '';
          record.rawSourceJson = resultSet.getString(resultSet.getColumnIndex('rawSourceJson')) || '';
          localMap.set(record.bookSourceUrl, record);
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      console.warn('批量读取书源本机数据失败:', e);
      return sources;
    }
    for (const source of sources) {
      const local = localMap.get(source.bookSourceUrl);
      if (!local) continue;
      source.loginHeader = local.loginHeader;
      source.loginInfo = local.loginInfo;
      source.rawSourceJson = local.rawSourceJson;
    }
    return sources;
  }

  private getStringColumn(resultSet: relationalStore.ResultSet, column: string, fallback: string = ''): string {
    const index = resultSet.getColumnIndex(column);
    if (index < 0) {
      return fallback;
    }
    return resultSet.getString(index) || fallback;
  }

  private getLongColumn(resultSet: relationalStore.ResultSet, column: string, fallback: number = 0): number {
    const index = resultSet.getColumnIndex(column);
    if (index < 0) {
      return fallback;
    }
    return resultSet.getLong(index);
  }

  async insertBookSource(source: BookSource): Promise<boolean> {
    if (!this.store) return false;
    const bucket: relationalStore.ValuesBucket = {
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceType: source.bookSourceType,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceComment: source.bookSourceComment,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      loginCheckJs: source.loginCheckJs,
      // 登录凭据与原始 JSON 副本不进同步表：book_source_local 未注册为分布式表。
      loginHeader: '',
      loginInfo: '',
      rawSourceJson: '',
      bookUrlPattern: source.bookUrlPattern,
      searchUrl: source.searchUrl,
      exploreUrl: source.exploreUrl,
      jsLib: source.jsLib,
      header: source.header,
      bookListRule: JSON.stringify(source.bookListRule),
      searchRule: JSON.stringify(source.searchRule),
      exploreRule: JSON.stringify(source.exploreRule),
      bookInfoRule: JSON.stringify(source.bookInfoRule),
      tocRule: JSON.stringify(source.tocRule),
      contentRule: JSON.stringify(source.contentRule),
      variableComment: source.variableComment,
      variable: source.variable,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: source.respondTime,
      customOrder: source.customOrder,
      customButton: source.customButton ? 1 : 0,
      eventListener: source.eventListener ? 1 : 0,
      isPinned: source.isPinned ? 1 : 0,
      enabled: source.enabled ? 1 : 0,
      enabledExplore: source.enabledExplore ? 1 : 0,
      isLocked: source.isLocked ? 1 : 0,
      validationStatus: this.normalizeBookSourceValidationStatus(source.validationStatus),
      weight: source.weight,
      concurrentRate: source.concurrentRate,
      enabledCookieJar: source.enabledCookieJar ? 1 : 0
    };

    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', source.bookSourceUrl);
    const resultSet = await this.store.query(predicates, []);
    const exists = resultSet.goToFirstRow();
    if (exists) {
      let locked = false;
      try {
        locked = this.getLongColumn(resultSet, 'isLocked') === 1;
        if (!locked) {
          // 导入更新已有书源时保留用户在管理页设置的顺序。
          bucket['customOrder'] = this.getLongColumn(resultSet, 'customOrder');
          source.customOrder = bucket['customOrder'] as number;
          bucket['isPinned'] = this.getLongColumn(resultSet, 'isPinned');
          source.isPinned = bucket['isPinned'] === 1;
          // 脚本设置与运行时缓存属于用户状态，更新书源定义时不能被覆盖。
          bucket['variable'] = this.getStringColumn(resultSet, 'variable');
          source.variable = bucket['variable'] as string;
        }
      } finally {
        resultSet.close();
      }
      if (locked) return false;
      // 登录凭据已从同步表移出：保留原有凭据（若本次未携带新凭据）。
      const existingLocal = await this.getBookSourceLocal(source.bookSourceUrl);
      const localRecord = new BookSourceLocal();
      localRecord.bookSourceUrl = source.bookSourceUrl;
      localRecord.loginHeader = source.loginHeader || (existingLocal ? existingLocal.loginHeader : '');
      localRecord.loginInfo = source.loginInfo || (existingLocal ? existingLocal.loginInfo : '');
      localRecord.rawSourceJson = source.rawSourceJson ||
        (existingLocal ? existingLocal.rawSourceJson : '');
      source.loginHeader = localRecord.loginHeader;
      source.loginInfo = localRecord.loginInfo;
      source.rawSourceJson = localRecord.rawSourceJson;
      await this.saveBookSourceLocal(localRecord);
      await this.store.update(bucket, predicates);
    } else {
      resultSet.close();
      // 新书源追加到现有顺序末尾，避免默认值 0 把它插到列表顶部。
      const maxOrderResult = await this.store.querySql('SELECT MAX(customOrder) AS maxOrder FROM book_sources');
      let maxOrder = -1;
      try {
        if (maxOrderResult.goToFirstRow()) {
          maxOrder = this.getLongColumn(maxOrderResult, 'maxOrder', -1);
        }
      } finally {
        maxOrderResult.close();
      }
      source.customOrder = Math.max(0, maxOrder + 1);
      bucket['customOrder'] = source.customOrder;
      const localRecord = new BookSourceLocal();
      localRecord.bookSourceUrl = source.bookSourceUrl;
      localRecord.loginHeader = source.loginHeader || '';
      localRecord.loginInfo = source.loginInfo || '';
      localRecord.rawSourceJson = source.rawSourceJson || '';
      await this.saveBookSourceLocal(localRecord);
      await this.store.insert('book_sources', bucket);
    }
    return true;
  }

  async updateBookSource(source: BookSource, originalBookSourceUrl: string = ''): Promise<void> {
    if (!this.store) return;
    const lookupUrl = originalBookSourceUrl || source.bookSourceUrl;
    if (await this.isBookSourceLocked(lookupUrl)) return;
    // 凭据与原始 JSON 写本机表，同步表对应列保持为空。
    const existingLocal = await this.getBookSourceLocal(lookupUrl);
    const localRecord = new BookSourceLocal();
    localRecord.bookSourceUrl = source.bookSourceUrl;
    localRecord.loginHeader = source.loginHeader || (existingLocal ? existingLocal.loginHeader : '');
    localRecord.loginInfo = source.loginInfo || (existingLocal ? existingLocal.loginInfo : '');
    localRecord.rawSourceJson = source.rawSourceJson ||
      (existingLocal ? existingLocal.rawSourceJson : '');
    await this.saveBookSourceLocal(localRecord);
    if (lookupUrl !== source.bookSourceUrl) {
      await this.deleteBookSourceLocal(lookupUrl);
    }
    const bucket: relationalStore.ValuesBucket = {
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceType: source.bookSourceType,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceComment: source.bookSourceComment,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      loginCheckJs: source.loginCheckJs,
      loginHeader: '',
      loginInfo: '',
      rawSourceJson: '',
      bookUrlPattern: source.bookUrlPattern,
      searchUrl: source.searchUrl,
      exploreUrl: source.exploreUrl,
      jsLib: source.jsLib,
      header: source.header,
      bookListRule: JSON.stringify(source.bookListRule),
      searchRule: JSON.stringify(source.searchRule),
      exploreRule: JSON.stringify(source.exploreRule),
      bookInfoRule: JSON.stringify(source.bookInfoRule),
      tocRule: JSON.stringify(source.tocRule),
      contentRule: JSON.stringify(source.contentRule),
      variableComment: source.variableComment,
      variable: source.variable,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: source.respondTime,
      customOrder: source.customOrder,
      customButton: source.customButton ? 1 : 0,
      eventListener: source.eventListener ? 1 : 0,
      isPinned: source.isPinned ? 1 : 0,
      enabled: source.enabled ? 1 : 0,
      enabledExplore: source.enabledExplore ? 1 : 0,
      isLocked: source.isLocked ? 1 : 0,
      validationStatus: this.normalizeBookSourceValidationStatus(source.validationStatus),
      weight: source.weight,
      concurrentRate: source.concurrentRate,
      enabledCookieJar: source.enabledCookieJar ? 1 : 0
    };

    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', lookupUrl);
    await this.store.update(bucket, predicates);
  }

  async deleteBookSource(bookSourceUrl: string): Promise<void> {
    if (!this.store) return;
    if (await this.isBookSourceLocked(bookSourceUrl)) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.delete(predicates);
    await this.deleteBookSourceLocal(bookSourceUrl);
  }

  async deleteBookSourceForSync(bookSourceUrl: string): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.delete(predicates);
    await this.deleteBookSourceLocal(bookSourceUrl);
  }

  async getBookSource(bookSourceUrl: string): Promise<BookSource | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    const resultSet = await this.store.query(predicates, []);
    try {
      if (!resultSet.goToFirstRow()) return null;
      const source = this.resultSetToBookSource(resultSet);
      return await this.hydrateBookSourceLocal(source);
    } finally {
      resultSet.close();
    }
  }

  async getAllBookSources(): Promise<BookSource[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.orderByDesc('isPinned');
    predicates.orderByAsc('customOrder');
    const resultSet = await this.store.query(predicates, []);
    const sources: BookSource[] = [];
    try {
      while (resultSet.goToNextRow()) {
        sources.push(this.resultSetToBookSource(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return await this.hydrateBookSourcesLocal(sources);
  }

  async restoreBookSource(source: BookSource): Promise<void> {
    if (!this.store || !source.bookSourceUrl) return;
    // 备份恢复会带回归属本机的凭据与原始 JSON：写本机表，不进同步表。
    const localRecord = new BookSourceLocal();
    localRecord.bookSourceUrl = source.bookSourceUrl;
    localRecord.loginHeader = source.loginHeader || '';
    localRecord.loginInfo = source.loginInfo || '';
    localRecord.rawSourceJson = source.rawSourceJson || '';
    await this.saveBookSourceLocal(localRecord);
    const bucket: relationalStore.ValuesBucket = {
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceType: source.bookSourceType,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceComment: source.bookSourceComment,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      loginCheckJs: source.loginCheckJs,
      loginHeader: '',
      loginInfo: '',
      rawSourceJson: '',
      bookUrlPattern: source.bookUrlPattern,
      searchUrl: source.searchUrl,
      exploreUrl: source.exploreUrl,
      jsLib: source.jsLib,
      header: source.header,
      bookListRule: JSON.stringify(source.bookListRule),
      searchRule: JSON.stringify(source.searchRule),
      exploreRule: JSON.stringify(source.exploreRule),
      bookInfoRule: JSON.stringify(source.bookInfoRule),
      tocRule: JSON.stringify(source.tocRule),
      contentRule: JSON.stringify(source.contentRule),
      variableComment: source.variableComment,
      variable: source.variable,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: source.respondTime,
      customOrder: source.customOrder,
      customButton: source.customButton ? 1 : 0,
      eventListener: source.eventListener ? 1 : 0,
      isPinned: source.isPinned ? 1 : 0,
      enabled: source.enabled ? 1 : 0,
      enabledExplore: source.enabledExplore ? 1 : 0,
      isLocked: source.isLocked ? 1 : 0,
      validationStatus: this.normalizeBookSourceValidationStatus(source.validationStatus),
      weight: source.weight,
      concurrentRate: source.concurrentRate,
      enabledCookieJar: source.enabledCookieJar ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', source.bookSourceUrl);
    const resultSet = await this.store.query(predicates, []);
    const exists = resultSet.rowCount > 0;
    resultSet.close();
    if (exists) {
      await this.store.update(bucket, predicates);
    } else {
      await this.store.insert('book_sources', bucket);
    }
  }

  /** 列表只读取轻量字段；规则详情在实际使用时再按主键加载。 */
  async getBookSourceSummaries(): Promise<BookSource[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.orderByDesc('isPinned');
    predicates.orderByAsc('customOrder');
    const columns = [
      'bookSourceUrl', 'bookSourceName', 'bookSourceGroup', 'loginUrl', 'loginUi',
      'loginCheckJs', 'exploreUrl', 'lastUpdateTime', 'customOrder', 'isPinned', 'enabled', 'enabledExplore', 'isLocked',
      'validationStatus'
    ];
    const resultSet = await this.store.query(predicates, columns);
    const sources: BookSource[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const source = new BookSource();
        source.bookSourceUrl = resultSet.getString(resultSet.getColumnIndex('bookSourceUrl'));
        source.bookSourceName = resultSet.getString(resultSet.getColumnIndex('bookSourceName'));
        source.bookSourceGroup = resultSet.getString(resultSet.getColumnIndex('bookSourceGroup'));
        source.loginUrl = resultSet.getString(resultSet.getColumnIndex('loginUrl'));
        source.loginUi = resultSet.getString(resultSet.getColumnIndex('loginUi'));
        source.loginCheckJs = resultSet.getString(resultSet.getColumnIndex('loginCheckJs'));
        source.exploreUrl = resultSet.getString(resultSet.getColumnIndex('exploreUrl'));
        source.lastUpdateTime = resultSet.getLong(resultSet.getColumnIndex('lastUpdateTime'));
        source.customOrder = resultSet.getLong(resultSet.getColumnIndex('customOrder'));
        source.isPinned = this.getLongColumn(resultSet, 'isPinned') === 1;
        source.enabled = resultSet.getLong(resultSet.getColumnIndex('enabled')) === 1;
        source.enabledExplore = resultSet.getLong(resultSet.getColumnIndex('enabledExplore')) === 1;
        source.isLocked = this.getLongColumn(resultSet, 'isLocked') === 1;
        source.validationStatus = this.normalizeBookSourceValidationStatus(
          this.getLongColumn(resultSet, 'validationStatus'));
        sources.push(source);
      }
    } finally {
      resultSet.close();
    }
    // 管理页/导出需要登录态标记与原始 JSON 做回导出，这里合并本机数据。
    return await this.hydrateBookSourcesLocal(sources);
  }

  async updateBookSourceListFields(bookSourceUrl: string, fields: Record<string, string | number>): Promise<void> {
    if (!this.store) return;
    if (await this.isBookSourceLocked(bookSourceUrl)) return;
    const bucket: relationalStore.ValuesBucket = {};
    if (fields['bookSourceGroup'] !== undefined) bucket['bookSourceGroup'] = fields['bookSourceGroup'];
    if (fields['enabled'] !== undefined) bucket['enabled'] = fields['enabled'];
    if (fields['enabledExplore'] !== undefined) bucket['enabledExplore'] = fields['enabledExplore'];
    if (fields['customOrder'] !== undefined) bucket['customOrder'] = fields['customOrder'];
    if (fields['validationStatus'] !== undefined) {
      bucket['validationStatus'] = this.normalizeBookSourceValidationStatus(Number(fields['validationStatus']));
    }
    bucket['lastUpdateTime'] = Date.now();
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update(bucket, predicates);
    if (fields['bookSourceGroup'] !== undefined ||
      fields['enabled'] !== undefined ||
      fields['enabledExplore'] !== undefined ||
      fields['customOrder'] !== undefined) {
    }
  }

  /** 书源排序属于列表管理信息，不受书源内容锁定状态影响。 */
  async updateBookSourceOrders(bookSourceUrls: string[]): Promise<void> {
    if (!this.store || bookSourceUrls.length === 0) return;
    const transaction = await this.store.createTransaction();
    try {
      for (let index = 0; index < bookSourceUrls.length; index++) {
        const bookSourceUrl = bookSourceUrls[index];
        if (!bookSourceUrl) continue;
        const predicates = new relationalStore.RdbPredicates('book_sources');
        predicates.equalTo('bookSourceUrl', bookSourceUrl);
        await transaction.update({ customOrder: index }, predicates);
      }
      await transaction.commit();
    } catch (e) {
      await transaction.rollback();
      throw e;
    }
  }

  /** 置顶属于列表管理信息，不受书源规则锁定状态影响。 */
  async setBookSourcePinned(bookSourceUrl: string, pinned: boolean): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({ isPinned: pinned ? 1 : 0 }, predicates);
  }

  /** 分组重命名或删除时更新归属；这类列表管理操作不改动书源规则内容。 */
  async updateBookSourceGroupMembership(bookSourceUrl: string, groupName: string): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({ bookSourceGroup: groupName, lastUpdateTime: Date.now() }, predicates);
  }

  async setBookSourceLocked(bookSourceUrl: string, locked: boolean): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({ isLocked: locked ? 1 : 0 }, predicates);
  }

  /** 校验结果是运行状态，锁定书源也需要正常记录。 */
  async updateBookSourceValidationStatus(bookSourceUrl: string, validationStatus: number): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({
      validationStatus: this.normalizeBookSourceValidationStatus(validationStatus)
    }, predicates);
  }

  /** Runtime source variables (for mirror selection/login actions) remain writable for locked rule definitions. */
  async updateBookSourceVariable(bookSourceUrl: string, variable: string): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({ variable: variable || '' }, predicates);
  }

  async updateBookSourceLoginRuntime(bookSourceUrl: string, variable: string, loginHeader: string,
    loginInfo: string): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    // 登录凭据是敏感数据且不跨设备：只写本机表，同步表的对应列保持为空。
    const existing = await this.getBookSourceLocal(bookSourceUrl);
    const record = new BookSourceLocal();
    record.bookSourceUrl = bookSourceUrl;
    record.loginHeader = loginHeader || '';
    record.loginInfo = loginInfo || '';
    record.rawSourceJson = existing ? existing.rawSourceJson : '';
    await this.saveBookSourceLocal(record);
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    await this.store.update({ variable: variable || '' }, predicates);
  }

  private normalizeBookSourceValidationStatus(value: number): number {
    if (value === BookSource.VALIDATION_PASSED || value === BookSource.VALIDATION_FAILED ||
      value === BookSource.VALIDATION_NO_RESULTS || value === BookSource.VALIDATION_NEEDS_VERIFICATION ||
      value === BookSource.VALIDATION_TEMPORARY_ERROR) {
      return value;
    }
    return BookSource.VALIDATION_UNCHECKED;
  }

  private async isBookSourceLocked(bookSourceUrl: string): Promise<boolean> {
    if (!this.store || !bookSourceUrl) return false;
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('bookSourceUrl', bookSourceUrl);
    const resultSet = await this.store.query(predicates, ['isLocked']);
    try {
      if (!resultSet.goToFirstRow()) return false;
      return this.getLongColumn(resultSet, 'isLocked') === 1;
    } finally {
      resultSet.close();
    }
  }

  async getEnabledBookSources(): Promise<BookSource[]> {
    return this.getEnabledBookSourcesForRuleScope('all');
  }

  async getEnabledBookSourcesForSearch(): Promise<BookSource[]> {
    const sources = await this.getEnabledBookSourcesForRuleScope('search');
    return sources.filter((source: BookSource): boolean =>
      !!(source.bookSourceUrl && source.bookSourceName && source.searchUrl &&
        source.searchRule && source.searchRule.bookList));
  }

  /** 启用且支持搜索的书源 URL 列表（换源等场景），与换源/搜索实际使用的书源集合保持同一口径。 */
  async getEnabledBookSourceUrls(): Promise<string[]> {
    const sources = await this.getEnabledBookSourcesForSearch();
    return sources.map((source: BookSource): string => source.bookSourceUrl || '')
      .filter((url: string): boolean => !!url);
  }

  async getEnabledBookSourcesForExplore(): Promise<BookSource[]> {
    return this.getEnabledBookSourcesForRuleScope('explore');
  }

  private async getEnabledBookSourcesForRuleScope(ruleScope: string): Promise<BookSource[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.equalTo('enabled', 1);
    if (ruleScope === 'explore') predicates.equalTo('enabledExplore', 1);
    predicates.orderByDesc('isPinned');
    predicates.orderByAsc('customOrder');
    const columns = ruleScope === 'search' ? this.searchBookSourceColumns() :
      (ruleScope === 'explore' ? this.exploreBookSourceColumns() : []);
    const resultSet = await this.store.query(predicates, columns);
    const sources: BookSource[] = [];
    try {
      while (resultSet.goToNextRow()) {
        sources.push(this.resultSetToBookSource(resultSet, ruleScope));
      }
    } finally {
      resultSet.close();
    }
    // 搜索/发现需要登录态（loginHeader/loginInfo），必须合并本机凭据。
    return await this.hydrateBookSourcesLocal(sources);
  }

  async searchBookSources(keyword: string): Promise<BookSource[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('book_sources');
    predicates.like('bookSourceName', `%${keyword}%`);
    predicates.orderByDesc('isPinned');
    predicates.orderByAsc('customOrder');
    const resultSet = await this.store.query(predicates, []);
    const sources: BookSource[] = [];
    try {
      while (resultSet.goToNextRow()) {
        sources.push(this.resultSetToBookSource(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return await this.hydrateBookSourcesLocal(sources);
  }

  private resultSetToBookSource(resultSet: relationalStore.ResultSet, ruleScope: string = 'all'): BookSource {
    const source = new BookSource();
    source.bookSourceUrl = this.getStringColumn(resultSet, 'bookSourceUrl');
    source.bookSourceName = this.getStringColumn(resultSet, 'bookSourceName');
    source.bookSourceType = this.getLongColumn(resultSet, 'bookSourceType');
    source.bookSourceGroup = this.getStringColumn(resultSet, 'bookSourceGroup');
    source.bookSourceComment = this.getStringColumn(resultSet, 'bookSourceComment');
    source.loginUrl = this.getStringColumn(resultSet, 'loginUrl');
    source.loginUi = this.getStringColumn(resultSet, 'loginUi');
    source.loginCheckJs = this.getStringColumn(resultSet, 'loginCheckJs');
    source.loginHeader = this.getStringColumn(resultSet, 'loginHeader');
    source.loginInfo = this.getStringColumn(resultSet, 'loginInfo');
    source.rawSourceJson = this.getStringColumn(resultSet, 'rawSourceJson');
    source.bookUrlPattern = this.getStringColumn(resultSet, 'bookUrlPattern');
    source.searchUrl = this.getStringColumn(resultSet, 'searchUrl');
    source.exploreUrl = this.getStringColumn(resultSet, 'exploreUrl');
    source.jsLib = this.getStringColumn(resultSet, 'jsLib');
    source.header = this.getStringColumn(resultSet, 'header');
    if (ruleScope === 'all') {
      try {
        source.bookListRule = JSON.parse(this.getStringColumn(resultSet, 'bookListRule'));
      } catch (e) {}
    }
    if (ruleScope === 'all' || ruleScope === 'search' || ruleScope === 'explore') {
      try {
        source.searchRule = JSON.parse(this.getStringColumn(resultSet, 'searchRule'));
      } catch (e) {}
    }
    if (ruleScope === 'all' || ruleScope === 'explore') {
      try {
        const parsed = JSON.parse(this.getStringColumn(resultSet, 'exploreRule')) as Object;
        if (parsed && !Array.isArray(parsed)) source.exploreRule = parsed as ExploreRule;
      } catch (e) {}
    }
    if (ruleScope === 'all') {
      try {
        source.bookInfoRule = JSON.parse(this.getStringColumn(resultSet, 'bookInfoRule'));
      } catch (e) {}
      try {
        const parsed = JSON.parse(this.getStringColumn(resultSet, 'tocRule')) as Object;
        if (parsed && !Array.isArray(parsed)) source.tocRule = parsed as TocRule;
        source.tocRule.nextTocUrl = source.tocRule.nextTocUrl || '';
      } catch (e) {}
      try {
        const parsed = JSON.parse(this.getStringColumn(resultSet, 'contentRule')) as Object;
        if (parsed && !Array.isArray(parsed)) source.contentRule = parsed as ContentRule;
        source.contentRule.sourceRegex = source.contentRule.sourceRegex || '';
        source.contentRule.nextContentUrl = source.contentRule.nextContentUrl || '';
        source.contentRule.imageDecode = source.contentRule.imageDecode || '';
      } catch (e) {}
    }
    source.variableComment = this.getStringColumn(resultSet, 'variableComment');
    source.variable = this.getStringColumn(resultSet, 'variable');
    source.lastUpdateTime = this.getLongColumn(resultSet, 'lastUpdateTime');
    source.respondTime = this.getLongColumn(resultSet, 'respondTime', 180000);
    source.customOrder = this.getLongColumn(resultSet, 'customOrder');
    source.customButton = this.getLongColumn(resultSet, 'customButton') === 1;
    source.eventListener = this.getLongColumn(resultSet, 'eventListener') === 1;
    source.isPinned = this.getLongColumn(resultSet, 'isPinned') === 1;
    source.enabled = this.getLongColumn(resultSet, 'enabled') === 1;
    source.isLocked = this.getLongColumn(resultSet, 'isLocked') === 1;
    source.enabledExplore = this.getLongColumn(resultSet, 'enabledExplore') === 1;
    source.validationStatus = this.normalizeBookSourceValidationStatus(
      this.getLongColumn(resultSet, 'validationStatus'));
    source.weight = this.getLongColumn(resultSet, 'weight');
    source.concurrentRate = this.getStringColumn(resultSet, 'concurrentRate');
    source.enabledCookieJar = this.getLongColumn(resultSet, 'enabledCookieJar', 1) === 1;
    return source;
  }

  private searchBookSourceColumns(): string[] {
    return [
      'bookSourceUrl', 'bookSourceName', 'bookSourceType', 'bookSourceGroup', 'bookSourceComment',
      'loginUrl', 'loginHeader', 'loginInfo', 'searchUrl', 'jsLib', 'header', 'searchRule',
      'variable', 'lastUpdateTime', 'respondTime', 'customOrder', 'customButton', 'eventListener',
      'isPinned', 'enabled', 'isLocked', 'validationStatus', 'weight', 'concurrentRate', 'enabledCookieJar'
    ];
  }

  private exploreBookSourceColumns(): string[] {
    return [
      'bookSourceUrl', 'bookSourceName', 'bookSourceType', 'bookSourceGroup', 'bookSourceComment',
      'loginUrl', 'loginHeader', 'loginInfo', 'searchUrl', 'exploreUrl', 'jsLib', 'header',
      'searchRule', 'exploreRule', 'variable', 'lastUpdateTime', 'respondTime', 'customOrder',
      'customButton', 'eventListener', 'isPinned', 'enabled', 'isLocked', 'enabledExplore',
      'validationStatus', 'weight', 'concurrentRate', 'enabledCookieJar'
    ];
  }

  async insertBookChapter(chapter: BookChapter): Promise<void> {
    if (!this.store) return;
    const bucket: relationalStore.ValuesBucket = {
      url: chapter.url,
      title: chapter.title,
      bookUrl: chapter.bookUrl,
      chapterIndex: chapter.index,
      isVip: chapter.isVip ? 1 : 0,
      isPay: chapter.isPay ? 1 : 0,
      resourceUrl: chapter.resourceUrl,
      tag: chapter.tag,
      startOffset: chapter.start,
      endOffset: chapter.end,
      variable: chapter.variable
    };

    await this.store.insert('book_chapters', bucket);
  }

  async insertBookChapters(chapters: BookChapter[]): Promise<void> {
    if (!this.store || chapters.length === 0) return;
    const buckets: relationalStore.ValuesBucket[] = [];
    for (const chapter of chapters) {
      buckets.push({
        url: chapter.url,
        title: chapter.title,
        bookUrl: chapter.bookUrl,
        chapterIndex: chapter.index,
        isVip: chapter.isVip ? 1 : 0,
        isPay: chapter.isPay ? 1 : 0,
        resourceUrl: chapter.resourceUrl,
        tag: chapter.tag,
        startOffset: chapter.start,
        endOffset: chapter.end,
        variable: chapter.variable
      });
    }
    for (let offset = 0; offset < buckets.length; offset += AppDatabase.BATCH_INSERT_CHUNK_SIZE) {
      await this.store.batchInsert('book_chapters',
        buckets.slice(offset, offset + AppDatabase.BATCH_INSERT_CHUNK_SIZE));
    }
  }

  async insertBookChaptersWithContents(bookUrl: string, chapters: BookChapter[], contents: string[]): Promise<void> {
    if (!this.store || !bookUrl || chapters.length === 0 || chapters.length !== contents.length) return;
    const cacheDate = Date.now();
    const chapterBuckets: relationalStore.ValuesBucket[] = [];
    const contentBuckets: relationalStore.ValuesBucket[] = [];
    for (let i = 0; i < chapters.length; i++) {
      const chapter = chapters[i];
      chapterBuckets.push({
        url: chapter.url,
        title: chapter.title,
        bookUrl: chapter.bookUrl,
        chapterIndex: chapter.index,
        isVip: chapter.isVip ? 1 : 0,
        isPay: chapter.isPay ? 1 : 0,
        resourceUrl: chapter.resourceUrl,
        tag: chapter.tag,
        startOffset: chapter.start,
        endOffset: chapter.end,
        variable: chapter.variable
      });
      contentBuckets.push({
        bookUrl: bookUrl,
        chapterIndex: chapter.index,
        chapterUrl: chapter.url,
        chapterName: chapter.title,
        content: contents[i] || ' ',
        cacheDate: cacheDate
      });
      chapter.cacheDate = cacheDate;
    }
    const transaction = await this.store.createTransaction();
    try {
      for (let offset = 0; offset < chapterBuckets.length; offset += AppDatabase.BATCH_INSERT_CHUNK_SIZE) {
        await transaction.batchInsert('book_chapters',
          chapterBuckets.slice(offset, offset + AppDatabase.BATCH_INSERT_CHUNK_SIZE));
        await transaction.batchInsert('book_contents',
          contentBuckets.slice(offset, offset + AppDatabase.BATCH_INSERT_CHUNK_SIZE));
      }
      await transaction.commit();
    } catch (e) {
      await transaction.rollback();
      throw e;
    }
  }

  async deleteBookChapters(bookUrl: string): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates('book_chapters');
    predicates.equalTo('bookUrl', bookUrl);
    await this.store.delete(predicates);
    await this.deleteReaderPaginationCache(bookUrl);
  }

  async getBookChapters(bookUrl: string): Promise<BookChapter[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('book_chapters');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.orderByAsc('chapterIndex');
    const resultSet = await this.store.query(predicates, []);
    const chapters: BookChapter[] = [];
    try {
      while (resultSet.goToNextRow()) {
        chapters.push(this.resultSetToBookChapter(resultSet));
      }
    } finally {
      resultSet.close();
    }
    const cacheDates = await this.getBookChapterCacheDateMap(bookUrl);
    for (const chapter of chapters) {
      chapter.cacheDate = cacheDates.get(chapter.index) || 0;
    }
    return chapters;
  }

  async searchBookChapters(bookUrl: string, keyword: string): Promise<BookChapter[]> {
    if (!this.store || !bookUrl || !keyword.trim()) return [];
    const predicates = new relationalStore.RdbPredicates('book_chapters');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.like('title', `%${keyword.trim()}%`);
    predicates.orderByAsc('chapterIndex');
    const resultSet = await this.store.query(predicates, []);
    const chapters: BookChapter[] = [];
    try {
      while (resultSet.goToNextRow()) {
        chapters.push(this.resultSetToBookChapter(resultSet));
      }
    } finally {
      resultSet.close();
    }
    const cacheDates = await this.getBookChapterCacheDateMap(bookUrl);
    for (const chapter of chapters) {
      chapter.cacheDate = cacheDates.get(chapter.index) || 0;
    }
    return chapters;
  }

  async getBookChapterCount(bookUrl: string): Promise<number> {
    if (!this.store) return 0;
    const predicates = new relationalStore.RdbPredicates('book_chapters');
    predicates.equalTo('bookUrl', bookUrl);
    const resultSet = await this.store.query(predicates, []);
    try {
      return resultSet.rowCount;
    } finally {
      resultSet.close();
    }
  }

  async getCachedChapterContent(bookUrl: string, chapterIndex: number): Promise<string> {
    if (!this.store) return '';
    const predicates = new relationalStore.RdbPredicates('book_contents');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('chapterIndex', chapterIndex);
    const resultSet = await this.store.query(predicates, ['content']);
    try {
      if (!resultSet.goToFirstRow()) return '';
      return resultSet.getString(resultSet.getColumnIndex('content')) || '';
    } finally {
      resultSet.close();
    }
  }

  async saveCachedChapterContent(bookUrl: string, chapter: BookChapter, content: string): Promise<void> {
    if (!this.store || !bookUrl || !content) return;
    const cacheDate = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      bookUrl: bookUrl,
      chapterIndex: chapter.index,
      chapterUrl: chapter.url,
      chapterName: chapter.title,
      content: content,
      cacheDate: cacheDate
    };
    const predicates = new relationalStore.RdbPredicates('book_contents');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('chapterIndex', chapter.index);
    const resultSet = await this.store.query(predicates, []);
    const exists = resultSet.rowCount > 0;
    resultSet.close();
    if (exists) {
      await this.store.update(bucket, predicates);
    } else {
      await this.store.insert('book_contents', bucket);
    }
    chapter.cacheDate = cacheDate;
  }

  async deleteBookCachedContent(bookUrl: string): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates('book_contents');
    predicates.equalTo('bookUrl', bookUrl);
    await this.store.delete(predicates);
    await this.deleteReaderPaginationCache(bookUrl);
  }

  async deleteCachedChapterContent(bookUrl: string, chapterIndex: number): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates('book_contents');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('chapterIndex', chapterIndex);
    await this.store.delete(predicates);
    await this.deleteReaderPaginationCache(bookUrl, chapterIndex);
  }

  async getReaderPaginationCache(bookUrl: string, chapterIndex: number,
    layoutKey: string): Promise<ReaderPaginationCacheRecord | null> {
    if (!this.store || !bookUrl || !layoutKey) return null;
    const predicates = new relationalStore.RdbPredicates('reader_pagination_cache');
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('chapterIndex', chapterIndex);
    predicates.equalTo('layoutKey', layoutKey);
    const resultSet = await this.store.query(predicates, ['starts', 'ends']);
    try {
      if (!resultSet.goToFirstRow()) return null;
      const starts = JSON.parse(resultSet.getString(resultSet.getColumnIndex('starts'))) as number[];
      const ends = JSON.parse(resultSet.getString(resultSet.getColumnIndex('ends'))) as number[];
      if (!Array.isArray(starts) || !Array.isArray(ends) || starts.length === 0 || starts.length !== ends.length) {
        return null;
      }
      const record = new ReaderPaginationCacheRecord();
      record.starts = starts;
      record.ends = ends;
      return record;
    } catch (_) {
      return null;
    } finally {
      resultSet.close();
    }
  }

  async saveReaderPaginationCache(bookUrl: string, chapterIndex: number, layoutKey: string,
    starts: number[], ends: number[]): Promise<void> {
    if (!this.store || !bookUrl || !layoutKey || starts.length === 0 || starts.length !== ends.length) return;
    const queueKey = `${bookUrl}\n${chapterIndex}`;
    this.readerPaginationPendingWrites.set(queueKey,
      new ReaderPaginationCacheWrite(bookUrl, chapterIndex, layoutKey, starts, ends));
    let task = this.readerPaginationWriteTasks.get(queueKey);
    if (!task) {
      task = this.flushReaderPaginationCacheWrites(queueKey);
      this.readerPaginationWriteTasks.set(queueKey, task);
    }
    await task;
  }

  private async flushReaderPaginationCacheWrites(queueKey: string): Promise<void> {
    try {
      while (this.readerPaginationPendingWrites.has(queueKey)) {
        const write = this.readerPaginationPendingWrites.get(queueKey);
        this.readerPaginationPendingWrites.delete(queueKey);
        if (!write || !this.store) continue;
        await this.deleteReaderPaginationCache(write.bookUrl, write.chapterIndex);
        const bucket: relationalStore.ValuesBucket = {
          bookUrl: write.bookUrl,
          chapterIndex: write.chapterIndex,
          layoutKey: write.layoutKey,
          starts: JSON.stringify(write.starts),
          ends: JSON.stringify(write.ends),
          updateTime: Date.now()
        };
        await this.store.insert('reader_pagination_cache', bucket,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      }
    } finally {
      this.readerPaginationWriteTasks.delete(queueKey);
    }
  }

  async deleteReaderPaginationCache(bookUrl: string, chapterIndex: number = -1): Promise<void> {
    if (!this.store || !bookUrl) return;
    const predicates = new relationalStore.RdbPredicates('reader_pagination_cache');
    predicates.equalTo('bookUrl', bookUrl);
    if (chapterIndex >= 0) predicates.equalTo('chapterIndex', chapterIndex);
    await this.store.delete(predicates);
  }

  async getBookChapterCacheDateMap(bookUrl: string): Promise<Map<number, number>> {
    const cacheDates: Map<number, number> = new Map();
    if (!this.store) return cacheDates;
    const predicates = new relationalStore.RdbPredicates('book_contents');
    predicates.equalTo('bookUrl', bookUrl);
    const resultSet = await this.store.query(predicates, ['chapterIndex', 'cacheDate']);
    try {
      while (resultSet.goToNextRow()) {
        cacheDates.set(
          resultSet.getLong(resultSet.getColumnIndex('chapterIndex')),
          resultSet.getLong(resultSet.getColumnIndex('cacheDate'))
        );
      }
    } finally {
      resultSet.close();
    }
    return cacheDates;
  }

  async getBookCachedChapterIndices(bookUrl: string): Promise<number[]> {
    const indices: number[] = [];
    const cacheDates = await this.getBookChapterCacheDateMap(bookUrl);
    cacheDates.forEach((_cacheDate: number, index: number) => {
      indices.push(index);
    });
    return indices;
  }

  private resultSetToBookChapter(resultSet: relationalStore.ResultSet): BookChapter {
    const chapter = new BookChapter();
    chapter.url = resultSet.getString(resultSet.getColumnIndex('url'));
    chapter.title = resultSet.getString(resultSet.getColumnIndex('title'));
    chapter.bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
    chapter.index = resultSet.getLong(resultSet.getColumnIndex('chapterIndex'));
    chapter.isVip = resultSet.getLong(resultSet.getColumnIndex('isVip')) === 1;
    chapter.isPay = resultSet.getLong(resultSet.getColumnIndex('isPay')) === 1;
    chapter.resourceUrl = resultSet.getString(resultSet.getColumnIndex('resourceUrl'));
    chapter.tag = resultSet.getString(resultSet.getColumnIndex('tag'));
    chapter.start = resultSet.getLong(resultSet.getColumnIndex('startOffset'));
    chapter.end = resultSet.getLong(resultSet.getColumnIndex('endOffset'));
    chapter.variable = resultSet.getString(resultSet.getColumnIndex('variable'));
    return chapter;
  }

  async getSearchKeywords(): Promise<SearchKeyword[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('search_keywords');
    predicates.orderByDesc('lastUseTime');
    const resultSet = await this.store.query(predicates, []);
    const keywords: SearchKeyword[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const keyword = new SearchKeyword();
        keyword.keyword = resultSet.getString(resultSet.getColumnIndex('keyword'));
        keyword.usage = resultSet.getLong(resultSet.getColumnIndex('usage'));
        keyword.lastUseTime = resultSet.getLong(resultSet.getColumnIndex('lastUseTime'));
        keywords.push(keyword);
      }
    } finally {
      resultSet.close();
    }
    return keywords;
  }

  async saveSearchKeyword(keyword: string): Promise<void> {
    if (!this.store) return;

    const predicates = new relationalStore.RdbPredicates('search_keywords');
    predicates.equalTo('keyword', keyword);
    const resultSet = await this.store.query(predicates, []);
    let usage = 0;
    try {
      if (resultSet.goToFirstRow()) {
        usage = resultSet.getLong(resultSet.getColumnIndex('usage')) + 1;
      }
    } finally {
      resultSet.close();
    }
    if (usage > 0) {
      const bucket: relationalStore.ValuesBucket = {
        usage: usage,
        lastUseTime: Date.now()
      };
      await this.store.update(bucket, predicates);
    } else {
      const bucket: relationalStore.ValuesBucket = {
        keyword: keyword,
        usage: 1,
        lastUseTime: Date.now()
      };
      await this.store.insert('search_keywords', bucket);
      // 搜索历史整表参与云同步，封顶保留最近 MAX_SEARCH_KEYWORDS 条，
      // 防止该表随使用无限增长并同步到云空间。
      await this.store.executeSql(
        `DELETE FROM search_keywords WHERE keyword NOT IN ` +
        `(SELECT keyword FROM search_keywords ORDER BY lastUseTime DESC ` +
        `LIMIT ${AppDatabase.MAX_SEARCH_KEYWORDS})`);
    }
  }

  async clearSearchKeywords(): Promise<void> {
    if (!this.store) return;
    await this.store.executeSql('DELETE FROM search_keywords');
  }

  async restoreSearchKeyword(keyword: SearchKeyword): Promise<void> {
    if (!this.store || !keyword.keyword) return;
    const predicates = new relationalStore.RdbPredicates('search_keywords');
    predicates.equalTo('keyword', keyword.keyword);
    const resultSet = await this.store.query(predicates, []);
    const bucket: relationalStore.ValuesBucket = {
      keyword: keyword.keyword,
      usage: keyword.usage,
      lastUseTime: keyword.lastUseTime
    };
    const exists = resultSet.rowCount > 0;
    resultSet.close();
    if (exists) {
      await this.store.update(bucket, predicates);
    } else {
      await this.store.insert('search_keywords', bucket);
    }
  }

  async deleteSearchKeyword(keyword: string): Promise<void> {
    if (!this.store) return;
    const predicates = new relationalStore.RdbPredicates('search_keywords');
    predicates.equalTo('keyword', keyword);
    await this.store.delete(predicates);
  }

  /**
   * 把 books.variable 拆成两部分：留在同步行的云端部分，和落到 book_local_meta 的本机部分。
   * 返回云端部分；本机部分由 persistBookLocalMeta 写入（调用方按需调用）。
   */
  static splitBookVariable(variable: string): { cloud: string, local: string } {
    let parsed: Record<string, Object> = {};
    try {
      const value = JSON.parse(variable || '{}') as Record<string, Object>;
      if (value && typeof value === 'object') {
        parsed = value;
      }
    } catch (_) {
      return { cloud: '{}', local: '{}' };
    }
    const cloud: Record<string, Object> = {};
    const local: Record<string, Object> = {};
    const keys = Object.keys(parsed);
    for (const key of keys) {
      if (LocalBookVariableKeys.isLocal(key)) {
        local[key] = parsed[key];
      } else {
        cloud[key] = parsed[key];
      }
    }
    return { cloud: JSON.stringify(cloud), local: JSON.stringify(local) };
  }

  /** 读取某本书的本机 variable 片段。 */
  async getBookLocalVariable(bookUrl: string): Promise<string> {
    if (!this.store || !bookUrl) return '{}';
    try {
      const resultSet = await this.store.querySql(
        'SELECT variable FROM book_local_meta WHERE bookUrl = ?', [bookUrl]);
      try {
        if (resultSet.goToFirstRow()) {
          return resultSet.getString(resultSet.getColumnIndex('variable')) || '{}';
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
      console.warn('读取书籍本机元数据失败:', e);
    }
    return '{}';
  }

  /** 写入某本书的本机 variable 片段（整块覆盖）。 */
  async saveBookLocalVariable(bookUrl: string, localVariable: string): Promise<void> {
    if (!this.store || !bookUrl) return;
    try {
      await this.store.executeSql(
        `INSERT OR REPLACE INTO book_local_meta (bookUrl, variable, updatedAt) VALUES (?, ?, ?)`,
        [bookUrl, localVariable || '{}', Date.now()]);
    } catch (e) {
      console.warn('保存书籍本机元数据失败:', e);
    }
  }

  /** 删除书籍时一并清理本机元数据。 */
  async deleteBookLocalVariable(bookUrl: string): Promise<void> {
    if (!this.store || !bookUrl) return;
    try {
      await this.store.executeSql('DELETE FROM book_local_meta WHERE bookUrl = ?', [bookUrl]);
    } catch (e) {
      console.warn('删除书籍本机元数据失败:', e);
    }
  }

  /** 书籍换源换 bookUrl 时，把本机元数据跟到新主键上。 */
  async renameBookLocalVariable(oldBookUrl: string, newBookUrl: string): Promise<void> {
    if (!this.store || !oldBookUrl || !newBookUrl || oldBookUrl === newBookUrl) return;
    const local = await this.getBookLocalVariable(oldBookUrl);
    await this.saveBookLocalVariable(newBookUrl, local);
    await this.deleteBookLocalVariable(oldBookUrl);
  }

  /** 读取书源的本机凭据与原始 JSON 副本。 */
  async getBookSourceLocal(bookSourceUrl: string): Promise<BookSourceLocal | null> {
    if (!this.store || !bookSourceUrl) return null;
    try {
      const predicates = new relationalStore.RdbPredicates('book_source_local');
      predicates.equalTo('bookSourceUrl', bookSourceUrl);
      const resultSet = await this.store.query(predicates, []);
      try {
        if (!resultSet.goToFirstRow()) return null;
        const record = new BookSourceLocal();
        record.bookSourceUrl = bookSourceUrl;
        record.loginHeader = this.getStringColumn(resultSet, 'loginHeader');
        record.loginInfo = this.getStringColumn(resultSet, 'loginInfo');
        record.rawSourceJson = this.getStringColumn(resultSet, 'rawSourceJson');
        return record;
      } finally {
        resultSet.close();
      }
    } catch (e) {
      console.warn('读取书源本机数据失败:', e);
    }
    return null;
  }

  /** 写入书源的本机凭据与原始 JSON 副本。 */
  async saveBookSourceLocal(record: BookSourceLocal): Promise<void> {
    if (!this.store || !record.bookSourceUrl) return;
    try {
      await this.store.executeSql(
        `INSERT OR REPLACE INTO book_source_local ` +
        `(bookSourceUrl, loginHeader, loginInfo, rawSourceJson, updatedAt) VALUES (?, ?, ?, ?, ?)`,
        [record.bookSourceUrl, record.loginHeader || '', record.loginInfo || '',
          record.rawSourceJson || '', Date.now()]);
    } catch (e) {
      console.warn('保存书源本机数据失败:', e);
    }
  }

  async deleteBookSourceLocal(bookSourceUrl: string): Promise<void> {
    if (!this.store || !bookSourceUrl) return;
    try {
      await this.store.executeSql(
        'DELETE FROM book_source_local WHERE bookSourceUrl = ?', [bookSourceUrl]);
    } catch (e) {
      console.warn('删除书源本机数据失败:', e);
    }
  }

  /** 保存书架"继续阅读"快照。该表不注册为分布式表，正文片段不再随 books 行上云。 */
  async saveBookShelfSnapshot(bookUrl: string, pageText: string, pageImage: string): Promise<void> {
    if (!this.store || !bookUrl) return;
    try {
      await this.store.executeSql(
        `INSERT OR REPLACE INTO book_shelf_snapshots (bookUrl, pageText, pageImage, updatedAt) ` +
        `VALUES (?, ?, ?, ?)`,
        [bookUrl, pageText, pageImage, Date.now()]);
    } catch (e) {
      console.warn('保存书架继续阅读快照失败:', e);
    }
  }

  async getBookShelfSnapshot(bookUrl: string): Promise<BookShelfSnapshot | null> {
    if (!this.store || !bookUrl) return null;
    const predicates = new relationalStore.RdbPredicates('book_shelf_snapshots');
    predicates.equalTo('bookUrl', bookUrl);
    const resultSet = await this.store.query(predicates, []);
    try {
      if (resultSet.goToFirstRow()) {
        return this.resultSetToShelfSnapshot(resultSet);
      }
    } finally {
      resultSet.close();
    }
    return null;
  }

  async getBookShelfSnapshots(): Promise<Map<string, BookShelfSnapshot>> {
    const snapshots = new Map<string, BookShelfSnapshot>();
    if (!this.store) return snapshots;
    const resultSet = await this.store.query(new relationalStore.RdbPredicates('book_shelf_snapshots'), []);
    try {
      while (resultSet.goToNextRow()) {
        const snapshot = this.resultSetToShelfSnapshot(resultSet);
        snapshots.set(snapshot.bookUrl, snapshot);
      }
    } finally {
      resultSet.close();
    }
    return snapshots;
  }

  private resultSetToShelfSnapshot(resultSet: relationalStore.ResultSet): BookShelfSnapshot {
    const snapshot = new BookShelfSnapshot();
    snapshot.bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
    snapshot.pageText = resultSet.getString(resultSet.getColumnIndex('pageText'));
    snapshot.pageImage = resultSet.getString(resultSet.getColumnIndex('pageImage'));
    return snapshot;
  }

  /**
   * 历史版本把"最后阅读页正文/图片"存进 books.variable 并随行上云。迁移到本地快照表，
   * 同时从 variable 中剥离这两个键，让 books 行（以及云空间里的对应记录）瘦身。
   */
  private async migrateBookShelfSnapshots(): Promise<void> {
    if (!this.store) return;
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.store.querySql('SELECT bookUrl, variable FROM books');
      while (resultSet.goToNextRow()) {
        const bookUrl = resultSet.getString(resultSet.getColumnIndex('bookUrl'));
        let variable = '';
        try {
          variable = resultSet.getString(resultSet.getColumnIndex('variable'));
        } catch (_) {
          variable = '';
        }
        if (!variable) continue;
        try {
          const parsed = JSON.parse(variable) as Record<string, Object>;
          if (!parsed || typeof parsed !== 'object') continue;
          const keys = Object.keys(parsed);
          const hasText = keys.includes('lastReadPageText');
          const hasImage = keys.includes('lastReadPageImage');
          if (!hasText && !hasImage) continue;
          const pageTextRaw: Object | undefined = parsed['lastReadPageText'];
          const pageImageRaw: Object | undefined = parsed['lastReadPageImage'];
          await this.saveBookShelfSnapshot(bookUrl,
            typeof pageTextRaw === 'string' ? pageTextRaw : '',
            typeof pageImageRaw === 'string' ? pageImageRaw : '');
          const clean: Record<string, Object> = {};
          for (const key of keys) {
            if (key !== 'lastReadPageText' && key !== 'lastReadPageImage') {
              clean[key] = parsed[key];
            }
          }
          const bucket: relationalStore.ValuesBucket = { variable: JSON.stringify(clean) };
          const predicates = new relationalStore.RdbPredicates('books');
          predicates.equalTo('bookUrl', bookUrl);
          await this.store.update(bucket, predicates);
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      console.warn('迁移书架继续阅读快照失败:', e);
    } finally {
      if (resultSet) resultSet.close();
    }
  }

  /** 端云同步心跳使用的本设备标识，首次调用时生成并持久化。 */
  async getOrCreateCloudDeviceId(): Promise<string> {
    if (this.cloudDeviceId) return this.cloudDeviceId;
    if (!this.store) return '';
    try {
      const resultSet = await this.store.querySql(
        `SELECT value FROM device_meta WHERE key = 'cloud_device_id'`);
      try {
        if (resultSet.goToFirstRow()) {
          const value = resultSet.getString(resultSet.getColumnIndex('value'));
          if (value) {
            this.cloudDeviceId = value;
            return value;
          }
        }
      } finally {
        resultSet.close();
      }
      const generated = `dev-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 10)}`;
      await this.store.executeSql(
        `INSERT OR REPLACE INTO device_meta (key, value) VALUES ('cloud_device_id', ?)`, [generated]);
      this.cloudDeviceId = generated;
      return generated;
    } catch (e) {
      console.warn('生成云同步设备标识失败:', e);
      return '';
    }
  }
}

export const appDb = AppDatabase.getInstance();

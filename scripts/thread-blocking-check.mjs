import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const scheduler = read('entry/src/main/ets/core/concurrency/CooperativeScheduler.ts');
const parseGate = read('entry/src/main/ets/core/concurrency/MainThreadParseGate.ts');
const preprocessor = read('entry/src/main/ets/core/concurrency/ReaderContentPreprocessor.ets');
const models = read('entry/src/main/ets/core/rule/RuleExecutionModels.ts');
const service = read('entry/src/main/ets/core/rule/RuleExecutionService.ts');
const stageRuntime = read('entry/src/main/ets/core/book/BookSourceStageWebRuntime.ts');
const stageRuntimeHost = read('entry/src/main/ets/components/BookSourceStageRuntimeHost.ets');
const search = read('entry/src/main/ets/core/book/SearchCoordinator.ts');
const explore = read('entry/src/main/ets/core/book/ExploreCoordinator.ts');
const webBook = read('entry/src/main/ets/core/book/WebBookService.ts');
const index = read('entry/src/main/ets/pages/Index.ets');
const reader = read('entry/src/main/ets/pages/ReadBook.ets');

assert(scheduler.includes('DEFAULT_UI_SLICE_MS: number = 6'),
  'Cooperative scheduler must keep the UI work slice below one frame');
assert(/setTimeout\(resolve,\s*[01]\)/.test(scheduler),
  'Cooperative scheduler must yield back to the event loop');
assert(scheduler.includes('CooperativeCancellationToken') && scheduler.includes('throwIfCancelled'),
  'Long-running rule work must remain cancellable');

assert(models.includes('listResult: boolean') && models.includes('readerActionMode: boolean'),
  'Rule requests must carry list-result and reader execution context');
assert(service.includes('executeFullJsFieldBatch') && service.includes('await runtime.execute(runtimeRequest)'),
  'Full JavaScript rules must execute through the isolated Stage Web runtime');
assert(!service.includes('fallback legacy'),
  'Unified rule execution must not silently fall back to synchronous legacy JavaScript');
assert(service.includes('await slice.checkpoint(token)') && service.includes('cancelOwner(ownerId: string)'),
  'Unified rule execution must be time-sliced and cancellable by owner');
assert(service.includes('yieldToNextUiFrame()') &&
  service.includes('CooperativeScheduler.DANGEROUS_OPERATION_MS'),
  'A pathological single-rule run (>=50ms) must be followed by a full-frame yield');
assert(/FRAME_YIELD_ITEM_INTERVAL:\s*number\s*=\s*8/.test(service),
  'Field batches must yield a full frame at least every 8 items');

// Process-wide main-thread parse admission: network concurrency must not translate into unbounded
// parsing concurrency on the single JS thread. Due native timer callbacks are coalesced into one
// uv_timer_task, per-pipeline setTimeout yields alone cannot prevent THREAD_BLOCK_6S appfreezes
// when responses arrive in a burst; waiters must park in a FIFO promise queue (no native timer)
// and permits must change hands at most once per frame.
assert(/DEFAULT_PARSE_CONCURRENCY:\s*number\s*=\s*3/.test(parseGate) &&
  /GRANT_FRAME_GAP_MS:\s*number\s*=\s*16/.test(parseGate),
  'Parse gate must bound main-thread parsing to 3 pipelines with 16ms frame-separated handoff');
const acquireStart = parseGate.indexOf('async acquire');
const acquireEnd = parseGate.indexOf('release(): void', acquireStart);
const acquireBody = parseGate.substring(acquireStart, acquireEnd);
assert(acquireBody.includes('this.waiters.push') && !acquireBody.includes('setTimeout'),
  'Parse gate waiters must park without arming a native timer so they cannot join timer coalescing');
assert(parseGate.includes('cancelCheck') && parseGate.includes('waiter.resolve(false)'),
  'Parse gate waiting must be abortable by the owning search/explore run');
for (const [name, source] of [['search', search], ['explore', explore]]) {
  assert(source.includes('MainThreadParseGate.get().acquire') &&
    /finally\s*\{[\s\S]*?MainThreadParseGate\.get\(\)\.release\(\)/.test(source),
    `${name} pipeline must acquire the parse gate around CPU parsing and release it in finally`);
}

for (const [name, source] of [['search', search], ['explore', explore], ['book', webBook]]) {
  assert(source.includes('RuleExecutionService'), `${name} flow must use RuleExecutionService`);
  assert(!source.includes('fallback legacy'), `${name} flow reintroduced a synchronous legacy fallback`);
}
assert(!search.includes('analyzeSearchField('),
  'Search must not parse result fields one-by-one on the UI thread');
assert(!explore.includes('analyzeExploreFieldBatch'),
  'Explore must not use its legacy field-batch parser');
assert((webBook.match(/RuleExecutionService\.get\(\)\.executeBatch/g) || []).length >= 5,
  'Book detail, catalogue and content parsing must use the unified execution entry');

assert(stageRuntime.includes('quarantineController') && stageRuntime.includes('this.controllers = this.controllers.filter'),
  'A timed-out Web runtime must be quarantined instead of reused');
// Since 2025-07 the stage runtime is a multi-slot hidden host pool: Index mounts POOL_SIZE hosts
// via ForEach, each host registers its own reset handler, and rebuilding a controller must not
// drop pool parallelism to zero (recycle only while another ready peer exists).
assert(/STAGE_RUNTIME_POOL_SIZE:\s*number\s*=\s*3/.test(stageRuntime) &&
  stageRuntime.includes('MAX_PARALLEL_TASKS') && /RECYCLE_TASK_INTERVAL:\s*number\s*=\s*6/.test(stageRuntime),
  'Stage Web runtime must keep a 3-host pool with task-count-based controller recycling');
assert(index.includes('BookSourceStageRuntimeHost') &&
  /ForEach\(this\.stageRuntimeHostSlots/.test(index) &&
  index.includes('STAGE_RUNTIME_POOL_SIZE'),
  'Index must mount the full pool of hidden Stage Web hosts through ForEach');
assert(stageRuntimeHost.includes('setResetHandler') && stageRuntimeHost.includes('resetHost()') &&
  stageRuntimeHost.includes('detach(') && stageRuntimeHost.includes('new webview.WebviewController()'),
  'Each Stage Web host must register a reset handler that rebuilds its Web node across a frame');
assert(stageRuntime.includes('this.controllers.length > 1'),
  'Controller recycling must keep at least one peer host so stage runtime parallelism never hits zero');

assert(preprocessor.includes('@Concurrent') && preprocessor.includes('taskpool.execute'),
  'Reader replacement rules must execute in TaskPool');
assert(preprocessor.includes('pattern.length > 4096') && preprocessor.includes('Nested unbounded quantifiers'),
  'Imported replacement rules must have basic regex abuse guards');
assert(reader.includes('ReaderContentPreprocessor.apply'),
  'Reader content must pass through the asynchronous preprocessor');
assert(reader.includes('this.appendReaderPaginationBatch(result, chapterIndex, imageOnlyPagination ? 8 : 1)'),
  'Background pagination must be bounded to one text page or a small pure-image batch');
assert(reader.includes('breakStrategy: graphicsText.BreakStrategy.GREEDY'),
  'Native paragraph measurement must use the bounded greedy line-break strategy');
assert(reader.includes('batchElapsedMs') && reader.includes('adaptiveDelay'),
  'Background pagination must monitor cost and adapt its scheduling delay');
assert(reader.includes("'下拉加载上一章'") && reader.includes("'上滑加载下一章'"),
  'Continuous reading must expose both chapter-boundary pull hints');
assert(reader.includes('runReaderComicChapterTransition') &&
  reader.includes('readerComicChapterTransitionOpacity'),
  'Continuous chapter switches must keep an explicit content transition');
assert(reader.includes('schedulePreviousChapterPaginationCompletion') &&
  reader.includes('scheduleNextChapterPaginationCompletion'),
  'Both adjacent chapters must be fully pre-paginated before a boundary switch');

console.log('Thread-blocking gate passed: main-thread parse admission, rule isolation, cancellation, ' +
  'TaskPool preprocessing, 3-host Web pool quarantine/rebuild, bounded pagination and continuous ' +
  'chapter handoff are all connected.');

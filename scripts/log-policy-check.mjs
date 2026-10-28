/**
 * 日志脱敏策略校验：禁止把 URL / Cookie / Token / 密码等敏感值原样写进控制台日志。
 *
 * 旧实现是"整行子串匹配"（console.log 所在行只要出现 url/token 等字样就报错），
 * 会把下面这些安全写法误判成泄漏：
 *   - 纯标签文案：`console.log('nextTocUrl:', tocRule.nextTocUrl ? 'set' : 'empty')`
 *   - 只打印数量：`console.log('pages:', pageUrls.length + 1)`
 *   - 已经脱敏过：`console.info('retry:', this.hostForLog(req.url))`
 * 因此改为解析 console 调用的**参数**，逐个判断"真正被打印出去的值"：
 *   1. 字符串字面量里出现 `://` → 直接判定为打印了 URL；
 *   2. 其余表达式先剥掉字面量，再看是否引用了敏感名字段；
 *   3. 引用了但属于"安全形态"（只取数量、只取布尔、走了脱敏函数）则放行。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const scan = ['entry/src/main/ets/core', 'entry/src/main/ets/utils', 'entry/src/main/ets/pages'];
const LEVELS = 'log';

/** 敏感字段名（剥掉字面量后的代码里命中即视为可疑）。 */
const SENSITIVE = /(url|uri|cookie|token|password|passwd|secret|authorization|credential)/i;

/**
 * 敏感"标签"字面量：只在独立成词时才算，避免把 `'nextTocUrl:'` 这类驼峰标签误判。
 * 用于兜住 `console.log('url:', u)` —— 变量名看不出来，但标签说明了打印的是 URL。
 */
const SENSITIVE_LABEL =
  /(^|[\s\-_/:])(url|uri|urls|cookie|token|tokens|password|passwd|secret|authorization|credential)(\s|:|=|$)/i;

/** 只输出"非原始值"的安全形态：数量 / 布尔 / 三元字面量。 */
const SAFE_SHAPES = [
  /\.(length|size|count)\b/,
  /\?\s*(['"`]|true\b|false\b|-?\d)/,
  /^\s*!!\s*[A-Za-z_$]/,
];

/** 项目内已知的脱敏函数：输出 host 或摘要，不含 query/凭据。 */
const SANITIZERS = /\b(hostForLog|urlHost|summarizeUrl|safeUrlForLog|urlForLog)\s*\(/;

/** 返回相对仓库根目录的文件路径。 */
function walk(relDir) {
  return fs.readdirSync(path.join(root, relDir), { withFileTypes: true }).flatMap((e) => {
    const rel = path.join(relDir, e.name);
    return e.isDirectory() ? walk(rel) : /\.(ets|ts)$/.test(e.name) ? [rel] : [];
  });
}

/** 从反引号处跳到模板字符串结束（含 ${} 嵌套）。 */
function skipTemplate(src, i) {
  let j = i + 1;
  while (j < src.length) {
    const c = src[j];
    if (c === '\\') { j += 2; continue; }
    if (c === '`') return j + 1;
    if (c === '$' && src[j + 1] === '{') {
      let k = j + 2;
      let depth = 1;
      while (k < src.length && depth > 0) {
        if (src[k] === '{') depth++;
        else if (src[k] === '}') depth--;
        k++;
      }
      j = k;
      continue;
    }
    j++;
  }
  return src.length;
}

/**
 * 跳过注释（注释里的引号/括号不能参与配对，否则扫描会"跑飞"）。
 * 不是注释则返回 -1。
 */
function skipComment(src, i) {
  if (src[i] !== '/') return -1;
  if (src[i + 1] === '/') {
    const nl = src.indexOf('\n', i + 2);
    return nl === -1 ? src.length : nl + 1;
  }
  if (src[i + 1] === '*') {
    const end = src.indexOf('*/', i + 2);
    return end === -1 ? src.length : end + 2;
  }
  return -1;
}

/** 截取 console.xxx( ... ) 括号内的参数文本（跨行、忽略字符串/注释里的括号）。 */
function captureArgs(src, openIdx) {
  let i = openIdx;
  let depth = 0;
  let quote = null;
  while (i < src.length) {
    // 极端情况下（源码本身括号不配对）兜底，避免把整个文件吞进来
    if (i - openIdx > 2000) return src.slice(openIdx + 1, i);
    const c = src[i];
    if (quote) {
      if (c === '\\') { i += 2; continue; }
      if (c === quote) quote = null;
      i++;
      continue;
    }
    const ci = skipComment(src, i);
    if (ci !== -1) { i = ci; continue; }
    if (c === "'" || c === '"') { quote = c; i++; continue; }
    if (c === '`') { i = skipTemplate(src, i); continue; }
    if (c === '(') { depth++; i++; continue; }
    if (c === ')') {
      depth--;
      if (depth === 0) return src.slice(openIdx + 1, i);
      i++;
      continue;
    }
    i++;
  }
  return src.slice(openIdx + 1);
}

/** 按顶层逗号切分参数。 */
function splitArgs(src) {
  const parts = [];
  let cur = '';
  let depth = 0;
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    const ci = skipComment(src, i);
    if (ci !== -1) { i = ci; continue; }
    if (c === "'" || c === '"') {
      let j = i + 1;
      let buf = c;
      while (j < src.length) {
        if (src[j] === '\\') { buf += src[j] + (src[j + 1] ?? ''); j += 2; continue; }
        buf += src[j];
        if (src[j] === c) { j++; break; }
        j++;
      }
      cur += buf;
      i = j;
      continue;
    }
    if (c === '`') {
      const end = skipTemplate(src, i);
      cur += src.slice(i, end);
      i = end;
      continue;
    }
    if (c === '(' || c === '[' || c === '{') { depth++; cur += c; i++; continue; }
    if (c === ')' || c === ']' || c === '}') { depth--; cur += c; i++; continue; }
    if (c === ',' && depth === 0) { parts.push(cur); cur = ''; i++; continue; }
    cur += c;
    i++;
  }
  parts.push(cur);
  return parts;
}

/** 拆出字面量内容与"纯代码"部分：字面量只是标签，代码才是被打印的值。 */
function splitLiterals(arg) {
  const literals = [];
  let code = '';
  let i = 0;
  while (i < arg.length) {
    const c = arg[i];
    const ci = skipComment(arg, i);
    if (ci !== -1) { i = ci; continue; }
    if (c === "'" || c === '"') {
      let j = i + 1;
      let buf = '';
      while (j < arg.length) {
        if (arg[j] === '\\') { buf += arg[j] + (arg[j + 1] ?? ''); j += 2; continue; }
        if (arg[j] === c) break;
        buf += arg[j];
        j++;
      }
      literals.push(buf);
      i = j + 1;
      continue;
    }
    if (c === '`') {
      const end = skipTemplate(arg, i);
      literals.push(arg.slice(i + 1, Math.max(i + 1, end - 1)));
      i = end;
      continue;
    }
    code += c;
    i++;
  }
  return { literals, code };
}

/**
 * 标记源码中"非代码"区域（字符串、模板字符串、注释）：值为 1 表示非代码。
 * 书源运行时会把一段 JS 源码塞进模板字符串，里面的 console.log 不是本工程的日志，必须排除。
 */
function buildNonCodeMask(src) {
  const mask = new Uint8Array(src.length);
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') {
      const nl = src.indexOf('\n', i);
      const end = nl === -1 ? src.length : nl;
      mask.fill(1, i, end);
      i = end;
      continue;
    }
    if (c === '/' && src[i + 1] === '*') {
      const end = src.indexOf('*/', i + 2);
      const stop = end === -1 ? src.length : end + 2;
      mask.fill(1, i, stop);
      i = stop;
      continue;
    }
    if (c === "'" || c === '"') {
      let j = i + 1;
      mask[i] = 1;
      while (j < src.length) {
        if (src[j] === '\\') { mask[j] = 1; mask[j + 1] = 1; j += 2; continue; }
        mask[j] = 1;
        if (src[j] === c) { j++; break; }
        j++;
      }
      i = j;
      continue;
    }
    if (c === '`') {
      let j = i + 1;
      mask[i] = 1;
      while (j < src.length) {
        if (src[j] === '\\') { mask[j] = 1; mask[j + 1] = 1; j += 2; continue; }
        if (src[j] === '`') { mask[j] = 1; j++; break; }
        if (src[j] === '$' && src[j + 1] === '{') {
          // ${} 内部仍是代码，交给后续扫描处理
          let depth = 1;
          j += 2;
          while (j < src.length && depth > 0) {
            if (src[j] === '{') depth++;
            else if (src[j] === '}') depth--;
            j++;
          }
          continue;
        }
        mask[j] = 1;
        j++;
      }
      i = j;
      continue;
    }
    i++;
  }
  return mask;
}

const violations = [];
for (const dir of scan) {
  for (const rel of walk(dir)) {
    const src = fs.readFileSync(path.join(root, rel), 'utf8');
    const mask = buildNonCodeMask(src);
    const call = new RegExp(`console\\.(?:${LEVELS})\\s*\\(`, 'g');
    let m;
    while ((m = call.exec(src))) {
      if (mask[m.index]) continue; // 字符串/注释里的 console 调用不算
      const line = src.slice(0, m.index).split(/\r?\n/).length;
      const openIdx = m.index + m[0].length - 1;
      for (const raw of splitArgs(captureArgs(src, openIdx))) {
        const arg = raw.trim();
        if (!arg) continue;
        const { literals, code } = splitLiterals(arg);
        if (literals.some((l) => /:\/\//.test(l))) {
          violations.push(`${rel}:${line} 字面量包含 URL -> ${arg.replace(/\s+/g, ' ').slice(0, 80)}`);
          continue;
        }
        const codeSensitive = SENSITIVE.test(code);
        if (codeSensitive && !SANITIZERS.test(code) && !SAFE_SHAPES.some((shape) => shape.test(arg))) {
          violations.push(`${rel}:${line} 打印了敏感值 -> ${arg.replace(/\s+/g, ' ').slice(0, 80)}`);
          continue;
        }
        if (!codeSensitive && literals.some((l) => SENSITIVE_LABEL.test(l))) {
          violations.push(`${rel}:${line} 日志标签指向敏感值 -> ${arg.replace(/\s+/g, ' ').slice(0, 80)}`);
        }
      }
      // 跳过已解析的参数，避免同一调用被重复匹配
      call.lastIndex = openIdx;
    }
  }
}

if (violations.length) {
  console.error(`Log policy check failed (${violations.length} potentially sensitive logs):\n${violations.join('\n')}`);
  process.exit(1);
}
console.log('Log policy check passed.');

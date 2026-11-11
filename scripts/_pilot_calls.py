"""For the pilot functions, find EVERY `Domain.func(` call site across the
whole ets tree, and flag any call whose first arg is NOT `this` (i.e. not a
ReadBook.ets delegate shell). A domain function is safe to convert iff every
direct call is the single-line delegate `Domain.func(this, ...)`.
"""
import re, io, sys, glob, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# pilot set: (Ops file basename without .ets, function name)
PILOT = {
    'ReaderChromeThemeOps': ['accentColor','buttonColor','dangerColor',
                             'customThemeFieldColor','isDarkHexColor',
                             'getTopControlSafePadding','currentReaderThemeIndex',
                             'themeRegexEmphasisColor'],
    'ReaderSettingsOps': ['settingsPanelTitle','readerTypographySelectedLabel',
                          'isReaderTouchMoved','readerTextAlignSelectedIndex',
                          'pageTurnModeSelectedIndex','readerEyeTurnPromptVisible'],
    'ReaderGestureOps': ['readerUsesSideAnchoredControls','getEffectiveReaderLineHeight',
                         'getReaderPageLineSpacing','bookmarkPullCommitDistance'],
    'ReaderTextPrepOps': ['ttsQuickProgressLabel','ttsQuickProgress',
                          'bookmarkActionMenuLeft'],
    'ReaderStyledTextOps': ['readerCommentPanelHeight','themeRegexEmphasisColor'],
    'ReaderTtsOrchestrationOps': ['getReaderBookUrl','getCurrentChapterIndex',
                                  'getCurrentPageIndex','isTtsSpeakingState',
                                  'isTtsPausedState'],
}

files = glob.glob('entry/src/main/ets/**/*.ets', recursive=True)
texts = {f: open(f, encoding='utf-8').read().split('\n') for f in files}

for dom, names in PILOT.items():
    print(f'=== {dom} ===')
    for name in names:
        hits = []
        pat = re.compile(r'\b' + re.escape(dom) + r'\.' + re.escape(name) + r'\s*\(')
        for f, lines in texts.items():
            for i, ln in enumerate(lines):
                if pat.search(ln):
                    hits.append((f, i+1, ln.strip()))
        # also value references (Domain.name without paren)
        val = []
        vpat = re.compile(r'\b' + re.escape(dom) + r'\.' + re.escape(name) + r'\b(?!\s*\()')
        for f, lines in texts.items():
            for i, ln in enumerate(lines):
                if vpat.search(ln):
                    val.append((f, i+1, ln.strip()))
        print(f'  {name}: {len(hits)} direct calls, {len(val)} value-refs')
        for f, n, s in hits:
            tag = '' if 'pages/ReadBook.ets' in f.replace('\\','/') else '  <-- NON-DELEGATE'
            print(f'      {os.path.basename(f)}:{n}: {s[:110]}{tag}')
        for f, n, s in val:
            print(f'      VALUE-REF {os.path.basename(f)}:{n}: {s[:110]}')
    print()

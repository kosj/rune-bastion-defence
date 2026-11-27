"""Subset the fonts to the glyphs actually used in the game's scripts (keeps the web download small:
fonts sit in the core pack, which gates the title screen). Re-run after adding new text."""
from fontTools.ttLib import TTCollection, TTFont
from fontTools import subset
import glob, os, shutil
chars = set()
for f in glob.glob('scripts/**/*.gd', recursive=True) + glob.glob('web/*.html'):
    if f.endswith('lang_ja.gd'):
        continue  # Japanese has its own font (ui_ja, below)
    text = open(f, encoding='utf-8').read()
    if f.endswith('.html'):
        # the loading page's Japanese lines use the browser's own fonts
        text = ''.join(c for c in text if not 0x3000 <= ord(c) <= 0x9fff)
    chars |= set(text)
chars |= set(''.join(chr(c) for c in range(32, 127)))
chars |= set('·…▶◀→←↑↓★☆%+-×÷—–!?.,:;()[]0123456789')
txt = ''.join(sorted(c for c in chars if c >= ' '))
import sys
# Japanese: its own font (Noto Sans CJK JP, Japanese glyph shapes) with just the characters of the
# Japanese table. It sits in the "menu" download chunk, not in core (Assets.add_ja_font hooks it in
# as a fallback of the Korean UI font once that chunk is mounted; until then Japanese shows English).
ja_chars = set()
for f in glob.glob('tools/i18n/ja_*.txt'):
    for line in open(f, encoding='utf-8'):
        if line.startswith('#') or '\t' not in line:
            continue
        ja_chars |= set(line.rstrip('\n').split('\t', 1)[1])
ja_txt = ''.join(sorted(c for c in ja_chars if ord(c) > 0x7f))
if '--check' in sys.argv:
    # CI: every character the scripts use must be in the shipped Korean UI fonts (else it renders
    # as a box): re-run this tool without --check after adding text
    bad = {}
    for f in ('ui', 'ui_black', 'title_kr'):
        cmap = TTFont('assets/fonts/%s.ttf' % f).getBestCmap()
        # emoji only appear on the HTML loading page (system fonts)
        miss = sorted(c for c in txt if 32 < ord(c) < 0x1F000 and ord(c) not in cmap and not (0xFE00 <= ord(c) <= 0xFE0F))
        if miss:
            bad[f] = ''.join(miss)
    if ja_txt:
        cmap_ja = TTFont('assets/fonts/ui_ja.ttf').getBestCmap()
        cmap_ui = TTFont('assets/fonts/ui.ttf').getBestCmap()
        miss = sorted(c for c in ja_txt if ord(c) not in cmap_ja and ord(c) not in cmap_ui)
        if miss:
            bad['ui_ja'] = ''.join(miss)
    if bad:
        sys.exit('fonts miss glyphs (run python3 tools/make_fonts.py): %s' % bad)
    print('fonts cover all %d characters' % len(txt))
    sys.exit(0)
def extract(ttc, want, out, text=None):
    col = TTCollection(ttc)
    for f in col.fonts:
        name = f['name'].getDebugName(1)
        if want in name and 'Mono' not in name:
            tmp = '/tmp/_f.otf'
            f.save(tmp)
            opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
            ft = TTFont(tmp)
            s = subset.Subsetter(opts); s.populate(text=text if text is not None else txt); s.subset(ft)
            ft.save(out)
            print(out, name, os.path.getsize(out))
            return
def subset_ttf(src, out):
    opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
    ft = TTFont(src)
    s = subset.Subsetter(opts); s.populate(text=txt); s.subset(ft)
    ft.save(out)
    print(out, os.path.basename(src), os.path.getsize(out))
os.makedirs('assets/fonts', exist_ok=True)
# body text in Medium (Bold everywhere read heavy and cramped at 16-18 px); buttons, numbers and
# row titles ("ui_black") in Bold
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSerifCJK-Black.ttc', 'Noto Serif CJK KR', 'assets/fonts/title_kr.ttf')
extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 'Noto Sans CJK KR', 'assets/fonts/ui_black.ttf')
if ja_txt:
    extract('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc', 'Noto Sans CJK JP', 'assets/fonts/ui_ja.ttf', ja_txt)
# the Latin title face: full Cardo has ~3000 glyphs (348 KB); the game uses a few hundred
subset_ttf('/usr/share/fonts/truetype/google-fonts/ofl/cardo/Cardo-Bold.ttf', 'assets/fonts/title.ttf')
print('glyphs', len(txt))

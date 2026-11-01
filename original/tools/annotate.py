"""Apply the names and descriptions in tools/names.py to the game's sources.

  python3 original/tools/annotate.py            (VASM=... if vasmm68k_mot is not on the PATH)

For each address in names.NAMES - (name, description):
  * the label at that address (found from vasm's symbol table: sub_XXXXX, l_XXXXX, dat_XXXXX, an
    equate inside a data file, or an older name) is renamed everywhere: original/scr_game.s, the
    data include files (sound/, gfx/, tracks/) and enhanced/src/scr_game.s;
  * an instruction with no label gets one (the line with its address comment);
  * a routine (its label followed by code) gets a header above it: the name and the description;
    data gets the description as a comment on its label's line.

Running it again changes only what changed in names.py. The sources are assembled before and after
and must give the same bytes: names never change the game. An address with no label and no
instruction line (inside a data file, inside an instruction) is reported and skipped.
"""
import hashlib, os, re, subprocess, sys, tempfile, textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ORIG, '..'))
VASM = os.environ.get('VASM', 'vasmm68k_mot')
sys.path.insert(0, HERE)
from names import NAMES

MAIN = os.path.join(ORIG, 'scr_game.s')
ENH = os.path.join(ROOT, 'enhanced', 'src', 'scr_game.s')
DATA_DIRS = ['sound', 'gfx', 'tracks']
RULE = ';' + '-' * 79


def files():
    fs = [MAIN] + ([ENH] if os.path.exists(ENH) else [])
    for d in DATA_DIRS:
        p = os.path.join(ORIG, d)
        fs += [os.path.join(p, f) for f in sorted(os.listdir(p)) if f.endswith('.s')]
    return fs


def assemble(src):
    """the bytes, and the symbols: name -> (value, kind 'A' label / 'E' equate)"""
    out, lst = tempfile.mktemp(), tempfile.mktemp()
    r = subprocess.run([VASM, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', ORIG, '-I', os.path.dirname(src),
                        '-L', lst, '-o', out, src], capture_output=True, text=True, cwd=os.path.dirname(src))
    if r.returncode:
        sys.exit(f'vasm {src}:\n{r.stdout}{r.stderr}')
    data = open(out, 'rb').read()
    syms = {}
    for ln in open(lst, errors='replace'):
        m = re.match(r'^(\w+)\s+([AE]):([0-9A-F]{8})\s*$', ln)
        if m:
            syms[m.group(1)] = (int(m.group(3), 16), m.group(2))
    os.remove(out); os.remove(lst)
    return data, syms


def header(name, desc):
    body = textwrap.wrap(f'{name} - {desc}', 93) if desc else [name]
    return [RULE] + ['; ' + l for l in body] + [RULE]


def main():
    before_main, syms = assemble(MAIN)
    before_enh = assemble(ENH)[0] if os.path.exists(ENH) else None
    texts = {f: open(f).read() for f in files()}
    # what each wanted name is now called
    by_addr = {}
    for n, (v, k) in syms.items():
        by_addr.setdefault(v, []).append(n)
    renames, inserts, skipped = {}, [], []
    taken = set(syms)
    for addr, (name, desc) in sorted(NAMES.items()):
        cur = [n for n in by_addr.get(addr, []) if re.match(r'^(sub|l|dat)_[0-9A-F]{5}$', n) or n in old_names(addr)]
        if name in syms and syms[name][0] == addr:
            continue
        if name in taken and syms.get(name, (None,))[0] != addr:
            sys.exit(f'{name} (${addr:X}) is already the name of ${syms[name][0]:X}')
        if cur:
            for c in cur:
                renames[c] = name if c == cur[0] else f'{name}_{c}'
        else:
            inserts.append((addr, name))
        taken.add(name)
    # renames everywhere (longest first, whole words)
    if renames:
        pat = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, renames), key=len, reverse=True)) + r')\b')
        for f in texts:
            texts[f] = pat.sub(lambda m: renames[m.group(1)], texts[f])
    # labels for instructions that have none (main and enhanced sources)
    for f in (MAIN, ENH):
        if f not in texts:
            continue
        lines = texts[f].split('\n')
        for addr, name in inserts:
            idx = next((i for i, l in enumerate(lines) if re.search(rf'; {addr:05X}\b', l) and not l.startswith('\tdc')), None)
            if idx is None:
                if f == MAIN:
                    skipped.append((addr, name))
                continue
            lines.insert(idx, f'{name}:')
        texts[f] = '\n'.join(lines)
    # headers and comments
    for f in texts:
        lines = texts[f].split('\n')
        out = []
        i = 0
        while i < len(lines):
            l = lines[i]
            m = re.match(r'^(\w+):(.*)$', l)
            want = next(((a, n, d) for a, (n, d) in NAMES.items() if m and n == m.group(1)), None) if m else None
            if want:
                a, n, d = want
                nxt = next((x for x in lines[i + 1:i + 4] if x.strip()), '')
                is_code = bool(re.search(r'; [0-9A-F]{5}', nxt)) and not nxt.startswith('\tdc')
                if is_code:
                    # drop a header we wrote before (the rule, '; Name - ...' lines, the rule)
                    j = len(out)
                    if j >= 2 and out[-1] == RULE:
                        k = j - 2
                        while k >= 0 and out[k].startswith('; ') and out[k] != RULE:
                            k -= 1
                        if k >= 0 and out[k] == RULE and out[k + 1].startswith(f'; {n} -') or (k >= 0 and out[k] == RULE and out[k + 1] == f'; {n}'):
                            del out[k:]
                    if out and out[-1].strip():
                        out.append('')
                    out += header(n, d)
                    out.append(f'{n}:{m.group(2)}' if m.group(2).strip().startswith('; (no ref') else f'{n}:')
                else:
                    out.append(f'{n}:' + (f'\t\t\t\t; {d}' if d else ''))
                i += 1
                continue
            out.append(l)
            i += 1
        texts[f] = '\n'.join(out)
    # the address comments back in their column (48) after names longer or shorter than the labels
    for f in texts:
        texts[f] = '\n'.join(realign(l) for l in texts[f].split('\n'))
    for f, t in texts.items():
        open(f, 'w', newline='\n').write(t)
    after_main, syms2 = assemble(MAIN)
    if after_main != before_main:
        sys.exit('the game no longer assembles to the same bytes: names.py or this tool is wrong')
    if before_enh is not None and assemble(ENH)[0] != before_enh:
        sys.exit('the enhanced game no longer assembles to the same bytes')
    named = sum(1 for a, (n, d) in NAMES.items() if syms2.get(n, (None,))[0] == a)
    print(f'{len(renames)} renamed, {len(inserts) - len(skipped)} labels added; {named} of {len(NAMES)} names in place;'
          f' the game assembles the same (sha1 {hashlib.sha1(after_main).hexdigest()})')
    for a, n in skipped:
        print(f'  skipped ${a:05X} {n}: no label or instruction there')


ADDR_COMMENT = re.compile(r'^((?:\t| {8})\S.*?)\s*; ([0-9A-F]{5})\b(.*)$')


def realign(line):
    m = ADDR_COMMENT.match(line)
    if not m or line.lstrip().startswith('dc'):
        return line
    code = m.group(1).expandtabs(8).rstrip()
    return code.ljust(47) + f' ; {m.group(2)}{m.group(3)}' if len(code) < 47 else f'{code} ; {m.group(2)}{m.group(3)}'


_OLD = {}


def old_names(addr):
    """names an address had in earlier versions of names.py (names_old.txt: 'ADDR NAME' lines,
    written by this tool) - so a renamed entry finds its label again"""
    if not _OLD:
        p = os.path.join(HERE, 'names_old.txt')
        if os.path.exists(p):
            for ln in open(p):
                a, n = ln.split()
                _OLD.setdefault(int(a, 16), set()).add(n)
        _OLD[-1] = set()
    return _OLD.get(addr, set())


def record_old():
    p = os.path.join(HERE, 'names_old.txt')
    have = set(open(p).read().split('\n')) if os.path.exists(p) else set()
    have |= {f'{a:05X} {n}' for a, (n, d) in NAMES.items()}
    open(p, 'w', newline='\n').write('\n'.join(sorted(x for x in have if x)) + '\n')


if __name__ == '__main__':
    main()
    record_old()

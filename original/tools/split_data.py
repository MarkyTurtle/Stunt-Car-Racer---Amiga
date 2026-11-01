"""Move blocks of data out of a game source into include files and binary files.

  python3 original/tools/split_data.py [source.s]        (default: original/scr_game.s)

Each block in BLOCKS below is a run of data in the source (dc.b/dc.w/dcb lines only - never
code) between two addresses. It is replaced by `include "<dir>/<name>.s"`, and the include
file holds what the block was, as parts:

  ('bin', start, end, label, file)   the bytes start-end as a binary file (incbin), under label
  ('dc',  start, end)                the bytes as dc.b lines (small pieces kept in the source)
  ('src', start, end, lines, anchors) hand-written source lines that assemble to those bytes
                                     (tables written with symbols); anchors: [(label, address)]
                                     of labels in those lines; checked like the rest

A label of the old source that falls inside a 'bin' part becomes an equate: label equ
part_label+offset, so every reference still assembles to the same address. Labels inside 'dc'
parts stay labels. The addresses of the source lines come from vasm's listing.

The source is assembled before and after and must give the same bytes: the split never changes
the game. Binary files are written under original/ (where the source's include path finds them:
the enhanced build passes -I original). Running it again on a source already split does nothing
for the blocks already moved.
"""
import os, re, subprocess, sys, tempfile, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..'))
VASM = os.environ.get('VASM', 'vasmm68k_mot')

# ---- the blocks ---------------------------------------------------------------------------
SAMPLES = [  # start, length, name (the sound driver's table at $1B6CA, in order)
    (0x0F4B8, 0x0984, 'sample0'), (0x0FE3C, 0x2348, 'sample1'), (0x12184, 0x1F4E, 'sample2'),
    (0x140D2, 0x0C24, 'sample3'), (0x14CF6, 0x1432, 'sample4'), (0x16128, 0x20EE, 'sample5'),
    (0x18216, 0x1BD0, 'sample6'), (0x19DE6, 0x0C64, 'sample7_engine'),
]
SAMPLE_TABLE = [  # period, volume, channel (the table's entries after pointer and length)
    (0x96, 0x1E, 1), (0xB4, 0x40, 1), (0xEE, 0x38, 1), (0x190, 0x32, 1),
    (0xEE, 0x40, 2), (0x118, 0x40, 3), (0x1F4, 0x40, 1), (0x12C, 0x30, 0),
]


def sound_parts():
    parts = []
    for s, n, name in SAMPLES:
        parts.append(('bin', s, s + n, 'Sample' + name[6:].split('_')[0] + ('_Engine' if 'engine' in name else ''),
                      f'sound/{name}.bin'))
    lines = ['', '; the engine sample at 6 rates, made by the sound driver at start-up ($F402)',
             'EngineBuffer:', '\tdcb.b\t$C80,0', '',
             '; the sound effects: pointer, length (bytes), period, volume, channel, (spare)',
             'SampleTable:']
    for (s, n, name), (per, vol, ch) in zip(SAMPLES, SAMPLE_TABLE):
        lab = 'Sample' + name[6:].split('_')[0] + ('_Engine' if 'engine' in name else '')
        lines.append(f'\tdc.l\t{lab},${n:X}')
        lines.append(f'\tdc.w\t${per:X},${vol:X},{ch},0')
    parts.append(('src', 0x1AA4A, 0x1B74A, lines, [('EngineBuffer', 0x1AA4A), ('SampleTable', 0x1B6CA)]))
    return parts


PICTURES = [  # record start (flag word), end, name. A record: flag.w (bit 15: packed), 16 colours, data
    (0x20182, 0x23C10, 'cockpit'), (0x23C30, 0x2B952, 'title'), (0x2B972, 0x30BAE, 'stadium'),
    (0x30BCE, 0x35A54, 'hall_of_fame'), (0x35A74, 0x3D796, 'divisions'), (0x3D7B6, 0x4475B, 'wreck'),
    (0x4477C, 0x4AF1D, 'season_win'), (0x4AF3E, 0x50E2B, 'season_crowd'), (0x50E4C, 0x56FD8, 'champion'),
]


def picture_parts():
    parts, pos = [], PICTURES[0][0]
    for s, e, name in PICTURES:
        if s > pos:
            parts.append(('dc', pos, s))          # the header left from each picture's file
        lab = 'Pic_' + ''.join(w.capitalize() for w in name.split('_'))
        parts.append(('bin', s, e, lab, f'gfx/{name}.bin'))
        pos = e
    return parts


TRACKS = [  # start, end, name (the offsets at $1F0A2; lengths found by running the track builder $5AE46)
    (0x1F8E4, 0x1F960, 'little_ramp'), (0x1F960, 0x1F9F1, 'stepping_stones'),
    (0x1F9F1, 0x1FA82, 'hump_back'), (0x1FA82, 0x1FB10, 'big_ramp'), (0x1FB10, 0x1FBA1, 'ski_jump'),
    (0x1FBA1, 0x1FC76, 'draw_bridge'), (0x1FC76, 0x1FD04, 'high_jump'), (0x1FD04, 0x1FDC4, 'roller_coaster'),
]


def track_parts():
    return [('bin', s, e, 'Track_' + ''.join(w.capitalize() for w in name.split('_')), f'tracks/{name}.bin')
            for s, e, name in TRACKS]


BLOCKS = [  # include file (under original/), start, end, header, parts
    ('sound/sound.s', 0x0F4B8, 0x1B74A,
     'The sound effects: 8 samples (8-bit, stored with the sign bit flipped: the start-up code\n'
     'flips it, $EE64), the engine buffer and the sound driver\'s table of them.', sound_parts),
    ('gfx/pictures.s', 0x20182, 0x56FD8,
     'The pictures: each a record of a flag word (bit 15: packed, ByteRun1 by line and plane,\n'
     'unpacked by $593F8; else 4 planes interleaved by word), 16 colours and 320x200 in 4 planes.\n'
     'The 32 bytes before each record are the header left from its picture file (not used).',
     picture_parts),
    ('gfx/screens.s', 0x6A594, 0x73100,
     'The two screens (4 planes of 320x200 each, $7D00 bytes: the start-up code sets the pointers at\n'
     '$6A584/$6A588 to $6A594 and $72294). The bytes here are what was in that memory when the\n'
     'game was saved to the disk: the game draws over them (the second screen runs on past the\n'
     'end of the file).', lambda: [('bin', 0x6A594, 0x73100, 'Screens', 'gfx/screens_initial.bin')]),
    ('tracks/tracks.s', 0x1F8E4, 0x1FDC4,
     'The 8 tracks, as the track builder ($5AE46) reads them: its table at $1F0A2 gives each\n'
     'one\'s start (byte-swapped, - $B100, + $1EF82).', track_parts),
]


# ---- the source ---------------------------------------------------------------------------
def assemble(src_dir, src, listing=None):
    out = tempfile.mktemp(suffix='.bin')
    cmd = [VASM, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', ORIG, '-I', src_dir] + \
          (['-L', listing] if listing else []) + ['-o', out, src]
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=src_dir)
    if r.returncode:
        sys.exit(f'vasm failed:\n{r.stdout}{r.stderr}')
    data = open(out, 'rb').read()
    os.remove(out)
    return data


def line_addresses(listing, main):
    """line number (1-based) in the main source -> address of its first byte (not the lines of
    the files it includes: the listing marks each file with 'Source: "name"')"""
    addr, cur = {}, None
    for ln in open(listing, errors='replace'):
        m = re.match(r'^Source: "(.*)"', ln)
        if m:
            cur = os.path.basename(m.group(1))
            continue
        m = re.match(r'^\d\d:([0-9A-F]{8}) [0-9A-F*]*\s*\t\s*(\d+):', ln)
        if m and cur == os.path.basename(main):
            addr.setdefault(int(m.group(2)), int(m.group(1), 16))
    return addr


def main():
    src = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ORIG, 'scr_game.s'))
    src_dir = os.path.dirname(src)
    lines = open(src).read().split('\n')
    lst = tempfile.mktemp(suffix='.lst')
    before = assemble(src_dir, src, lst)
    addr = line_addresses(lst, src)
    os.remove(lst)
    org = 0xE700
    image = lambda a, b: before[a - org:b - org]
    def line_starts(addr):
        """each line: its start address (labels and blank lines take the next line's)"""
        st = [None] * len(lines)
        nxt = org + len(before)
        for i in range(len(lines) - 1, -1, -1):
            if i + 1 in addr:
                nxt = addr[i + 1]
            st[i] = nxt
        return st

    def reindex():
        tmp = src + '.split.s'
        open(tmp, 'w').write('\n'.join(lines))
        lst = tempfile.mktemp(suffix='.lst')
        got = assemble(src_dir, tmp, lst)
        os.remove(tmp)
        if got != before:
            d = next((i for i in range(min(len(got), len(before))) if got[i] != before[i]), 0)
            sys.exit(f'the split source differs from the original (first at ${org + d:X})')
        a = line_addresses(lst, tmp)
        os.remove(lst)
        return a, line_starts(a)

    def cut(at):
        """break the data line that straddles address at into two dc.b lines"""
        coded = [i for i in range(len(lines)) if (i + 1) in addr]
        for k, i in enumerate(coded):
            ls = starts[i]
            le = starts[coded[k + 1]] if k + 1 < len(coded) else org + len(before)
            if ls < at < le:
                if not re.match(r'^\t(dc\.[bwl]|dcb\.[bwl])\t', lines[i]):
                    sys.exit(f'${at:X} is inside an instruction (line {i + 1})')
                new = []
                for p, q in ((ls, at), (at, le)):
                    chunk = image(p, q)
                    new += ['\tdc.b\t' + ','.join(f'${x:02X}' for x in chunk[j:j + 16]) for j in range(0, len(chunk), 16)]
                lines[i:i + 1] = new
                return True
        return False

    starts = line_starts(addr)
    done = []
    for inc, s, e, header, mkparts in BLOCKS:
        if any(l.strip() == f'include\t"{inc}"' for l in lines):
            print(f'{inc}: already split')
            continue
        for at in (s, e):               # (re-indexed after each cut: the lines move)
            if cut(at):
                addr, starts = reindex()
        # the lines that make the block: from the first line starting at s to the last before e
        isdata = lambda i: (i + 1) in addr or re.match(r'^\w+:', lines[i])
        first = min(i for i, a in enumerate(starts) if a >= s and isdata(i))
        last = max(i for i, a in enumerate(starts) if a < e and (i + 1) in addr)
        if starts[first] != s:
            sys.exit(f'{inc}: no line starts at ${s:X} (first line at ${starts[first]:X})')
        end_of_last = min([a for i, a in enumerate(starts) if i > last and (i + 1) in addr] or [org + len(before)])
        if end_of_last != e:
            sys.exit(f'{inc}: the block ends at ${end_of_last:X}, not ${e:X} (a line straddles it)')
        for i in range(first, last + 1):
            t = lines[i]
            if t.strip() and not re.match(r'^\w+:\s*(;.*)?$', t) and not re.match(r'^\t(dc\.[bwl]|dcb\.[bwl])\t', t) \
                    and not t.lstrip().startswith(';'):
                sys.exit(f'{inc}: line {i + 1} is not data: {t}')
        labels = {}
        for i in range(first, last + 1):
            m = re.match(r'^(\w+):', lines[i])
            if m:
                labels[m.group(1)] = starts[i]
        parts = mkparts()
        out = [f'; {l}' if l else ';' for l in header.split('\n')]
        out = [';' + '-' * 95] + out + [f'; ({os.path.basename(src)}, ${s:X}-${e - 1:X}: split out by tools/split_data.py)',
                                        ';' + '-' * 95, '']
        used = set()
        pos = s
        for p in parts:
            kind, ps, pe = p[0], p[1], p[2]
            if ps != pos:
                sys.exit(f'{inc}: parts not contiguous at ${pos:X}')
            pos = pe
            inner = sorted((a, n) for n, a in labels.items() if ps <= a < pe)
            if kind == 'bin':
                lab, fn = p[3], p[4]
                path = os.path.join(ORIG, fn)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                open(path, 'wb').write(image(ps, pe))
                out += [f'{lab}:', f'\tincbin\t"{fn}"\t\t; ${ps:05X}-${pe - 1:05X}, {pe - ps} bytes']
                for a, n in inner:
                    out.append(f'{n}\tequ\t{lab}+${a - ps:X}' if a != ps else f'{n}\tequ\t{lab}')
                    used.add(n)
            elif kind == 'dc':
                q = ps
                marks = sorted(set([a for a, n in inner] + [pe]))
                for m in marks:
                    if m > q:
                        chunk = image(q, m)
                        for k in range(0, len(chunk), 16):
                            out.append('\tdc.b\t' + ','.join(f'${x:02X}' for x in chunk[k:k + 16]))
                    out += [f'{n}:' for a, n in inner if a == m]
                    used |= {n for a, n in inner if a == m}
                    q = m
            elif kind == 'src':
                lab_lines, anchors = p[3], p[4]
                out += lab_lines
                for a, n in inner:          # labels inside: equates on the anchor before them
                    al, aa = max((x for x in anchors if x[1] <= a), key=lambda x: x[1])
                    out.append(f'{n}\tequ\t{al}+${a - aa:X}' if a != aa else f'{n}\tequ\t{al}')
                    used.add(n)
            out.append('')
        if pos != e:
            sys.exit(f'{inc}: parts end at ${pos:X}, not ${e:X}')
        missing = set(labels) - used
        if missing:
            sys.exit(f'{inc}: labels not placed: {sorted(missing)}')
        inc_path = os.path.join(ORIG, inc)
        os.makedirs(os.path.dirname(inc_path), exist_ok=True)
        open(inc_path, 'w').write('\n'.join(out).rstrip('\n') + '\n')
        n_lines = last - first + 1
        lines[first:last + 1] = [f'\tinclude\t"{inc}"']
        addr, starts = reindex()        # (checks the source still assembles to the same bytes)
        print(f'{inc}: ${s:X}-${e - 1:X} ({e - s} bytes, {n_lines} lines) -> {len(parts)} parts')
        done.append(inc)
    open(src, 'w').write('\n'.join(lines))
    print(f'{os.path.relpath(src)}: {len(lines)} lines, reassembles identical (sha1 {hashlib.sha1(before).hexdigest()})')


if __name__ == '__main__':
    main()

"""Render the game's split-out data to files to look at and listen to:

  original/render/out/gfx/<picture>.png      the pictures (gfx/*.bin), with their own colours
  original/render/out/sound/<sample>.wav     the samples (sound/*.bin), 8-bit mono at the rate
                                             their period in the sample table plays them

  python3 original/render/assets.py

The formats (docs/DATA.md): a picture is a flag word (bit 15: packed), 16 colours ($0RGB), then
320x200 in 4 planes - packed: ByteRun1 for each line of each plane in turn (40 bytes; as the
game's $593F8), else the 4 planes interleaved by word. The samples are 8-bit, stored with the
sign bit flipped (the game flips it at start-up), which is the unsigned 8-bit of a WAV file."""
import os, struct, sys, wave
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(ORIG, 'tools'))
from split_data import PICTURES, SAMPLES, SAMPLE_TABLE

PAL_CLOCK = 3546895         # Paula's clock (PAL): rate = clock / period


def picture(rec):
    """a picture record -> 320x200 RGB image"""
    flag = struct.unpack('>H', rec[:2])[0]
    cols = [((v >> 8 & 15) * 17, (v >> 4 & 15) * 17, (v & 15) * 17) for v in struct.unpack('>16H', rec[2:34])]
    data = rec[34:]
    planes = [bytearray() for _ in range(4)]
    if flag & 0x8000:
        p = 0
        for y in range(200):
            for pl in range(4):
                line = bytearray()
                while len(line) < 40:
                    c = data[p]; p += 1
                    if c < 128:
                        line += data[p:p + c + 1]; p += c + 1
                    elif c != 128:
                        line += bytes([data[p]]) * (257 - c); p += 1
                planes[pl] += line
    else:
        for i in range(0, 32000, 8):
            for pl in range(4):
                planes[pl] += data[i + 2 * pl:i + 2 * pl + 2]
    img = Image.new('RGB', (320, 200))
    px = img.load()
    for y in range(200):
        for x in range(320):
            o, b = y * 40 + x // 8, 7 - x % 8
            px[x, y] = cols[sum(((planes[k][o] >> b) & 1) << k for k in range(4))]
    return img


def main():
    gdir, sdir = os.path.join(HERE, 'out', 'gfx'), os.path.join(HERE, 'out', 'sound')
    os.makedirs(gdir, exist_ok=True); os.makedirs(sdir, exist_ok=True)
    for s, e, name in PICTURES:
        rec = open(os.path.join(ORIG, 'gfx', name + '.bin'), 'rb').read()
        picture(rec).save(os.path.join(gdir, name + '.png'))
        print(f'render/out/gfx/{name}.png')
    for (s, n, name), (per, vol, ch) in zip(SAMPLES, SAMPLE_TABLE):
        data = open(os.path.join(ORIG, 'sound', name + '.bin'), 'rb').read()
        with wave.open(os.path.join(sdir, name + '.wav'), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(1); w.setframerate(round(PAL_CLOCK / per))
            w.writeframes(data)
        print(f'render/out/sound/{name}.wav ({round(PAL_CLOCK / per)} Hz, {len(data)} bytes)')


if __name__ == '__main__':
    main()

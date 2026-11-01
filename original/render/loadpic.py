"""Render the loading picture (original/bin/loadpic_78000.bin: 4 planes, 320x200) with the
loader's colours to original/render/out/loadpic.png (doubled in size).

  python3 original/render/loadpic.py"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
# the loader's copper list colours ($40EA): its palette at $4D04 as its $44B0 sets it
PAL = [0x033, 0x000, 0x555, 0x777, 0x999, 0xBBB, 0xDDD, 0xFFF, 0x300, 0x500, 0x700, 0x900, 0xB00, 0xD00, 0xF00, 0x9B9]
PLANE = 0x1F40

d = open(os.path.join(HERE, '..', 'bin', 'loadpic_78000.bin'), 'rb').read()
img = Image.new('RGB', (320, 200))
for y in range(200):
    for x in range(320):
        o, b = y * 40 + x // 8, 7 - x % 8
        c = sum(((d[p * PLANE + o] >> b) & 1) << p for p in range(4))
        v = PAL[c]
        img.putpixel((x, y), ((v >> 8) * 17, (v >> 4 & 15) * 17, (v & 15) * 17))
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
img.resize((640, 400), Image.NEAREST).save(os.path.join(HERE, 'out', 'loadpic.png'))
print('render/out/loadpic.png')

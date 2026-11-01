"""Unpack the Turbo loader: run its own decruncher ($40020-$4013E) under Unicorn and write the
code it unpacks to $4000.

  python3 unpack_loader.py <t002-008_loader_packed.bin> <loader_4000.bin>

The decruncher reads the unpacked and packed lengths from $40148/$4014C ($A4CA, $31C6), unpacks
backwards from the end of the data at $40150 to $4000, then (at $4013E) restores the registers
and jumps to $4000; the emulation stops there."""
import sys
from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN
from unicorn.m68k_const import UC_CPU_M68K_M68000, UC_M68K_REG_A7

packed = open(sys.argv[1], 'rb').read()
u = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
u.ctl_set_cpu_model(UC_CPU_M68K_M68000)
u.mem_map(0, 0x100000)
u.mem_write(0x40000, packed)
u.reg_write(UC_M68K_REG_A7, 0x80000)
u.emu_start(0x40020, 0x4013E)
n = int.from_bytes(packed[0x148:0x14C], 'big')
open(sys.argv[2], 'wb').write(bytes(u.mem_read(0x4000, n)))
print(f'unpacked ${n:X} bytes to $4000')

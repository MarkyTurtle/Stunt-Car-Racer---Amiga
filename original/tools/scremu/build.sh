#!/bin/sh
# Build scremu (emu.c) against Musashi, cloned into ./Musashi if needed.
set -e
cd "$(dirname "$0")"
[ -d Musashi ] || git clone -q --depth 1 https://github.com/kstenerud/Musashi
# The 68000's timing corrected where Musashi's table differs from the 68000 manual (measured on an
# A500 with the telemetry build's calibration run, enhanced/measurements/): ADD, SUB, AND, OR .L
# <ea>,Dn and ADDA, SUBA .L <ea>,An take 8 cycles, not 6, when <ea> is a register.
if ! grep -q 'scremu: 68000 timing' Musashi/m68k_in.c; then
    sed -i -E 's/^((add|sub|and|or) +32 +er +[da] .*U U U U U +)6( +6 +2 +2 +2)$/\18\3/; s/^((adda|suba) +32 +\. +[da] .*U U U U U +)6( +6 +2 +2 +2)$/\18\3/' Musashi/m68k_in.c
    echo '/* scremu: 68000 timing of ADD/SUB/AND/OR.L and ADDA/SUBA.L from a register corrected (build.sh) */' >> Musashi/m68k_in.c
    rm -f Musashi/m68kops.c Musashi/m68kops.h
fi
[ -f Musashi/m68kops.c ] || (cd Musashi && gcc -o m68kmake m68kmake.c && ./m68kmake . m68k_in.c > /dev/null)
cat > conf.h <<'EOC'
#define M68K_INSTRUCTION_HOOK       M68K_OPT_SPECIFY_HANDLER
#define M68K_INSTRUCTION_CALLBACK(pc) instr_hook(pc)
void instr_hook(unsigned int pc);
EOC
gcc -O2 -include conf.h -IMusashi -o scremu emu.c Musashi/m68kcpu.c Musashi/m68kops.c Musashi/m68kdasm.c \
    Musashi/softfloat/softfloat.c -lm
echo "built $(pwd)/scremu"

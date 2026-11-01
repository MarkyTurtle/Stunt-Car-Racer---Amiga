#!/bin/sh
# Build scremu (emu.c) against Musashi, cloned into ./Musashi if needed.
set -e
cd "$(dirname "$0")"
[ -d Musashi ] || git clone -q --depth 1 https://github.com/kstenerud/Musashi
[ -f Musashi/m68kops.c ] || (cd Musashi && gcc -o m68kmake m68kmake.c && ./m68kmake . m68k_in.c > /dev/null)
cat > conf.h <<'EOC'
#define M68K_INSTRUCTION_HOOK       M68K_OPT_SPECIFY_HANDLER
#define M68K_INSTRUCTION_CALLBACK(pc) instr_hook(pc)
void instr_hook(unsigned int pc);
EOC
gcc -O2 -include conf.h -IMusashi -o scremu emu.c Musashi/m68kcpu.c Musashi/m68kops.c Musashi/m68kdasm.c \
    Musashi/softfloat/softfloat.c -lm
echo "built $(pwd)/scremu"

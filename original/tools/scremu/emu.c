/* scremu: runs Stunt Car Racer (the game at $E700) on a minimal Amiga, for studying it.
 * (Adapted from the New Zealand Story repository's tools/nzsemu/emu.c.)
 *
 * A 68000 (Musashi) with 512K of chip RAM and just what the game uses: the vertical blank
 * (level 3), the CIA timers and TOD (levels 2 and 6), the keyboard (CIA-A serial: level 2), the
 * audio interrupts (level 4), the blitter (area mode, done at once when BLTSIZE is written), the
 * joystick in port 2, a serial port that is always empty and ready (the two-player link), and the
 * copper's writes to INTREQ (its interrupt), raised at the line its list waits for.
 * The disk is not emulated (the game reads it only for the save disk). The display is not drawn:
 * snapshots of memory and the custom registers are written instead, and tools/screen.py draws
 * them by following the copper list.
 *
 * Started as the release's loader leaves it: the game at $E700, the release's helper block at $C0,
 * the loading picture at $78000 (the game's picture table points at it), USP $7FFFC, SSP $3D80,
 * a0 = $E700, d0 = 0, interrupts masked, PC = $E700.
 *
 * A word or long read or write at an odd address (an address error on a 68000: the game would
 * crash) is logged ("address error: ..."), the first 20.
 *
 * Memory use: every byte of the 512K is marked by what touched it - the CPU reading, writing,
 * executing (each instruction's first word), and DMA (the blitter's channels, the bitplanes the
 * copper lists and the CPU point at, for the display window's lines, the copper lists, audio
 * samples, sprites). "usage FILE" writes it: a byte per address, bit 0 read, 1 written,
 * 2 executed, 3 DMA.
 *
 *   scremu GAME.bin HELPER.bin LOADPIC.bin SCRIPT
 *
 * SCRIPT, one command a line (# comments):
 *   frames N              run N frames (PAL, not interlaced: 313 lines of 454 CPU cycles - 227 colour clocks)
 *   joy [u][d][l][r][f]   hold these joystick directions / fire; "joy" alone: none
 *   random N SEED         N frames with a random joystick (held 8-40 frames at a time)
 *   key CODE              press and release a raw key (hex)
 *   poke ADDR VAL [b|w|l] write memory
 *   snap PREFIX           write PREFIX.mem (512K) and PREFIX.regs (the custom registers, 512 bytes)
 *   cover FILE            write the coverage bitmap (1 bit per byte address, $80000 bits)
 *   usage FILE            write the memory-use map (above)
 *   record LO HI FILE N   run N frames, appending memory LO-HI to FILE after each (for finding
 *                         variables: how they change with the controls)
 *   usageclear            clear it (to leave out, say, the start-up checksum's reads of the game)
 *   calls 1               count, from now, the calls of each routine (the targets of the jsr/bsr
 *                         executed)
 *   callsdump FILE        write them: "addr count", one line a routine
 *   log FILE              append events to FILE
 *   until ADDR [N]        run until the PC reaches ADDR (at most N frames)
 *   hits ADDR N [M]       run whole frames until the PC has reached ADDR N times from now (at most M
 *                         frames): the frame it is reached in run to its end, so the timing is as
 *                         with frames (a loop's Nth pass waited for whatever it took to get there)
 *   call ADDR [D0]        call a routine (interrupts masked, time going on) until it returns
 *   calli ADDR [D0]       the same with the interrupts on (frames going on as usual)
 *   audio FILE            log every write to the audio registers and DMACON: "cycle reg value"
 *   load FILE ADDR        copy a file into memory at ADDR
 *   trace ADDR            log the frame, line and registers each time the PC reaches ADDR
 *   traceall 1 / 0        trace prints all the registers (on a second line)
 *   profile 1 / 0         count the CPU cycles spent at each instruction, from now / stop
 *   profdump FILE         write them: "pc cycles", one line an instruction
 *   writelog LO HI        log every CPU write to LO-HI (to the log, else stdout): "frame line pc addr value/size"
 *   cpulost N             N CPU cycles of every line lost to DMA (the CPU waits at the line's start):
 *                         6 by default, which fits an A500 (with Musashi's 68000 timing corrected,
 *                         build.sh, and each line's overrun carried into the next: the telemetry
 *                         build's calibration run within 1.2% - enhanced/measurements/); 0: none
 *   pokecopy DST SRC ADD  write byte DST = byte SRC + ADD (to keep a variable tied to another)
 *   chipbus 1 / 0         an instruction run from chip memory takes its cycles rounded up to a multiple
 *                         of 4 (off by default: it does not fit the A500's calibration run - 4-7%
 *                         too slow for simple loops - cpulost does)
 *   inject ADDR [D0]      make the game call ADDR now, as from where it is (with D0): the script goes on
 *                         while it runs (to press fire in it, take snapshots)
 *   disk ADDR ADF|none    the game's 4489_byteloader (at ADDR) done at once from the ADF; "none": no disk in
 *                         (each call fails). The disk is otherwise not emulated.
 *   crashwatch            stop when the PC leaves the memory (below $C0 or above 512K): print the last 64 PCs
 *   writecount LO HI      count every CPU write to each word of LO-HI, and by the instruction that wrote it
 *   writecountdump PREFIX write them: PREFIX.addr (a 32-bit count a word, host order), PREFIX.pc ("pc count")
 *   callprof 1 / 0        time the call tree, from now / stop: each jsr/bsr's time, its callees' included
 *   callprofdump FILE     write it: "caller callee calls cycles", one line a caller -> callee (caller 0:
 *                         the top: called by no routine being timed)
 *   blittime 1            the blitter busy (DMACONR bit 14) for 2 CPU cycles a memory cycle, and its
 *                         interrupt (INTREQ bit 6) when it is done (at the end of that line)
 *   blitcheck 1           report each CPU read or write of what a blit still running writes (its D
 *                         channel's words: blittime's time) - on a real Amiga the CPU would see or be
 *                         overwritten by the blit's results out of order ("blit hazard"; the count at the end)
 *   watchpc LO HI         log each instruction's first write to each 256-byte block of LO-HI
 *   watch LO HI           log the first write to each 256-byte block of LO-HI, with the PC
 *   readwatch LO HI       log each instruction's first CPU read of each 256-byte block of LO-HI
 *   dmacheck LO HI        log each DMA read or write that reaches LO-HI (once per kind and 16 bytes)
 *   cpumult N             the CPU N times as fast as an A500's (an accelerated Amiga: the CPU only; the
 *                         beam, the blitter and the rest keep their time)
 *   phasetrack FLAG LO HI which code's writes to LO-HI other code reads: the phase is 3 in an interrupt,
 *                         else bits 0-1 of the byte at FLAG (0-2, set by the code under study); a read of
 *                         a byte last written in another phase is counted
 *   phasedump FILE        write them: "writer reader addr pc count" (phases 0-3)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "m68k.h"

#define RAM 0x80000                   /* chip RAM: 512K */
#define LINE_CYCLES 454               /* a line: 227 colour clocks, 454 CPU cycles */
static int cpumult = 1;               /* cpumult N: the CPU N times as fast (a faster Amiga), the rest as before */
#define FRAME_LINES 313               /* a frame: a PAL long frame (no interlace) */
#define SNAP 0x80000                  /* what a snapshot / the coverage holds: the first 512K */
#define SLOW_LO 0xC00000              /* slow RAM ("trapdoor"), the CPU's only */
#define SLOW_SIZE 0x80000
static uint8_t ram[RAM], slow[SLOW_SIZE];
static uint16_t cust[0x100];          /* custom registers as last written / derived */
static uint16_t intena, intreq, dmacon, adkcon;
static uint8_t cover[SNAP / 8];
static uint8_t usage[SNAP];           /* bit 0 read, 1 written, 2 executed, 3 DMA */
static unsigned *calls;               /* jsr/bsr targets reached */
static unsigned call_from;
static FILE *logf;
static unsigned long frame, line_no;
static unsigned joy;                  /* bits: 1 up 2 down 4 left 8 right 16 fire 32 button 2 */
static unsigned until_pc = 0xFFFFFFFF; static int until_hit;
static unsigned hits_pc = 0xFFFFFFFF; static long hits_left;   /* hits: the passes still to come */
static unsigned trace_pc = 0xFFFFFFFF; static int trace_all;
static void snapshot(const char *prefix);
static void odd_access(unsigned a, const char *what);
static unsigned rnd(void);
static int blits, blit_line; static long blit_words, blit_cycles;
static long cyc_now(void);
static int blit_timed; static long blit_busy_until;   /* blittime: the blitter busy for its cycles */
static long blit_irq_at;                                /* blittime: its interrupt due (0: none) */
static int bh_on; static unsigned bh_lo, bh_hi, bh_row, bh_w; static unsigned long bh_n;   /* blitcheck */
static FILE *audf;
static unsigned watch_lo = 1, watch_hi = 0; static uint8_t watched[RAM / 256];
static int watch_pcs; static unsigned seen_n, seen[8192];   /* watchpc: (block << 20 | pc) seen */
static unsigned rwatch_lo = 1, rwatch_hi = 0; static unsigned rseen_n, rseen[8192];
static void rwatch(unsigned a) {
    if (a < rwatch_lo || a >= rwatch_hi) return;
    unsigned pc = m68k_get_reg(NULL, M68K_REG_PPC);
    if (a - pc < 16) return;                                /* (fetching its own instruction) */
    unsigned key = (a >> 8) << 20 | (pc & 0xFFFFF);
    for (unsigned i = 0; i < rseen_n; i++) if (rseen[i] == key) return;
    if (rseen_n < 8192) rseen[rseen_n++] = key;
    if (logf) fprintf(logf, "frame %lu: read of $%05X by pc $%X\n", frame, a, pc);
}
/* phasetrack: which code's writes other code reads. The phase: 3 in an interrupt (the IPL mask not 0),
   else bits 0-1 of the byte at pt_flag (the game under study sets it: 0-2). Each byte of LO-HI is marked with
   the phase that last wrote it; a read of it in another phase is counted (by the phases, the address
   and the reading instruction) */
static unsigned pt_flag, pt_lo = 1, pt_hi = 0; static uint8_t *pt_mark;
static struct { unsigned key, pc, n; } *pt_hits; static unsigned pt_n;
static int pt_phase(void) { return (m68k_get_reg(NULL, M68K_REG_SR) & 0x0700) ? 3 : (ram[pt_flag] & 3); }
static void pt_write(unsigned a) { if (a >= pt_lo && a < pt_hi) pt_mark[a - pt_lo] = 4 | pt_phase(); }
static void pt_read(unsigned a) {
    if (a < pt_lo || a >= pt_hi) return;
    uint8_t m = pt_mark[a - pt_lo]; if (!(m & 4)) return;
    int w = m & 3, r = pt_phase(); if (w == r) return;
    unsigned pc = m68k_get_reg(NULL, M68K_REG_PPC), key = a << 4 | w << 2 | r;
    for (unsigned i = 0; i < pt_n; i++) if (pt_hits[i].key == key && pt_hits[i].pc == pc) { pt_hits[i].n++; return; }
    if (pt_n < 65536) { pt_hits[pt_n].key = key; pt_hits[pt_n].pc = pc; pt_hits[pt_n++].n = 1; }
}
static unsigned dma_lo = 1, dma_hi = 0; static unsigned dma_seen_n, dma_seen[4096];
static uint16_t rw(uint32_t a);
static void dma_note(const char *kind, unsigned a, unsigned n) {   /* a DMA area: a .. a+n */
    for (unsigned i = 0; i < n && a + i < SNAP; i++) usage[a + i] |= 8;
    if (dma_lo >= dma_hi || a + n <= dma_lo || a >= dma_hi) return;
    unsigned key = (a >> 4) << 4 | (kind[0] & 15);
    for (unsigned i = 0; i < dma_seen_n; i++) if (dma_seen[i] == key) return;
    if (dma_seen_n < 4096) dma_seen[dma_seen_n++] = key;
    if (logf) fprintf(logf, "frame %lu: DMA %s $%06X-$%06X by pc $%X\n", frame, kind, a, a + n,
                      m68k_get_reg(NULL, M68K_REG_PPC));
}
static void dma_ptr(unsigned reg, unsigned v) {             /* a pointer register loaded */
    if (reg >= 0xE0 && reg < 0x100) {                     /* a plane: the display window's lines */
        if ((dmacon & 0x300) != 0x300 || (reg - 0xE0) / 4 >= ((cust[0x100 / 2] >> 12) & 7)) return;
        unsigned vs = cust[0x8E / 2] >> 8, ve = cust[0x90 / 2] >> 8; if (!(ve & 0x80)) ve += 0x100;
        unsigned words = ((cust[0x94 / 2] - cust[0x92 / 2]) & 0xFF) / 8 + 1;
        int mod = (int16_t)cust[(((reg - 0xE0) / 4) & 1 ? 0x10A : 0x108) / 2];
        dma_note("bitplane", v, (ve > vs ? ve - vs : 200) * (2 * words + mod)); }
    else if (reg >= 0x120 && reg < 0x140) {               /* a sprite: its words to the 0,0 end */
        unsigned n = 0; while (n < 2048 && (rw(v + n) | rw(v + n + 2))) n += 4;
        dma_note("sprite", v, n + 4); }
    else if (reg == 0x80 || reg == 0x84) dma_note("copper", v, 4);
}
static void watch(unsigned a) {
    if (watch_pcs && a >= watch_lo && a < watch_hi) {
        unsigned pc = m68k_get_reg(NULL, M68K_REG_PPC), key = (a >> 8) << 20 | (pc & 0xFFFFF);
        for (unsigned i = 0; i < seen_n; i++) if (seen[i] == key) return;
        if (seen_n < 8192) seen[seen_n++] = key;
        if (logf) fprintf(logf, "frame %lu: write to $%05X by pc $%X\n", frame, a, pc);
        return;
    }
    if (a >= watch_lo && a < watch_hi && !watched[a >> 8]) {
        watched[a >> 8] = 1;
        if (logf) fprintf(logf, "frame %lu: first write to $%05X block by pc $%X\n", frame, a & ~0xFF, m68k_get_reg(NULL, M68K_REG_PPC));
    }
}

/* ---- CIAs */
typedef struct {
    uint8_t pra, prb, ddra, ddrb, icr_mask, icr_flags, cra, crb, sdr;
    uint16_t ta, tb, ta_latch, tb_latch;
    uint32_t tod, alarm; int tod_halt; uint32_t tod_latch; int tod_latched;
} cia_t;
static cia_t ciaa, ciab;
static int key_queue[16], kq_n; static int key_delay;

static void update_irq(void) {
    unsigned act = intena & 0x4000 ? (intena & intreq & 0x3FFF) : 0;
    int lvl = 0;
    if (act & 0x6000) lvl = 6; else if (act & 0x1800) lvl = 5; else if (act & 0x0780) lvl = 4;
    else if (act & 0x0070) lvl = 3; else if (act & 0x0008) lvl = 2; else if (act & 0x0007) lvl = 1;
    m68k_set_irq(lvl);
}
static void cia_irq(cia_t *c, int bit) {
    c->icr_flags |= bit;
    if (c->icr_mask & bit) { c->icr_flags |= 0x80; intreq |= (c == &ciaa) ? 0x0008 : 0x2000; update_irq(); }
}

/* ---- audio interrupts: a channel's request is set when its DMA starts a block (and again
 * each time the block repeats); a channel whose DMA is off requests at once (the sound driver
 * waits for that after stopping a channel) */
static long aud_next[4] = {-1, -1, -1, -1}; static long cyc_total;
static void dma_note(const char *kind, unsigned a, unsigned n);
static void aud_schedule(int ch) {                          /* (a block starts: its samples are read) */
    unsigned len = cust[(0xA4 + 16 * ch) / 2], per = cust[(0xA6 + 16 * ch) / 2];
    dma_note("audio", ((unsigned)cust[(0xA0 + 16 * ch) / 2] << 16 | cust[(0xA2 + 16 * ch) / 2]) & (RAM - 2),
             2 * (len ? len : 0x10000));
    if (!len) len = 0x10000; if (per < 124) per = 124;
    aud_next[ch] = cyc_total + (long)len * 2 * per * 2;
}

/* ---- blitter: area mode, at once */
static uint16_t rw(uint32_t a) { a &= RAM - 2; return ram[a] << 8 | ram[a + 1]; }
static void watch(unsigned a);
static void ww(uint32_t a, uint16_t v) { a &= RAM - 2; watch(a); ram[a] = v >> 8; ram[a + 1] = v; }   /* (blitter: usage by dma_note) */
static uint32_t ptr(int r) { return ((uint32_t)cust[r / 2] << 16 | cust[r / 2 + 1]) & (RAM - 2); }
static void blit(uint16_t size) {
    uint16_t con0 = cust[0x40 / 2], con1 = cust[0x42 / 2];
    blits++;
    if (con1 & 1) {                                 /* line mode (the Hardware Reference Manual's): a pixel a step */
        int n = size >> 6 ? size >> 6 : 1024;      /* the pixels (the major axis' length + 1) */
        blit_line++;
        blit_words += n;
        blit_cycles += (long)n * 4;                /* about 4 memory cycles a pixel */
        if (blit_timed) blit_busy_until = cyc_now() + 2L * n * 4;
        int ash = con0 >> 12, bsh = con1 >> 12, mt = con0 & 0xFF;
        int sud = con1 >> 4 & 1, sul = con1 >> 3 & 1, aul = con1 >> 2 & 1, sing = con1 >> 1 & 1;
        int32_t d = (int16_t)cust[0x52 / 2] | 0;    /* BLTAPT's low word: the error, signed */
        int16_t amod = cust[0x64 / 2], bmod = cust[0x62 / 2], cmod = cust[0x60 / 2];
        uint32_t cp = ptr(0x48);
        uint16_t bdat = cust[0x72 / 2], adat = cust[0x74 / 2];
        int moved_y = 1;                            /* the first pixel is always plotted (ONEDOT: the first of a row) */
        for (int i = 0; i < n; i++) {
            uint16_t a = (adat >> ash) & 0xFFFF, c = rw(cp);
            if (!(adat & 0x8000)) a = adat >> ash;
            uint16_t b = (bdat >> bsh & 1) ? 0xFFFF : 0;
            if (!sing || moved_y) {
                uint16_t dd = 0;
                for (int k = 0; k < 8; k++) if (mt >> k & 1)
                    dd |= (k & 4 ? a : ~a) & (k & 2 ? b : ~b) & (k & 1 ? c : ~c);
                ww(cp, dd);
            }
            bsh = (bsh - 1) & 15;
            int sign = d < 0;
            moved_y = 0;
            /* the major axis always, the minor one when the error is not negative */
            for (int pass = 0; pass < 2; pass++) {
                if (pass == 1 && sign) break;
                int vertical = pass == 0 ? sud : !sud;          /* this step's axis */
                int back = pass == 0 ? aul : sul;              /* up / left */
                if (vertical) { cp += back ? -cmod : cmod; moved_y = 1; }
                else if (back) { if (ash == 0) { ash = 15; cp -= 2; } else ash--; }
                else { if (ash == 15) { ash = 0; cp += 2; } else ash++; }
            }
            d += sign ? bmod : amod;
        }
        cust[0x48 / 2] = cp >> 16; cust[0x4A / 2] = cp; cust[0x54 / 2] = cp >> 16; cust[0x56 / 2] = cp;
        goto done;
    }
    int h = size >> 6 ? size >> 6 : 1024, w = size & 63 ? size & 63 : 64;
    blit_words += (long)h * w;
    int use = con0 >> 8 & 15, ash = con0 >> 12, bsh = con1 >> 12, mt = con0 & 0xFF, desc = con1 & 2;
    {   /* the blitter's memory cycles (280 ns each): about one a channel a word, at least 2 */
        int n = (use & 8 ? 1 : 0) + (use & 4 ? 1 : 0) + (use & 2 ? 1 : 0) + (use & 1 ? 1 : 0);
        blit_cycles += (long)h * w * (n < 2 ? 2 : n);
        if (blit_timed) blit_busy_until = cyc_now() + 2L * h * w * (n < 2 ? 2 : n);   /* 2 CPU cycles each */
    }
    uint16_t fwm = cust[0x44 / 2], lwm = cust[0x46 / 2];
    uint32_t pa = ptr(0x50), pb = ptr(0x4C), pc = ptr(0x48), pd = ptr(0x54);
    int16_t ma = cust[0x64 / 2], mb = cust[0x62 / 2], mc = cust[0x60 / 2], md = cust[0x66 / 2];
    {                                                      /* the blits' areas (descending: below the pointers) */
        unsigned span[4] = {h * (2 * w + ma), h * (2 * w + mb), h * (2 * w + mc), h * (2 * w + md)};
        unsigned at[4] = {pa, pb, pc, pd}; const char *nm[4] = {"blitA", "blitB", "blitC", "blitD"};
        for (int k = 0; k < 4; k++) if (use & (8 >> k)) {
            unsigned n = span[k] > 0x40000 ? 0 : span[k];
            dma_note(nm[k], (con1 & 2) ? at[k] + 2 - n : at[k], n); }
    }
    if (bh_on && (use & 1)) {                              /* blitcheck: the D channel's words, until it is done */
        bh_row = 2 * w + md; bh_w = 2 * w;
        if (desc) { bh_lo = pd + 2 - h * bh_row; bh_row = 0; } else bh_lo = pd;
        bh_hi = bh_lo + h * (2 * w + md);
    }
    uint16_t adat = cust[0x74 / 2], bdat = cust[0x72 / 2], cdat = cust[0x70 / 2];
    int step = desc ? -2 : 2;
    int fill = (con1 >> 3) & 3;                     /* IFE / EFE (fill mode) */
    for (int y = 0; y < h; y++) {
        uint16_t olda = 0, oldb = 0; int fc = (con1 >> 2) & 1;
        for (int x = 0; x < w; x++) {
            uint16_t a = use & 8 ? rw(pa) : adat, b = use & 4 ? rw(pb) : bdat, c = use & 2 ? rw(pc) : cdat;
            if (use & 8) pa += step; if (use & 4) pb += step; if (use & 2) pc += step;
            uint16_t am = a;
            if (x == 0) am &= fwm;
            if (x == w - 1) am &= lwm;
            uint16_t as, bs;
            if (!desc) { as = (uint16_t)(((uint32_t)olda << 16 | am) >> ash); bs = (uint16_t)(((uint32_t)oldb << 16 | b) >> bsh); }
            else       { as = (uint16_t)(((uint32_t)am << 16 | olda) >> (16 - ash)); bs = (uint16_t)(((uint32_t)b << 16 | oldb) >> (16 - bsh)); }
            olda = am; oldb = b;
            uint16_t d = 0;
            for (int i = 0; i < 8; i++) if (mt >> i & 1)
                d |= (i & 4 ? as : ~as) & (i & 2 ? bs : ~bs) & (i & 1 ? c : ~c);
            if (fill) {                              /* descending fill, word by word */
                uint16_t o = 0;
                for (int bit = 0; bit < 16; bit++) {
                    int v = d >> bit & 1;
                    if (v) fc ^= 1;
                    int out = (fill & 2) ? (fc ^ v) : (fc | v);
                    if (fill & 1) out = fc | v;
                    o |= out << bit;
                }
                d = o;
            }
            if (use & 1) { ww(pd, d); pd += step; }
        }
        if (use & 8) pa += desc ? -ma : ma; if (use & 4) pb += desc ? -mb : mb;
        if (use & 2) pc += desc ? -mc : mc; if (use & 1) pd += desc ? -md : md;
    }
    cust[0x50 / 2] = pa >> 16; cust[0x52 / 2] = pa; cust[0x4C / 2] = pb >> 16; cust[0x4E / 2] = pb;
    cust[0x48 / 2] = pc >> 16; cust[0x4A / 2] = pc; cust[0x54 / 2] = pd >> 16; cust[0x56 / 2] = pd;
done:
    if (blit_timed && !(con1 & 1)) { blit_irq_at = blit_busy_until; return; }   /* (blittime: when it is done) */
    intreq |= 0x0040; update_irq();
}
static long cyc_now(void);
static void bhaz(unsigned a, const char *what) {             /* blitcheck: the CPU at a running blit's words */
    if (a < bh_lo || a >= bh_hi || cyc_now() >= blit_busy_until) return;
    if (bh_row && (a - bh_lo) % bh_row >= bh_w) return;      /* (its modulo's gaps: not written) */
    if (bh_n++ < 20) fprintf(logf ? logf : stdout, "blit hazard: frame %lu line %lu, a CPU %s of $%X by the instruction at $%X (a blit to $%X-$%X running)\n",
                             frame, line_no, what, a, m68k_get_reg(NULL, M68K_REG_PPC), bh_lo, bh_hi);
}

/* ---- memory */
static unsigned beam(void) {
    unsigned cyc = (LINE_CYCLES * cpumult - m68k_cycles_remaining()) / cpumult;
    if ((int)cyc < 0) cyc = 0; if (cyc > LINE_CYCLES - 1) cyc = LINE_CYCLES - 1;
    return (line_no << 8 | (cyc / 2)) & 0xFFFF;
}
static unsigned custom_read(unsigned r) {
    switch (r) {
    case 0x002: return (dmacon & 0x3FFF) | (blit_timed && cyc_now() < blit_busy_until ? 0x4000 : 0);
                                                             /* DMACONR: the blitter busy (blittime) */
    case 0x004: return (line_no >> 8) & 1;                   /* VPOSR (PAL OCS) */
    case 0x006: return beam();                               /* VHPOSR */
    case 0x00A: return 0;                                    /* JOY0DAT */
    case 0x00C: {                                            /* JOY1DAT */
        unsigned r1 = joy & 8 ? 1 : 0, l = joy & 4 ? 1 : 0, d = joy & 2 ? 1 : 0, u = joy & 1 ? 1 : 0;
        return (l << 9) | ((l ^ u) << 8) | (r1 << 1) | (r1 ^ d); }
    case 0x010: return adkcon;
    case 0x016: return joy & 32 ? 0xBF00 : 0xFF00;           /* POTGOR: port 2's second button (DATRY) */
    case 0x018: return 0x3000;                               /* SERDATR: TBE, TSRE (nothing received) */
    case 0x01A: return 0;                                    /* DSKBYTR */
    case 0x01C: return intena;
    case 0x01E:
        for (int ch = 0; ch < 4; ch++)
            if (!((dmacon & 0x200) && (dmacon & (1 << ch)))) intreq |= 0x80 << ch;
        update_irq();
        return intreq;
    }
    return cust[r / 2];
}
static long cyc_now(void);
static void custom_write(unsigned r, unsigned v) {
    v &= 0xFFFF;
    cust[r / 2] = v;
    if (audf && ((r >= 0xA0 && r < 0xE0) || r == 0x096)) fprintf(audf, "%ld %03X %04X\n", cyc_now(), r, v);
    if ((r & 2) && ((r >= 0x80 && r < 0x88) || (r >= 0xE0 && r < 0x100) || (r >= 0x120 && r < 0x140)))
        dma_ptr(r - 2, ((unsigned)cust[(r - 2) / 2] << 16 | v) & (RAM - 2));   /* (the low word: the pointer whole) */

    switch (r) {
    case 0x058: blit(v); break;
    case 0x096: { unsigned old = dmacon; dmacon = v & 0x8000 ? dmacon | (v & 0x7FFF) : dmacon & ~v;
        for (int ch = 0; ch < 4; ch++) {
            unsigned m = 0x200 | (1 << ch);
            if ((dmacon & m) == m && (old & m) != m) { intreq |= 0x80 << ch; update_irq(); aud_schedule(ch); }
            if ((dmacon & m) != m) aud_next[ch] = -1;
        }
        break; }
    case 0x09A: intena = v & 0x8000 ? intena | (v & 0x7FFF) : intena & ~v; update_irq(); break;
    case 0x09C: intreq = v & 0x8000 ? intreq | (v & 0x7FFF) : intreq & ~v; update_irq(); break;
    case 0x09E: adkcon = v & 0x8000 ? adkcon | (v & 0x7FFF) : adkcon & ~v; break;
    }
}
static unsigned cia_read(cia_t *c, int reg, int isa) {
    switch (reg) {
    case 0: if (isa) {                                       /* PRA: /FIR1 /FIR0 /RDY /TK0 /WPRO /CHNG */
                unsigned v = 0xFC; if (joy & 16) v &= ~0x80; return (v & ~c->ddra) | (c->pra & c->ddra); }
            return c->pra;
    case 1: return c->prb;
    case 2: return c->ddra; case 3: return c->ddrb;
    case 4: return c->ta & 0xFF; case 5: return c->ta >> 8;
    case 6: return c->tb & 0xFF; case 7: return c->tb >> 8;
    case 8: { uint32_t t = c->tod_latched ? c->tod_latch : c->tod; c->tod_latched = 0; return t & 0xFF; }
    case 9: return ((c->tod_latched ? c->tod_latch : c->tod) >> 8) & 0xFF;
    case 10: c->tod_latch = c->tod; c->tod_latched = 1; return (c->tod >> 16) & 0xFF;
    case 12: return c->sdr;
    case 13: { unsigned f = c->icr_flags; c->icr_flags = 0;
        intreq &= ~(isa ? 0x0008 : 0x2000); update_irq(); return f; }
    case 14: return c->cra; case 15: return c->crb;
    }
    return 0;
}
static void cia_write(cia_t *c, int reg, unsigned v) {
    v &= 0xFF;
    switch (reg) {
    case 0: c->pra = v; break; case 1: c->prb = v; break;
    case 2: c->ddra = v; break; case 3: c->ddrb = v; break;
    case 4: c->ta_latch = (c->ta_latch & 0xFF00) | v; break;
    case 5: c->ta_latch = (c->ta_latch & 0xFF) | v << 8; if (!(c->cra & 1)) c->ta = c->ta_latch; break;
    case 6: c->tb_latch = (c->tb_latch & 0xFF00) | v; break;
    case 7: c->tb_latch = (c->tb_latch & 0xFF) | v << 8; if (!(c->crb & 1)) c->tb = c->tb_latch; break;
    case 8: if (c->crb & 0x80) c->alarm = (c->alarm & 0xFFFF00) | v; else { c->tod = (c->tod & 0xFFFF00) | v; c->tod_halt = 0; } break;
    case 9: if (c->crb & 0x80) c->alarm = (c->alarm & 0xFF00FF) | v << 8; else c->tod = (c->tod & 0xFF00FF) | v << 8; break;
    case 10: if (c->crb & 0x80) c->alarm = (c->alarm & 0x00FFFF) | v << 16; else { c->tod = (c->tod & 0x00FFFF) | v << 16; c->tod_halt = 1; } break;
    case 12: c->sdr = v; break;
    case 13: if (v & 0x80) c->icr_mask |= v & 0x7F; else c->icr_mask &= ~v; break;
    case 14: if (v & 0x10) c->ta = c->ta_latch; c->cra = v & ~0x10; break;
    case 15: if (v & 0x10) c->tb = c->tb_latch; c->crb = v & ~0x10; break;
    }
}
unsigned int m68k_read_memory_8(unsigned int a) {
    a &= 0xFFFFFF;
    if (a < RAM) { rwatch(a); pt_read(a); usage[a] |= 1; if (bh_on) bhaz(a, "read"); return ram[a]; }
    if (a - SLOW_LO < SLOW_SIZE) return slow[a - SLOW_LO];
    if ((a & 0xFFF000) == 0xBFE000 && (a & 1)) return cia_read(&ciaa, (a >> 8) & 15, 1);
    if ((a & 0xFFF000) == 0xBFD000 && !(a & 1)) return cia_read(&ciab, (a >> 8) & 15, 0);
    if ((a & 0xFFF000) == 0xDFF000) { unsigned v = custom_read(a & 0x1FE); return a & 1 ? v & 0xFF : v >> 8; }
    return 0;
}
unsigned int m68k_read_memory_16(unsigned int a) {
    if (a & 1) odd_access(a & 0xFFFFFF, "a word read");
    a &= 0xFFFFFF;
    if (a < RAM) { rwatch(a); pt_read(a); pt_read(a + 1); usage[a] |= 1; usage[a + 1] |= 1; if (bh_on) bhaz(a, "read"); return ram[a] << 8 | ram[a + 1]; }
    if (a - SLOW_LO < SLOW_SIZE) return slow[a - SLOW_LO] << 8 | slow[a - SLOW_LO + 1];
    if ((a & 0xFFF000) == 0xDFF000) return custom_read(a & 0x1FE);
    return m68k_read_memory_8(a) << 8 | m68k_read_memory_8(a + 1);
}
unsigned int m68k_read_memory_32(unsigned int a) {
    if (a & 1) odd_access(a & 0xFFFFFF, "a long read"); return m68k_read_memory_16(a) << 16 | m68k_read_memory_16(a + 2); }
static unsigned wlog_lo = 1, wlog_hi = 0; static FILE *wlogf;   /* writelog: every CPU write to LO-HI */
static unsigned wc_lo = 1, wc_hi = 0; static unsigned *wc_addr, *wc_pc;   /* writecount: CPU writes to LO-HI */
static void wcount(unsigned a) {
    if (a >= wc_lo && a < wc_hi) { wc_addr[(a - wc_lo) >> 1]++; unsigned pc = m68k_get_reg(NULL, M68K_REG_PPC); if (pc < RAM) wc_pc[pc >> 1]++; }
}
static unsigned long odd_n;                                 /* word/long accesses at odd addresses: the 68000's address error */
static void odd_access(unsigned a, const char *what) {
    if (odd_n++ < 20) { FILE *o = logf ? logf : stdout;
        fprintf(o, "address error: frame %lu line %lu, %s at $%X by the instruction at $%X\n", frame, line_no, what, a,
                m68k_get_reg(NULL, M68K_REG_PPC)); }
}
static void wlog(unsigned a, unsigned v, int size) {
    wcount(a & ~1u);
    if (a + size > wlog_lo && a < wlog_hi && wlogf)
        fprintf(wlogf, pt_flag ? "%lu %lu %X %X %X/%d %d\n" : "%lu %lu %X %X %X/%d\n", frame, line_no, m68k_get_reg(NULL, M68K_REG_PPC), a, v, size,
                pt_flag ? pt_phase() : 0);   /* (with phasetrack on: the phase too) */
}
void m68k_write_memory_8(unsigned int a, unsigned int v) {
    a &= 0xFFFFFF;
    if (a < RAM) { wlog(a, v & 0xFF, 1); watch(a); pt_write(a); usage[a] |= 2; if (bh_on) bhaz(a, "write"); ram[a] = v; return; }
    if (a - SLOW_LO < SLOW_SIZE) { slow[a - SLOW_LO] = v; return; }
    if ((a & 0xFFF000) == 0xBFE000 && (a & 1)) { cia_write(&ciaa, (a >> 8) & 15, v); return; }
    if ((a & 0xFFF000) == 0xBFD000 && !(a & 1)) { cia_write(&ciab, (a >> 8) & 15, v); return; }
    if ((a & 0xFFF000) == 0xDFF000) { unsigned r = a & 0x1FE; custom_write(r, a & 1 ? (cust[r / 2] & 0xFF00) | (v & 0xFF) : (v & 0xFF) << 8 | (v & 0xFF)); }
}
void m68k_write_memory_16(unsigned int a, unsigned int v) {
    if (a & 1) odd_access(a & 0xFFFFFF, "a word write");
    a &= 0xFFFFFF;
    if (a < RAM) { wlog(a, v & 0xFFFF, 2); watch(a); pt_write(a); pt_write(a + 1); usage[a] |= 2; usage[a + 1] |= 2; if (bh_on) bhaz(a, "write"); ram[a] = v >> 8; ram[a + 1] = v; return; }
    if (a - SLOW_LO < SLOW_SIZE) { slow[a - SLOW_LO] = v >> 8; slow[a - SLOW_LO + 1] = v; return; }
    if ((a & 0xFFF000) == 0xDFF000) { custom_write(a & 0x1FE, v); return; }
    m68k_write_memory_8(a, v >> 8); m68k_write_memory_8(a + 1, v);
}
void m68k_write_memory_32(unsigned int a, unsigned int v) { if (a & 1) { odd_access(a & 0xFFFFFF, "a long write"); odd_n += 2; } m68k_write_memory_16(a, v >> 16); m68k_write_memory_16(a + 2, v); }
unsigned int m68k_read_disassembler_8(unsigned int a) { return m68k_read_memory_8(a); }
unsigned int m68k_read_disassembler_16(unsigned int a) { return m68k_read_memory_16(a); }
unsigned int m68k_read_disassembler_32(unsigned int a) { return m68k_read_memory_32(a); }

static unsigned *prof; static unsigned prof_pc; static long prof_cyc;   /* profile: CPU cycles by pc */

/* callprof: the call tree's time. Each jsr/bsr pushes a frame (its target, the cycle and the stack
 * pointer it returns to); a frame ends when the stack pointer is back above it (rts, or the
 * routine dropping its return address). Each caller -> callee edge adds up its calls and its
 * cycles, the callee's own and those of everything it calls (interrupts included). */
#define CP_DEPTH 256
#define CP_EDGES 65536
static int callprof; static unsigned cp_pending;               /* the jsr/bsr just executed: its stack pointer */
static struct { unsigned target, sp; long start; } cp_stack[CP_DEPTH]; static int cp_n;
static struct { unsigned from, to; unsigned long n; long long cyc; } cp_edge[CP_EDGES];
static void cp_add(unsigned from, unsigned to, long cyc) {
    unsigned h = (from * 2654435761u ^ to * 40503u) & (CP_EDGES - 1);
    while (cp_edge[h].n && (cp_edge[h].from != from || cp_edge[h].to != to)) h = (h + 1) & (CP_EDGES - 1);
    cp_edge[h].from = from; cp_edge[h].to = to; cp_edge[h].n++; cp_edge[h].cyc += cyc;
}
static void cp_hook(unsigned pc) {
    unsigned sp = m68k_get_reg(NULL, M68K_REG_A7); long c = cyc_now();
    while (cp_n && sp >= cp_stack[cp_n - 1].sp) {           /* returned (or the return address dropped) */
        cp_n--; cp_add(cp_n ? cp_stack[cp_n - 1].target : 0, cp_stack[cp_n].target, c - cp_stack[cp_n].start);
    }
    if (cp_pending && sp == cp_pending - 4 && cp_n < CP_DEPTH) {
        cp_stack[cp_n].target = pc; cp_stack[cp_n].sp = cp_pending; cp_stack[cp_n].start = c; cp_n++;
    }
    cp_pending = 0;
    unsigned op = m68k_read_memory_16(pc);
    if ((op & 0xFFC0) == 0x4E80 || (op & 0xFF00) == 0x6100) cp_pending = sp;
}

static int crashwatch; static unsigned pcring[64]; static unsigned pcring_n;   /* crashwatch: the last 64 PCs */
static unsigned disk_loader = 0xFFFFFFFF; static uint8_t *disk_adf; static long disk_size; static long disk_loads;
/* disk: the game's call of the 4489_byteloader done at once from an ADF (d0 offset, d1 length, a0
 * where -> d0 = 0), or failed (d0 = 1) with no disk in */
static void disk_call(void) {
    unsigned off = m68k_get_reg(NULL, M68K_REG_D0), len = m68k_get_reg(NULL, M68K_REG_D1), dst = m68k_get_reg(NULL, M68K_REG_A0);
    int ok = disk_adf && off + len <= (unsigned long)disk_size && dst + len <= RAM;
    if (ok) { memcpy(ram + dst, disk_adf + off, len); for (unsigned i = 0; i < len; i++) usage[dst + i] |= 8; }
    if (logf) fprintf(logf, "frame %lu: disk read $%X+$%X to $%X: %s\n", frame, off, len, dst, ok ? "ok" : "failed");
    disk_loads++;
    m68k_set_reg(M68K_REG_D0, ok ? 0 : 1);
    unsigned sp = m68k_get_reg(NULL, M68K_REG_A7);
    m68k_set_reg(M68K_REG_PC, m68k_read_memory_32(sp)); m68k_set_reg(M68K_REG_A7, sp + 4);
}
static int chipbus; static long cb_last = -1; static unsigned cb_pc = 0xFFFFFFFF;
static int cpulost = 6, cl_pending, cl_taken;   /* cpulost N: N CPU cycles of each line lost to DMA (taken at its start) */
/* chipbus: the 68000 on the chip bus can start a memory access only every 4 cycles (2 colour
 * clocks): an instruction run from chip memory takes its cycles rounded up to a multiple of 4 */
static void chipbus_hook(unsigned pc) {
    long c = cyc_now();
    if (cb_last >= 0 && cb_pc < RAM && c > cb_last) {
        long pad = (4 - (c - cb_last) % 4) % 4;
        if (pad) { m68k_modify_timeslice(-(int)pad); c += pad; }
    }
    cb_last = c; cb_pc = pc;
}
void instr_hook(unsigned int pc) {
    pc &= 0xFFFFFF;
    if (cl_pending) { cl_pending = 0; m68k_modify_timeslice(-cpulost); cl_taken = cpulost; }
    if (chipbus) chipbus_hook(pc);
    if (pc == disk_loader) { disk_call(); return; }
    if (crashwatch) {
        if (pc < 0xC0 || pc >= RAM) {
            FILE *o = logf ? logf : stdout;
            fprintf(o, "crash: frame %lu line %lu, the PC at $%X; the instructions before it, oldest first:\n", frame, line_no, pc);
            for (unsigned i = 0; i < 64; i++) fprintf(o, " $%X", pcring[(pcring_n + i) & 63]);
            fprintf(o, "\n  a7 $%X\n", m68k_get_reg(NULL, M68K_REG_A7));
            crashwatch = 0; until_hit = 1; m68k_end_timeslice();
        }
        pcring[pcring_n++ & 63] = pc;
    }
    if (callprof) cp_hook(pc);
    if (prof) {
        long c = cyc_now();
        if (prof_pc < RAM) prof[prof_pc >> 1] += (unsigned)(c - prof_cyc);
        prof_pc = pc; prof_cyc = c;
    }
    if (pc < SNAP) cover[pc >> 3] |= 1 << (pc & 7);
    if (pc == until_pc) { until_hit = 1; m68k_end_timeslice(); }
    if (pc == hits_pc && hits_left > 0) hits_left--;
    if (pc < SNAP) usage[pc] |= 4;
    if (calls) {                                             /* a jsr/bsr's target: the instruction after it */
        if (call_from) { calls[pc >> 1]++; call_from = 0; }
        unsigned op = m68k_read_memory_16(pc);
        if ((op & 0xFFC0) == 0x4E80 || (op & 0xFF00) == 0x6100) call_from = pc;
    }
    if (pc == trace_pc && logf)
        fprintf(logf, "frame %lu line %lu: pc $%X sr $%04X a7 $%X intreq $%04X d0 $%X d1 $%X d2 $%X a0 $%X a1 $%X a5 $%X a6 $%X\n",
                frame, line_no, pc, m68k_get_reg(NULL, M68K_REG_SR), m68k_get_reg(NULL, M68K_REG_A7), intreq, m68k_get_reg(NULL, M68K_REG_D0), m68k_get_reg(NULL, M68K_REG_D1),
                m68k_get_reg(NULL, M68K_REG_D2), m68k_get_reg(NULL, M68K_REG_A0), m68k_get_reg(NULL, M68K_REG_A1),
                m68k_get_reg(NULL, M68K_REG_A5), m68k_get_reg(NULL, M68K_REG_A6));
    if (pc == trace_pc && logf && trace_all)               /* (traceall 1: the other registers too) */
        fprintf(logf, "  d3 $%X d4 $%X d5 $%X d6 $%X d7 $%X a2 $%X a3 $%X a4 $%X\n", m68k_get_reg(NULL, M68K_REG_D3), m68k_get_reg(NULL, M68K_REG_D4),
                m68k_get_reg(NULL, M68K_REG_D5), m68k_get_reg(NULL, M68K_REG_D6), m68k_get_reg(NULL, M68K_REG_D7), m68k_get_reg(NULL, M68K_REG_A2),
                m68k_get_reg(NULL, M68K_REG_A3), m68k_get_reg(NULL, M68K_REG_A4));
}

/* ---- timing: a frame of 313 lines (a PAL long frame, as the Amiga shows without interlace) of
 * 454 CPU cycles (227 colour clocks; the CPU at 7.09 MHz): 142,102 cycles, 49.92 frames a second */
static void cia_tick_timers(cia_t *c, int eclocks) {
    for (int i = 0; i < eclocks; i++) {
        int ta_under = 0;
        if ((c->cra & 1) && !(c->cra & 0x20)) {
            if (c->ta == 0) { ta_under = 1; c->ta = c->ta_latch; cia_irq(c, 1); if (c->cra & 8) c->cra &= ~1; }
            else c->ta--;
        }
        if (c->crb & 1) {
            int mode = (c->crb >> 5) & 3, tick = mode == 0 ? 1 : mode >= 2 ? ta_under : 0;
            if (tick) {
                if (c->tb == 0) { c->tb = c->tb_latch; cia_irq(c, 2); if (c->crb & 8) c->crb &= ~1; }
                else c->tb--;
            }
        }
    }
}
static long cyc_now(void) { long c = (LINE_CYCLES * cpumult - m68k_cycles_remaining()) / cpumult; if (c < 0) c = 0; if (c > LINE_CYCLES) c = LINE_CYCLES; return cyc_total + c; }
static int line_over;              /* the cycles the last line's last instruction ran over its end */
static void run_line(void) {
    cb_last = -1;                                            /* (chipbus: from the line's start) */
    cl_pending = cpulost > 0;
    {   /* an instruction that runs over the line's end takes those cycles from the next line */
        int want = LINE_CYCLES * cpumult - line_over;
        if (want < 1) { line_over -= LINE_CYCLES * cpumult; }
        else { cl_taken = 0; line_over = m68k_execute(want) + cl_taken - want; }
    }
    cyc_total += LINE_CYCLES;
    if (blit_irq_at && cyc_total >= blit_irq_at) { blit_irq_at = 0; intreq |= 0x0040; update_irq(); }   /* (blittime) */
    cia_tick_timers(&ciaa, 45); cia_tick_timers(&ciab, 45);
    /* CIA-B TOD counts lines (HSYNC) */
    if (!ciab.tod_halt) { ciab.tod = (ciab.tod + 1) & 0xFFFFFF; if (ciab.tod == ciab.alarm) cia_irq(&ciab, 4); }
    for (int ch = 0; ch < 4; ch++)
        if (aud_next[ch] >= 0 && cyc_total >= aud_next[ch]) { intreq |= 0x80 << ch; update_irq(); aud_schedule(ch); }
    line_no++;
}
static void keyboard_tick(void) {
    if (key_delay > 0) { key_delay--; return; }
    if (kq_n) {
        int k = key_queue[0]; memmove(key_queue, key_queue + 1, --kq_n * sizeof(int));
        ciaa.sdr = ~((k << 1) | (k >> 7)) & 0xFF;            /* the keyboard's encoding */
        cia_irq(&ciaa, 8); key_delay = 3;
    }
}
/* the copper's writes to INTREQ (its interrupt), each at the line of the WAIT before it: raised by
 * run_frame at that line */
static unsigned cop_irq_line[16], cop_irq_val[16]; static int cop_irq_n;
static void copper_walk(unsigned a) {                       /* a copper list: its pointers, its interrupts */
    unsigned hi[0x100] = {0}, vpos = 0;
    dma_note("copper", a, 4);
    for (int i = 0; i < 1024; i++, a += 4) {
        unsigned w1 = rw(a), w2 = rw(a + 2);
        if (w1 == 0xFFFF && w2 == 0xFFFE) { dma_note("copper", a - 4 * i, 4 * i + 4); return; }
        if (w1 & 1) {                                          /* WAIT (SKIP not followed) */
            if (!(w2 & 1)) { unsigned v = w1 >> 8; if (vpos >= 0x100) v += 0x100; if (v > vpos) vpos = v; }
            continue; }
        unsigned r = w1 & 0x1FE;
        if (r == 0x09C && cop_irq_n < 16) { cop_irq_line[cop_irq_n] = vpos; cop_irq_val[cop_irq_n++] = w2; }
        if (r & 2) { if ((r >= 0x80 && r < 0x88) || (r >= 0xE0 && r < 0x100) || (r >= 0x120 && r < 0x140))
                         dma_ptr(r - 2, (hi[(r - 2) / 2] << 16 | w2) & (RAM - 2)); }
        else hi[r / 2] = w2;
    }
}
static void run_frame(void) {
    line_no = 0;
    cop_irq_n = 0;
    if ((dmacon & 0x280) == 0x280) {                           /* the copper on: its lists */
        copper_walk(((unsigned)cust[0x80 / 2] << 16 | cust[0x82 / 2]) & (RAM - 2));
        if (cust[0x84 / 2] | cust[0x86 / 2]) copper_walk(((unsigned)cust[0x84 / 2] << 16 | cust[0x86 / 2]) & (RAM - 2));
    }
    /* CIA-A TOD counts frames (VSYNC) */
    ciaa.tod = (ciaa.tod + 1) & 0xFFFFFF;
    intreq |= 0x0020; update_irq();                           /* VERTB */
    keyboard_tick();
    for (int l = 0; l < FRAME_LINES && !until_hit; l++) {
        for (int k = 0; k < cop_irq_n; k++)                     /* the copper's interrupts at their line */
            if (cop_irq_line[k] == line_no && (dmacon & 0x280) == 0x280) {
                unsigned v = cop_irq_val[k]; intreq = v & 0x8000 ? intreq | (v & 0x7FFF) : intreq & ~v; update_irq(); }
        run_line();
    }
    frame++;
}

static uint32_t rng = 1;
static unsigned rnd(void) { rng = rng * 1103515245 + 12345; return rng >> 16; }
static void snapshot(const char *prefix) {
    char fn[500]; snprintf(fn, sizeof fn, "%s.mem", prefix); FILE *o = fopen(fn, "wb"); fwrite(ram, 1, SNAP, o); fclose(o);
    snprintf(fn, sizeof fn, "%s.regs", prefix); o = fopen(fn, "wb");
    for (int i = 0; i < 0x100; i++) { uint16_t v = cust[i]; fputc(v >> 8, o); fputc(v & 0xFF, o); } fclose(o);
}

static void load_file(const char *fn, unsigned at) {
    FILE *f = fopen(fn, "rb"); if (!f) { perror(fn); exit(1); }
    fread(ram + at, 1, RAM - at, f); fclose(f);
}

int main(int argc, char **argv) {
    if (argc < 5) { fprintf(stderr, "usage: scremu GAME.bin HELPER.bin LOADPIC.bin SCRIPT\n"); return 2; }
    load_file(argv[1], 0xE700); load_file(argv[2], 0xC0); load_file(argv[3], 0x78000);
    m68k_init(); m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    ram[0] = 0; ram[1] = 0; ram[2] = 0x3D; ram[3] = 0x80; ram[4] = 0; ram[5] = 0; ram[6] = 0xE7; ram[7] = 0;
    m68k_pulse_reset();
    m68k_set_reg(M68K_REG_SR, 0x2700); m68k_set_reg(M68K_REG_USP, 0x7FFFC); m68k_set_reg(M68K_REG_ISP, 0x3D80);
    m68k_set_reg(M68K_REG_SP, 0x3D80);
    m68k_set_reg(M68K_REG_D0, 0); m68k_set_reg(M68K_REG_A0, 0xE700); m68k_set_reg(M68K_REG_PC, 0xE700);
    memset(usage, 0, sizeof usage); memset(cover, 0, sizeof cover);
    ciaa.cra = ciab.cra = 0; ciaa.icr_mask = 0; ciab.icr_mask = 0;
    FILE *sc = fopen(argv[4], "r"); if (!sc) { perror(argv[4]); return 1; }
    char ln[512];
    while (fgets(ln, sizeof ln, sc)) {
        char cmd[32] = "", a1[256] = "", a2[256] = "", a3[16] = "";
        if (sscanf(ln, "%31s %255s %255s %15s", cmd, a1, a2, a3) < 1 || cmd[0] == '#') continue;
        if (!strcmp(cmd, "frames")) { long n = strtol(a1, 0, 0); for (long i = 0; i < n; i++) run_frame(); }
        else if (!strcmp(cmd, "joy")) { joy = 0; for (char *p = a1; *p; p++) joy |= *p == 'u' ? 1 : *p == 'd' ? 2 : *p == 'l' ? 4 : *p == 'r' ? 8 : *p == 'f' ? 16 : *p == '2' ? 32 : 0; }
        else if (!strcmp(cmd, "random")) {
            long n = strtol(a1, 0, 0); rng = strtoul(a2, 0, 0);
            for (long i = 0; i < n;) { joy = rnd() & 31; if ((joy & 3) == 3) joy &= ~2; if ((joy & 12) == 12) joy &= ~4;
                long hold = 8 + rnd() % 33; for (long k = 0; k < hold && i < n; k++, i++) run_frame(); }
            joy = 0;
        }
        else if (!strcmp(cmd, "key")) { int k = strtol(a1, 0, 16); key_queue[kq_n++] = k; key_queue[kq_n++] = k | 0x80; }
        else if (!strcmp(cmd, "poke")) {
            unsigned a = strtoul(a1, 0, 0), v = strtoul(a2, 0, 0);
            if (a3[0] == 'b') m68k_write_memory_8(a, v); else if (a3[0] == 'l') m68k_write_memory_32(a, v); else m68k_write_memory_16(a, v);
        }
        else if (!strcmp(cmd, "snap")) snapshot(a1);
        else if (!strcmp(cmd, "load")) {
            FILE *i = fopen(a1, "rb"); if (!i) { perror(a1); return 1; }
            unsigned a = strtoul(a2, 0, 0); fread(ram + a, 1, RAM - a, i); fclose(i);
        }
        else if (!strcmp(cmd, "record")) {                     /* record LO HI FILE N: N frames, LO-HI each frame */
            char b[4][300] = {{0}}; sscanf(ln, "%*s %299s %299s %299s %299s", b[0], b[1], b[2], b[3]);
            unsigned lo = strtoul(b[0], 0, 0), hi = strtoul(b[1], 0, 0); long n = strtol(b[3], 0, 0);
            FILE *o = fopen(b[2], "ab");
            for (long i = 0; i < n; i++) { run_frame(); fwrite(ram + lo, 1, hi - lo, o); }
            fclose(o); }
        else if (!strcmp(cmd, "usageclear")) memset(usage, 0, sizeof usage);
        else if (!strcmp(cmd, "usage")) { FILE *o = fopen(a1, "wb"); fwrite(usage, 1, sizeof usage, o); fclose(o); }
        else if (!strcmp(cmd, "calls")) { if (!calls) calls = calloc(RAM / 2, sizeof *calls); }
        else if (!strcmp(cmd, "callsdump")) {
            FILE *o = fopen(a1, "w");
            for (unsigned i = 0; i < RAM / 2; i++) if (calls[i]) fprintf(o, "%X %u\n", i * 2, calls[i]);
            fclose(o); }
        else if (!strcmp(cmd, "cover")) { FILE *o = fopen(a1, "wb"); fwrite(cover, 1, sizeof cover, o); fclose(o); }
        else if (!strcmp(cmd, "audio")) { audf = fopen(a1, "w"); }
        else if (!strcmp(cmd, "call") || !strcmp(cmd, "calli") || !strcmp(cmd, "play")) {
          long reps = !strcmp(cmd, "play") ? strtol(a2, 0, 0) : 1;
          for (long rep = 0; rep < reps; rep++) {
            unsigned sp = m68k_get_reg(NULL, M68K_REG_SP) - 4, sr = m68k_get_reg(NULL, M68K_REG_SR);
            m68k_write_memory_16(0x1F0, 0x60FE);                 /* bra * : where it returns to */
            m68k_write_memory_32(sp, 0x1F0); m68k_set_reg(M68K_REG_SP, sp);
            if (a2[0] && reps == 1 && strcmp(cmd, "play")) m68k_set_reg(M68K_REG_D0, strtoul(a2, 0, 0));
            m68k_set_reg(M68K_REG_SR, strcmp(cmd, "calli") ? 0x2700 : 0x2000); m68k_set_reg(M68K_REG_PC, strtoul(a1, 0, 0));
            until_pc = 0x1F0; until_hit = 0;
            for (long n = 0; n < 2000000 && !until_hit; n++) {
                if (strcmp(cmd, "calli")) { run_line(); if (line_no >= FRAME_LINES) { line_no = 0; frame++; } }
                else { run_frame(); n += FRAME_LINES - 1; }                 /* (calli: whole frames, interrupts and all) */
            }
            if (!until_hit) printf("%s $%s: did not return\n", cmd, a1);
            until_pc = 0xFFFFFFFF; until_hit = 0;
            m68k_set_reg(M68K_REG_SR, sr);
            if (reps > 1) { while (line_no < FRAME_LINES) run_line(); line_no = 0; frame++; }
          }
        }
        else if (!strcmp(cmd, "trace")) { trace_pc = strtoul(a1, 0, 0); }
        else if (!strcmp(cmd, "traceall")) { trace_all = atoi(a1); }   /* traceall 1: trace prints all the registers */
        else if (!strcmp(cmd, "readwatch")) { rwatch_lo = strtoul(a1, 0, 0); rwatch_hi = strtoul(a2, 0, 0); }
        else if (!strcmp(cmd, "dmacheck")) { dma_lo = strtoul(a1, 0, 0); dma_hi = strtoul(a2, 0, 0); }
        else if (!strcmp(cmd, "blittime")) { blit_timed = atoi(a1); }
        else if (!strcmp(cmd, "blitcheck")) { bh_on = atoi(a1); }
        else if (!strcmp(cmd, "profile")) {                  /* profile 1: start counting, 0: stop */
            if (atoi(a1)) { if (!prof) prof = calloc(RAM / 2, sizeof *prof); prof_pc = RAM; prof_cyc = cyc_now(); }
            else { free(prof); prof = 0; } }
        else if (!strcmp(cmd, "profdump")) {                 /* profdump FILE: "pc cycles" for each */
            FILE *o = fopen(a1, "w");
            if (o && prof) for (unsigned i = 0; i < RAM / 2; i++) if (prof[i]) fprintf(o, "%X %u\n", i * 2, prof[i]);
            if (o) fclose(o); }
        else if (!strcmp(cmd, "writelog")) { wlog_lo = strtoul(a1, 0, 0); wlog_hi = strtoul(a2, 0, 0); if (!wlogf) wlogf = logf ? logf : stdout; }
        else if (!strcmp(cmd, "pokecopy")) {                   /* pokecopy DST SRC ADD: byte DST = byte SRC + ADD */
            unsigned d = strtoul(a1, 0, 0), sr = strtoul(a2, 0, 0); long add = strtol(a3, 0, 0);
            if (d < RAM && sr < RAM) ram[d] = (uint8_t)(ram[sr] + add); }
        else if (!strcmp(cmd, "chipbus")) chipbus = atoi(a1);
        else if (!strcmp(cmd, "cpumult")) cpumult = atoi(a1) > 0 ? atoi(a1) : 1;   /* cpumult N: the CPU N times as fast */
        else if (!strcmp(cmd, "cpulost")) cpulost = atoi(a1);  /* cpulost N: N cycles a line lost to DMA */  /* chipbus 1: the chip bus's 4-cycle grid */
        else if (!strcmp(cmd, "inject")) {                     /* inject ADDR [D0]: the game made to call ADDR now (it returns where it was) */
            unsigned sp = m68k_get_reg(NULL, M68K_REG_A7) - 4; m68k_write_memory_32(sp, m68k_get_reg(NULL, M68K_REG_PC));
            m68k_set_reg(M68K_REG_A7, sp); if (a2[0]) m68k_set_reg(M68K_REG_D0, strtoul(a2, 0, 0));
            m68k_set_reg(M68K_REG_PC, strtoul(a1, 0, 0)); }
        else if (!strcmp(cmd, "disk")) {                       /* disk ADDR ADF|none: the byteloader at ADDR, done from ADF */
            disk_loader = strtoul(a1, 0, 0); free(disk_adf); disk_adf = 0;
            if (strcmp(a2, "none")) { FILE *f = fopen(a2, "rb"); if (!f) { perror(a2); exit(1); }
                fseek(f, 0, SEEK_END); disk_size = ftell(f); rewind(f); disk_adf = malloc(disk_size);
                if (fread(disk_adf, 1, disk_size, f) != (size_t)disk_size) exit(1); fclose(f); } }
        else if (!strcmp(cmd, "crashwatch")) crashwatch = 1;  /* stop when the PC leaves memory: the last 64 PCs */
        else if (!strcmp(cmd, "writecount")) {                /* writecount LO HI: count each CPU write to LO-HI */
            wc_lo = strtoul(a1, 0, 0); wc_hi = strtoul(a2, 0, 0); free(wc_addr); free(wc_pc);
            wc_addr = calloc((wc_hi - wc_lo) / 2 + 1, sizeof *wc_addr); wc_pc = calloc(RAM / 2, sizeof *wc_pc); }
        else if (!strcmp(cmd, "phasetrack")) {                /* phasetrack FLAG LO HI: (above) */
            pt_flag = strtoul(a1, 0, 0); pt_lo = strtoul(a2, 0, 0); pt_hi = strtoul(a3, 0, 0);
            free(pt_mark); pt_mark = calloc(pt_hi - pt_lo + 1, 1); if (!pt_hits) pt_hits = calloc(65536, sizeof *pt_hits); pt_n = 0; }
        else if (!strcmp(cmd, "phasedump")) {                 /* phasedump FILE: "writer reader addr pc count" */
            FILE *o = fopen(a1, "w");
            for (unsigned i = 0; o && i < pt_n; i++)
                fprintf(o, "%u %u %X %X %u\n", pt_hits[i].key >> 2 & 3, pt_hits[i].key & 3, pt_hits[i].key >> 4, pt_hits[i].pc, pt_hits[i].n);
            if (o) fclose(o); }
        else if (!strcmp(cmd, "writecountdump")) {            /* writecountdump PREFIX: PREFIX.addr (a u32 a word), PREFIX.pc ("pc count") */
            char fn[500]; snprintf(fn, sizeof fn, "%s.addr", a1); FILE *o = fopen(fn, "wb");
            if (o && wc_addr) { fwrite(wc_addr, sizeof *wc_addr, (wc_hi - wc_lo) / 2, o); fclose(o); }
            snprintf(fn, sizeof fn, "%s.pc", a1); o = fopen(fn, "w");
            for (unsigned i = 0; o && wc_pc && i < RAM / 2; i++) if (wc_pc[i]) fprintf(o, "%X %u\n", i * 2, wc_pc[i]);
            if (o) fclose(o); }
        else if (!strcmp(cmd, "callprof")) { callprof = atoi(a1); cp_n = 0; cp_pending = 0; if (callprof) memset(cp_edge, 0, sizeof cp_edge); }
        else if (!strcmp(cmd, "callprofdump")) {             /* callprofdump FILE: "caller callee calls cycles" */
            FILE *o = fopen(a1, "w");
            for (int i = 0; o && i < CP_EDGES; i++) if (cp_edge[i].n) fprintf(o, "%X %X %lu %lld\n", cp_edge[i].from, cp_edge[i].to, cp_edge[i].n, cp_edge[i].cyc);
            if (o) fclose(o); }
        else if (!strcmp(cmd, "watchpc")) { watch_pcs = 1; watch_lo = strtoul(a1, 0, 0); watch_hi = strtoul(a2, 0, 0); seen_n = 0; }
        else if (!strcmp(cmd, "watch")) { watch_pcs = 0; watch_lo = strtoul(a1, 0, 0); watch_hi = strtoul(a2, 0, 0); memset(watched, 0, sizeof watched); }
        else if (!strcmp(cmd, "log")) { logf = fopen(a1, "a"); setvbuf(logf, 0, _IOLBF, 0); }
        else if (!strcmp(cmd, "hits")) {
            hits_pc = strtoul(a1, 0, 0); long want = strtol(a2, 0, 0), n = a3[0] ? strtol(a3, 0, 0) : 100000, i;
            hits_left = want;
            for (i = 0; i < n && hits_left > 0; i++) run_frame();
            printf("hits $%X: %s at frame %lu (%ld passes)\n", hits_pc, hits_left ? "NOT reached" : "reached", frame, want - hits_left);
            hits_pc = 0xFFFFFFFF; hits_left = 0;
        }
        else if (!strcmp(cmd, "until")) {
            until_pc = strtoul(a1, 0, 0); until_hit = 0; long n = a2[0] ? strtol(a2, 0, 0) : 100000;
            for (long i = 0; i < n && !until_hit; i++) run_frame();
            printf("until $%X: %s at frame %lu\n", until_pc, until_hit ? "reached" : "NOT reached", frame);
            if (until_hit) line_over = 0;                      /* (its frame cut short there: the next from its start) */
            until_pc = 0xFFFFFFFF; until_hit = 0;
        }
        else fprintf(stderr, "unknown command: %s\n", cmd);
    }
    unsigned ncov = 0; for (unsigned i = 0; i < sizeof cover; i++) ncov += __builtin_popcount(cover[i]);
    printf("frames %lu, instructions at %u addresses, blits %d (%d line mode, %ld words), pc $%X sr $%04X\n", frame, ncov, blits, blit_line, blit_words,
           m68k_get_reg(NULL, M68K_REG_PC), m68k_get_reg(NULL, M68K_REG_SR));
    if (bh_on) printf("blit hazards %lu\n", bh_n);
    return 0;
}

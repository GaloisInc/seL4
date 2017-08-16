/*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 */

#include <config.h>
#include <arch/kernel/boot_sys.h>
#include <arch/model/statedata.h>
#include <machine/io.h>
#include <plat/machine/io.h>


#define VGA_STD 1 // comment out to have regular output

#ifdef VGA_STD

/*
enum vga_color {
  VGA_COLOR_BLACK = 0,
  VGA_COLOR_BLUE = 1,
  VGA_COLOR_GREEN = 2,
  VGA_COLOR_CYAN = 3,
  VGA_COLOR_RED = 4,
  VGA_COLOR_MAGENTA = 5,
  VGA_COLOR_BROWN = 6,
  VGA_COLOR_LIGHT_GREY = 7,
  VGA_COLOR_DARK_GREY = 8,
  VGA_COLOR_LIGHT_BLUE = 9,
  VGA_COLOR_LIGHT_GREEN = 10,
  VGA_COLOR_LIGHT_CYAN = 11,
  VGA_COLOR_LIGHT_RED = 12,
  VGA_COLOR_LIGHT_MAGENTA = 13,
  VGA_COLOR_LIGHT_BROWN = 14,
  VGA_COLOR_WHITE = 15,
};

static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg) {
  return fg | bg << 4;
}

static inline uint16_t vga_entry(unsigned char uc, uint8_t color) {
  return (uint16_t) uc | (uint16_t) color << 8;
}

const uint16_t VGA_WIDTH = 80;
const uint16_t VGA_HEIGHT = 24;

uint16_t terminal_row = 0;
uint16_t terminal_column = 0;
uint8_t terminal_color = 7;
uint16_t* terminal_buffer = (uint16_t*)0xB8000;
char vga_buf[4096];


static inline uint8_t printable(unsigned char c) {
    return (c >= 'A' && c <= 'Z') ||
           (c >= 'a' && c <= 'z') ||
           (c == ' ') ||
           (c >= '0' && c <= '9');
}

static inline void terminal_clear(void){
  for (uint16_t y = 0; y < VGA_HEIGHT; y++) {
    for (uint16_t x = 0; x < VGA_WIDTH; x++) {
      const uint16_t index = y * VGA_WIDTH + x;
      terminal_buffer[index] = vga_entry(' ', terminal_color);
    }
  }
}

static inline void terminal_setcolor(uint8_t color) {
  terminal_color = color;
}

static inline void terminal_putentryat(unsigned char c, uint8_t color, uint16_t x, uint16_t y) {
  const uint16_t index = y * VGA_WIDTH + x;
  terminal_buffer[index] = vga_entry(c, color);
}

static inline void terminal_shift_row(void) {
  terminal_row = VGA_HEIGHT-1;
  memset(vga_buf, 0, sizeof(vga_buf));
  memcpy(vga_buf, &terminal_buffer[VGA_WIDTH], 3936);
  memset(terminal_buffer, 0, 4096);
  memcpy(terminal_buffer, vga_buf, 3936);
}

static inline void terminal_newline(void) {
  if (++terminal_row == VGA_HEIGHT) {
    terminal_shift_row();
  }
  terminal_column = 0;
}

static inline void terminal_put_printable(unsigned char c) {
  terminal_putentryat(c, terminal_color, terminal_column, terminal_row);
    if (++terminal_column == VGA_WIDTH) {
      terminal_column = 0;
      if (++terminal_row == VGA_HEIGHT)
        terminal_shift_row();
    }
}

static inline void terminal_putchar(unsigned char c) {
  if (c == '\n') {
    terminal_newline();
  } else {
    if (printable(c)) {
      terminal_put_printable(c);
    }
  }
}
*/


/* Assumptions on the graphics mode and frame buffer location */
#define EGA_TEXT_FB_BASE 0xB8000
#define MODE_WIDTH 80
#define MODE_HEIGHT 25

/* How many lines to scroll by */
#define SCROLL_LINES 1

/* Hacky global state */
static volatile short *base_ptr = (short*)EGA_TEXT_FB_BASE;
static int cursor_x = 0;
static int cursor_y = 0;

static void
scroll(void)
{
    /* number of chars we are dropping when we do the scroll */
    int clear_chars = SCROLL_LINES * MODE_WIDTH;
    /* number of chars we need to move to perform the scroll. This all the lines
     * minus however many we drop */
    int scroll_chars = MODE_WIDTH * MODE_HEIGHT - clear_chars;
    /* copy the lines up. we skip the same number of characters that we will clear, and move the
     * rest to the top. cannot use memcpy as the regions almost certainly overlap */
    memcpy((void*)base_ptr, (void*)&base_ptr[clear_chars], scroll_chars * sizeof(*base_ptr));
    /* now zero out the bottom lines that we got rid of */
    memset((void*)&base_ptr[scroll_chars], 0, clear_chars * sizeof(*base_ptr));
    /* move the virtual cursor up */
    cursor_y -= SCROLL_LINES;
}

static int
text_ega_putchar(int c)
{
    /* emulate various control characters */
    if (c == '\t') {
        text_ega_putchar(' ');
        while (cursor_x % 4 != 0) {
            text_ega_putchar(' ');
        }
    } else if (c == '\n') {
        cursor_y ++;
        /* assume a \r with a \n */
        cursor_x = 0;
    } else if (c == '\r') {
        cursor_x = 0;
    } else {
        /* 7<<8 constructs a nice neutral grey color. */
        base_ptr[cursor_y * MODE_WIDTH + cursor_x] = ((char)c) | (7 << 8);
        cursor_x++;
    }
    if (cursor_x >= MODE_WIDTH) {
        cursor_x = 0;
        cursor_y++;
    }
    while (cursor_y >= MODE_HEIGHT) {
        scroll();
    }
    return 0;
}
#endif

#if defined(CONFIG_DEBUG_BUILD) || defined(CONFIG_PRINTING)
void
serial_init(uint16_t port)
{
    while (!(in8(port + 5) & 0x60)); /* wait until not busy */

    out8(port + 1, 0x00); /* disable generating interrupts */
    out8(port + 3, 0x80); /* line control register: command: set divisor */
    out8(port,     0x01); /* set low byte of divisor to 0x01 = 115200 baud */
    out8(port + 1, 0x00); /* set high byte of divisor to 0x00 */
    out8(port + 3, 0x03); /* line control register: set 8 bit, no parity, 1 stop bit */
    out8(port + 4, 0x0b); /* modem control register: set DTR/RTS/OUT2 */

    in8(port);     /* clear recevier port */
    in8(port + 5); /* clear line status port */
    in8(port + 6); /* clear modem status port */
}
#endif /* CONFIG_PRINTING || CONFIG_DEBUG_BUILD */

#ifdef CONFIG_PRINTING
void
putConsoleChar(unsigned char a)
{
    //terminal_putchar(a);
    text_ega_putchar((int) a);
    while (x86KSconsolePort && !(in8(x86KSconsolePort + 5) & 0x20));
    out8(x86KSconsolePort, a);
}
#endif /* CONFIG_PRINTING */

#ifdef CONFIG_DEBUG_BUILD
void
putDebugChar(unsigned char a)
{
    while (x86KSdebugPort && (in8(x86KSdebugPort + 5) & 0x20) == 0);
    out8(x86KSdebugPort, a);
}

unsigned char
getDebugChar(void)
{
    while ((in8(x86KSdebugPort + 5) & 1) == 0);
    return in8(x86KSdebugPort);
}
#endif /* CONFIG_DEBUG_BUILD */

/* FMD FT61E0A5 special function registers, for XC8.
 *
 * Addresses and bit names from the FT61E0Ax/FT64E0Ax datasheet V1.02
 * (docs/datasheets/). Only what this project uses. The core (INDF/FSR/STATUS/
 * BSR/WREG/PCLATH/INTCON) and the EEPROM/PROM controller sit where a PIC16F1's
 * do; the peripherals don't, so don't include <xc.h>: the PIC part we compile
 * for (tools/build.py) would bring its own, wrong, peripheral definitions.
 */
#ifndef FT61E0A5_H
#define FT61E0A5_H

#include <stdint.h>

#define SFR(name, addr) extern volatile uint8_t name __at(addr)

/* core */
SFR(STATUS, 0x003);
SFR(INTCON, 0x00B);
#define GIE  0x80
#define PEIE 0x40

/* ports */
SFR(PORTA, 0x00C);
SFR(PORTB, 0x00D);
SFR(PORTC, 0x00E);
SFR(TRISA, 0x08C);
SFR(TRISB, 0x08D);
SFR(TRISC, 0x08E);
SFR(LATA, 0x10C);
SFR(LATB, 0x10D);
SFR(LATC, 0x10E);
SFR(WPUA, 0x18C);
SFR(WPUB, 0x18D);
SFR(WPUC, 0x18E);
SFR(ANSELA, 0x197);

/* clock, watchdog */
SFR(WDTCON, 0x097);
SFR(OSCCON, 0x099);
SFR(PCKEN, 0x09A);
#define PCKEN_ADC   0x01
#define PCKEN_TIM1  0x02
#define PCKEN_TIM2  0x04
#define PCKEN_TIM4  0x08
#define PCKEN_UART1 0x20
SFR(MISC0, 0x19D);
SFR(TCKSRC, 0x31F);  /* bits 6:4 T2CKSRC, 2:0 T1CKSRC; 011 = 2 x HIRC (32 MHz) */

/* data EEPROM / program memory */
SFR(EEADRL, 0x191);
SFR(EEADRH, 0x192);
SFR(EEDATL, 0x193);
SFR(EEDATH, 0x194);
SFR(EECON1, 0x195);
SFR(EECON2, 0x196);
#define EE_RD    0x01
#define EE_WR    0x02
#define EE_WREN  0x04
#define EE_CFGS  0x40
#define EE_EEPGD 0x80

/* USART1 (Tuya link; TX PA6, RX PA7 at reset) */
SFR(UR1DATAL, 0x48C);
SFR(UR1IER, 0x48E);
#define UR1_RXNE 0x01
SFR(UR1LCR, 0x48F);
SFR(UR1MCR, 0x491);
SFR(UR1LSR, 0x492);
#define UR1_RXNEF 0x01
#define UR1_OVERF 0x02
#define UR1_FEF   0x08
#define UR1_TXEF  0x20
SFR(UR1DLL, 0x494);
SFR(UR1DLH, 0x495);
SFR(UR1TC, 0x49C);
SFR(ODCON0, 0x21F);

/* TIM1 (radar soft-UART transmit bit clock) */
SFR(TIM1CR1, 0x211);
SFR(TIM1IER, 0x215);
SFR(TIM1SR1, 0x216);
SFR(TIM1EGR, 0x218);
SFR(TIM1CNTRH, 0x28C);
SFR(TIM1CNTRL, 0x28D);
SFR(TIM1PSCRH, 0x28E);
SFR(TIM1PSCRL, 0x28F);
SFR(TIM1ARRH, 0x290);
SFR(TIM1ARRL, 0x291);

/* TIM2 (radar soft-UART receive bit clock) */
SFR(TIM2CR1, 0x30C);
SFR(TIM2IER, 0x30D);
SFR(TIM2SR1, 0x30E);
SFR(TIM2EGR, 0x310);
SFR(TIM2CNTRH, 0x316);
SFR(TIM2CNTRL, 0x317);
SFR(TIM2PSCR, 0x318);
SFR(TIM2ARRH, 0x319);
SFR(TIM2ARRL, 0x31A);

/* TIM1/TIM2/TIM4 CR1 bits */
#define TIM_CEN  0x01
#define TIM_UDIS 0x02
#define TIM_URS  0x04
#define TIM_OPM  0x08
#define TIM_ARPE 0x80
/* IER/SR/EGR bit 0: update interrupt enable / flag (write 1 to clear) / generate */
#define TIM_U    0x01

/* TIM4 (system tick) */
SFR(TIM4CR1, 0x111);
SFR(TIM4IER, 0x112);
SFR(TIM4SR, 0x113);
SFR(TIM4CNTR, 0x115);
SFR(TIM4PSCR, 0x116);
SFR(TIM4ARR, 0x117);

/* external pin interrupts */
SFR(EPIF0, 0x014);   /* flags, write 1 to clear */
SFR(EPIE0, 0x094);
SFR(EPS0, 0x118);
SFR(EPS1, 0x119);    /* bits 1:0 EINT4: 01 = PB4 */
SFR(ITYPE0, 0x11E);
SFR(ITYPE1, 0x11F);  /* bits 1:0 EINT4 edge: 01 rising, 10 falling */

/* ADC */
SFR(ADRESL, 0x09B);
SFR(ADRESH, 0x09C);
SFR(ADCON0, 0x09D);  /* bits 6:4 CHS, 1 GO/DONE, 0 ADON */
SFR(ADCON1, 0x09E);
SFR(ADCON2, 0x09F);
#define AD_GO 0x02

/* RAM the stock bootloader relies on while the application runs. Define both
 * once (BOOTLOADER_RAM in one .c file) so the compiler never allocates them:
 *   0x020 bit 0  set by the bootloader before it jumps to 0x600; its interrupt
 *                vector only passes interrupts on to 0x604 while it is set
 *   0x07E bit 0  set by that vector on every interrupt (common RAM) */
#define BOOTLOADER_RAM \
    volatile uint8_t boot_app_flag __at(0x020); \
    volatile uint8_t boot_isr_scratch __at(0x07E)

#define clrwdt() asm("clrwdt")
#define nop()    asm("nop")
#define reset()  asm("reset")

#endif

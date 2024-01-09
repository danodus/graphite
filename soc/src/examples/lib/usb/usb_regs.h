
// Header file for the USB11 controller.
// Note that the registers of this controller form a compatible superset
// of the controller at this location:
// https://github.com/ultraembedded/core_usb_host
//

#ifndef USB_REGS_H
#define USB_REGS_H

// USB11 register numbers
#define REG_CTRL        0x00
#define REG_STAT        0x01
#define REG_IRQ_A       0x02
#define REG_IRQ_S       0x03
#define REG_IRQ_E       0x04
#define REG_TXLEN       0x05
#define REG_TOKEN       0x06
#define REG_RXSTS       0x07
#define REG_DATA        0x08

// CTRL register bits
#define CTL_SOF_EN      0x0001
#define CTL_OPMODE0     0x0000
#define CTL_OPMODE1     0x0002
#define CTL_OPMODE2     0x0004
#define CTL_OPMODE3     0x0006
#define CTL_XCVRSEL0    0x0000
#define CTL_XCVRSEL1    0x0008
#define CTL_XCVRSEL2    0x0010
#define CTL_XCVRSEL3    0x0018
#define CTL_TERMSEL     0x0020
#define CTL_DP_PULLD    0x0040    
#define CTL_DN_PULLD    0x0080
#define CTL_TX_FLSH     0x0100

// STAT register bits
#define STAT_DP         0x0001
#define STAT_DN         0x0002
#define STAT_PHYERR     0x0004
#define STAT_DETECT     0x0008

// IRQ registers bits
#define IRQ_DETECT      0x0008
#define IRQ_ERR         0x0004
#define IRQ_DONE        0x0002
#define IRQ_FRAME       0x0001

// TOKEN register bits
#define TKN_START   0x80000000
#define TKN_IN      0x40000000
#define TKN_HS      0x20000000
#define TKN_DATA1   0x10000000

// RXSTS register bits
#define RX_QUEUED   0x80000000
#define RX_CRCERR   0x40000000
#define RX_TIMEOUT  0x20000000
#define SIE_IDLE    0x10000000

#endif

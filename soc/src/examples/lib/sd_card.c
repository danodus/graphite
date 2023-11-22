// Ref.: http://www.rjhcoding.com/avrc-sd-interface-1.php

#include "sd_card.h"

#include "io.h"

// SPI_STATUS write:
// bit 0: slave select 0, sd card
// bit 1: slave select 1, unused
// bit 2: fast
// bit 3: unused

// SPI_STATUS read:
// bit 0: ready

#define CS_BIT      0x1

#define SD_START_TOKEN  0xFE

#define SD_MAX_READ_ATTEMPTS    300000
#define SD_MAX_WRITE_ATTEMPTS   750000

#define CS_ENABLE(_ctx_)  { _ctx_->sd_cs = CS_BIT; MEM_WRITE(SPI_STATUS, _ctx_->sd_cs); }
#define CS_DISABLE(_ctx_) { _ctx_->sd_cs = 0; MEM_WRITE(SPI_STATUS, _ctx_->sd_cs); }

static void delay(unsigned int ms)
{
    unsigned int t = MEM_READ(TIMER) + ms;
    while (MEM_READ(TIMER) < t);
}

static uint8_t spi_transfer(sd_context_t *ctx, uint8_t mosi)
{
    char s[32];

    // wait until ready
    while (!(MEM_READ(SPI_STATUS) & 0x1));

    // send and receive (slow 8-bit)
    MEM_WRITE(SPI_DATA, (uint32_t)mosi);

    // wait until ready
    while (!(MEM_READ(SPI_STATUS) & 0x1));

    uint32_t miso = MEM_READ(SPI_DATA);

    return (uint8_t)miso;
}

static void sd_command(sd_context_t *ctx, uint8_t cmd, uint32_t arg, uint8_t crc)
{
    uint8_t m[5];
    m[0] = cmd | 0x40;
    m[1] = (uint8_t)(arg >> 24);
    m[2] = (uint8_t)(arg >> 16);
    m[3] = (uint8_t)(arg >> 8);
    m[4] = (uint8_t)(arg);

    for (int i = 0; i < 5; ++i)
        spi_transfer(ctx, m[i]);

    // transmit crc
    spi_transfer(ctx, crc | 0x1);
}

static uint8_t sd_read_res1(sd_context_t *ctx)
{
    uint8_t i = 0, res1 = 0xFF;

    // keep polling until actual data received
    while((res1 = spi_transfer(ctx, 0xFF)) == 0xFF)
    {
        i++;

        // if no data is received for 8 bytes, break
        if (i > 8)
            break;
    }

    return res1;
}

static void sd_read_res3_7(sd_context_t *ctx, uint8_t *res)
{
    // read response 1 in R7
    res[0] = sd_read_res1(ctx);

    // if error reading R1, return
    if (res[0] > 1) return;

    // read remaining bytes
    res[1] = spi_transfer(ctx, 0xFF);
    res[2] = spi_transfer(ctx, 0xFF);
    res[3] = spi_transfer(ctx, 0xFF);
    res[4] = spi_transfer(ctx, 0xFF);
}

static void sd_power_up_seq(sd_context_t *ctx)
{
    // make sure the card is deselected
    CS_DISABLE(ctx);

    // give sd card time to power up
    delay(1);

    // send 80 clock cycles to synchronize
    for (uint8_t i = 0; i < 10; ++i)
        spi_transfer(ctx, 0xFF);

    // deselect SD card
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);
}

static uint8_t sd_go_idle_state(sd_context_t *ctx)
{
    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send CMD0
    sd_command(ctx, 0, 0x00000000, 0x94);

    // read response
    uint8_t res1 = sd_read_res1(ctx);

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);

    return res1;
}

static void sd_send_if_cond(sd_context_t *ctx, uint8_t *res)
{
    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send cmd8
    sd_command(ctx, 8, 0x000001AA, 0x86);

    // read response
    sd_read_res3_7(ctx, res);

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);
}

static void sd_read_ocr(sd_context_t *ctx, uint8_t *res)
{
    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send cmd58
    sd_command(ctx, 58, 0x00000000, 0x00);

    // read response
    sd_read_res3_7(ctx, res);

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);
}

static uint8_t sd_send_app(sd_context_t *ctx)
{
    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send cmd55
    sd_command(ctx, 55, 0x00000000, 0x00);

    // read response
    uint8_t res1 = sd_read_res1(ctx);

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);

    return res1;
}

static uint8_t sd_send_op_cond(sd_context_t *ctx)
{
    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send cmd41
    sd_command(ctx, 41, 0x40000000, 0x00);

    // read response
    uint8_t res1 = sd_read_res1(ctx);

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);

    return res1;
}

bool sd_read_single_block(sd_context_t *ctx, uint32_t addr, uint8_t *buf)
{
    uint8_t token;
    uint8_t res1, read;
    unsigned int read_attempts;

    // set token to none
    token = 0xFF;

    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send CMD17
    sd_command(ctx, 17, addr, 0x00);

    // read R1
    res1 = sd_read_res1(ctx);

    // if response received from the card
    if (res1 != 0xFF) {
        // wait for a response token (timeout == 100ms)
        read_attempts = 0;
        while (++read_attempts != SD_MAX_READ_ATTEMPTS)
            if ((read = spi_transfer(ctx, 0xFF)) != 0xFF)
                break;

            // if response token is 0xFE
            if (read == 0xFE) {
                // read block
                for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i)
                    *buf++ = spi_transfer(ctx, 0xFF);

                // read 16-bit CRC
                spi_transfer(ctx, 0xFF);
                spi_transfer(ctx, 0xFF);
            }

            // set token to card response
            token = read;
    }

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);

    return res1 == 0x00 && token == 0xFE;
}

bool sd_write_single_block(sd_context_t *ctx, uint32_t addr, const uint8_t *buf)
{
    uint8_t token;
    uint8_t res1, write;
    unsigned int write_attempts;

    // set token to none
    token = 0xFF;

    // assert chip select
    spi_transfer(ctx, 0xFF);
    CS_ENABLE(ctx);
    spi_transfer(ctx, 0xFF);

    // send CMD24
    sd_command(ctx, 24, addr, 0x00);

    // read R1
    res1 = sd_read_res1(ctx);

    if (res1 == 0x00) {
        // send start token
        spi_transfer(ctx, SD_START_TOKEN);

        // write buffer to card
        for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i)
            spi_transfer(ctx, buf[i]);
    }

    // if response received from the card
    if (res1 != 0xFF) {
        // wait for a response token (timeout == 250ms)
        write_attempts = 0;
        while (++write_attempts != SD_MAX_WRITE_ATTEMPTS)
            if ((write = spi_transfer(ctx, 0xFF)) != 0xFF) {
                token = 0xFF;
                break;
            }

        // if data accepted
        if ((write & 0x1F) == 0x05) {
            // set token to data accepted
            token = 0x05;

            // wait for write to finish (timeout == 250ms)
            write_attempts = 0;
            while (spi_transfer(ctx, 0xFF) == 0x00)
                if (++write_attempts == SD_MAX_WRITE_ATTEMPTS) {
                    token = 0x00;
                    break;
                }
        }
    }

    // deassert chip select
    spi_transfer(ctx, 0xFF);
    CS_DISABLE(ctx);
    spi_transfer(ctx, 0xFF);

    return res1 == 0x00 && token == 0x05;    
}

static bool sd_init_internal(sd_context_t *ctx)
{
    ctx->sd_cs = 0;

    uint8_t res[5];

    // start the power up sequence
    sd_power_up_seq(ctx);

    // command card to go idle (CMD0)
    res[0] = sd_go_idle_state(ctx);

    // send if conditions (CMD8)
    sd_send_if_cond(ctx, res);

    // read operation conditions register (CMD58)
    sd_read_ocr(ctx, res);

    // send operating condition (ACMD41) until no longer in idle
    for (int i = 0; i < 100; ++i) {
        // send app (CMD55)
        sd_send_app(ctx);
        res[0] = sd_send_op_cond(ctx);
        if (res[0] == 0x00 || res[0] != 0x01)
            break;
    }

    return res[0] == 0x00;
}

bool sd_init(sd_context_t *ctx)
{
    int retries = 0;
    while (retries++ < 3) {
        if (sd_init_internal(ctx))
            return true;
        delay(100);
    }
    return false;
}
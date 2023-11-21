#ifndef SD_CARD_H
#define SD_CARD_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#define SD_BLOCK_LEN  512

typedef struct {
    uint32_t sd_cs;
} sd_context_t;

bool sd_init(sd_context_t *ctx);
bool sd_read_single_block(sd_context_t *ctx, uint32_t addr, uint8_t *buf);
bool sd_write_single_block(sd_context_t *ctx, uint32_t addr, const uint8_t *buf);

#endif // SD_CARD_H

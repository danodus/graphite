// Ref.: http://www.rjhcoding.com/avrc-sd-interface-1.php

#include <stdlib.h>
#include <sd_card.h>
#include <io.h>

int main(void) {
    print("SD card test\r\n");

    sd_context_t sd_ctx;

    if (!sd_init(&sd_ctx)) {
        print("SD card initialization failed.\r\n");
        return EXIT_FAILURE;
    }

    print("SD card initialization successful.\r\n");

    return EXIT_SUCCESS;
}
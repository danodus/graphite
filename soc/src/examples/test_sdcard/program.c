// Ref.: http://www.rjhcoding.com/avrc-sd-interface-1.php

#include <stdlib.h>
#include <sd_card.h>
#include <io.h>
#include <fat_filelib.h>
#include <fat_misc.h>

sd_context_t sd_ctx;

int read_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_read_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

int write_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_write_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

static void print_val(int v) {
    char s[32];
    uitoa(v, s, 16);
    print(s);
}

void list_directory(const char *path)
{
    FL_DIR dirstat;

    printf(("\r\nDirectory %s\r\n", path));

    if (fl_opendir(path, &dirstat))
    {
        struct fs_dir_ent dirent;

        while (fl_readdir(&dirstat, &dirent) == 0)
        {
            int d,m,y,h,mn,s;
            fatfs_convert_from_fat_time(dirent.write_time, &h,&m,&s);
            fatfs_convert_from_fat_date(dirent.write_date, &d,&mn,&y);
            printf("%02d/%02d/%04d  %02d:%02d      ", d,mn,y,h,m);

            if (dirent.is_dir)
            {
                printf("%s <DIR>\r\n", dirent.filename);
            }
            else
            {
                printf("%s [%d bytes]\r\n", dirent.filename, dirent.size);
            }
        }

        fl_closedir(&dirstat);
    }
}

int main(void) {
    printf("SD card test\r\n");

    if (!sd_init(&sd_ctx)) {
        printf("SD card initialization failed.\r\n");
        return EXIT_FAILURE;
    }

    printf("SD card initialization successful.\r\n");

    fl_init();

    // Attach media access functions to library
    if (fl_attach_media(read_sector, write_sector) != FAT_INIT_OK)
    {
        printf("Failed to init file system\r\n");
        fl_shutdown();
        return EXIT_FAILURE;
    }

    list_directory("/");

    printf("Success!\r\n");

    fl_shutdown();

    return EXIT_SUCCESS;
}
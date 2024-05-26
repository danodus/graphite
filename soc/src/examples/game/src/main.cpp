#include "SDL2/SDL.h"

#include "Game.h"
#include <stdio.h>

int main(void)
{
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        fprintf(stderr, "Error initializing SDL.\r\n");
        return 1;
    }

    printf("Start game...\r\n");
    Game game;
    game.run();
    printf("Done.\r\n");
    return 0;
}
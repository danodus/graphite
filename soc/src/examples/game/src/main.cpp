#include "SDL2/SDL.h"

#include "GameEngine/Game.h"
#include <stdio.h>

#include "GameEngine/GL.h"

int main(void)
{
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        fprintf(stderr, "Error initializing SDL.\n");
        return 1;
    }

    printf("Start...\n");

    try {
        Game game;
        game.run();
    } catch (const std::exception& e) {
        printf("Error: %s\n", e.what());
        return 1;
    }
    printf("Done.\n");
 
    return 0;
}
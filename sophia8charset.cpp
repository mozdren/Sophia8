// Example program:
// Using SDL2 to create an application window

#include <cstdio>

#include "SDL.h"
#include "definitions.h"

class char_information
{
public:
    bool character[8][8] = {false};
    int addresses[8] = {0};

    void draw_char_small(SDL_Renderer *renderer, const int xs, const int ys)
    {
        for (auto y = 0; y < 8; y++)
        {
            for (auto x = 0; x < 8; x++)
            {
                if (character[y][x])
                {
                    SDL_SetRenderDrawColor(renderer, 255, 255, 255, SDL_ALPHA_OPAQUE);
                }
                else
                {
                    SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
                }
                SDL_RenderDrawPoint(renderer, xs + x, ys + y);
            }
        }
    }

    void draw_char_big(SDL_Renderer *renderer, const int xs, const int ys)
    {
        for (auto y = 0; y < 8; y++)
        {
            for (auto x = 0; x < 8; x++)
            {
                SDL_Rect rect{ xs + x * 32, ys + y * 32, 32, 32 };

                if (character[y][x])
                {
                    SDL_SetRenderDrawColor(renderer, 255, 255, 255, SDL_ALPHA_OPAQUE);
                    SDL_RenderFillRect(renderer, &rect);
                }
                
                SDL_SetRenderDrawColor(renderer, 127, 127, 127, SDL_ALPHA_OPAQUE);
                SDL_RenderDrawRect(renderer, &rect);
            }
        }
    }
};

class characters_information
{
public:
    char_information characters[256];

    characters_information()
    {
        auto address = CHAR_MEM_ADDRESS;
        for (auto &ch: characters)
        {
            for (auto &cur_address: ch.addresses)
            {
                cur_address = address;
                address += 8;
            }

            for (auto &char_line: ch.character)
            {
                for (auto &char_bit: char_line)
                {
                    char_bit = false;
                }
            }
        }
    }
};

void draw_field(SDL_Renderer *renderer)
{
    SDL_Rect rect;
    rect.x = 10;
    rect.y = 10;
    rect.w = 10;
    rect.h = 10;
    SDL_SetRenderDrawColor(renderer, 127, 127, 127, 255);
    SDL_RenderDrawRect(renderer, &rect);
}

int main(int argc, char* argv[]) {
    SDL_Init(SDL_INIT_VIDEO);              // Initialize SDL2

    // Create an application window with the following settings:
    const auto window = SDL_CreateWindow(
        "CharSet Editor for Sophia8", // window title
        SDL_WINDOWPOS_UNDEFINED, // initial x position
        SDL_WINDOWPOS_UNDEFINED, // initial y position
        640, // width, in pixels
        480, // height, in pixels
        SDL_WINDOW_OPENGL // flags - see below
    );

    const auto renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    // Check that the window was successfully created
    if (window == nullptr) {
        // In the case that the window could not be made...
        printf("Could not create window: %s\n", SDL_GetError());
        return 1;
    }

    // test A
    char_information ch_info;
    ch_info.character[0][3] = true;
    ch_info.character[1][2] = true;
    ch_info.character[1][4] = true;
    ch_info.character[2][1] = true;
    ch_info.character[2][5] = true;
    ch_info.character[3][0] = true;
    ch_info.character[3][6] = true;
    ch_info.character[4][0] = true;
    ch_info.character[4][1] = true;
    ch_info.character[4][2] = true;
    ch_info.character[4][3] = true;
    ch_info.character[4][4] = true;
    ch_info.character[4][5] = true;
    ch_info.character[4][6] = true;
    ch_info.character[5][0] = true;
    ch_info.character[5][6] = true;
    ch_info.character[6][0] = true;
    ch_info.character[6][6] = true;

    while (true) {
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
        }

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        //draw_field(renderer);
        
        ch_info.draw_char_small(renderer, 300, 10);
        ch_info.draw_char_big(renderer, 10, 10);
        
        SDL_RenderPresent(renderer);
    }

    // Close and destroy the window
    SDL_DestroyWindow(window);

    // Clean up
    SDL_Quit();
    return 0;
}
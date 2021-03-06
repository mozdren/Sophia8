// Example program:
// Using SDL2 to create an application window

#include <cstdio>

#include "SDL.h"
#include "definitions.h"
#include <cstdlib>
#include <string>
#include <fstream>

class char_information
{
public:
    bool character[8][8] = {{false}};
    int addresses[8] = {0};

    void draw_char_small(SDL_Renderer *renderer, const int xs, const int ys, const bool selected = false)
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

        SDL_Rect rect = { xs - 1,ys - 1, 10, 10 };
        if (selected) SDL_SetRenderDrawColor(renderer, 255, 0, 0, SDL_ALPHA_OPAQUE);
        else SDL_SetRenderDrawColor(renderer, 64, 64, 64, SDL_ALPHA_OPAQUE);
        SDL_RenderDrawRect(renderer, &rect);
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
        uint16_t address = CHAR_MEM_ADDRESS;
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

    void draw_characters(SDL_Renderer *renderer, const int sx, const int sy, const int selected = -1)
    {
        auto sxc = sx;
        auto syc = sy;
        auto index = 0;

        for (auto &ch : characters)
        {
            ch.draw_char_small(renderer, sxc, syc, index == selected);
            sxc += 11;
            if (sxc - sx > 250) {
                syc += 11;
                sxc = sx;
            }
            index++;
        }
    }

    void save(const std::string& filename)
    {
        std::ofstream file;

        file.open(filename);

        for (auto &ch : characters)
        {
            for (auto &ch_line: ch.character)
            {
                for (auto &ch_bit: ch_line)
                {
                    file << (ch_bit ? 1 : 0) << " ";
                }
                file << std::endl;
            }
            file << std::endl;
        }

        file.close();
    }

    void save_asm(const std::string& filename)
    {
        std::ofstream file;

        file.open(filename);

        for (auto &ch : characters)
        {
            auto li = 0;
            for (auto &ch_line : ch.character)
            {
                file << "0x" << std::hex << std::uppercase 
                     << ch.addresses[li] << std::dec 
                     << std::nouppercase << ": db 0b";
                for (auto &ch_bit : ch_line)
                {
                    file << (ch_bit ? 1 : 0);
                }
                file << std::endl;
                li++;
            }
            file << std::endl;
        }

        file.close();
    }

    void load(const std::string& filename)
    {
        std::ifstream file;

        file.open(filename);

        for (auto& character : characters)
        {
            for (auto& ch_line : character.character)
            {
                for (auto& ch_bit : ch_line)
                {
                    char read_char;
                    file >> read_char;
                    ch_bit = read_char == '1';
                }
            }
        }

        file.close();
    }
};

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

    characters_information characters_information_table;
    characters_information_table.load(R"(C:\developement\Sophia8\chars.dat)");
    auto current_character = 0;

    while (true) {
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
            if (e.type == SDL_KEYDOWN)
            {
                if (e.key.keysym.sym == SDLK_ESCAPE)
                {
                    break;
                }
                if (e.key.keysym.sym == SDLK_RIGHT)
                {
                    current_character++;
                    if (current_character > 255) current_character = 0;
                }
                if (e.key.keysym.sym == SDLK_LEFT)
                {
                    current_character--;
                    if (current_character < 0) current_character = 255;
                }
                if (e.key.keysym.sym == SDLK_s)
                {
                    characters_information_table.save(R"(C:\developement\Sophia8\chars.dat)");
                    characters_information_table.save_asm(R"(C:\developement\Sophia8\chars.asm)");
                }
            }
            if (e.type == SDL_MOUSEBUTTONDOWN)
            {
                int x, y;
                SDL_GetMouseState(&x, &y);
                auto& cur_bit = characters_information_table.characters[current_character].character[(y - 10) / 32][(x - 10) / 32];
                cur_bit = !cur_bit;
            }
        }

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        
        characters_information_table.characters[current_character].draw_char_small(renderer, 300, 10);
        characters_information_table.characters[current_character].draw_char_big(renderer, 10, 10);
        characters_information_table.draw_characters(renderer, 10, 300, current_character);
        
        SDL_RenderPresent(renderer);
    }

    // Close and destroy the window
    SDL_DestroyWindow(window);

    // Clean up
    SDL_Quit();
    return 0;
}
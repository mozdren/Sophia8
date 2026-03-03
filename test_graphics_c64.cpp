#include "graphics_c64.h"

#include <cassert>
#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>

static std::vector<uint8_t> read_file(const char* path)
{
    FILE* f = std::fopen(path, "rb");
    assert(f && "failed to open file");
    std::fseek(f, 0, SEEK_END);
    long sz = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    assert(sz > 0);
    std::vector<uint8_t> buf;
    buf.resize(static_cast<size_t>(sz));
    std::fread(buf.data(), 1, buf.size(), f);
    std::fclose(f);
    return buf;
}

static size_t find_header_end(const std::vector<uint8_t>& data)
{
    // P6 header ends after the third newline ("P6\n", "W H\n", "255\n")
    int nl = 0;
    for (size_t i = 0; i < data.size(); i++)
    {
        if (data[i] == '\n')
        {
            nl++;
            if (nl == 3) return i + 1;
        }
    }
    return 0;
}

int main()
{
    // Build a 9000-byte gfx buffer.
    std::vector<uint8_t> gfx(GraphicsC64::kTotalBytes, 0);

    // Cell (0,0): diagonal bits, FG=white (1), BG=black (0).
    // bitmap row i: bit at col i set => MSB >> i
    for (int i = 0; i < 8; i++)
    {
        gfx[i] = static_cast<uint8_t>(0x80u >> i);
    }
    gfx[8] = static_cast<uint8_t>((1u << 4) | 0u);

    const char* out = "test_frame.ppm";
    graphics_c64_draw_ppm(gfx.data(), out);

    auto ppm = read_file(out);
    const size_t header_end = find_header_end(ppm);
    assert(header_end > 0);

    const size_t pixel0 = header_end + 0; // (0,0)
    // (0,0) is ON => white
    assert(ppm[pixel0 + 0] == 0xFF);
    assert(ppm[pixel0 + 1] == 0xFF);
    assert(ppm[pixel0 + 2] == 0xFF);

    // (1,0) is OFF => black
    const size_t pixel10 = header_end + 3; // (1,0)
    assert(ppm[pixel10 + 0] == 0x00);
    assert(ppm[pixel10 + 1] == 0x00);
    assert(ppm[pixel10 + 2] == 0x00);

    // (1,1) diagonal ON => white
    const size_t pixel11 = header_end + static_cast<size_t>((1 * GraphicsC64::kWidth + 1) * 3);
    assert(ppm[pixel11 + 0] == 0xFF);
    assert(ppm[pixel11 + 1] == 0xFF);
    assert(ppm[pixel11 + 2] == 0xFF);

    std::printf("test_graphics_c64: OK\n");
    return 0;
}

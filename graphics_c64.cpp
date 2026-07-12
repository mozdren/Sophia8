#include "graphics_c64.h"

#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <vector>

struct RGB { uint8_t r, g, b; };

// Commonly used C64 palette approximations (16 colors).
// These are not meant to be perfect, but are stable and deterministic.
static constexpr RGB kC64Palette[16] = {
    { 0x00, 0x00, 0x00 }, // 0 black
    { 0xFF, 0xFF, 0xFF }, // 1 white
    { 0x88, 0x00, 0x00 }, // 2 red
    { 0xAA, 0xFF, 0xEE }, // 3 cyan
    { 0xCC, 0x44, 0xCC }, // 4 purple
    { 0x00, 0xCC, 0x55 }, // 5 green
    { 0x00, 0x00, 0xAA }, // 6 blue
    { 0xEE, 0xEE, 0x77 }, // 7 yellow
    { 0xDD, 0x88, 0x55 }, // 8 orange
    { 0x66, 0x44, 0x00 }, // 9 brown
    { 0xFF, 0x77, 0x77 }, // A light red
    { 0x33, 0x33, 0x33 }, // B dark grey
    { 0x77, 0x77, 0x77 }, // C grey
    { 0xAA, 0xFF, 0x66 }, // D light green
    { 0x00, 0x88, 0xFF }, // E light blue
    { 0xBB, 0xBB, 0xBB }, // F light grey
};

static inline void set_px(uint8_t* rgb_out, const int x, const int y, const RGB px)
{
    const size_t idx = static_cast<size_t>((y * GraphicsC64::kWidth + x) * 3);
    rgb_out[idx + 0] = px.r;
    rgb_out[idx + 1] = px.g;
    rgb_out[idx + 2] = px.b;
}

static inline void append_u32_be(std::vector<uint8_t>& out, const uint32_t value)
{
    out.push_back(static_cast<uint8_t>((value >> 24) & 0xFF));
    out.push_back(static_cast<uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<uint8_t>(value & 0xFF));
}

static uint32_t crc32_update(uint32_t crc, const uint8_t* data, const size_t size)
{
    crc = ~crc;
    for (size_t i = 0; i < size; ++i)
    {
        crc ^= data[i];
        for (int bit = 0; bit < 8; ++bit)
        {
            const uint32_t mask = static_cast<uint32_t>(-(static_cast<int32_t>(crc) & 1));
            crc = (crc >> 1) ^ (0xEDB88320u & mask);
        }
    }
    return ~crc;
}

static uint32_t adler32_sum(const uint8_t* data, const size_t size)
{
    constexpr uint32_t mod = 65521u;
    uint32_t s1 = 1u;
    uint32_t s2 = 0u;
    for (size_t i = 0; i < size; ++i)
    {
        s1 = (s1 + data[i]) % mod;
        s2 = (s2 + s1) % mod;
    }
    return (s2 << 16) | s1;
}

static void append_chunk(std::vector<uint8_t>& out,
                         const char name[4],
                         const uint8_t* data,
                         const size_t size)
{
    append_u32_be(out, static_cast<uint32_t>(size));
    const size_t start = out.size();
    out.push_back(static_cast<uint8_t>(name[0]));
    out.push_back(static_cast<uint8_t>(name[1]));
    out.push_back(static_cast<uint8_t>(name[2]));
    out.push_back(static_cast<uint8_t>(name[3]));
    if (size > 0 && data)
    {
        out.insert(out.end(), data, data + size);
    }
    const uint32_t crc = crc32_update(0, &out[start], 4 + size);
    append_u32_be(out, crc);
}

static std::vector<uint8_t> build_png_bytes(const std::vector<uint8_t>& rgb)
{
    std::vector<uint8_t> png;
    const uint8_t sig[8] = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
    png.insert(png.end(), sig, sig + 8);

    uint8_t ihdr[13] = {};
    ihdr[0] = static_cast<uint8_t>((GraphicsC64::kWidth >> 24) & 0xFF);
    ihdr[1] = static_cast<uint8_t>((GraphicsC64::kWidth >> 16) & 0xFF);
    ihdr[2] = static_cast<uint8_t>((GraphicsC64::kWidth >> 8) & 0xFF);
    ihdr[3] = static_cast<uint8_t>(GraphicsC64::kWidth & 0xFF);
    ihdr[4] = static_cast<uint8_t>((GraphicsC64::kHeight >> 24) & 0xFF);
    ihdr[5] = static_cast<uint8_t>((GraphicsC64::kHeight >> 16) & 0xFF);
    ihdr[6] = static_cast<uint8_t>((GraphicsC64::kHeight >> 8) & 0xFF);
    ihdr[7] = static_cast<uint8_t>(GraphicsC64::kHeight & 0xFF);
    ihdr[8] = 8;
    ihdr[9] = 2;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    append_chunk(png, "IHDR", ihdr, sizeof(ihdr));

    std::vector<uint8_t> raw;
    raw.reserve(static_cast<size_t>(GraphicsC64::kHeight) * (1 + static_cast<size_t>(GraphicsC64::kWidth) * 3));
    const size_t row_bytes = static_cast<size_t>(GraphicsC64::kWidth) * 3;
    for (int y = 0; y < GraphicsC64::kHeight; ++y)
    {
        raw.push_back(0x00);
        const size_t src_off = static_cast<size_t>(y) * row_bytes;
        raw.insert(raw.end(),
                   rgb.begin() + static_cast<std::ptrdiff_t>(src_off),
                   rgb.begin() + static_cast<std::ptrdiff_t>(src_off + row_bytes));
    }

    std::vector<uint8_t> zlib;
    zlib.push_back(0x78);
    zlib.push_back(0x01);

    size_t offset = 0;
    while (offset < raw.size())
    {
        const size_t chunk = std::min<size_t>(65535, raw.size() - offset);
        const bool final = (offset + chunk) >= raw.size();
        zlib.push_back(static_cast<uint8_t>(final ? 0x01 : 0x00));
        zlib.push_back(static_cast<uint8_t>(chunk & 0xFF));
        zlib.push_back(static_cast<uint8_t>((chunk >> 8) & 0xFF));
        const uint16_t nlen = static_cast<uint16_t>(~static_cast<uint16_t>(chunk));
        zlib.push_back(static_cast<uint8_t>(nlen & 0xFF));
        zlib.push_back(static_cast<uint8_t>((nlen >> 8) & 0xFF));
        zlib.insert(zlib.end(),
                    raw.begin() + static_cast<std::ptrdiff_t>(offset),
                    raw.begin() + static_cast<std::ptrdiff_t>(offset + chunk));
        offset += chunk;
    }

    append_u32_be(zlib, adler32_sum(raw.data(), raw.size()));
    append_chunk(png, "IDAT", zlib.data(), zlib.size());
    append_chunk(png, "IEND", nullptr, 0);
    return png;
}

static bool write_bytes_file(const uint8_t* data, const size_t size, const char* out_path)
{
    if (!data || !out_path) return false;

    FILE* f = std::fopen(out_path, "wb");
    if (!f) return false;

    const size_t written = std::fwrite(data, 1, size, f);
    std::fclose(f);
    return written == size;
}

static void render_text_into_framebuffer(uint8_t* gfx_frame,
                                         const uint8_t* text_mem,
                                         const uint8_t* charset_mem,
                                         const uint8_t* text_state)
{
    if (!gfx_frame || !text_mem || !charset_mem || !text_state) return;

    const uint8_t text_enabled = text_state[0];
    if (!text_enabled) return;

    const uint8_t cursor_x = text_state[1];
    const uint8_t cursor_y = text_state[2];
    const bool cursor_visible = text_state[3] != 0;

    for (int cy = 0; cy < GraphicsC64::kTextRows; cy++)
    {
        for (int cx = 0; cx < GraphicsC64::kTextCols; cx++)
        {
            const uint8_t ch = text_mem[static_cast<size_t>(cy * GraphicsC64::kTextCols + cx)];
            const size_t cell_index = static_cast<size_t>(cy * GraphicsC64::kCellsW + cx);
            uint8_t* cell = gfx_frame + cell_index * GraphicsC64::kBytesPerCell;
            const bool is_cursor = cursor_visible &&
                                   cx == static_cast<int>(cursor_x) &&
                                   cy == static_cast<int>(cursor_y);

            if (!is_cursor && (ch < GraphicsC64::kTextAsciiFirst || ch >= 0x7F))
            {
                continue;
            }

            // Text is painted into the framebuffer copy using a visible
            // foreground color while preserving the existing background nibble.
            cell[8] = static_cast<uint8_t>((cell[8] & 0x0F) | 0x10);

            const uint8_t* glyph = nullptr;
            if (ch >= GraphicsC64::kTextAsciiFirst && ch < 0x7F)
            {
                glyph = charset_mem + static_cast<size_t>((ch - GraphicsC64::kTextAsciiFirst) * GraphicsC64::kTextCellH);
            }
            for (int row = 0; row < GraphicsC64::kTextCellH; row++)
            {
                uint8_t bits = is_cursor ? 0xFF : 0x00;
                if (glyph) bits = glyph[row];
                if (is_cursor) bits = 0xFF;
                for (int col = 0; col < GraphicsC64::kTextCellW; col++)
                {
                    if ((bits & (0x80u >> col)) == 0) continue;
                    cell[row] |= static_cast<uint8_t>(0x80u >> col);
                }
            }
        }
    }
}

void graphics_c64_render_rgb(const uint8_t* gfx_mem,
                             uint8_t* rgb_out,
                             const size_t rgb_out_size,
                             const uint8_t* text_mem,
                             const uint8_t* charset_mem,
                             const uint8_t* text_state)
{
    const size_t need = static_cast<size_t>(GraphicsC64::kWidth * GraphicsC64::kHeight * 3);
    if (!gfx_mem || !rgb_out || rgb_out_size < need) return;

    std::vector<uint8_t> frame;
    frame.assign(gfx_mem, gfx_mem + GraphicsC64::kTotalBytes);
    render_text_into_framebuffer(frame.data(), text_mem, charset_mem, text_state);

    const uint8_t* p = frame.data();
    for (int cy = 0; cy < GraphicsC64::kCellsH; cy++)
    {
        for (int cx = 0; cx < GraphicsC64::kCellsW; cx++)
        {
            const uint8_t* bitmap = p;
            const uint8_t color = p[8];
            p += GraphicsC64::kBytesPerCell;

            const uint8_t fg = (color >> 4) & 0x0F;
            const uint8_t bg = (color >> 0) & 0x0F;
            const RGB fg_rgb = kC64Palette[fg];
            const RGB bg_rgb = kC64Palette[bg];

            for (int row = 0; row < 8; row++)
            {
                const uint8_t bits = bitmap[row];
                const int y = cy * 8 + row;
                for (int col = 0; col < 8; col++)
                {
                    const bool on = (bits & (0x80u >> col)) != 0;
                    const int x = cx * 8 + col;
                    const RGB px = on ? fg_rgb : bg_rgb;
                    set_px(rgb_out, x, y, px);
                }
            }
        }
    }
}

static void draw_image_file(const uint8_t* gfx_mem,
                            const char* out_path,
                            const uint8_t* text_mem,
                            const uint8_t* charset_mem,
                            const uint8_t* text_state,
                            const bool png_mode)
{
    if (!gfx_mem || !out_path) return;

    std::vector<uint8_t> rgb(static_cast<size_t>(GraphicsC64::kWidth * GraphicsC64::kHeight * 3));
    graphics_c64_render_rgb(gfx_mem, rgb.data(), rgb.size(), text_mem, charset_mem, text_state);

    if (png_mode)
    {
        const std::vector<uint8_t> png = build_png_bytes(rgb);
        (void)write_bytes_file(png.data(), png.size(), out_path);
    }
    else
    {
        FILE* f = std::fopen(out_path, "wb");
        if (!f) return;
        std::fprintf(f, "P6\n%d %d\n255\n", GraphicsC64::kWidth, GraphicsC64::kHeight);
        (void)std::fwrite(rgb.data(), 1, rgb.size(), f);
        std::fclose(f);
    }
}

void graphics_c64_draw_ppm(const uint8_t* gfx_mem,
                           const char* out_path,
                           const uint8_t* text_mem,
                           const uint8_t* charset_mem,
                           const uint8_t* text_state)
{
    draw_image_file(gfx_mem, out_path, text_mem, charset_mem, text_state, false);
}

void graphics_c64_draw_png(const uint8_t* gfx_mem,
                           const char* out_path,
                           const uint8_t* text_mem,
                           const uint8_t* charset_mem,
                           const uint8_t* text_state)
{
    draw_image_file(gfx_mem, out_path, text_mem, charset_mem, text_state, true);
}

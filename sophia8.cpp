/*****************************************************************************/
/*                                                                           */
/* Project: Sophia8 - an 8 bit virtual machine                               */
/* Author:  Karel Mozdren                                                    */
/* File:    sophia8.cpp                                                      */
/* Date:    06.04.2017                                                       */
/*                                                                           */
/* Description:                                                              */
/*                                                                           */
/* This is a simple virtual machine which simulates 8 bit computer with      */
/* 16 bit addressing, and random access memory (not a plain stack machine).  */
/* The machine has 8 general purpose registers and a stack which starts      */
/* pointing at the end of memory and goes down as being pushed upon.         */
/*                                                                           */
/*****************************************************************************/

/* INCLUDES ******************************************************************/

//#define DEBUG_COMMAND

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdlib>

#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <algorithm>

#include "definitions.h"

#ifndef LOADR
    #define LOADR 0x1C
#endif

/* Windows real-time console I/O */
#ifdef _WIN32
    #include <conio.h>
#else
    /* POSIX real-time console I/O (Linux/macOS) */
    #include <unistd.h>
    #include <termios.h>
    #include <fcntl.h>
    #include <sys/select.h>
    #include <sys/time.h>
    #include <cstdlib>
#endif

#ifdef DEBUG_COMMAND
    #define DBG_CMD(...) do { printf(__VA_ARGS__); printf("\n"); } while (0)
#else
    #define DBG_CMD(...)
#endif

/* Memory-mapped I/O (0xFF00..0xFF03)
 * 0xFF00 KBD_STATUS (R): bit0=1 if a byte is available
 * 0xFF01 KBD_DATA   (R): pops a byte (7-bit ASCII), returns 0x00 if none
 * 0xFF02 TTY_STATUS (R): bit0=1 always
 * 0xFF03 TTY_DATA   (W): write byte to console
 */
static inline uint8_t mmio_read(uint16_t address);
static inline void    mmio_write(uint16_t address, uint8_t value);
static inline uint8_t mem_read(uint16_t address);
static inline void    mem_write(uint16_t address, uint8_t value);


/* REGISTERS *****************************************************************/

/* registers */

static uint8_t  r[8];           /* general purpose registers                 */
static uint16_t ip;             /* instruction pointer                       */
static uint16_t sp;             /* stack pointer                             */
static uint16_t bp;             /* stack frame pointer                       */

/* flags registers */

static uint8_t  c;              /* carry flag                                */

/* MEMORY ********************************************************************/

static uint8_t  mem[MEM_SIZE];  /* random access memory                      */

static void print_help(const char* prog)
{
    printf("Sophia8 VM (sophia8)\n\n");
    printf("Usage:\n");
    printf("  %s\n", prog);
    printf("      Run built-in test program.\n\n");
    printf("  %s <image.bin>\n", prog);
    printf("      Load and run a raw 0xFFFF-byte memory image.\n\n");
    printf("  %s <program.deb>\n", prog);
    printf("      Load a .deb debug map (emitted by s8asm), then load its referenced .bin, then run.\n\n");
    printf("  %s <program.deb> <break_file> <break_line>\n", prog);
    printf("      Run and stop when execution reaches the source location mapped from file:line.\n");
    printf("      When hit: prints registers, writes debug.img snapshot, and stops.\n\n");
    printf("  %s debug.img\n", prog);
    printf("      Resume execution from a previously saved debug snapshot.\n\n");
    printf("  %s debug.img <program.deb> <break_file> <break_line>\n", prog);
    printf("      Resume from snapshot and use .deb mapping to set a new breakpoint.\n\n");
    printf("Options:\n");
    printf("  -h, --help\n");
    printf("      Show this help.\n");
}

/* Memory-mapped I/O implementation ******************************************/
#ifndef _WIN32
/* POSIX (Linux/macOS) console input
 *
 * We emulate the same MMIO semantics as the Windows implementation:
 *  - KBD_STATUS returns 1 if a byte is available
 *  - KBD_DATA   returns a 7-bit ASCII byte and consumes it, or 0 if none
 *
 * The terminal is put into a non-canonical, no-echo mode and stdin is set
 * to non-blocking. We also keep a 1-byte queue so that KBD_STATUS does not
 * consume input.
 */
static termios g_old_term;
static bool    g_term_configured = false;
static int     g_old_flags = -1;
static int     g_kbd_queued = -1;

static void restore_console()
{
    if (!g_term_configured) return;

    tcsetattr(STDIN_FILENO, TCSANOW, &g_old_term);
    if (g_old_flags != -1)
    {
        fcntl(STDIN_FILENO, F_SETFL, g_old_flags);
    }

    g_term_configured = false;
    g_kbd_queued = -1;
}

static void setup_console()
{
    if (g_term_configured) return;

    /* save and configure terminal (raw-ish: no canonical mode, no echo) */
    if (tcgetattr(STDIN_FILENO, &g_old_term) == 0)
    {
        termios raw = g_old_term;
        raw.c_lflag &= static_cast<unsigned long>(~(ICANON | ECHO));
        raw.c_cc[VMIN]  = 0;
        raw.c_cc[VTIME] = 0;
        tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    }

    /* set stdin non-blocking */
    g_old_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (g_old_flags != -1)
    {
        fcntl(STDIN_FILENO, F_SETFL, g_old_flags | O_NONBLOCK);
    }

    atexit(restore_console);
    g_term_configured = true;
}

static bool stdin_readable_now()
{
    setup_console();

    fd_set rfds;
    FD_ZERO(&rfds);
    FD_SET(STDIN_FILENO, &rfds);

    timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 0;

    const int rc = select(STDIN_FILENO + 1, &rfds, NULL, NULL, &tv);
    return (rc > 0) && FD_ISSET(STDIN_FILENO, &rfds);
}

static void fill_kbd_queue_if_needed()
{
    if (g_kbd_queued != -1) return;
    if (!stdin_readable_now()) return;

    unsigned char ch = 0;
    const ssize_t n = read(STDIN_FILENO, &ch, 1);
    if (n == 1)
    {
        g_kbd_queued = static_cast<int>(ch & 0x7F); /* 7-bit ASCII */
    }
}

static uint8_t pop_kbd_byte()
{
    fill_kbd_queue_if_needed();
    if (g_kbd_queued == -1) return 0x00;

    const uint8_t out = static_cast<uint8_t>(g_kbd_queued);
    g_kbd_queued = -1;
    return out;
}
#endif

static inline uint8_t mmio_read(uint16_t address)
{
#ifdef _WIN32
    if (address == 0xFF00) return _kbhit() ? 0x01 : 0x00;
    if (address == 0xFF01)
    {
        if (!_kbhit()) return 0x00;

        int ch = _getch();
        if (ch == 0 || ch == 0xE0)
        {
            /* swallow special key */
            (void)_getch();
            return 0x00;
        }

        return static_cast<uint8_t>(ch & 0x7F);
    }
    if (address == 0xFF02) return 0x01;
    return 0x00;
#else
    if (address == 0xFF00)
    {
        fill_kbd_queue_if_needed();
        return (g_kbd_queued != -1) ? 0x01 : 0x00;
    }

    if (address == 0xFF01)
    {
        return pop_kbd_byte();
    }

    if (address == 0xFF02)
    {
        /* bit0=1 always (as documented by kernel.s8) */
        return 0x01;
    }

    return 0x00;
#endif
}

static inline void mmio_write(const uint16_t address, const uint8_t value)
{
    if (address == 0xFF03)
    {
        putchar(static_cast<int>(value));
        fflush(stdout);
    }
}

static inline uint8_t mem_read(const uint16_t address)
{
    if (address >= 0xFF00 && address <= 0xFF03) return mmio_read(address);
    if (address >= MEM_SIZE) return 0x00;
    return mem[address];
}

static inline void mem_write(const uint16_t address, const uint8_t value)
{
    if (address >= 0xFF00 && address <= 0xFF03) { mmio_write(address, value); return; }
    if (address >= MEM_SIZE) return;
    mem[address] = value;
}

/* SPECIAL TRIGGERS **********************************************************/

static uint8_t  STOP = 0x00;    /* should stop the machine?                  */

/* DEBUG / BREAKPOINT SUPPORT ************************************************/

namespace fs = std::filesystem;

struct DebLine {
    uint16_t addr = 0;
    bool is_code = false;
    std::string file;
    int line_no = 0;
};

static bool ends_with(const std::string& s, const std::string& suf) {
    return s.size() >= suf.size() && s.compare(s.size() - suf.size(), suf.size(), suf) == 0;
}

static std::string trim(const std::string& s) {
    const auto b = s.find_first_not_of(" \t\r\n");
    if (b == std::string::npos) return "";
    const auto e = s.find_last_not_of(" \t\r\n");
    return s.substr(b, e - b + 1);
}

static bool load_deb_map(const char* deb_path,
                         std::string& out_bin_path,
                         std::vector<DebLine>& out_lines)
{
    out_bin_path.clear();
    out_lines.clear();

    std::ifstream f(deb_path, std::ios::binary);
    if (!f) {
        printf("Failed to open .deb file: %s\n", deb_path);
        return false;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.rfind("; Binary:", 0) == 0) {
            out_bin_path = trim(line.substr(std::strlen("; Binary:")));
            continue;
        }
        if (line.empty() || line[0] == ';') continue;

        std::istringstream iss(line);
        std::string addr_hex;
        std::string len_str;
        std::string kind_str;
        if (!(iss >> addr_hex >> len_str >> kind_str)) continue;

        uint32_t addr_val = 0;
        try {
            addr_val = static_cast<uint32_t>(std::stoul(addr_hex, nullptr, 16));
        } catch (...) {
            continue;
        }

        // Parse source location from the end of the *full* line:
        //   ...  <file>:<line>: <original source line>
        const auto c1 = line.rfind(':');
        if (c1 == std::string::npos) continue;
        const auto c0 = line.rfind(':', c1 - 1);
        if (c0 == std::string::npos) continue;

        const std::string line_part = trim(line.substr(c0 + 1, c1 - (c0 + 1)));
        if (line_part.empty() || !std::all_of(line_part.begin(), line_part.end(), [](char ch){ return ch >= '0' && ch <= '9'; }))
        {
            continue;
        }

        const auto pos2 = line.rfind("  ", c0);
        if (pos2 == std::string::npos) continue;
        const std::string file_part = trim(line.substr(pos2, c0 - pos2));

        int line_no = 0;
        try {
            line_no = std::stoi(line_part);
        } catch (...) {
            continue;
        }

        DebLine dl;
        dl.addr = static_cast<uint16_t>(addr_val & 0xFFFF);
        dl.is_code = (kind_str == "CODE");
        dl.file = file_part;
        dl.line_no = line_no;
        out_lines.push_back(std::move(dl));
    }

    if (out_bin_path.empty()) {
        printf("Invalid .deb file (missing '; Binary:' header): %s\n", deb_path);
        return false;
    }

    // Resolve bin path relative to the .deb directory if needed.
    try {
        fs::path binp(out_bin_path);
        if (binp.is_relative()) {
            fs::path debp(deb_path);
            binp = debp.parent_path() / binp;
            out_bin_path = binp.lexically_normal().string();
        }
    } catch (...) {
        // ignore
    }

    return true;
}

static bool find_break_addr(const std::vector<DebLine>& lines,
                            const std::string& break_file,
                            const int break_line,
                            uint16_t& out_addr)
{
    out_addr = 0;
    bool found = false;
    uint16_t best = 0xFFFF;

    fs::path wantp(break_file);
    const std::string want_base = wantp.filename().string();

    for (const auto& l : lines) {
        if (!l.is_code) continue;
        if (l.line_no != break_line) continue;

        bool match = false;
        if (l.file == break_file) match = true;
        else {
            fs::path p(l.file);
            if (p.filename().string() == want_base) match = true;
        }
        if (!match) continue;

        if (!found || l.addr < best) {
            found = true;
            best = l.addr;
        }
    }

    if (!found) return false;
    out_addr = best;
    return true;
}

// Returns true if the .deb map contains *any* mapping (CODE or DATA) for the
// requested source file:line.
//
// This is used to provide a clear error when users try to set a breakpoint
// on a line that exists but does not emit executable code.
static bool has_any_mapping_for_line(const std::vector<DebLine>& lines,
                                    const std::string& break_file,
                                    const int break_line)
{
    fs::path wantp(break_file);
    const std::string want_base = wantp.filename().string();

    for (const auto& l : lines)
    {
        if (l.line_no != break_line) continue;

        bool match = false;
        if (l.file == break_file) match = true;
        else
        {
            fs::path p(l.file);
            if (p.filename().string() == want_base) match = true;
        }

        if (match) return true;
    }
    return false;
}

static void write_u16_be(std::ofstream& f, const uint16_t v) {
    const uint8_t b[2] = { static_cast<uint8_t>((v >> 8) & 0xFF), static_cast<uint8_t>(v & 0xFF) };
    f.write(reinterpret_cast<const char*>(b), 2);
}

static bool read_u16_be(std::ifstream& f, uint16_t& out) {
    uint8_t b[2];
    f.read(reinterpret_cast<char*>(b), 2);
    if (!f) return false;
    out = static_cast<uint16_t>((static_cast<uint16_t>(b[0]) << 8) | static_cast<uint16_t>(b[1]));
    return true;
}

static bool save_debug_image(const char* path)
{
    std::ofstream f(path, std::ios::binary);
    if (!f) {
        printf("Failed to write debug image: %s\n", path);
        return false;
    }

    // Layout:
    //   magic[4] = "S8DI"
    //   version  = 0x01
    //   r[8]
    //   ip, sp, bp (u16 big-endian)
    //   c (u8)
    //   reserved[7]
    //   mem[MEM_SIZE]
    const char magic[4] = { 'S', '8', 'D', 'I' };
    f.write(magic, 4);
    const uint8_t ver = 0x01;
    f.write(reinterpret_cast<const char*>(&ver), 1);
    f.write(reinterpret_cast<const char*>(r), 8);
    write_u16_be(f, ip);
    write_u16_be(f, sp);
    write_u16_be(f, bp);
    f.write(reinterpret_cast<const char*>(&c), 1);
    const uint8_t zeros[7] = {0,0,0,0,0,0,0};
    f.write(reinterpret_cast<const char*>(zeros), 7);
    f.write(reinterpret_cast<const char*>(mem), MEM_SIZE);

    if (!f) {
        printf("Failed while writing debug image: %s\n", path);
        return false;
    }
    return true;
}

static bool load_debug_image(const char* path)
{
    std::ifstream f(path, std::ios::binary);
    if (!f) return false;

    char magic[4] = {0,0,0,0};
    f.read(magic, 4);
    if (!f) return false;
    if (!(magic[0]=='S' && magic[1]=='8' && magic[2]=='D' && magic[3]=='I')) {
        return false;
    }
    uint8_t ver = 0;
    f.read(reinterpret_cast<char*>(&ver), 1);
    if (!f || ver != 0x01) return false;

    f.read(reinterpret_cast<char*>(r), 8);
    if (!f) return false;
    if (!read_u16_be(f, ip)) return false;
    if (!read_u16_be(f, sp)) return false;
    if (!read_u16_be(f, bp)) return false;
    f.read(reinterpret_cast<char*>(&c), 1);
    if (!f) return false;

    char tmp[7];
    f.read(tmp, 7);
    if (!f) return false;

    f.read(reinterpret_cast<char*>(mem), MEM_SIZE);
    if (!f) return false;

    STOP = 0;
    return true;
}

/* MACHINE CODE **************************************************************/

/**
 *
 * initializes memory and registers to a startup values.
 * 
 * All ram values are set to 0x00 (HALT) and sets stack pointer and block
 * pointer to top of the memory.
 *
 */
void init_machine()
{
    uint16_t i;
    STOP = 0;

    /* clean all memory */
    for (i = 0; i < MEM_SIZE; i++)
    {
        mem[i] = HALT;
    }

    /* initialize registers */
    ip = 0;
    sp = MEM_SIZE;
    bp = MEM_SIZE;
    c = 0;

    for (i = 0; i < 8; i++)
    {
        r[i] = 0;
    }
}

/**
 * Processing a load instruction. This instruction loads data from a 16bit
 * memory location and saves it to a defined register.
 * 
 * LOAD 0x1A2B, R0 -> 00 1A 2B 00
 */
void load_instruction()
{
    static uint16_t memory_source;
    static uint8_t destination;
    static uint8_t value;

    memory_source = static_cast<uint16_t>(mem[ip + 1]);
    memory_source <<= 8;
    memory_source += static_cast<uint16_t>(mem[ip + 2]);

    value = mem_read(memory_source);

    destination = mem[ip + 3];

    switch (destination) 
    {
        case IR0: r[0] = value; break;
        case IR1: r[1] = value; break;
        case IR2: r[2] = value; break;
        case IR3: r[3] = value; break;
        case IR4: r[4] = value; break;
        case IR5: r[5] = value; break;
        case IR6: r[6] = value; break;
        case IR7: r[7] = value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 4;
}

/**
 * Processing a store instruction. This instruction stores data from a specific
 * register to a 16bit memory location.
 * 
 * STORE 0x1A2B, R0 -> 01 1A 2B 00
 */
void store_instruction()
{
    static uint16_t memory_destination;
    static uint8_t source;
    static uint8_t value;

    source = mem[ip + 1]; 

    memory_destination = static_cast<uint16_t>(mem[ip + 2]);
    memory_destination <<= 8;
    memory_destination += static_cast<uint16_t>(mem[ip + 3]);

    switch (source) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    mem_write(memory_destination, value);

    ip += 4;
}

/**
 * Processing a store instruction. This instruction stores data from a specific
 * register to a 16bit memory location defined by two additional registers.
 * 
 * STORER R0, R1, R2 -> 02 00 01 02
 */
void storer_instruction()
{
    static uint8_t source_register;
    static uint8_t destination_register_h;
    static uint8_t destination_register_l;
    
    static uint8_t value;
    static uint16_t destinationAddress;

    source_register = mem[ip + 1];
    destination_register_h = mem[ip + 2];
    destination_register_l = mem[ip + 3];
    
    switch (source_register) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    switch (destination_register_h) 
    {
        case IR0: destinationAddress = static_cast<uint16_t>(r[0]) << 8; break;
        case IR1: destinationAddress = static_cast<uint16_t>(r[1]) << 8; break;
        case IR2: destinationAddress = static_cast<uint16_t>(r[2]) << 8; break;
        case IR3: destinationAddress = static_cast<uint16_t>(r[3]) << 8; break;
        case IR4: destinationAddress = static_cast<uint16_t>(r[4]) << 8; break;
        case IR5: destinationAddress = static_cast<uint16_t>(r[5]) << 8; break;
        case IR6: destinationAddress = static_cast<uint16_t>(r[6]) << 8; break;
        case IR7: destinationAddress = static_cast<uint16_t>(r[7]) << 8; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (destination_register_l) 
    {
        case IR0: destinationAddress += static_cast<uint16_t>(r[0]); break;
        case IR1: destinationAddress += static_cast<uint16_t>(r[1]); break;
        case IR2: destinationAddress += static_cast<uint16_t>(r[2]); break;
        case IR3: destinationAddress += static_cast<uint16_t>(r[3]); break;
        case IR4: destinationAddress += static_cast<uint16_t>(r[4]); break;
        case IR5: destinationAddress += static_cast<uint16_t>(r[5]); break;
        case IR6: destinationAddress += static_cast<uint16_t>(r[6]); break;
        case IR7: destinationAddress += static_cast<uint16_t>(r[7]); break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    mem_write(destinationAddress, value);
    
    ip += 4;
}

/**
 * Processing a load instruction via register-defined address. This instruction loads
 * data from a 16bit memory location defined by two registers into a destination register.
 *
 * LOADR R0, R1, R2 -> 1C 00 01 02
 */
void loadr_instruction()
{
    static uint8_t destination_register;
    static uint8_t source_register_h;
    static uint8_t source_register_l;

    static uint16_t source_address;
    static uint8_t value;

    destination_register = mem[ip + 1];
    source_register_h    = mem[ip + 2];
    source_register_l    = mem[ip + 3];

    /* compute address from registers */
    source_address = 0;
    switch (source_register_h)
    {
        case IR0: source_address = static_cast<uint16_t>(r[0]) << 8; break;
        case IR1: source_address = static_cast<uint16_t>(r[1]) << 8; break;
        case IR2: source_address = static_cast<uint16_t>(r[2]) << 8; break;
        case IR3: source_address = static_cast<uint16_t>(r[3]) << 8; break;
        case IR4: source_address = static_cast<uint16_t>(r[4]) << 8; break;
        case IR5: source_address = static_cast<uint16_t>(r[5]) << 8; break;
        case IR6: source_address = static_cast<uint16_t>(r[6]) << 8; break;
        case IR7: source_address = static_cast<uint16_t>(r[7]) << 8; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    switch (source_register_l)
    {
        case IR0: source_address += static_cast<uint16_t>(r[0]); break;
        case IR1: source_address += static_cast<uint16_t>(r[1]); break;
        case IR2: source_address += static_cast<uint16_t>(r[2]); break;
        case IR3: source_address += static_cast<uint16_t>(r[3]); break;
        case IR4: source_address += static_cast<uint16_t>(r[4]); break;
        case IR5: source_address += static_cast<uint16_t>(r[5]); break;
        case IR6: source_address += static_cast<uint16_t>(r[6]); break;
        case IR7: source_address += static_cast<uint16_t>(r[7]); break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    value = mem_read(source_address);

    switch (destination_register)
    {
        case IR0: r[0] = value; break;
        case IR1: r[1] = value; break;
        case IR2: r[2] = value; break;
        case IR3: r[3] = value; break;
        case IR4: r[4] = value; break;
        case IR5: r[5] = value; break;
        case IR6: r[6] = value; break;
        case IR7: r[7] = value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 4;
}

/**
 * Processing a set instruction. This instruction stores imidiate value to a
 * specific register.
 * 
 * SET 0x1A, R0 -> 03 1A 00
 */
void set_instruction()
{
    static uint8_t destination;
    static uint8_t value;

    value = mem[ip + 1];
    destination = mem[ip + 2];

    switch (destination) 
    {
        case IR0: r[0] = value; break;
        case IR1: r[1] = value; break;
        case IR2: r[2] = value; break;
        case IR3: r[3] = value; break;
        case IR4: r[4] = value; break;
        case IR5: r[5] = value; break;
        case IR6: r[6] = value; break;
        case IR7: r[7] = value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 3;
}

/**
 * Processing a push instruction. This instruction stores a register value to
 * a top of the stack.
 *
 * PUSH R0 -> 10 00
 */
void push_instruction()
{
    static uint8_t source;
    static uint8_t value;

    sp--;
    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = static_cast<uint8_t>(ip & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((ip & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }
    
    if (source == ISP)
    {
        value = static_cast<uint8_t>(sp & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((sp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }

    if (source == IBP)
    {
        value = static_cast<uint8_t>(bp & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((bp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }

    switch (source) 
    {
    case IR0: value = r[0]; break;
    case IR1: value = r[1]; break;
    case IR2: value = r[2]; break;
    case IR3: value = r[3]; break;
    case IR4: value = r[4]; break;
    case IR5: value = r[5]; break;
    case IR6: value = r[6]; break;
    case IR7: value = r[7]; break;
    default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    mem[sp] = value;

    ip+= 2;
}

/**
 * Processing a pop instruction. This instruction stores value on top of the
 * stack to a specific register.
 *
 * POP R0 -> 11 00
 */
void pop_instruction()
{
    static uint8_t source;
    static uint16_t value;

    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        ip = value;
        sp += 2;
        ip += 2;
        return;
    }
    if (source == ISP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        sp = value;
        sp += 2;
        ip += 2;
        return;
    }
    if (source == IBP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        bp = value;
        sp += 2;
        ip += 2;
        return;
    }
    
    value = static_cast<uint16_t>(mem[sp]);

    switch (source) 
    {
    case IR0: r[0] = static_cast<uint8_t>(value); break;
    case IR1: r[1] = static_cast<uint8_t>(value); break;
    case IR2: r[2] = static_cast<uint8_t>(value); break;
    case IR3: r[3] = static_cast<uint8_t>(value); break;
    case IR4: r[4] = static_cast<uint8_t>(value); break;
    case IR5: r[5] = static_cast<uint8_t>(value); break;
    case IR6: r[6] = static_cast<uint8_t>(value); break;
    case IR7: r[7] = static_cast<uint8_t>(value); break;
    default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    sp++;
    ip+= 2;
}

/*
 *
 * Increase Instruction. Increases register value by 1.
 *
 */
void inc_instruction()
{
    static uint8_t what;
    
    what = mem[ip + 1];

    switch (what) 
    {
        case IR0: r[0]++; c = r[0] == 0x00 ? 1 : 0; break;
        case IR1: r[1]++; c = r[1] == 0x00 ? 1 : 0; break;
        case IR2: r[2]++; c = r[2] == 0x00 ? 1 : 0; break;
        case IR3: r[3]++; c = r[3] == 0x00 ? 1 : 0; break;
        case IR4: r[4]++; c = r[4] == 0x00 ? 1 : 0; break;
        case IR5: r[5]++; c = r[5] == 0x00 ? 1 : 0; break;
        case IR6: r[6]++; c = r[6] == 0x00 ? 1 : 0; break;
        case IR7: r[7]++; c = r[7] == 0x00 ? 1 : 0; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 2;
}

/*
 *
 * Decrease Instruction. Decreases register value by 1.
 *
 */
void dec_instruction()
{
    static uint8_t what;
    
    what = mem[ip + 1];

    switch (what) 
    {
        case IR0: r[0]--; c = r[0] == 0xFF ? 1 : 0; break;
        case IR1: r[1]--; c = r[1] == 0xFF ? 1 : 0; break;
        case IR2: r[2]--; c = r[2] == 0xFF ? 1 : 0; break;
        case IR3: r[3]--; c = r[3] == 0xFF ? 1 : 0; break;
        case IR4: r[4]--; c = r[4] == 0xFF ? 1 : 0; break;
        case IR5: r[5]--; c = r[5] == 0xFF ? 1 : 0; break;
        case IR6: r[6]--; c = r[6] == 0xFF ? 1 : 0; break;
        case IR7: r[7]--; c = r[7] == 0xFF ? 1 : 0; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 2;
}

/**
 *
 * JMP instruction. Jumps to a specific 16 bit address.
 *
 */
void jmp_instruction()
{
    static uint16_t jump_address;

    jump_address = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jump_address += static_cast<uint16_t>(mem[ip + 2]);

    ip = jump_address;
}

/**
 *
 * compares register to a value. If register value is less than imediate value
 * it sets the carry bit to true. Does subtraction on the backend. Subtracted
 * value is set in the register that has been used for comparison.
 *
 */
void cmp_instruction()
{
    static uint8_t source_register;
    static uint8_t value;
    
    source_register = mem[ip + 1];
    value = mem[ip + 2];
    
    switch (source_register) 
    {
        case IR0: c = r[0] >= value ? 0 : 1; r[0] -= value; break;
        case IR1: c = r[1] >= value ? 0 : 1; r[1] -= value; break;
        case IR2: c = r[2] >= value ? 0 : 1; r[2] -= value; break;
        case IR3: c = r[3] >= value ? 0 : 1; r[3] -= value; break;
        case IR4: c = r[4] >= value ? 0 : 1; r[4] -= value; break;
        case IR5: c = r[5] >= value ? 0 : 1; r[5] -= value; break;
        case IR6: c = r[6] >= value ? 0 : 1; r[6] -= value; break;
        case IR7: c = r[7] >= value ? 0 : 1; r[7] -= value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * compares register to another register. If register value is less than
 * imediate value it sets the carry bit to true. Does subtraction on the
 * backend. Subtracted value is set in the register that has been used 
 * for comparison.
 *
 */
void cmpr_instruction()
{
    static uint8_t register0;
    static uint8_t register1;
    static uint8_t value;
    
    register0 = mem[ip + 1];
    register1 = mem[ip + 2];
    
    switch (register1) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (register0) 
    {
        case IR0: c = r[0] >= value ? 0 : 1;  r[0] -= value; break;
        case IR1: c = r[1] >= value ? 0 : 1;  r[1] -= value; break;
        case IR2: c = r[2] >= value ? 0 : 1;  r[2] -= value; break;
        case IR3: c = r[3] >= value ? 0 : 1;  r[3] -= value; break;
        case IR4: c = r[4] >= value ? 0 : 1;  r[4] -= value; break;
        case IR5: c = r[5] >= value ? 0 : 1;  r[5] -= value; break;
        case IR6: c = r[6] >= value ? 0 : 1;  r[6] -= value; break;
        case IR7: c = r[7] >= value ? 0 : 1;  r[7] -= value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * "Jump if zero" instruction. Jumps to a specific 16 bit address if selected
 * register is set to zero.
 *
 */
void jz_instruction()
{
    static uint8_t sourceRegister;
    static uint16_t jumpAddress;
    
    sourceRegister = mem[ip + 1];
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 2]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 3]);
    
    switch (sourceRegister) 
    {
        case IR0: if (r[0] == 0) {ip = jumpAddress; return;} break;
        case IR1: if (r[1] == 0) {ip = jumpAddress; return;} break;
        case IR2: if (r[2] == 0) {ip = jumpAddress; return;} break;
        case IR3: if (r[3] == 0) {ip = jumpAddress; return;} break;
        case IR4: if (r[4] == 0) {ip = jumpAddress; return;} break;
        case IR5: if (r[5] == 0) {ip = jumpAddress; return;} break;
        case IR6: if (r[6] == 0) {ip = jumpAddress; return;} break;
        case IR7: if (r[7] == 0) {ip = jumpAddress; return;} break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * "Jump if not zero" instruction. Jumps to a specific 16 bit address if
 * selected register is not set to zero.
 *
 */
void jnz_instruction()
{
    static uint8_t source_register;
    static uint16_t jump_address;
    
    source_register = mem[ip + 1];
    
    jump_address = static_cast<uint16_t>(mem[ip + 2]) << 8;
    jump_address += static_cast<uint16_t>(mem[ip + 3]);
    
    switch (source_register) 
    {
        case IR0: if (r[0] != 0) {ip = jump_address; return;} break;
        case IR1: if (r[1] != 0) {ip = jump_address; return;} break;
        case IR2: if (r[2] != 0) {ip = jump_address; return;} break;
        case IR3: if (r[3] != 0) {ip = jump_address; return;} break;
        case IR4: if (r[4] != 0) {ip = jump_address; return;} break;
        case IR5: if (r[5] != 0) {ip = jump_address; return;} break;
        case IR6: if (r[6] != 0) {ip = jump_address; return;} break;
        case IR7: if (r[7] != 0) {ip = jump_address; return;} break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * "Jump if carry set" instruction. Jumps to a specific 16 bit address if
 * carry is set.
 *
 */
void jc_instruction()
{
    static uint16_t jumpAddress;
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    if (c != 0)
    {
        ip = jumpAddress;
        return;
    }
    
    ip += 3;
}

/**
 *
 * "Jump if carry not set" instruction. Jumps to a specific 16 bit address if
 * carry is not set.
 *
 */
void jnc_instruction()
{
    static uint16_t jumpAddress;
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    if (c == 0)
    {
        ip = jumpAddress;
        return;
    }
    
    ip += 3;
}

/**
 *
 * Add instruction. Adds a value to a register.
 *
 */
void add_instruction()
{
    static uint8_t dest_register;
    static uint8_t value;
    
    value = mem[ip + 1];
    dest_register = mem[ip + 2];
    
    switch (dest_register)
    {
        case IR0: c = static_cast<uint16_t>(r[0]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[0] += value; break;
        case IR1: c = static_cast<uint16_t>(r[1]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[1] += value; break;
        case IR2: c = static_cast<uint16_t>(r[2]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[2] += value; break;
        case IR3: c = static_cast<uint16_t>(r[3]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[3] += value; break;
        case IR4: c = static_cast<uint16_t>(r[4]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[4] += value; break;
        case IR5: c = static_cast<uint16_t>(r[5]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[5] += value; break;
        case IR6: c = static_cast<uint16_t>(r[6]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[6] += value; break;
        case IR7: c = static_cast<uint16_t>(r[7]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[7] += value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Addr instruction. Adds a value of a specific register to a value in destination register.
 *
 */
void addr_instruction()
{
    static uint8_t destRegister;
    static uint8_t sourceRegister;
    static uint8_t value;
    
    sourceRegister = mem[ip + 1];
    destRegister = mem[ip + 2];
    
    switch (sourceRegister)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (destRegister)
    {
        case IR0: c = static_cast<uint16_t>(r[0]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[0] += value; break;
        case IR1: c = static_cast<uint16_t>(r[1]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[1] += value; break;
        case IR2: c = static_cast<uint16_t>(r[2]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[2] += value; break;
        case IR3: c = static_cast<uint16_t>(r[3]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[3] += value; break;
        case IR4: c = static_cast<uint16_t>(r[4]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[4] += value; break;
        case IR5: c = static_cast<uint16_t>(r[5]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[5] += value; break;
        case IR6: c = static_cast<uint16_t>(r[6]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[6] += value; break;
        case IR7: c = static_cast<uint16_t>(r[7]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[7] += value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Call instruction. Jumps to a specified address and pushes return instruction
 * address onto a stack.
 *
 */
void call_instruction()
{
    static uint16_t callAddress;
    static uint16_t returnAddress;
    
    callAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    callAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    returnAddress = ip + 3;
    
    mem[sp - 2] = static_cast<uint8_t>((returnAddress & 0xFF00) >> 8);
    mem[sp - 1] = static_cast<uint8_t>(returnAddress & 0x00FF);
    sp -= 2;
    
    ip = callAddress;
}

/**
 *
 * Ret instruction. Returns from a procedure using the top of the stack as a
 * return address.
 *
 */
void ret_instruction()
{
    ip = static_cast<uint16_t>(mem[sp]) << 8;
    ip += static_cast<uint16_t>(mem[sp + 1]);
    sp += 2;
}

/**
 *
 * Sub instruction. Subtracts a value from a register.
 *
 */
void sub_instruction()
{
    static uint8_t destRegister;
    static uint8_t value;
    
    value = mem[ip + 1];
    destRegister = mem[ip + 2];
    
    switch (destRegister)
    {
        case IR0: c = r[0] < value ? 1 : 0; r[0] -= value; break;
        case IR1: c = r[1] < value ? 1 : 0; r[1] -= value; break;
        case IR2: c = r[2] < value ? 1 : 0; r[2] -= value; break;
        case IR3: c = r[3] < value ? 1 : 0; r[3] -= value; break;
        case IR4: c = r[4] < value ? 1 : 0; r[4] -= value; break;
        case IR5: c = r[5] < value ? 1 : 0; r[5] -= value; break;
        case IR6: c = r[6] < value ? 1 : 0; r[6] -= value; break;
        case IR7: c = r[7] < value ? 1 : 0; r[7] -= value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Subr instruction. Subtracts a value of a specific register from a value in destination register.
 *
 */
void subr_instruction()
{
    static uint8_t dest_register;
    static uint8_t source_register;
    static uint8_t value;
    
    source_register = mem[ip + 1];
    dest_register = mem[ip + 2];
    
    switch (source_register)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (dest_register)
    {
        case IR0: c = r[0] < value ? 1 : 0; r[0] -= value; break;
        case IR1: c = r[1] < value ? 1 : 0; r[1] -= value; break;
        case IR2: c = r[2] < value ? 1 : 0; r[2] -= value; break;
        case IR3: c = r[3] < value ? 1 : 0; r[3] -= value; break;
        case IR4: c = r[4] < value ? 1 : 0; r[4] -= value; break;
        case IR5: c = r[5] < value ? 1 : 0; r[5] -= value; break;
        case IR6: c = r[6] < value ? 1 : 0; r[6] -= value; break;
        case IR7: c = r[7] < value ? 1 : 0; r[7] -= value; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Mul instruction. multiplies a register by value. Saves result into two
 * registers.
 *
 */
void mul_instruction()
{
    static uint8_t dest_register_l;
    static uint8_t dest_register_h;
    static uint16_t value;
    static uint16_t result;
    
    value = static_cast<uint16_t>(mem[ip + 1]);
    dest_register_h = mem[ip + 2];
    dest_register_l = mem[ip + 3];
    
    switch (dest_register_l)
    {
        case IR0: 
            result = static_cast<uint16_t>(r[0]) * value;
            r[0] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR1: 
            result = static_cast<uint16_t>(r[1]) * value; 
            r[1] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR2: 
            result = static_cast<uint16_t>(r[2]) * value; 
            r[2] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR3: 
            result = static_cast<uint16_t>(r[3]) * value; 
            r[3] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR4: 
            result = static_cast<uint16_t>(r[4]) * value; 
            r[4] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR5: 
            result = static_cast<uint16_t>(r[5]) * value; 
            r[5] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR6: 
            result = static_cast<uint16_t>(r[6]) * value; 
            r[6] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR7: 
            result = static_cast<uint16_t>(r[7]) * value; 
            r[7] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    c = result > 0xFF ? 1 : 0;
    
    switch (dest_register_h)
    {
        case IR0: r[0] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR1: r[1] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR2: r[2] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR3: r[3] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR4: r[4] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR5: r[5] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR6: r[6] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR7: r[7] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Mulr instruction. Multiplies register value by a register value. Saves 
 * result into two registers.
 *
 */
void mulr_instruction()
{
    static uint8_t srcRegister;
    static uint8_t destRegisterL;
    static uint8_t destRegisterH;
    static uint16_t value;
    static uint16_t result;
    
    srcRegister = mem[ip + 1];
    destRegisterH = mem[ip + 2];
    destRegisterL = mem[ip + 3];
    
    switch (srcRegister)
    {
        case IR0: value = static_cast<uint16_t>(r[0]); break;
        case IR1: value = static_cast<uint16_t>(r[1]); break;
        case IR2: value = static_cast<uint16_t>(r[2]); break;
        case IR3: value = static_cast<uint16_t>(r[3]); break;
        case IR4: value = static_cast<uint16_t>(r[4]); break;
        case IR5: value = static_cast<uint16_t>(r[5]); break;
        case IR6: value = static_cast<uint16_t>(r[6]); break;
        case IR7: value = static_cast<uint16_t>(r[7]); break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (destRegisterL)
    {
        case IR0: 
            result = static_cast<uint16_t>(r[0]) * value;
            r[0] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR1: 
            result = static_cast<uint16_t>(r[1]) * value; 
            r[1] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR2: 
            result = static_cast<uint16_t>(r[2]) * value; 
            r[2] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR3: 
            result = static_cast<uint16_t>(r[3]) * value; 
            r[3] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR4: 
            result = static_cast<uint16_t>(r[4]) * value; 
            r[4] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR5: 
            result = static_cast<uint16_t>(r[5]) * value; 
            r[5] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR6: 
            result = static_cast<uint16_t>(r[6]) * value; 
            r[6] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR7: 
            result = static_cast<uint16_t>(r[7]) * value; 
            r[7] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    c = result > 0xFF ? 1 : 0;
    
    switch (destRegisterH)
    {
        case IR0: r[0] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR1: r[1] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR2: r[2] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR3: r[3] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR4: r[4] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR5: r[5] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR6: r[6] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR7: r[7] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Div instruction. divides a register by value. Saves results into two
 * registers. First register holds rusult of the dision, and the second
 * the rest of the division.
 *
 */
void divInstruction()
{
    static uint8_t dest_register_result;
    static uint8_t dest_register_rest;
    static uint8_t value;
    static uint8_t result;
    static uint8_t rest;
    
    value = mem[ip + 1];
    dest_register_result = mem[ip + 2];
    dest_register_rest = mem[ip + 3];
    
    switch (dest_register_result)
    {
        case IR0: result = r[0] / value; rest = r[0] % value; r[0] = result; break;
        case IR1: result = r[1] / value; rest = r[1] % value; r[1] = result; break;
        case IR2: result = r[2] / value; rest = r[2] % value; r[2] = result; break;
        case IR3: result = r[3] / value; rest = r[3] % value; r[3] = result; break;
        case IR4: result = r[4] / value; rest = r[4] % value; r[4] = result; break;
        case IR5: result = r[5] / value; rest = r[5] % value; r[5] = result; break;
        case IR6: result = r[6] / value; rest = r[6] % value; r[6] = result; break;
        case IR7: result = r[7] / value; rest = r[7] % value; r[7] = result; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (dest_register_rest)
    {
        case IR0: r[0] = rest; break;
        case IR1: r[1] = rest; break;
        case IR2: r[2] = rest; break;
        case IR3: r[3] = rest; break;
        case IR4: r[4] = rest; break;
        case IR5: r[5] = rest; break;
        case IR6: r[6] = rest; break;
        case IR7: r[7] = rest; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Divr instruction. divides a register by another register. Saves results into
 * two registers. First register holds rusult of the dision, and the second
 * the rest of the division.
 *
 */
void divr_instruction()
{
    static uint8_t src_register;
    static uint8_t dest_register_result;
    static uint8_t dest_register_rest;
    static uint8_t value;
    static uint8_t result;
    static uint8_t rest;
    
    src_register = mem[ip + 1];
    
    switch (src_register)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    dest_register_result = mem[ip + 2];
    dest_register_rest = mem[ip + 3];
    
    switch (dest_register_result)
    {
        case IR0: result = r[0] / value; rest = r[0] % value; r[0] = result; break;
        case IR1: result = r[1] / value; rest = r[1] % value; r[1] = result; break;
        case IR2: result = r[2] / value; rest = r[2] % value; r[2] = result; break;
        case IR3: result = r[3] / value; rest = r[3] % value; r[3] = result; break;
        case IR4: result = r[4] / value; rest = r[4] % value; r[4] = result; break;
        case IR5: result = r[5] / value; rest = r[5] % value; r[5] = result; break;
        case IR6: result = r[6] / value; rest = r[6] % value; r[6] = result; break;
        case IR7: result = r[7] / value; rest = r[7] % value; r[7] = result; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    switch (dest_register_rest)
    {
        case IR0: r[0] = rest; break;
        case IR1: r[1] = rest; break;
        case IR2: r[2] = rest; break;
        case IR3: r[3] = rest; break;
        case IR4: r[4] = rest; break;
        case IR5: r[5] = rest; break;
        case IR6: r[6] = rest; break;
        case IR7: r[7] = rest; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
    
    ip += 4;
}

/*
 *
 * Shifts value to the right. If last shifted bit was 1, then sets carry to 1.
 *
 */
void shrInstruction()
{
    static uint8_t what;
    static uint8_t val;
    
    val = mem[ip + 1];
    what = mem[ip + 2];

    switch (what) 
    {
        case IR0: c = (r[0] >> (val - 1)) % 2; r[0] >>= val; break;
        case IR1: c = (r[1] >> (val - 1)) % 2; r[1] >>= val; break;
        case IR2: c = (r[2] >> (val - 1)) % 2; r[2] >>= val; break;
        case IR3: c = (r[3] >> (val - 1)) % 2; r[3] >>= val; break;
        case IR4: c = (r[4] >> (val - 1)) % 2; r[4] >>= val; break;
        case IR5: c = (r[5] >> (val - 1)) % 2; r[5] >>= val; break;
        case IR6: c = (r[6] >> (val - 1)) % 2; r[6] >>= val; break;
        case IR7: c = (r[7] >> (val - 1)) % 2; r[7] >>= val; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 3;
}

/*
 *
 * Shifts value to the left. If last shifted bit was 1, then sets carry to 1.
 *
 */
void shl_instruction()
{
    static uint8_t what;
    static uint8_t val;
    
    val = mem[ip + 1];
    what = mem[ip + 2];

    switch (what) 
    {
        case IR0: c = r[0] << (val - 1) > 127 ? 1 : 0; r[0] <<= val; break;
        case IR1: c = r[1] << (val - 1) > 127 ? 1 : 0; r[1] <<= val; break;
        case IR2: c = r[2] << (val - 1) > 127 ? 1 : 0; r[2] <<= val; break;
        case IR3: c = r[3] << (val - 1) > 127 ? 1 : 0; r[3] <<= val; break;
        case IR4: c = r[4] << (val - 1) > 127 ? 1 : 0; r[4] <<= val; break;
        case IR5: c = r[5] << (val - 1) > 127 ? 1 : 0; r[5] <<= val; break;
        case IR6: c = r[6] << (val - 1) > 127 ? 1 : 0; r[6] <<= val; break;
        case IR7: c = r[7] << (val - 1) > 127 ? 1 : 0; r[7] <<= val; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }

    ip += 3;
}

/**
 *
 * Processes instruction. If unknown instruction or halt, then the VM stops.
 *
 */
void process_instruction()
{
    switch (mem[ip])
    {
	        case LOADR: DBG_CMD("LOADR 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); loadr_instruction(); break;
        case LOAD: DBG_CMD("LOAD 0x%02X, 0x%04X", mem[ip+1], (uint16_t)(mem[ip+2]<<8)|mem[ip+3]); load_instruction(); break;
        case STORE: DBG_CMD("STORE 0x%02X, 0x%04X", mem[ip+1], (uint16_t)(mem[ip+2]<<8)|mem[ip+3]); store_instruction(); break;
        case STORER: DBG_CMD("STORER 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); storer_instruction(); break;
        case SET: DBG_CMD("SET 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); set_instruction(); break;
        case PUSH: DBG_CMD("PUSH 0x%02X", mem[ip+1]); push_instruction(); break;
        case POP: DBG_CMD("POP 0x%02X", mem[ip+1]); pop_instruction(); break;
        case INC: DBG_CMD("INC 0x%02X", mem[ip+1]); inc_instruction(); break;
        case DEC: DBG_CMD("DEC 0x%02X", mem[ip+1]); dec_instruction(); break;
        case JMP: DBG_CMD("JMP 0x%04X", (uint16_t)(mem[ip+1]<<8)|mem[ip+2]); jmp_instruction(); break;
        case CMP: DBG_CMD("CMP 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); cmp_instruction(); break;
        case CMPR: DBG_CMD("CMPR 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); cmpr_instruction(); break;
        case JZ: DBG_CMD("JZ 0x%02X, 0x%04X", mem[ip+1], (uint16_t)(mem[ip+2]<<8)|mem[ip+3]); jz_instruction(); break;
        case JNZ: DBG_CMD("JNZ 0x%02X, 0x%04X", mem[ip+1], (uint16_t)(mem[ip+2]<<8)|mem[ip+3]); jnz_instruction(); break;
        case JC: DBG_CMD("JC 0x%04X", (uint16_t)(mem[ip+1]<<8)|mem[ip+2]); jc_instruction(); break;
        case JNC: DBG_CMD("JNC 0x%04X", (uint16_t)(mem[ip+1]<<8)|mem[ip+2]); jnc_instruction(); break;
        case ADD: DBG_CMD("ADD 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); add_instruction(); break;
        case ADDR: DBG_CMD("ADDR 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); addr_instruction(); break;
        case CALL: DBG_CMD("CALL 0x%04X", (uint16_t)(mem[ip+1]<<8)|mem[ip+2]); call_instruction(); break;
        case RET: DBG_CMD("RET"); ret_instruction(); break;
        case SUB: DBG_CMD("SUB 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); sub_instruction(); break;
        case SUBR: DBG_CMD("SUBR 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); subr_instruction(); break;
        case MUL: DBG_CMD("MUL 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); mul_instruction(); break;
        case MULR: DBG_CMD("MULR 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); mulr_instruction(); break;
        case DIV: DBG_CMD("DIV 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); divInstruction(); break;
        case DIVR: DBG_CMD("DIVR 0x%02X, 0x%02X, 0x%02X", mem[ip+1], mem[ip+2], mem[ip+3]); divr_instruction(); break;
        case SHL: DBG_CMD("SHL 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); shl_instruction(); break;
        case SHR: DBG_CMD("SHR 0x%02X, 0x%02X", mem[ip+1], mem[ip+2]); shrInstruction(); break;
        case NOP: DBG_CMD("NOP"); ip++; break;
        case HALT: DBG_CMD("HALT"); STOP = 1; break;
        default: DBG_CMD("UNKNOWN 0x%02X", mem[ip]); STOP = 1; break;
    }
}

/**
 *
 * Prints Memory
 *
 */
void print_memory()
{
    for (uint16_t i = 0; i < MEM_SIZE; i++)
    {
        if (i % 64 == 0)
        {
            // ReSharper disable once CppPrintfRiskyFormat
            printf("\n%#06x:", i);
        }

        printf(" %02x", mem[i]);
    }

    printf("\n");
}

/**
 *
 * Print registers
 *
 */
void print_registers()
{
    for (uint8_t i = 0; i < 8; i++)
    {
        printf("R%d = 0x%02x ", i, r[i]);
    }

    printf("IP = 0x%04x ", ip);
    printf("SP = 0x%04x ", sp);
    printf("BP = 0x%04x ", bp);
    printf("C = %d\n", c ? 1 : 0);
}

void run(const bool break_enabled = false,
         const uint16_t break_addr = 0,
         const char* break_file = nullptr,
         const int break_line = 0)
{
    while (!STOP)
    {
        if (break_enabled && ip == break_addr)
        {
            printf("BREAK at %s:%d (0x%04X)\n",
                   break_file ? break_file : "<unknown>",
                   break_line,
                   static_cast<unsigned>(break_addr));
            print_registers();
            (void)save_debug_image("debug.img");
            STOP = 1;
            break;
        }

        process_instruction();
    }

    //print_memory();
    //print_registers();
}

void load_test_code()
{
    uint8_t test_code[202] = {
        SET,   0x0A,       IR0,        // 3
        STORE, IR0,        0xFF, 0xC0, // 7
        LOAD,  0xFF, 0xC0, IR1,        // 11
        SET,   0x01,       IR0,        // 14
        SET,   0x02,       IR1,        // 17
        SET,   0x03,       IR2,        // 20
        SET,   0x04,       IR3,        // 23
        SET,   0x05,       IR4,        // 26
        SET,   0x06,       IR5,        // 29
        SET,   0x07,       IR6,        // 32
        SET,   0x08,       IR7,        // 35
        PUSH,  IR0,                    // 37
        PUSH,  IR1,                    // 39
        PUSH,  IR2,                    // 41
        PUSH,  IR3,                    // 43
        PUSH,  IR4,                    // 45
        PUSH,  IR5,                    // 47
        PUSH,  IR6,                    // 49
        PUSH,  IR7,                    // 51
        POP,   IR0,                    // 53
        POP,   IR1,                    // 55
        POP,   IR2,                    // 57
        POP,   IR3,                    // 59
        POP,   IR4,                    // 61
        POP,   IR5,                    // 63
        POP,   IR6,                    // 65
        POP,   IR7,                    // 67
        SET,   0x00,       IR7,        // 70
        SET,   0xFF,       IR6,        // 73
        DEC,   IR7,                    // 75
        INC,   IR6,                    // 77
        SET,   0xBB,       IR0,        // 80
        SET,   0xFF,       IR1,        // 83
        SET,   0xC1,       IR2,        // 86
        STORER,IR0,        IR1, IR2,   // 90
        CMP,   IR0,        0x10,       // 93
        CMPR,  IR0,        IR1,        // 96
        NOP,                           // 97
        SET,   0xFF,       IR0,        // 100
        SET,   0x0A,       IR1,        // 103
        STORER,IR1,        IR0, IR1,   // 107
        DEC,   IR1,                    // 109
        JNZ,   IR1,        0x00, 0x67, // 113
        SET,   0xAA,       IR0,        // 116
        ADD,   0x01,       IR0,        // 119
        ADD,   0xFF,       IR0,        // 122
        SET,   0x00,       IR1,        // 125
        ADDR,  IR0,        IR1,        // 128
        CALL,  0x00, 0xC9,             // 131
        SET,   0x09,       IR0,        // 134
        SUB,   0x0A,       IR0,        // 137
        SET,   0x09,       IR1,        // 140
        SET,   0x0A,       IR2,        // 143
        SUBR,  IR1,        IR2,        // 146
        SET,   0xEE,       IR1,        // 149
        MUL,   0xEE,       IR0, IR1,   // 153
        SET,   0xEE,       IR0,        // 156
        SET,   0xEE,       IR2,        // 159
        MULR,  IR0,        IR1, IR2,   // 163
        SET,   0x0A,       IR0,        // 166
        DIV,   0x06,       IR0, IR1,   // 170
        SET,   0x06,       IR0,        // 173
        SET,   0x0A,       IR1,        // 176
        DIVR,  IR0,        IR1, IR2,   // 180
        SET,   0x01,       IR0,        // 183
        SHL,   0x07,       IR0,        // 186
        SHL,   0x01,       IR0,        // 189
        SET,   0x80,       IR0,        // 192
        SHR,   0x07,       IR0,        // 195
        SHR,   0x01,       IR0,        // 198
        JMP,   0xAB, 0xCD,             // 201
        RET};                          // 202

    for (uint16_t i = 0; i < 202; i++)
    {
        mem[i] = test_code[i];
    }
}

/**
 *
 * Starts the code until it reaches halt instruction or end of code memory.
 *
 */
/**
 * Loads a full memory image from a raw binary file into mem[0..MEM_SIZE-1].
 * Returns true on success, false otherwise.
 */
bool load_bin_file(const char* file_path)
{
    FILE* f = fopen(file_path, "rb");
    if (!f)
    {
        printf("Failed to open bin file: %s\n", file_path);
        return false;
    }

    (void)fread(mem, 1, MEM_SIZE, f);
    fclose(f);
    return true;
}


int main(int argc, char** argv)
{
    if (argc >= 2)
    {
        const std::string a1 = argv[1];
        if (a1 == "-h" || a1 == "--help")
        {
            print_help(argv[0]);
            return 0;
        }
    }

    init_machine();

    /*
     * Usage:
     *   sophia8
     *       runs built-in test program
     *
     *   sophia8 <image.bin>
     *       loads and runs a raw memory image
     *
     *   sophia8 <program.deb> [<break_file> <break_line>]
     *       loads .deb debug map (emitted by s8asm), loads the referenced .bin,
     *       and optionally stops at the given source file/line.
     *
     *   sophia8 debug.img [<program.deb> <break_file> <break_line>]
     *       resumes from a saved debug image (written on breakpoint) and may
     *       still use a .deb + breakpoint.
     */

    std::string deb_bin_path;
    std::vector<DebLine> deb_lines;
    bool have_deb = false;
    bool have_state = false;

    int argi = 1;
    if (argc >= 2)
    {
        // 1) Try to load a debug image first (resume).
        if (load_debug_image(argv[argi]))
        {
            have_state = true;
            argi++;
        }
    }

    // Help may appear after a debug image too: `sophia8 debug.img --help`
    if (argi < argc)
    {
        const std::string a = argv[argi];
        if (a == "-h" || a == "--help")
        {
            print_help(argv[0]);
            return 0;
        }
    }

    if (!have_state)
    {
        if (argc <= 1)
        {
            load_test_code();
        }
        else
        {
            const std::string p = argv[argi];
            if (ends_with(p, ".deb"))
            {
                have_deb = load_deb_map(argv[argi], deb_bin_path, deb_lines);
                if (!have_deb) return 1;
                if (!load_bin_file(deb_bin_path.c_str())) return 1;
                argi++;
            }
            else
            {
                if (!load_bin_file(argv[argi])) return 1;
                argi++;
            }
        }
    }
    else
    {
        // Resumed state: optionally load a .deb for breakpoint mapping.
        if (argi < argc)
        {
            const std::string p = argv[argi];
            if (ends_with(p, ".deb"))
            {
                have_deb = load_deb_map(argv[argi], deb_bin_path, deb_lines);
                if (!have_deb) return 1;
                argi++;
            }
        }
    }

    bool break_enabled = false;
    uint16_t break_addr = 0;
    const char* break_file = nullptr;
    int break_line = 0;

    if (argi + 1 < argc)
    {
        if (!have_deb)
        {
            printf("Breakpoint requires a .deb debug map.\n");
            return 1;
        }

        break_file = argv[argi];
        break_line = std::atoi(argv[argi + 1]);
        if (break_line <= 0)
        {
            printf("Invalid breakpoint line: %s\n", argv[argi + 1]);
            return 1;
        }

        if (!find_break_addr(deb_lines, break_file, break_line, break_addr))
        {
            // Distinguish between:
            //  - file:line exists in the debug map but only as DATA (or otherwise non-executable)
            //  - file:line does not exist in the debug map at all
            if (has_any_mapping_for_line(deb_lines, break_file, break_line))
            {
                printf("No executable code on this line.\n");
            }
            else
            {
                printf("Breakpoint not found in .deb: %s:%d\n", break_file, break_line);
            }
            return 1;
        }

        break_enabled = true;
    }

    run(break_enabled, break_addr, break_file, break_line);
    return 0;
}

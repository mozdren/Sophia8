// s8asm.cpp - Sophia8 Assembler (C++17)
// Spec: deterministic Sophia8 assembler with .include and .org entry marker.
//
// Features (frozen):
// - Output is full 0xFFFF-byte memory image (addresses 0x0000..0xFFFE), zero-filled.
// - Implicit entry stub at 0x0000..0x0002: JMP <ENTRY>
// - Default emission begins at 0x0003.
// - .org <addr>: sets location counter to addr (>=0x0003). Multiple allowed.
// - .org (no operand): entry marker only (does not move LC). Allowed exactly once.
// - If .org (no operand) exists -> ENTRY is its LC. Else ENTRY is first .org <addr>.
// - .org is mandatory overall (either form must appear at least once).
// - .include "file.s8": pure textual include at position; nested includes allowed.
//   Path resolution: 1) including file dir, 2) entry file dir, else error.
//   Include cycles: strict error w/ include chain. Multiple include of same file: strict error.
// - Labels are global; duplicate labels are strict error.
// - Case-sensitive syntax. Comments start with ';' to end-of-line.
// - Immediates must use '#': #0x.. #123 #0b..
// - Addresses are plain 0x.... or labels (no '#').
// - .byte: numeric literals only (no labels, no '#'), trailing comma allowed.
// - .word: numeric literals or labels (no '#'), trailing comma allowed.
// - Any overlap emission is a strict error.
//
// Build:
//   g++ -std=c++17 -O2 s8asm.cpp -o s8asm
// Use:
//   ./s8asm main.s8 -o image.bin

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <optional>
#include <stdexcept>
#include <sstream>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <algorithm>

namespace fs = std::filesystem;

static constexpr uint32_t MEM_SIZE = 0xFFFF; // bytes, valid indices 0x0000..0xFFFE

static void print_help(const char* prog)
{
    // Keep this text implementation-accurate. Anything not listed here should be considered undefined.
    std::cout
        << "Sophia8 Assembler (s8asm)\n"
        << "\n"
        << "Usage:\n"
        << "  " << prog << " <input.s8> [-o <output.bin>]\n"
        << "\n"
        << "Options:\n"
        << "  -o, --output <file>   Output image file (default: sophia8_image.bin)\n"
        << "  -h, --help            Show this help\n"
        << "\n"
        << "What it produces:\n"
        << "  <output.bin>          Full 0xFFFF-byte memory image (0x0000..0xFFFE), zero-filled\n"
        << "  <output.pre.s8>       Fully preprocessed source (.include expanded) with ';@ file:line' markers\n"
        << "  <output.deb>          Debug map used by sophia8 for file:line breakpoints\n"
        << "\n"
        << "Key rules (strict):\n"
        << "  - Implicit entry stub at 0x0000..0x0002: JMP <entry>. User code/data must start >= 0x0003\n"
        << "  - .org <addr> sets absolute location (numeric literal only); .org (no operand) marks entry (once)\n"
        << "  - .include is textual, include-once is enforced, include cycles are errors\n"
        << "  - Labels are global and case-sensitive; duplicates and undefined labels are errors\n"
        << "  - .byte: numeric literals only; .word: literals or labels; .string: 7-bit ASCII with escapes\n"
        << "  - Any overlapping emission is an error\n"
        << "\n"
        << "Examples:\n"
        << "  " << prog << " main.s8 -o program.bin\n";
}

struct AsmError : public std::runtime_error {
    std::string file;
    int line_no;
    std::string line;
    std::vector<std::string> include_stack;
    AsmError(std::string msg,
             std::string file_,
             int line_no_,
             std::string line_,
             std::vector<std::string> stack = {})
        : std::runtime_error(std::move(msg)),
          file(std::move(file_)),
          line_no(line_no_),
          line(std::move(line_)),
          include_stack(std::move(stack)) {}
};

static inline std::string trim(const std::string& s) {
    size_t b = 0;
    while (b < s.size() && std::isspace((unsigned char)s[b])) b++;
    size_t e = s.size();
    while (e > b && std::isspace((unsigned char)s[e-1])) e--;
    return s.substr(b, e-b);
}

static inline bool starts_with(const std::string& s, const std::string& p) {
    return s.size() >= p.size() && std::memcmp(s.data(), p.data(), p.size()) == 0;
}

static inline std::vector<std::string> split_operands(const std::string& s) {
    std::vector<std::string> out;
    std::string cur;
    for (char ch : s) {
        if (ch == ',') {
            auto t = trim(cur);
            if (!t.empty()) out.push_back(t);
            cur.clear();
        } else {
            cur.push_back(ch);
        }
    }
    auto t = trim(cur);
    if (!t.empty()) out.push_back(t);
    return out; // trailing comma => last empty ignored
}

static inline bool is_ident(const std::string& s) {
    if (s.empty()) return false;
    if (!(std::isalpha((unsigned char)s[0]) || s[0]=='_')) return false;
    for (size_t i=1;i<s.size();++i) {
        char c = s[i];
        if (!(std::isalnum((unsigned char)c) || c=='_')) return false;
    }
    return true;
}

static inline uint32_t parse_int_literal(const std::string& s) {
    // hex 0x, bin 0b, else decimal
    if (s.size() >= 2 && s[0]=='0' && (s[1]=='x' || s[1]=='X')) {
        return std::stoul(s.substr(2), nullptr, 16);
    }
    if (s.size() >= 2 && s[0]=='0' && (s[1]=='b' || s[1]=='B')) {
        return std::stoul(s.substr(2), nullptr, 2);
    }
    return std::stoul(s, nullptr, 10);
}

static inline std::string join_stack(const std::vector<std::string>& st) {
    std::ostringstream oss;
    for (size_t i=0;i<st.size();++i) {
        oss << "  [" << i << "] " << st[i] << "\n";
    }
    return oss.str();
}
static inline bool is_hex_digit(char c) {
    return (c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F');
}
static inline uint8_t hex_val(char c) {
    if (c>='0'&&c<='9') return (uint8_t)(c-'0');
    if (c>='a'&&c<='f') return (uint8_t)(10 + (c-'a'));
    return (uint8_t)(10 + (c-'A'));
}


// ===========================
// ISA hardcoded
// ===========================
static const std::unordered_map<std::string, uint8_t> OPC = {
    {"HALT",0x00},{"LOAD",0x01},{"STORE",0x02},{"STORER",0x03},{"LOADR",0x1C},{"SET",0x04},
    {"INC",0x05},{"DEC",0x06},{"JMP",0x07},{"CMP",0x08},{"CMPR",0x09},
    {"JZ",0x0A},{"JNZ",0x0B},{"JC",0x0C},{"JNC",0x0D},{"ADD",0x0E},
    {"ADDR",0x0F},{"PUSH",0x10},{"POP",0x11},{"CALL",0x12},{"RET",0x13},
    {"SUB",0x14},{"SUBR",0x15},{"MUL",0x16},{"MULR",0x17},{"DIV",0x18},
    {"DIVR",0x19},{"SHL",0x1A},{"SHR",0x1B},{"NOP",0xFF},
};

static const std::unordered_map<std::string, int> ILEN = {
    {"HALT",1},{"NOP",1},{"RET",1},
    {"INC",2},{"DEC",2},{"PUSH",2},{"POP",2},
    {"JMP",3},{"CALL",3},{"JC",3},{"JNC",3},
    {"SET",3},{"ADD",3},{"SUB",3},{"CMP",3},{"CMPR",3},{"ADDR",3},{"SUBR",3},{"SHL",3},{"SHR",3},
    {"LOAD",4},{"STORE",4},{"STORER",4},{"LOADR",4},{"JZ",4},{"JNZ",4},{"MUL",4},{"MULR",4},{"DIV",4},{"DIVR",4},
};

static const std::unordered_map<std::string, uint8_t> REGTOK = {
    {"R0",0xF2},{"R1",0xF3},{"R2",0xF4},{"R3",0xF5},{"R4",0xF6},{"R5",0xF7},{"R6",0xF8},{"R7",0xF9},
    {"IP",0xFA},{"SP",0xFB},{"BP",0xFC},
};

static inline bool is_gpr(const std::string& r) {
    return r.size()==2 && r[0]=='R' && r[1]>='0' && r[1]<='7';
}

enum class OpKind { Addr16, Imm8, Gpr, AnyReg };

static const std::unordered_map<std::string, std::vector<OpKind>> SPECS = {
    {"LOAD",  {OpKind::Addr16, OpKind::Gpr}},
    {"STORE", {OpKind::Gpr, OpKind::Addr16}},
    {"STORER",{OpKind::Gpr, OpKind::Gpr, OpKind::Gpr}},
    {"LOADR", {OpKind::Gpr, OpKind::Gpr, OpKind::Gpr}},
    {"SET",   {OpKind::Imm8, OpKind::Gpr}},
    {"INC",   {OpKind::Gpr}},
    {"DEC",   {OpKind::Gpr}},
    {"JMP",   {OpKind::Addr16}},
    {"CALL",  {OpKind::Addr16}},
    {"RET",   {}},
    {"JZ",    {OpKind::Gpr, OpKind::Addr16}},
    {"JNZ",   {OpKind::Gpr, OpKind::Addr16}},
    {"JC",    {OpKind::Addr16}},
    {"JNC",   {OpKind::Addr16}},
    {"CMP",   {OpKind::Gpr, OpKind::Imm8}},
    {"CMPR",  {OpKind::Gpr, OpKind::Gpr}},
    {"ADD",   {OpKind::Imm8, OpKind::Gpr}},
    {"ADDR",  {OpKind::Gpr, OpKind::Gpr}},
    {"SUB",   {OpKind::Imm8, OpKind::Gpr}},
    {"SUBR",  {OpKind::Gpr, OpKind::Gpr}},
    {"MUL",   {OpKind::Imm8, OpKind::Gpr, OpKind::Gpr}},
    {"MULR",  {OpKind::Gpr, OpKind::Gpr, OpKind::Gpr}},
    {"DIV",   {OpKind::Imm8, OpKind::Gpr, OpKind::Gpr}},
    {"DIVR",  {OpKind::Gpr, OpKind::Gpr, OpKind::Gpr}},
    {"SHL",   {OpKind::Imm8, OpKind::Gpr}},
    {"SHR",   {OpKind::Imm8, OpKind::Gpr}},
    {"PUSH",  {OpKind::AnyReg}},
    {"POP",   {OpKind::AnyReg}},
    {"NOP",   {}},
    {"HALT",  {}},
};

// ===========================
// Preprocessor (.include)
// ===========================

struct SrcLine {
    std::string text;
    std::string file;
    int line_no;
    std::vector<std::string> include_stack; // entry -> ... -> current file
};

static std::string read_file_text(const fs::path& p) {
    std::ifstream in(p, std::ios::binary);
    if (!in) throw std::runtime_error("Cannot open file: " + p.string());
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

static fs::path canonical_or_absolute(const fs::path& p) {
    // canonical() fails if file doesn't exist; use absolute then weakly_canonical
    std::error_code ec;
    auto abs = fs::absolute(p, ec);
    if (ec) return p;
    auto wc = fs::weakly_canonical(abs, ec);
    if (ec) return abs;
    return wc;
}

static fs::path resolve_include(const fs::path& including_file,
                                const fs::path& entry_file,
                                const std::string& inc,
                                const SrcLine& at) {
    // inc is as in quotes
    fs::path rel = inc;
    if (rel.is_absolute()) {
        if (fs::exists(rel)) return canonical_or_absolute(rel);
        throw AsmError("Include file not found: " + rel.string(), at.file, at.line_no, at.text, at.include_stack);
    }
    fs::path p1 = including_file.parent_path() / rel;
    if (fs::exists(p1)) return canonical_or_absolute(p1);
    fs::path p2 = entry_file.parent_path() / rel;
    if (fs::exists(p2)) return canonical_or_absolute(p2);
    throw AsmError("Include file not found (searched: including dir, entry dir): " + rel.string(),
                   at.file, at.line_no, at.text, at.include_stack);
}

static void preprocess_file(const fs::path& file_path,
                            const fs::path& entry_file,
                            std::vector<SrcLine>& out,
                            std::vector<fs::path>& stack_paths,
                            std::unordered_set<std::string>& included_set,
                            std::vector<std::string> include_stack) {
    fs::path canon = canonical_or_absolute(file_path);
    std::string canon_s = canon.string();

    // cycle detection (stack)
    for (const auto& sp : stack_paths) {
        if (canonical_or_absolute(sp).string() == canon_s) {
            // cycle: report chain
            std::ostringstream msg;
            msg << "Include cycle detected:\n";
            for (const auto& p : stack_paths) msg << "  -> " << canonical_or_absolute(p).string() << "\n";
            msg << "  -> " << canon_s << "\n";
            throw AsmError(msg.str(), canon_s, 0, "", include_stack);
        }
    }

    // include-once strict: if already included anywhere, error
    if (included_set.find(canon_s) != included_set.end()) {
        throw AsmError("Multiple inclusion is forbidden (already included): " + canon_s,
                       canon_s, 0, "", include_stack);
    }
    included_set.insert(canon_s);

    stack_paths.push_back(canon);
    include_stack.push_back(canon_s);

    std::string text;
    try {
        text = read_file_text(canon);
    } catch (const std::exception& e) {
        throw AsmError(std::string("Failed to read include file: ") + e.what(), canon_s, 0, "", include_stack);
    }

    std::istringstream iss(text);
    std::string line;
    int line_no = 0;
    while (std::getline(iss, line)) {
        line_no++;
        SrcLine sl{line, canon_s, line_no, include_stack};

        // Strip comments for directive detection, but preserve original line for errors
        std::string code = trim(line.substr(0, line.find(';')));
        if (code.empty()) {
            out.push_back(sl);
            continue;
        }

        // Allow label: .include "x"
        // We'll look for ".include" after removing a leading label if present.
        std::string scan = code;
        while (true) {
            auto pos = scan.find(':');
            if (pos == std::string::npos) break;
            std::string lab = trim(scan.substr(0, pos));
            if (!is_ident(lab)) break;
            scan = trim(scan.substr(pos+1));
            // only peel one label; if multiple labels chained, peel again
            if (scan.empty()) break;
        }

        if (starts_with(scan, ".include")) {
            // format: .include "file.s8"
            std::string rest = trim(scan.substr(std::strlen(".include")));
            if (rest.size() < 2 || rest.front() != '"' || rest.back() != '"') {
                throw AsmError(R"(Invalid .include syntax. Expected: .include "file.s8")",
                               canon_s, line_no, line, include_stack);
            }
            std::string inc = rest.substr(1, rest.size()-2);
            fs::path inc_path = resolve_include(canon, entry_file, inc, sl);
            preprocess_file(inc_path, entry_file, out, stack_paths, included_set, include_stack);
            // Do not emit the .include line itself (textual include replaces it)
            continue;
        }

        out.push_back(sl);
    }

    stack_paths.pop_back();
    // include_stack is by value, no pop needed
}

// ===========================
// Assembler passes
// ===========================

static std::vector<uint8_t> decode_c_string(const std::string& quoted, const SrcLine& sl) {
    // quoted must be a full quoted string: "...." with no surrounding whitespace.
    if (quoted.size() < 2 || quoted.front() != '"' || quoted.back() != '"') {
        throw AsmError(R"(Invalid .string syntax. Expected: .string "text")", sl.file, sl.line_no, sl.text, sl.include_stack);
    }
    std::vector<uint8_t> out;
    for (size_t i = 1; i + 1 < quoted.size(); ++i) {
        unsigned char c = (unsigned char)quoted[i];
        if (c == '\\') {
            if (i + 1 >= quoted.size() - 1) {
                throw AsmError("Invalid escape at end of string", sl.file, sl.line_no, sl.text, sl.include_stack);
            }
            char n = quoted[++i];
            switch (n) {
                case '\\': out.push_back((uint8_t)'\\'); break;
                case '"':  out.push_back((uint8_t)'"'); break;
                case 'n':  out.push_back((uint8_t)0x0A); break;
                case 'r':  out.push_back((uint8_t)0x0D); break;
                case 't':  out.push_back((uint8_t)0x09); break;
                case '0':  out.push_back((uint8_t)0x00); break;
                case 'x': {
                    // require exactly two hex digits
                    if (i + 2 >= quoted.size() - 1) {
                        throw AsmError("Invalid \\xNN escape (needs two hex digits)", sl.file, sl.line_no, sl.text, sl.include_stack);
                    }
                    char h1 = quoted[i+1];
                    char h2 = quoted[i+2];
                    if (!is_hex_digit(h1) || !is_hex_digit(h2)) {
                        throw AsmError("Invalid \\xNN escape (non-hex digit)", sl.file, sl.line_no, sl.text, sl.include_stack);
                    }
                    uint8_t v = (uint8_t)((hex_val(h1) << 4) | hex_val(h2));
                    out.push_back(v);
                    i += 2;
                    break;
                }
                default:
                    throw AsmError(std::string("Unknown escape sequence: \\") + n, sl.file, sl.line_no, sl.text, sl.include_stack);
            }
        } else {
            if (c > 0x7F) {
                throw AsmError("Non-ASCII character in .string (only 7-bit ASCII allowed)", sl.file, sl.line_no, sl.text, sl.include_stack);
            }
            out.push_back((uint8_t)c);
        }
    }
    for (uint8_t b : out) {
        if (b > 0x7F) {
            throw AsmError("Non-ASCII byte in .string (value > 0x7F). Use only 7-bit ASCII.", sl.file, sl.line_no, sl.text, sl.include_stack);
        }
    }
    return out;
}

struct Item {
    enum class Kind { Dir, Ins } kind;
    std::string name;
    std::vector<std::string> ops;
    uint32_t addr = 0;
    int size = 0;
    SrcLine src;
};

static void throw_here(const std::string& msg, const SrcLine& sl) {
    throw AsmError(msg, sl.file, sl.line_no, sl.text, sl.include_stack);
}

static inline void require(bool cond, const std::string& msg, const SrcLine& sl) {
    if (!cond) throw_here(msg, sl);
}

static inline void emit_byte(std::vector<uint8_t>& img,
                             std::vector<uint8_t>& used,
                             uint32_t addr,
                             uint8_t val,
                             const SrcLine& sl) {
    require(addr < MEM_SIZE, "Emit address out of range: 0x" + ([](uint32_t a){std::ostringstream o;o<<std::hex<<std::uppercase<<a;return o.str();})(addr), sl);
    require(used[addr] == 0, "Overlap at address 0x" + ([](uint32_t a){std::ostringstream o;o<<std::hex<<std::uppercase<<a;return o.str();})(addr), sl);
    img[addr] = val;
    used[addr] = 1;
}

// ===========================
// Debug map (.deb)
// ===========================

struct DebRecord {
    enum class Kind { Code, Data } kind;
    uint32_t addr = 0;
    std::vector<uint8_t> bytes;
    // Source location and original line text.
    // For implicit/stub emissions, file will be "<implicit>" and line_no=0.
    std::string file;
    int line_no = 0;
    std::string text;
};

static inline void deb_push(std::vector<DebRecord>* deb,
                            DebRecord::Kind kind,
                            uint32_t addr,
                            const std::vector<uint8_t>& bytes,
                            const SrcLine& sl) {
    if (!deb) return;
    DebRecord r;
    r.kind = kind;
    r.addr = addr;
    r.bytes = bytes;
    r.file = sl.file;
    r.line_no = sl.line_no;
    r.text = sl.text;
    deb->push_back(std::move(r));
}

static inline void deb_push_implicit(std::vector<DebRecord>* deb,
                                     DebRecord::Kind kind,
                                     uint32_t addr,
                                     const std::vector<uint8_t>& bytes,
                                     const std::string& text) {
    if (!deb) return;
    DebRecord r;
    r.kind = kind;
    r.addr = addr;
    r.bytes = bytes;
    r.file = "<implicit>";
    r.line_no = 0;
    r.text = text;
    deb->push_back(std::move(r));
}

static inline uint32_t resolve_addr16(const std::string& tok,
                                      const std::unordered_map<std::string, uint32_t>& sym,
                                      const SrcLine& sl) {
    require(!tok.empty(), "Empty address operand", sl);
    require(tok[0] != '#', "Address operand must not start with '#'", sl);
    if (is_ident(tok)) {
        auto it = sym.find(tok);
        require(it != sym.end(), "Undefined label '" + tok + "'", sl);
        return it->second & 0xFFFF;
    }
    uint32_t v = 0;
    try { v = parse_int_literal(tok); }
    catch (...) { throw_here("Invalid address literal: " + tok, sl); }
    require(v <= 0xFFFF, "Address literal out of 16-bit range: " + tok, sl);
    return v;
}

static inline uint8_t resolve_imm8(const std::string& tok, const SrcLine& sl) {
    require(!tok.empty(), "Empty immediate operand", sl);
    require(tok[0] == '#', "Immediate operand must start with '#'", sl);
    uint32_t v = 0;
    try { v = parse_int_literal(tok.substr(1)); }
    catch (...) { throw_here("Invalid immediate literal: " + tok, sl); }
    require(v <= 0xFF, "Immediate out of 8-bit range: " + tok, sl);
    return (uint8_t)v;
}

static inline uint8_t resolve_reg(const std::string& tok, OpKind kind, const SrcLine& sl) {
    auto it = REGTOK.find(tok);
    require(it != REGTOK.end(), "Invalid register '" + tok + "'", sl);
    if (kind == OpKind::Gpr) {
        require(is_gpr(tok), "Register '" + tok + "' not allowed here (must be R0..R7)", sl);
    }
    return it->second;
}

static inline void emit_u16be(std::vector<uint8_t>& img,
                              std::vector<uint8_t>& used,
                              uint32_t& addr,
                              uint32_t v,
                              const SrcLine& sl) {
    emit_byte(img, used, addr++, (uint8_t)((v >> 8) & 0xFF), sl);
    emit_byte(img, used, addr++, (uint8_t)(v & 0xFF), sl);
}

static std::vector<uint8_t> assemble(const std::vector<SrcLine>& src_lines,
                                     std::vector<DebRecord>* deb_records = nullptr) {
    std::unordered_map<std::string, uint32_t> sym;
    std::vector<Item> items;

    uint32_t lc = 0x0003;
    bool any_org = false;
    bool entry_mark_present = false;
    std::optional<uint32_t> entry_mark_addr;
    std::optional<uint32_t> first_org_addr;

    // PASS 1: labels + layout
    for (const auto& sl : src_lines) {
        std::string raw = sl.text;
        std::string code = trim(raw.substr(0, raw.find(';')));
        if (code.empty()) continue;

        // parse labels (possibly multiple chained)
        while (true) {
            auto pos = code.find(':');
            if (pos == std::string::npos) break;
            std::string lab = trim(code.substr(0, pos));
            if (!is_ident(lab)) break;
            require(sym.find(lab) == sym.end(), "Duplicate label '" + lab + "'", sl);
            sym[lab] = lc;
            code = trim(code.substr(pos+1));
            if (code.empty()) break;
        }
        if (code.empty()) continue;

        if (code[0] == '.') {
            // directive
            std::string dname;
            std::string rest;
            {
                std::istringstream iss(code);
                iss >> dname;
                std::getline(iss, rest);
                rest = trim(rest);
            }
            auto ops = split_operands(rest);

            if (dname == ".org") {
                any_org = true;
                if (ops.empty()) {
                    require(!entry_mark_present, ".org (no operand) may appear only once", sl);
                    entry_mark_present = true;
                    entry_mark_addr = lc; // does not move LC
                    items.push_back(Item{Item::Kind::Dir, ".org", ops, lc, 0, sl});
                } else {
                    require(ops.size() == 1, ".org expects 0 or 1 operand", sl);
                    require(ops[0].size() > 0 && ops[0][0] != '#', ".org operand must not use '#'", sl);
                    require(!is_ident(ops[0]), ".org operand must be a numeric literal (labels not allowed)", sl);
                    uint32_t addr = 0;
                    try { addr = parse_int_literal(ops[0]); }
                    catch (...) { throw_here("Invalid .org address literal: " + ops[0], sl); }
                    require(addr <= 0xFFFF, ".org out of 16-bit range", sl);
                    require(addr >= 0x0003, ".org must be >= 0x0003", sl);
                    if (!first_org_addr.has_value()) first_org_addr = addr;
                    lc = addr;
                    items.push_back(Item{Item::Kind::Dir, ".org", ops, lc, 0, sl});
                }
            } else if (dname == ".string") {
                require(!rest.empty(), R"(.string expects a quoted string operand)", sl);
                auto bytes = decode_c_string(rest, sl);
                items.push_back(Item{Item::Kind::Dir, ".string", {rest}, lc, (int)bytes.size() + 1, sl});
                lc += (uint32_t)bytes.size() + 1;
            } else if (dname == ".byte") {
                require(!ops.empty(), ".byte requires at least 1 operand", sl);
                items.push_back(Item{Item::Kind::Dir, ".byte", ops, lc, (int)ops.size(), sl});
                lc += (uint32_t)ops.size();
            } else if (dname == ".word") {
                require(!ops.empty(), ".word requires at least 1 operand", sl);
                items.push_back(Item{Item::Kind::Dir, ".word", ops, lc, (int)ops.size() * 2, sl});
                lc += (uint32_t)ops.size() * 2;
            } else if (dname == ".include") {
                // Should have been expanded in preprocessing. If it remains, treat as error (strict).
                throw_here("Unexpected .include after preprocessing (internal error or malformed input).", sl);
            } else {
                throw_here("Unknown directive '" + dname + "'", sl);
            }

        } else {
            // instruction
            std::string mnem;
            std::string rest;
            {
                std::istringstream iss(code);
                iss >> mnem;
                std::getline(iss, rest);
                rest = trim(rest);
            }
            auto it = SPECS.find(mnem);
            require(it != SPECS.end(), "Unknown instruction '" + mnem + "'", sl);
            auto ops = split_operands(rest);
            require(ops.size() == it->second.size(),
                    mnem + " expects " + std::to_string(it->second.size()) + " operand(s)", sl);

            auto itlen = ILEN.find(mnem);
            require(itlen != ILEN.end(), "No length for instruction '" + mnem + "'", sl);
            int sz = itlen->second;

            items.push_back(Item{Item::Kind::Ins, mnem, ops, lc, sz, sl});
            lc += (uint32_t)sz;
        }

        require(lc <= MEM_SIZE, "Assembly exceeds MEM_SIZE (0xFFFF bytes)", sl);
    }

    require(any_org, "No .org found (mandatory; use .org <addr> and/or .org)", src_lines.empty() ? SrcLine{"","",0,{}} : src_lines.front());

    // Determine entry
    uint32_t entry = 0;
    if (entry_mark_present) {
        entry = entry_mark_addr.value();
    } else {
        require(first_org_addr.has_value(), "No .org <addr> found and no .org entry marker present", src_lines.empty() ? SrcLine{"","",0,{}} : src_lines.front());
        entry = first_org_addr.value();
    }

    // PASS 2: emit
    std::vector<uint8_t> img(MEM_SIZE, 0x00);
    std::vector<uint8_t> used(MEM_SIZE, 0x00);
    // reserve 0x0000..0x0002 for implicit entry stub
    used[0] = used[1] = used[2] = 1;

    for (const auto& it : items) {
        if (it.kind == Item::Kind::Dir) {
            if (it.name == ".org") continue;

            uint32_t addr = it.addr;
            if (it.name == ".byte") {
                std::vector<uint8_t> span;
                span.reserve(it.ops.size());
                for (const auto& op : it.ops) {
                    require(!op.empty(), ".byte empty operand", it.src);
                    require(op[0] != '#', ".byte elements must not use '#'", it.src);
                    require(!is_ident(op), ".byte does not allow labels", it.src);
                    uint32_t v = 0;
                    try { v = parse_int_literal(op); }
                    catch (...) { throw_here("Invalid .byte literal: " + op, it.src); }
                    require(v <= 0xFF, ".byte value out of 8-bit range: " + op, it.src);
                    span.push_back((uint8_t)v);
                    emit_byte(img, used, addr++, (uint8_t)v, it.src);
                }
                deb_push(deb_records, DebRecord::Kind::Data, it.addr, span, it.src);
            } else if (it.name == ".string") {
                require(it.ops.size() == 1, ".string expects exactly 1 operand", it.src);
                auto bytes = decode_c_string(it.ops[0], it.src);
                std::vector<uint8_t> span;
                span.reserve(bytes.size() + 1);
                for (uint8_t b : bytes) {
                    span.push_back(b);
                    emit_byte(img, used, addr++, b, it.src);
                }
                span.push_back(0x00);
                emit_byte(img, used, addr++, 0x00, it.src); // implicit terminator
                deb_push(deb_records, DebRecord::Kind::Data, it.addr, span, it.src);
            } else if (it.name == ".word") {
                std::vector<uint8_t> span;
                span.reserve(it.ops.size() * 2);
                for (const auto& op : it.ops) {
                    require(!op.empty(), ".word empty operand", it.src);
                    require(op[0] != '#', ".word elements must not use '#'", it.src);
                    uint32_t v = 0;
                    if (is_ident(op)) {
                        auto si = sym.find(op);
                        require(si != sym.end(), "Undefined label '" + op + "'", it.src);
                        v = si->second & 0xFFFF;
                    } else {
                        try { v = parse_int_literal(op); }
                        catch (...) { throw_here("Invalid .word literal: " + op, it.src); }
                        require(v <= 0xFFFF, ".word value out of 16-bit range: " + op, it.src);
                    }
                    span.push_back((uint8_t)((v >> 8) & 0xFF));
                    span.push_back((uint8_t)(v & 0xFF));
                    emit_u16be(img, used, addr, v, it.src);
                }
                deb_push(deb_records, DebRecord::Kind::Data, it.addr, span, it.src);
            }
            continue;
        }

        // instruction
        auto opit = OPC.find(it.name);
        require(opit != OPC.end(), "Unknown opcode for '" + it.name + "'", it.src);
        uint8_t opc = opit->second;

        uint32_t addr = it.addr;
        std::vector<uint8_t> span;
        span.reserve((size_t)it.size);
        span.push_back(opc);
        emit_byte(img, used, addr++, opc, it.src);

        auto spec = SPECS.at(it.name);

        auto get_addr = [&](const std::string& t)->uint32_t { return resolve_addr16(t, sym, it.src); };
        auto get_imm  = [&](const std::string& t)->uint8_t  { return resolve_imm8(t, it.src); };
        auto get_gpr  = [&](const std::string& t)->uint8_t  { return resolve_reg(t, OpKind::Gpr, it.src); };
        auto get_anyr = [&](const std::string& t)->uint8_t  { return resolve_reg(t, OpKind::AnyReg, it.src); };

        // Encode per mnemonic (fixed layouts)
        const std::string& m = it.name;

        if (m == "STORE") {
            uint8_t r = get_gpr(it.ops[0]);
            uint32_t a = get_addr(it.ops[1]);
            span.push_back(r);
            emit_byte(img, used, addr++, r, it.src);
            span.push_back((uint8_t)((a >> 8) & 0xFF));
            span.push_back((uint8_t)(a & 0xFF));
            emit_u16be(img, used, addr, a, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "LOAD") {
            uint32_t a = get_addr(it.ops[0]);
            uint8_t r = get_gpr(it.ops[1]);
            span.push_back((uint8_t)((a >> 8) & 0xFF));
            span.push_back((uint8_t)(a & 0xFF));
            emit_u16be(img, used, addr, a, it.src);
            span.push_back(r);
            emit_byte(img, used, addr++, r, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "JMP" || m == "CALL" || m == "JC" || m == "JNC") {
            uint32_t a = get_addr(it.ops[0]);
            span.push_back((uint8_t)((a >> 8) & 0xFF));
            span.push_back((uint8_t)(a & 0xFF));
            emit_u16be(img, used, addr, a, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "JZ" || m == "JNZ") {
            uint8_t r = get_gpr(it.ops[0]);
            uint32_t a = get_addr(it.ops[1]);
            span.push_back(r);
            emit_byte(img, used, addr++, r, it.src);
            span.push_back((uint8_t)((a >> 8) & 0xFF));
            span.push_back((uint8_t)(a & 0xFF));
            emit_u16be(img, used, addr, a, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "SET" || m == "ADD" || m == "SUB" || m == "SHL" || m == "SHR") {
            uint8_t imm = get_imm(it.ops[0]);
            uint8_t r = get_gpr(it.ops[1]);
            span.push_back(imm);
            span.push_back(r);
            emit_byte(img, used, addr++, imm, it.src);
            emit_byte(img, used, addr++, r, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "CMP") {
            uint8_t r = get_gpr(it.ops[0]);
            uint8_t imm = get_imm(it.ops[1]);
            span.push_back(r);
            span.push_back(imm);
            emit_byte(img, used, addr++, r, it.src);
            emit_byte(img, used, addr++, imm, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "INC" || m == "DEC") {
            uint8_t r = get_gpr(it.ops[0]);
            span.push_back(r);
            emit_byte(img, used, addr++, r, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "CMPR" || m == "ADDR" || m == "SUBR") {
            uint8_t r0 = get_gpr(it.ops[0]);
            uint8_t r1 = get_gpr(it.ops[1]);
            span.push_back(r0);
            span.push_back(r1);
            emit_byte(img, used, addr++, r0, it.src);
            emit_byte(img, used, addr++, r1, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "LOADR") {
            uint8_t rdst = get_gpr(it.ops[0]);
            uint8_t rhi  = get_gpr(it.ops[1]);
            uint8_t rlo  = get_gpr(it.ops[2]);
            span.push_back(rdst);
            span.push_back(rhi);
            span.push_back(rlo);
            emit_byte(img, used, addr++, rdst, it.src);
            emit_byte(img, used, addr++, rhi, it.src);
            emit_byte(img, used, addr++, rlo, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }

        if (m == "STORER") {
            uint8_t rsrc = get_gpr(it.ops[0]);
            uint8_t rhi = get_gpr(it.ops[1]);
            uint8_t rlo = get_gpr(it.ops[2]);
            span.push_back(rsrc);
            span.push_back(rhi);
            span.push_back(rlo);
            emit_byte(img, used, addr++, rsrc, it.src);
            emit_byte(img, used, addr++, rhi, it.src);
            emit_byte(img, used, addr++, rlo, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "MUL" || m == "DIV") {
            uint8_t imm = get_imm(it.ops[0]);
            uint8_t r1 = get_gpr(it.ops[1]);
            uint8_t r2 = get_gpr(it.ops[2]);
            span.push_back(imm);
            span.push_back(r1);
            span.push_back(r2);
            emit_byte(img, used, addr++, imm, it.src);
            emit_byte(img, used, addr++, r1, it.src);
            emit_byte(img, used, addr++, r2, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "MULR" || m == "DIVR") {
            uint8_t rsrc = get_gpr(it.ops[0]);
            uint8_t r1 = get_gpr(it.ops[1]);
            uint8_t r2 = get_gpr(it.ops[2]);
            span.push_back(rsrc);
            span.push_back(r1);
            span.push_back(r2);
            emit_byte(img, used, addr++, rsrc, it.src);
            emit_byte(img, used, addr++, r1, it.src);
            emit_byte(img, used, addr++, r2, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "PUSH" || m == "POP") {
            uint8_t r = get_anyr(it.ops[0]);
            span.push_back(r);
            emit_byte(img, used, addr++, r, it.src);
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }
        if (m == "NOP" || m == "HALT" || m == "RET") {
            // opcode only
            deb_push(deb_records, DebRecord::Kind::Code, it.addr, span, it.src);
            continue;
        }

        throw_here("Encoding not implemented for " + m, it.src);
    }

    // Emit implicit entry JMP at 0x0000
    img[0x0000] = OPC.at("JMP");
    img[0x0001] = (uint8_t)((entry >> 8) & 0xFF);
    img[0x0002] = (uint8_t)(entry & 0xFF);
    deb_push_implicit(
        deb_records,
        DebRecord::Kind::Code,
        0x0000,
        std::vector<uint8_t>{OPC.at("JMP"), (uint8_t)((entry >> 8) & 0xFF), (uint8_t)(entry & 0xFF)},
        "JMP <entry>"
    );

    return img;
}

// ===========================
// CLI
// ===========================

static void write_bin(const fs::path& out, const std::vector<uint8_t>& img) {
    std::ofstream f(out, std::ios::binary);
    if (!f) throw std::runtime_error("Cannot open output: " + out.string());
    f.write((const char*)img.data(), (std::streamsize)img.size());
    if (!f) throw std::runtime_error("Write failed: " + out.string());
}

// Write the fully-preprocessed source (all .include expanded) to a sidecar file.
// This is intended for debugging: it preserves original lines and adds only
// comment markers that record the originating file and line.
static void write_preprocessed(const fs::path& pre_out, const std::vector<SrcLine>& expanded) {
    std::ofstream f(pre_out, std::ios::binary);
    if (!f) throw std::runtime_error("Cannot open preprocessed output: " + pre_out.string());

    f << "; s8asm preprocessed output (all .include expanded)\n";
    f << "; This file is generated to aid debugging.\n\n";

    std::string last_file;
    for (const auto& sl : expanded) {
        if (sl.file != last_file) {
            f << "\n; ===== BEGIN FILE: " << sl.file << " =====\n";
            last_file = sl.file;
        }
        // Record origin for every line (as a comment) while keeping the
        // original line intact so the file can be re-assembled if needed.
        f << ";@ " << sl.file << ":" << sl.line_no << "\n";
        f << sl.text << "\n";
    }

    if (!f) throw std::runtime_error("Write failed: " + pre_out.string());
}

static fs::path default_debug_path(const fs::path& bin_out) {
    fs::path p = bin_out;
    // e.g. prog.bin -> prog.deb
    p.replace_extension(".deb");
    return p;
}

static std::string hex4(uint32_t v) {
    std::ostringstream o;
    o << std::hex << std::uppercase;
    o.width(4);
    o.fill('0');
    o << (v & 0xFFFF);
    return o.str();
}

static std::string hex2(uint32_t v) {
    std::ostringstream o;
    o << std::hex << std::uppercase;
    o.width(2);
    o.fill('0');
    o << (v & 0xFF);
    return o.str();
}

static void write_debug_map(const fs::path& deb_out,
                            const std::vector<DebRecord>& recs,
                            const fs::path& bin_out) {
    std::ofstream f(deb_out, std::ios::binary);
    if (!f) throw std::runtime_error("Cannot open debug output: " + deb_out.string());

    f << "; s8asm debug map (.deb)\n";
    f << "; This file is generated automatically and matches the emitted binary image exactly.\n";
    f << "; Binary: " << bin_out.string() << "\n";
    f << "; Format: AAAA  LEN  KIND  BYTES...  file:line: original source line\n\n";

    // Sort by address so output is deterministic.
    std::vector<DebRecord> sorted = recs;
    std::sort(sorted.begin(), sorted.end(), [](const DebRecord& a, const DebRecord& b) {
        if (a.addr != b.addr) return a.addr < b.addr;
        // Keep CODE before DATA at same address (should not happen due to overlap rules).
        return (int)a.kind < (int)b.kind;
    });

    for (const auto& r : sorted) {
        f << hex4(r.addr) << "  ";
        f.width(3);
        f.fill(' ');
        f << std::dec << (int)r.bytes.size() << "  ";
        f << (r.kind == DebRecord::Kind::Code ? "CODE" : "DATA") << "  ";

        for (size_t i = 0; i < r.bytes.size(); ++i) {
            f << hex2(r.bytes[i]);
            if (i + 1 < r.bytes.size()) f << ' ';
        }
        f << "  " << r.file << ":" << r.line_no << ": " << r.text << "\n";
    }

    if (!f) throw std::runtime_error("Write failed: " + deb_out.string());
}

static fs::path default_preprocessed_path(const fs::path& bin_out) {
    fs::path p = bin_out;
    // e.g. prog.bin -> prog.pre.s8
    p.replace_extension(".pre.s8");
    return p;
}

static void print_error(const AsmError& e) {
    std::cerr << "ERROR: " << e.what() << "\n";
    if (!e.file.empty()) {
        std::cerr << "At: " << e.file;
        if (e.line_no > 0) std::cerr << ":" << e.line_no;
        std::cerr << "\n";
    }
    if (!e.line.empty()) {
        std::cerr << ">> " << e.line << "\n";
    }
    if (!e.include_stack.empty()) {
        std::cerr << "Include stack:\n" << join_stack(e.include_stack);
    }
}

int main(int argc, char** argv) {
    try {
        if (argc >= 2) {
            const std::string a1 = argv[1];
            if (a1 == "-h" || a1 == "--help") {
                print_help(argv[0]);
                return 0;
            }
        }
        if (argc < 2) {
            print_help(argv[0]);
            return 2;
        }
        fs::path input = argv[1];
        fs::path output = "sophia8_image.bin";
        for (int i=2;i<argc;i++) {
            std::string a = argv[i];
            if (a=="-h" || a=="--help") {
                print_help(argv[0]);
                return 0;
            }
            if ((a=="-o" || a=="--output") && i+1 < argc) {
                output = argv[++i];
            } else {
                std::cerr << "Unknown argument: " << a << "\n";
                return 2;
            }
        }

        fs::path entry = canonical_or_absolute(input);
        std::vector<SrcLine> expanded;
        std::vector<fs::path> stack_paths;
        std::unordered_set<std::string> included_set;
        preprocess_file(entry, entry, expanded, stack_paths, included_set, {});

        // Always dump the fully-preprocessed source next to the output binary.
        // This helps debug issues that only show up after includes are expanded.
        write_preprocessed(default_preprocessed_path(output), expanded);

        std::vector<DebRecord> deb;
        auto img = assemble(expanded, &deb);
        write_bin(output, img);

        // Always dump debug map next to the binary.
        write_debug_map(default_debug_path(output), deb, output);
        std::cout << "OK: wrote " << img.size() << " bytes to " << output.string() << "\n";
        return 0;

    } catch (const AsmError& e) {
        print_error(e);
        return 1;
    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 1;
    }
}

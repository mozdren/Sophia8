#include "assembly_parser.h"

int main()
{
    auto commands = assembly_parser::parse_file(R"(C:\developement\Sophia8\test.asm)");
    return 0;
}

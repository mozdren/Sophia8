#pragma once

#include <string>
#include <vector>

namespace assembly_parser {

    class command_line_str
    {
    public:
        int line_number{};
        std::string label;
        std::string command;
        std::vector<std::string> parameters;
        std::string comments;
        std::string file;
    };

    std::string eat_string(command_line_str &cmd_str, const std::string& parameters_line);
    std::string eat_char(command_line_str &cmd_str, const std::string& parameters_line);
    void parse_params(command_line_str &cmd_str, const std::string& parameters_line);
    void parse_command(command_line_str &cmd_str, const std::string& clean_command_line);
    void parse_label(command_line_str &cmd_str, const std::string& clean_command_line);
    void parse_line(command_line_str &cmd_str, const std::string& command_line);
    std::vector<command_line_str> parse_file(const std::string& filename);

}

#include <fstream>

#include "assembly_parser.h"
#include "my_string.h"

namespace assembly_parser {

    std::string eat_string(command_line_str &cmd_str, const std::string& parameters_line)
    {
        auto string_trimmed = my_string::trim(parameters_line);
        if (string_trimmed.empty() || string_trimmed[0] != '"') return string_trimmed;
        const int pos = string_trimmed.find('"', 1);
        if (pos >= 0)
        {
            const auto out_string = my_string::trim(string_trimmed.substr(0, pos + 1));
            auto rest_string = my_string::trim(string_trimmed.substr(pos + 1));
            cmd_str.parameters.push_back(out_string);
            return rest_string;
        }
        return string_trimmed;
    }

    std::string eat_char(command_line_str &cmd_str, const std::string& parameters_line)
    {
        auto string_trimmed = my_string::trim(parameters_line);
        if (string_trimmed.size() < 3 || string_trimmed[0] != '\'' || string_trimmed[2] != '\'') return string_trimmed;
        const auto out_string = my_string::trim(string_trimmed.substr(0, 3));
        auto rest_string = my_string::trim(string_trimmed.substr(3));
        cmd_str.parameters.push_back(out_string);
        return rest_string;
    }

    void parse_params(command_line_str &cmd_str, const std::string& parameters_line)
    {
        if (my_string::trim(parameters_line).empty()) return;
        auto to_eat = parameters_line;
        to_eat = eat_string(cmd_str, to_eat);
        to_eat = eat_char(cmd_str, to_eat);
        int sep = to_eat.find(',');
        while (sep >= 0)
        {
            auto clean_param = my_string::trim(to_eat.substr(0, sep));
            if (!clean_param.empty()) cmd_str.parameters.push_back(clean_param);
            to_eat = to_eat.substr(sep + 1, to_eat.size());
            to_eat = eat_string(cmd_str, to_eat);
            to_eat = eat_char(cmd_str, to_eat);
            sep = to_eat.find(',');
        }
        auto to_eat_trimmed = my_string::trim(to_eat);
        if (!to_eat_trimmed.empty())
            cmd_str.parameters.push_back(to_eat_trimmed);
    }

    void parse_command(command_line_str &cmd_str, const std::string& clean_command_line)
    {
        const int sep = clean_command_line.find(' ');
        std::string params;
        if (sep >= 0)
        {
            cmd_str.command = my_string::to_upper(my_string::trim(clean_command_line.substr(0, sep)));
            parse_params(cmd_str, my_string::trim(clean_command_line.substr(sep + 1, clean_command_line.size())));
        }
        else
        {
            cmd_str.command = my_string::to_upper(my_string::trim(clean_command_line));
        }
    }

    void parse_label(command_line_str &cmd_str, const std::string& clean_command_line)
    {
        const int sep = clean_command_line.find(':');
        auto command = clean_command_line;
        if (sep >= 0)
        {
            command = clean_command_line.substr(sep + 1, clean_command_line.size());
            cmd_str.label = my_string::trim(clean_command_line.substr(0, sep));
        }
        parse_command(cmd_str, my_string::trim(command));
    }

    void parse_line(command_line_str &cmd_str, const std::string& command_line)
    {
        const int col_pos = command_line.find(';');
        auto command = command_line;
        if (col_pos >= 0)
        {
            cmd_str.comments = my_string::trim(command_line.substr(col_pos + 1, command_line.size()));
            command = command_line.substr(0, col_pos);
        }
        parse_label(cmd_str, my_string::trim(command));
    }

    std::vector<command_line_str> parse_file(const std::string& filename)
    {
        std::string line;
        std::ifstream source_file(filename);
        std::vector<command_line_str> parsed_commands;

        if (!source_file.is_open()) return parsed_commands;

        int line_number = 0;
        while (std::getline(source_file, line))
        {
            command_line_str cmd_str;
            if (!my_string::trim(line).empty())
            {
                parse_line(cmd_str, line);
                cmd_str.line_number = line_number;
                cmd_str.file = filename;
                if (!cmd_str.command.empty() || !cmd_str.label.empty()) {
                    parsed_commands.push_back(cmd_str);
                }
            }
            line_number++;
        }

        return parsed_commands;
    }

}

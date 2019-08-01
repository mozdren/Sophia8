#include <vector>
#include <fstream>
#include <string>
#include <cctype>

class command_line_str
{
public:
    int line_number{};
    std::string label;
    std::string command;
    std::vector<std::string> parameters;
    std::string comments;
};

std::string to_upper(const std::string &str)
{
    std::string ret = str;
    for (auto& c : ret) c = toupper(c);
    return ret;
}

std::string trim_left(const std::string &str)
{
    if (str.empty()) return "";
    for (unsigned i=0; i < str.size() ; i++)
    {
        if (!std::isspace(str[i]))
        {
            return str.substr(i, str.size());
        }
    }
    return "";
}

std::string trim_right(const std::string &str)
{
    if (str.empty()) return "";
    for (auto i = str.size() - 1; i > 0; i--)
    {
        if (!std::isspace(str[i]))
        {
            return str.substr(0, i + 1);
        }
    }
    return "";
}

std::string trim(const std::string &str)
{
    if (str.empty()) return "";
    return trim_left(trim_right(str));
}

std::string eat_string(command_line_str &cmd_str, const std::string& parameters_line)
{
    auto string_trimmed = trim(parameters_line);
    if (string_trimmed.empty() || string_trimmed[0] != '"') return string_trimmed;
    const int pos = string_trimmed.find('"', 1);
    if (pos >= 0)
    {
        const auto out_string = trim(string_trimmed.substr(0, pos + 1));
        auto rest_string = trim(string_trimmed.substr(pos + 1));
        cmd_str.parameters.push_back(out_string);
        return rest_string;
    }
    return string_trimmed;
}

std::string eat_char(command_line_str &cmd_str, const std::string& parameters_line)
{
    auto string_trimmed = trim(parameters_line);
    if (string_trimmed.size() < 3 || string_trimmed[0] != '\'' || string_trimmed[2] != '\'') return string_trimmed;
    const auto out_string = trim(string_trimmed.substr(0, 3));
    auto rest_string = trim(string_trimmed.substr(3));
    cmd_str.parameters.push_back(out_string);
    return rest_string;
}

void parse_params(command_line_str &cmd_str, const std::string& parameters_line)
{
    if (trim(parameters_line).empty()) return;
    auto to_eat = parameters_line;
    to_eat = eat_string(cmd_str, to_eat);
    to_eat = eat_char(cmd_str, to_eat);
    int sep = to_eat.find(',');
    while (sep >= 0)
    {
        auto clean_param = trim(to_eat.substr(0, sep));
        if (!clean_param.empty()) cmd_str.parameters.push_back(clean_param);
        to_eat = to_eat.substr(sep + 1, to_eat.size());
        to_eat = eat_string(cmd_str, to_eat);
        to_eat = eat_char(cmd_str, to_eat);
        sep = to_eat.find(',');
    }
    auto to_eat_trimmed = trim(to_eat);
    if (!to_eat_trimmed.empty())
        cmd_str.parameters.push_back(to_eat_trimmed);
}

void parse_command(command_line_str &cmd_str, const std::string& clean_command_line)
{
    const int sep = clean_command_line.find(' ');
    std::string params;
    if (sep >= 0)
    {
        cmd_str.command = to_upper(trim(clean_command_line.substr(0, sep)));
        parse_params(cmd_str, trim(clean_command_line.substr(sep + 1, clean_command_line.size())));
    }
    else 
    {
        cmd_str.command = to_upper(trim(clean_command_line));
    }
}

void parse_label(command_line_str &cmd_str, const std::string& clean_command_line)
{
    const int sep = clean_command_line.find(':');
    auto command = clean_command_line;
    if (sep >= 0)
    {
         command = clean_command_line.substr(sep + 1, clean_command_line.size());
         cmd_str.label = trim(clean_command_line.substr(0, sep));
    }
    parse_command(cmd_str, trim(command));
}

void parse_line(command_line_str &cmd_str, const std::string& command_line)
{
    const int col_pos = command_line.find(';');
    auto command = command_line;
    if (col_pos >= 0)
    {
        cmd_str.comments = trim(command_line.substr(col_pos + 1, command_line.size()));
        command = command_line.substr(0, col_pos);
    }
    parse_label(cmd_str, trim(command));
}

int main()
{
    std::string line;
    std::ifstream source_file("C:\\developement\\Sophia8\\test.asm");

    if (!source_file.is_open()) return 1;

    std::vector<command_line_str> parsed_commands;
    int line_number = 0;
    while (std::getline(source_file, line))
    {
        command_line_str cmd_str;
        if (!trim(line).empty())
        {
            parse_line(cmd_str, line);
            cmd_str.line_number = line_number;
            if (!cmd_str.command.empty() || !cmd_str.label.empty()) {
                parsed_commands.push_back(cmd_str);
            }
        }
        line_number++;
    }

    return 0;
}

#include <vector>
#include <fstream>
#include <string>
#include <iostream>
#include <cctype>

class command_line_str
{
public:
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
    for (auto i=0; i < str.size() ; i++)
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
    for (auto i = str.size() - 1; i >= 0; i--)
    {
        if (!std::isspace(str[i]))
        {
            return str.substr(0, i + 1);
        }
    }
}

std::string trim(const std::string &str)
{
    return trim_left(trim_right(str));
}

void parse_params(command_line_str &cmd_str, const std::string& parameters_line)
{
    if (trim(parameters_line).empty()) return;
    auto to_eat = parameters_line;
    int sep = to_eat.find(',');
    while (sep > 0)
    {
        cmd_str.parameters.push_back(trim(to_eat.substr(0, sep)));
        to_eat = to_eat.substr(sep + 1, to_eat.size());
        sep = to_eat.find(',');
    }
    cmd_str.parameters.push_back(trim(to_eat));
}

void parse_command(command_line_str &cmd_str, const std::string& clean_command_line)
{
    const int sep = clean_command_line.find(' ');
    std::string params;
    if (sep > 0)
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
    if (sep > 0)
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
    if (col_pos > 0)
    {
        cmd_str.comments = trim(command_line.substr(col_pos + 1, command_line.size()));
        command = command_line.substr(0, col_pos);
    }
    parse_label(cmd_str, trim(command));
}

int main()
{
    std::string line;
    std::ifstream source_file("C:\\developement\\Sophia8\\build\\Debug\\test.asm");

    if (!source_file.is_open()) return 1;

    std::vector<command_line_str> parsed_commands;

    while (std::getline(source_file, line))
    {
        command_line_str cmd_str;
        parse_line(cmd_str, line);
        parsed_commands.push_back(cmd_str);
    }

    return 0;
}

#pragma once

#include <string>

namespace my_string {
    std::string to_upper(const std::string &str);
    std::string trim_left(const std::string &str);
    std::string trim_right(const std::string &str);
    std::string trim(const std::string &str);
}

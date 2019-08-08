#include "my_string.h"
#include <cctype>

namespace my_string {

    std::string to_upper(const std::string &str)
    {
        std::string ret = str;
        for (auto& c : ret) c = toupper(c);
        return ret;
    }

    std::string trim_left(const std::string &str)
    {
        if (str.empty()) return "";
        for (unsigned i = 0; i < str.size(); i++)
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

}

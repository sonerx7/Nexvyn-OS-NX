// Header-heavy libstdc++ (GCC 15) code under clang 20: compile check only (build_clang.py compile stl_heavy.cpp).
// -DSTL_STD20 adds the C++20 pieces (ranges, span, format) to see where libstdc++ 15 and clang 20 disagree.
#include <algorithm>
#include <any>
#include <charconv>
#include <filesystem>
#include <map>
#include <memory_resource>
#include <optional>
#include <regex>
#include <sstream>
#include <string_view>
#include <unordered_map>
#include <variant>
#include <vector>
#ifdef STL_STD20
#include <format>
#include <ranges>
#include <span>
#endif

struct Visitor {
    int operator()(int v) const { return v; }
    int operator()(const std::string& s) const { return (int)s.size(); }
};

int stl_heavy(const char* text) {
    std::regex re("([a-z]+)=([0-9]+)");
    std::cmatch m;
    int total = 0;
    if (std::regex_search(text, m, re)) total += std::stoi(m[2].str());
    std::variant<int, std::string> v = std::string("abc");
    total += std::visit(Visitor{}, v);
    std::optional<int> o = 3;
    total += o.value_or(0);
    std::any a = 5;
    total += std::any_cast<int>(a);
    char buf[16];
    auto r = std::to_chars(buf, buf + sizeof buf, 1234);
    total += (int)(r.ptr - buf);
    std::pmr::monotonic_buffer_resource pool;
    std::pmr::vector<int> pv(&pool);
    pv.push_back(7);
    total += pv[0];
    std::filesystem::path p("/a/b/c.txt");
    total += (int)p.filename().string().size();
    std::ostringstream os;
    os << 12.5 << " " << total;
    std::unordered_map<std::string, std::vector<int>> um;
    um["x"].push_back(1);
    std::string str = os.str();
    std::string_view sv = str;
    total += (int)sv.size();
#ifdef STL_STD20
    std::vector<int> xs{1, 2, 3, 4};
    for (int x : xs | std::views::filter([](int i) { return i % 2 == 0; })) total += x;
    std::span<int> sp(xs);
    total += (int)sp.size();
    total += (int)std::format("{}-{}", 1, "two").size();
#endif
    return total;
}

export ZIG_LOCAL_CACHE_DIR := "./.cache/"

zig:
    zig run -lc -lglfw -lvulkan main.zig 2>&1

cpp:
    zig c++ vulkan-tutorial.cpp -lglfw -lvulkan -o cpp.out
    ./cpp.out 2>&1

build:
    zig build-exe -lc -lglfw -lvulkan main.zig -OReleaseSmall
    -mv ./main ./zig.out
    zig c++ vulkan-tutorial.cpp -lglfw -lvulkan -Oz -o cpp.out
    eza -l zig.out cpp.out

clean zig_cache_dir="":
    rm -f cpp.out zig.out
    [ -z {{zig_cache_dir}} ] || rm -rf {{ZIG_LOCAL_CACHE_DIR}}

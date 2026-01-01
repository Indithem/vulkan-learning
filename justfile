zig args="":
    zig run -lc -lglfw -lvulkan src/main.zig {{args}}

cpp:
    zig c++ vulkan-tutorial.cpp -lglfw -lvulkan -o cpp.out
    ./cpp.out 2>&1

build:
    zig build-exe -lc -lglfw -lvulkan main.zig -OReleaseSmall
    -mv ./main ./zig.out
    zig c++ vulkan-tutorial.cpp -lglfw -lvulkan -Oz -o cpp.out
    eza -l zig.out cpp.out

clean:
    rm -f cpp.out zig.out

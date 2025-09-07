default: run

build:
    gcc -g -o a.out ./main.c -lvulkan -Wall -lglfw

run: build
    ./a.out

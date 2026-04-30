const std = @import("std");
pub const c_std = @cImport({
    @cInclude("string.h");
    @cInclude("errno.h");
    @cInclude("sys/resource.h");
    @cInclude("stdio.h");
});
const Init = @import("Init.zig");
pub const c = @cImport({
    @cInclude("c.h");
});


const dbg_print = std.debug.print;
const assert = std.debug.assert;
var allocator_init = std.heap.DebugAllocator(.{
    // .verbose_log = true,
}).init;
pub const allocator = allocator_init.allocator();
pub var stdout: std.Io.Writer = undefined;
pub var stdin: std.Io.Reader = undefined;

pub const WIDTH = 1000;
pub const HEIGHT = 1000;

pub fn main() !void {

    var stdbuf: [1024*10]u8 = undefined;
	var stdout_writer = std.fs.File.stdout().writer(&stdbuf);
	try stdout_writer.file.lock(.exclusive);
	defer stdout_writer.file.unlock();
    stdout = stdout_writer.interface;

    var stdinbuf: [1024*10]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdinbuf);
    try stdin_reader.file.lock(.exclusive);
    defer stdin_reader.file.unlock();
    stdin = stdin_reader.interface;

    try test_print();

    var init = Init{};

    const init_usage = get_usage();
    dbg_print("Initial usage: {d}\n", .{init_usage});
{
    try init.create_instance();
    defer c.vkDestroyInstance(init.vk_instance, null);

    try init.get_appropriate_physical_device();
    defer allocator.free(init.physical_devices);

    try init.create_device();
    defer c.vkDestroyDevice(init.vk_device, null);

    try init.create_buffer();
    defer c.vmaDestroyAllocator(init.vma_allocator);
    // defer c.vmaDestroyBuffer(init.vma_allocator, init.buffer, init.buffer_allocation);

    // note: command_pool should be synchronised
    var command_pool: c.VkCommandPool = undefined;
    try vk_raise(c.vkCreateCommandPool(init.vk_device, &c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    }, null, &command_pool));
    defer c.vkDestroyCommandPool(init.vk_device, command_pool, null);

    // note: also be synchronised
    var prim_command_buffer: c.VkCommandBuffer = undefined;
    try vk_raise(c.vkAllocateCommandBuffers(init.vk_device, &c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = command_pool,
        .commandBufferCount = 1,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    }, &prim_command_buffer));
    defer c.vkFreeCommandBuffers(init.vk_device, command_pool, 1, &prim_command_buffer);

    var image: c.VkImage = undefined;
    var allocation: c.VmaAllocation = undefined;

    dbg_print("before_creating: {d}\n", .{get_usage()-init_usage});
    try vk_raise(c.vmaCreateImage(init.vma_allocator, 
        &c.VkImageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .format = c.VK_FORMAT_R8G8B8A8_UINT,
            .imageType = c.VK_IMAGE_TYPE_2D,
            .extent = c.VkExtent3D{
                .width = WIDTH,
                .height = HEIGHT,
                .depth = 1,
            },
            .usage = c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .tiling = c.VK_IMAGE_TILING_OPTIMAL,
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
        }, 
        &c.VmaAllocationCreateInfo{.usage = c.VMA_MEMORY_USAGE_AUTO}, 
        &image, &allocation, null));
    dbg_print("after creating: {d}\n", .{get_usage()-init_usage});
    
    c.vmaDestroyImage(init.vma_allocator, image, allocation);
    dbg_print("after destroying image: {d}\n", .{get_usage()-init_usage});
}
    dbg_print("after destroying all: {d}\n", .{get_usage()-init_usage});

    // stdin.discardAll(1);
    // dbg_print("discarded: {}\n", .{try stdin.discardRemaining()});
    std.debug.print("Done.\n", .{});
    if (!allocator_init.detectLeaks()) {dbg_print("No memory leaks found.\n", .{});}
    else {return error.LeaksFound;}
}

fn test_print() !void {
    const red_rgba: [WIDTH*HEIGHT*4]u8 = .{0xFF, 0x00, 0x00, 0xFF} ** (WIDTH * HEIGHT);
    const green_rgba: [WIDTH*HEIGHT*4]u8 = .{0x00, 0xFF, 0x00, 0xFF} ** (WIDTH * HEIGHT);
    const yellow_rgba: [WIDTH*HEIGHT*4]u8 = .{0xFF, 0xFF, 0x00, 0xFF} ** (WIDTH * HEIGHT);
    try print_color(red_rgba);
    std.Thread.sleep(1*std.time.ns_per_s);
    try print_color(yellow_rgba);
    std.Thread.sleep(1*std.time.ns_per_s);
    try print_color(green_rgba);
}

test "print colors" {
    var buf: [1024*10]u8 = undefined;
	var stdout_writer = std.fs.File.stdout().writer(&buf);
	try stdout_writer.file.lock(.exclusive);
	defer stdout_writer.file.unlock();
    stdout = stdout_writer.interface;

    try test_print();
}

pub fn print_color(buffer: [WIDTH * HEIGHT * 4]u8) !void {

	try stdout.print("\x1b[{};{}H", .{2+1, 0+1});
	try stdout.print("\x1b_Gi=1,q=1,m=1,a=T,f=32,s={d},v={d};\x1b\\", .{WIDTH, HEIGHT});

    var buf_encoded: [WIDTH*HEIGHT*4*2]u8 = undefined;
	const encoded = std.base64.standard.Encoder.encode(&buf_encoded, &buffer);
	var chunker = std.mem.window(u8, encoded, 4096, 4096);
    while (chunker.next()) |chunk| {
		try stdout.print("\x1b_Gi=1,m=1;", .{});
		try stdout.writeAll(chunk);
		try stdout.print("\x1b\\", .{});
    }
	try stdout.print("\x1b_Gi=1,m=0;\x1b\\", .{});


	try stdout.flush();
}

fn get_usage() c_long {
    var usage: c_std.rusage = undefined;

    if (c_std.getrusage(c_std.RUSAGE_SELF, &usage)!=0) {
        @panic("getrusage failed");   
    } else {
        return usage.unnamed_0.ru_maxrss;
    }
}

/// the return type for get_slice(), comptime
fn get_sliceT(function_to_call: anytype) type {
    // we are also asserting that `function_to_call` is a fn from .@"fn" enum field
    const args_type = @typeInfo(@TypeOf(function_to_call)).@"fn".params;
    const len = args_type.len;

    const array_of_T = args_type[len - 1].type.?;
    // similarly, we are also asserting that it's a [*c]T type
    const T = @typeInfo(array_of_T).@"pointer".child;
    return T;
}

pub fn get_slice(function_to_call: anytype, args: anytype, comptime T: type) ![]T {
    return get_slice_v1(function_to_call, args);
}

pub fn get_slice_v1(function_to_call: anytype, args: anytype) ![]get_sliceT(function_to_call) {
    // general structure:
    // var queue_family_count: u32 = undefined;
    // c.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_family_count, null);
    // const queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    // defer allocator.free(queue_families);
    // c.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_family_count, queue_families.ptr);

    const T = get_sliceT(function_to_call);
    var count: u32 = undefined;
    const ret = @call(.auto, function_to_call, args ++ .{&count, null});
    if (@TypeOf(ret) == c_int) try vk_raise(ret);
    const slice: []T = try allocator.alloc(T, count);
    const ret2 = @call(.auto, function_to_call, args ++ .{&count, slice.ptr});
    if (@TypeOf(ret2) == c_int) try vk_raise(ret2);

    return slice;
}

pub fn vk_raise(result: c.VkResult) !void {
    if (result != c.VK_SUCCESS) {
        dbg_print("Got error: {x}", .{result});
        return error.UnknownError;
    }
}
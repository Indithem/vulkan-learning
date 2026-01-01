const std = @import("std");
pub const c_std = @cImport({
    @cInclude("string.h");
});
const Init = @import("Init.zig");
pub const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    // @cDefine("GLFW_INCLUDE_VULKAN", {});
    // @cInclude("GLFW/glfw3.h");
});


const dbg_print = std.debug.print;
const assert = std.debug.assert;
var allocator_init = std.heap.DebugAllocator(.{
    // .verbose_log = true,
}).init;
pub const allocator = allocator_init.allocator();

const WIDTH = 800;
const HEIGHT = 600;

pub fn main() !void {
    defer {
        if (!allocator_init.detectLeaks())
            dbg_print("No memory leaks found.\n", .{});
    }

    var initializing_struct = Init{};

    try initializing_struct.create_instance();
    defer c.vkDestroyInstance(initializing_struct.vk_instance, null);

    try initializing_struct.get_appropriate_physical_device();
    defer allocator.free(initializing_struct.physical_devices);

    try initializing_struct.create_device();
    defer c.vkDestroyDevice(initializing_struct.vk_device, null);

    // const queue_families = try get_slice(c.vkGetPhysicalDeviceQueueFamilyProperties, c.VkQueueFamilyProperties, 
    //     .{initializing_struct.physical_devices[initializing_struct.req_device_idx]});
    // defer allocator.free(queue_families); 

    // const graphics_family_index = v: {
    //     var gfx_idx: u32 = 0;
    //     for (queue_families, 0..) |qf, i| {
    //         if (qf.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
    //             gfx_idx = @intCast(i);
    //             break;
    //         }
    //     }
    //     break :v gfx_idx;
    // };

    // const presentation_family_index = v:{
    //     var pres_idx: ?u32 = null;
    //     for (queue_families, 0..) |_, i| {
    //         var present_support: c.VkBool32 = 0;
    //         try vk_raise_uknown(c.vkGetPhysicalDeviceSurfaceSupportKHR(
    //             physical_devices[req_device_idx],
    //             @intCast(i),
    //             vk_surface,
    //             &present_support,
    //         ));
    //         if (present_support != 0) {
    //             pres_idx = @intCast(i);
    //             break;
    //         }
    //     }
    //     break :v try (pres_idx orelse VulkanErrors.NoPresentationSupport);
    // };

    // // const vk_device: c.VkDevice = v:{
    // //     var dev: c.VkDevice = undefined;
    // //     const queues: []const c.VkDeviceQueueCreateInfo = if (graphics_family_index != presentation_family_index) 
    // //     &[2]c.VkDeviceQueueCreateInfo{
    // //         .{
    // //             .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    // //             .queueFamilyIndex = graphics_family_index,
    // //             .queueCount = 1,
    // //             .pQueuePriorities = &@floatCast(1.0),
    // //         },
    // //         .{
    // //             .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    // //             .queueFamilyIndex = presentation_family_index,
    // //             .queueCount = 1,
    // //             .pQueuePriorities = &@floatCast(1.0),
    // //         }
    // //     } else &[1]c.VkDeviceQueueCreateInfo{
    // //         .{
    // //             .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    // //             .queueFamilyIndex = graphics_family_index,
    // //             .queueCount = 1,
    // //             .pQueuePriorities = &@floatCast(1.0),
    // //         }
    // //     };

    // //     try vk_raise(VulkanErrors.InitializingError, c.vkCreateDevice(
    // //         physical_devices[req_device_idx],
    // //         &c.VkDeviceCreateInfo{
    // //             .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    // //             .pQueueCreateInfos = queues.ptr,
    // //             .queueCreateInfoCount = @intCast(queues.len),
    // //             .enabledExtensionCount = needed_device_extensions.len,
    // //             .ppEnabledExtensionNames = &needed_device_extensions,
    // //             .enabledLayerCount = validation_layers.len,     // cannot verify if this works
    // //             .ppEnabledLayerNames  = &validation_layers,     // latest implementations ignore these 2
    // //             .pEnabledFeatures = null,
    // //         },
    // //         null,
    // //         &dev,
    // //     ));
    // //     break :v dev;
    // // };
    // // defer c.vkDestroyDevice(vk_device, null);
    
    // var graphics_queue: c.VkQueue = undefined;
    // c.vkGetDeviceQueue(vk_device, graphics_family_index, 0, &graphics_queue);

    // var presentation_queue: c.VkQueue = undefined;
    // c.vkGetDeviceQueue(vk_device, presentation_family_index, 0, &presentation_queue);

    // dbg_print("Created logical device and initialized queues.\n", .{});

    // while (glfw.glfwWindowShouldClose(window) == 0) : ({
    //     glfw.glfwPollEvents();
    // }) {
    //     break;  //FIXME: change
    // }


    std.debug.print("Done.\n", .{});
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
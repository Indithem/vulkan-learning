const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const c_std = @cImport({
    @cInclude("string.h");
});
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});


const dbg_print = std.debug.print;
var allocator_init = std.heap.DebugAllocator(.{
    // .verbose_log = true,
}).init;
const allocator = allocator_init.allocator();

var free_u32: u32 = undefined;
var free_usize: usize = undefined;

pub fn main() !void {
    defer {
        if (!allocator_init.detectLeaks())
            dbg_print("No memory leaks found.\n", .{});
    }

    try glfw_raise(GLFWErrors.InitializingError, glfw.glfwInit());
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);

    const window: *glfw.GLFWwindow = glfw.glfwCreateWindow(800, 600, "Test Window", null, null)
        orelse return GLFWErrors.InitializingError;
    defer glfw.glfwDestroyWindow(window);

    std.debug.print("Initialized GLFW, window={}.\n", .{window});

    // std.debug.print("Vulkan extensions supported (count) = {}\n", .{
    //     val:{
    //         var extensions_count: u32 = undefined;
    //         try vk_raise(VulkanErrors.UnknownError, vk.vkEnumerateInstanceExtensionProperties(null, &extensions_count, null));
    //         break :val extensions_count;
    //     }
    // });

    // PRETTYFYME:
    // struct type outside the val: block is preffered?
    const needed_extensions: [][*:0]const u8 = val:{
        var count: u32 = undefined;
        const c_ext = glfw.glfwGetRequiredInstanceExtensions(&count);

        var slice = try allocator.alloc([*:0]const u8, count+1);
        for (0..count) |i|
            slice[i] = c_ext[i];
            slice[count] = "VK_EXT_debug_utils";

        // dbg_print("Needed extensions (count) = {d}\n", .{slice.len});
        // for (slice, 0..) |str, i| {
        //     dbg_print("    {d}.{s}\n", .{i+1, str});
        // }

        break :val slice;
    };
    defer allocator.free(needed_extensions);

    var vk_instance: vk.VkInstance = undefined;

    const available_vk_layers: []vk.VkLayerProperties = val:{
        var count: u32 = undefined;
        try vk_raise(VulkanErrors.UnknownError, vk.vkEnumerateInstanceLayerProperties(&count, null));
        const slice: []vk.VkLayerProperties = try allocator.alloc(vk.VkLayerProperties, count);
        try vk_raise(VulkanErrors.UnknownError, vk.vkEnumerateInstanceLayerProperties(&count, slice.ptr));

        // dbg_print("All {} available validation layers:\n", .{count});
        // for (slice, 0..) |prop, i| {
        //     dbg_print("{d}-layerName= {s} specVersion={d} implementationVer={d} description={s}\n",
        //         .{i+1, prop.layerName, prop.specVersion, prop.implementationVersion, prop.description});
        // }

        break :val slice;
    };
    defer allocator.free(available_vk_layers);

    const validation_layers = [_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
        "VK_LAYER_MESA_device_select",
    };
    for (validation_layers) |layer| {
        if (!for (available_vk_layers) |avail| {
            if (c_std.strcmp(layer, &avail.layerName) == 0)
                break true;
        } else false) {
            dbg_print("Validation Layer = {s} is not available!\n", .{layer});
            return VulkanErrors.NoValidationSupport;
        }
    }

    try vk_raise(VulkanErrors.InitializingError, vk.vkCreateInstance(
        &vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &vk.VkApplicationInfo{
                .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .applicationVersion = vk.VK_MAKE_API_VERSION(1, 0, 0, 0),
                .engineVersion = vk.VK_MAKE_API_VERSION(1, 0, 0, 0),
                .apiVersion = vk.VK_API_VERSION_1_0,
                .pApplicationName = "idk",
                .pEngineName = "never used",
                // .pNext = null,
            },
            .enabledExtensionCount = @intCast(needed_extensions.len),
            .ppEnabledExtensionNames = needed_extensions.ptr,
            .enabledLayerCount = validation_layers.len,
            .ppEnabledLayerNames = &validation_layers,
            .pNext =
        &vk.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity =
                // vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType =
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = &struct {
                fn callback(
                    severity: vk.VkDebugUtilsMessageSeverityFlagsEXT,
                    msg_type: vk.VkDebugUtilsMessageTypeFlagBitsEXT,
                    data: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
                    user_data: ?*anyopaque
                ) callconv(.c) u32 {
                    _ = user_data;
                    _ = severity;
                    _ = msg_type;
                    // TODO: print these messages in different color.
                    dbg_print("validation layer: {s}\n", .{data.?.pMessage});
                    return 0;
                }
            }.callback,
        },
        },
        // Allocator, and VkInstance
        null, &vk_instance),
    );
    defer vk.vkDestroyInstance(vk_instance, null);

    std.debug.print("Initialized vulkan, instance={?}\n", .{vk_instance});

    try vk_raise(VulkanErrors.UnknownError, vk.vkEnumeratePhysicalDevices(vk_instance, &free_u32, null));
    const physical_devices = try allocator.alloc(vk.VkPhysicalDevice, free_u32);
    defer allocator.free(physical_devices);
    try vk_raise(VulkanErrors.UnknownError, vk.vkEnumeratePhysicalDevices(vk_instance, &free_u32, physical_devices.ptr));

    dbg_print("Found {d} devices:\n", .{physical_devices.len});

    free_usize = physical_devices.len;
    for (physical_devices, 0..) |dev, i| {
        var props: vk.VkPhysicalDeviceProperties = undefined;
        var feats: vk.VkPhysicalDeviceFeatures = undefined;
        vk.vkGetPhysicalDeviceProperties(dev, &props);
        vk.vkGetPhysicalDeviceFeatures(dev, &feats);
        if (props.deviceType==vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) free_usize=i;

        dbg_print("    {d}. Name = {s} (Integrated={})\n", .{i+1,
            props.deviceName,
            props.deviceType==vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU,
        });
        // dbg_print("{}\n", .{feats});
    }
    const req_device = physical_devices[free_usize];

    vk.vkGetPhysicalDeviceQueueFamilyProperties(req_device, &free_u32, null);
    const slice = try allocator.alloc(vk.VkQueueFamilyProperties, free_u32);
    defer allocator.free(slice);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(req_device, &free_u32, slice.ptr);
    free_usize = slice.len;
    for (slice, 0..) |s, i| if (s.queueFlags&vk.VK_QUEUE_GRAPHICS_BIT==vk.VK_QUEUE_GRAPHICS_BIT) {free_usize=i;};


    while (glfw.glfwWindowShouldClose(window) == 0) : ({
        glfw.glfwPollEvents();
    }) {
        break;  //FIXME: change
    }


    std.debug.print("Done.\n", .{});
}



const VulkanErrors = error {
    UnknownError,
    InitializingError,
    ExtensionNamesError,
    NoValidationSupport,
};

const GLFWErrors = error {
    UnknownError,
    InitializingError,
};

fn vk_raise(comptime err_type: VulkanErrors, expr_result:vk.VkResult) VulkanErrors!void {
    return switch (expr_result) {
        vk.VK_SUCCESS => {},
        vk.VK_ERROR_LAYER_NOT_PRESENT => VulkanErrors.NoValidationSupport,
        vk.VK_ERROR_EXTENSION_NOT_PRESENT => VulkanErrors.ExtensionNamesError,
        else => brk:{
            std.debug.print("vk_raise error: {}\n", .{expr_result});
            break :brk err_type;
        },
    };
}

fn glfw_raise(comptime err_type: GLFWErrors, expr_result:c_int) GLFWErrors!void {
    return switch (expr_result) {
        glfw.GLFW_TRUE => {},
        glfw.GLFW_FALSE => err_type,
        else => brk:{
            std.debug.print("glfw_raise error: {}\n", .{expr_result});
            break :brk err_type;
        },
    };
}

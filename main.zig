const std = @import("std");
const c_std = @cImport({
    @cInclude("string.h");
});
const glfw = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = glfw;


const dbg_print = std.debug.print;
var allocator_init = std.heap.DebugAllocator(.{
    // .verbose_log = true,
}).init;
const allocator = allocator_init.allocator();

var free_u32: u32 = undefined;
var free_usize: usize = undefined;

const WIDTH = 800;
const HEIGHT = 600;

pub fn main() !void {
    defer {
        if (!allocator_init.detectLeaks())
            dbg_print("No memory leaks found.\n", .{});
    }

    try glfw_raise(GLFWErrors.InitializingError, glfw.glfwInit());
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);

    const window: *glfw.GLFWwindow = glfw.glfwCreateWindow(WIDTH, HEIGHT, "Test Window", null, null)
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

        const needed_extensions = [_][*:0]const u8 {
            "VK_EXT_debug_utils",
        };

        var slice = try allocator.alloc([*:0]const u8, count+needed_extensions.len);
        for (0..count) |i| slice[i] = c_ext[i];
        for (needed_extensions, 0..) |a, i| slice[count+i] = a;

        // dbg_print("Needed extensions (count= {d})\n", .{slice.len});
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
        //     dbg_print("{d}-layerName={s} specVersion={d} implementationVer={d} description={s}\n",
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

    var vk_surface: vk.VkSurfaceKHR = undefined;
    try vk_raise(VulkanErrors.InitializingError, glfw.glfwCreateWindowSurface(
        vk_instance,
        window,
        null,
        &vk_surface,
    ));
    defer vk.vkDestroySurfaceKHR(vk_instance, vk_surface, null);

    std.debug.print("Initialized vulkan, instance={?}\n", .{vk_instance});

    try vk_raise(VulkanErrors.UnknownError, vk.vkEnumeratePhysicalDevices(vk_instance, &free_u32, null));
    const physical_devices = try allocator.alloc(vk.VkPhysicalDevice, free_u32);
    defer allocator.free(physical_devices);
    try vk_raise(VulkanErrors.UnknownError, vk.vkEnumeratePhysicalDevices(vk_instance, &free_u32, physical_devices.ptr));

    dbg_print("Found {d} devices\n", .{physical_devices.len});

    const needed_device_extensions = [_][*:0]const u8{
        vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };

    const req_device_idx = v:{
        var req_idx: usize = physical_devices.len;

        for (physical_devices, 0..) |dev, i| {
            var usable = true;
            defer if (usable) {
                req_idx = i;
            };

            var props: vk.VkPhysicalDeviceProperties = undefined;
            var feats: vk.VkPhysicalDeviceFeatures = undefined;
            vk.vkGetPhysicalDeviceProperties(dev, &props);
            vk.vkGetPhysicalDeviceFeatures(dev, &feats);
            if (props.deviceType!=vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) {
                dbg_print("{d} is not an iGPU\n", .{i});
                usable=false;
            }

            // dbg_print("    {d}. Name = {s} (Integrated={})\n", .{i+1,
            //     props.deviceName,
            //     props.deviceType==vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU,
            // });
            // dbg_print("{}\n", .{feats});

            var queue_family_count: u32 = undefined;
            vk.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_family_count, null);
            const queue_families = try allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
            defer allocator.free(queue_families);
            vk.vkGetPhysicalDeviceQueueFamilyProperties(dev, &queue_family_count, queue_families.ptr);
            // for (queue_families, 0..) |qf, j| {
            //     dbg_print("\t\t{d}. QueueFamily: Flags={x} Count={d} TimestampValidBits={d} VK_QUEUE_GRAPHICS_BIT={}\n", 
            //     .{j+1,
            //         qf.queueFlags,
            //         qf.queueCount,
            //         qf.timestampValidBits,
            //         qf.queueFlags&vk.VK_QUEUE_GRAPHICS_BIT!=0
            //     });
            // }

            var extensions_count: u32 = undefined;
            try vk_raise(VulkanErrors.UnknownError, 
                vk.vkEnumerateDeviceExtensionProperties(dev, null, &extensions_count, null));

            const extensions = try allocator.alloc(vk.VkExtensionProperties, extensions_count);
            defer allocator.free(extensions);
            try vk_raise(VulkanErrors.UnknownError, 
                vk.vkEnumerateDeviceExtensionProperties(dev, null, &extensions_count, extensions.ptr));

            for (needed_device_extensions) |need_ext| {
                var found = false;
                for (extensions) |ext| {
                    if (c_std.strcmp(need_ext, &ext.extensionName) == 0) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    usable = false;
                    dbg_print("{d} is missing device extension: {s}\n", .{i, need_ext});
                }
            }

            // query swapchain support details
            const needed_format: vk.VkSurfaceFormatKHR = .{
                .format = vk.VK_FORMAT_B8G8R8A8_SRGB,
                .colorSpace = vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            };
            const needed_present_mode: vk.VkPresentModeKHR = vk.VK_PRESENT_MODE_FIFO_KHR;
            {
                var capabilities: vk.VkSurfaceCapabilitiesKHR = undefined;
                try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
                    physical_devices[i],
                    vk_surface,
                    &capabilities,
                ));

                var foramt_count: u32 = undefined;
                try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfaceFormatsKHR(
                    physical_devices[i],
                    vk_surface,
                    &foramt_count,
                    null,
                ));
                const formats = try allocator.alloc(vk.VkSurfaceFormatKHR, foramt_count);
                defer allocator.free(formats);
                try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfaceFormatsKHR(
                    physical_devices[i],
                    vk_surface,
                    &foramt_count,
                    formats.ptr,
                ));

                var present_mode_count: u32 = undefined;
                try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfacePresentModesKHR(
                    physical_devices[i],
                    vk_surface,
                    &present_mode_count,
                    null,
                ));
                const present_modes = try allocator.alloc(vk.VkPresentModeKHR, present_mode_count);
                defer allocator.free(present_modes);
                try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfacePresentModesKHR(
                    physical_devices[i],
                    vk_surface,
                    &present_mode_count,
                    present_modes.ptr,
                ));

                // dbg_print("present modes = {any} formats = {any}\n", .{present_modes, formats});
                var format_found = false;
                for (formats) |fmt| {
                    if (fmt.format == needed_format.format and fmt.colorSpace == needed_format.colorSpace) {
                        format_found = true;
                        break;
                    }
                }
                if (!format_found) {
                    usable = false;
                    dbg_print("{d} does not have needed surface format.\n", .{i});
                }

                var present_mode_found = false;
                for (present_modes) |pm| {
                    if (pm == needed_present_mode) {
                        present_mode_found = true;
                        break;
                    }
                }
                if (!present_mode_found) {
                    usable = false;
                    dbg_print("{d} does not have needed present mode.\n", .{i});
                }
            }
        
        }
        
        break :v try if (req_idx!=physical_devices.len) req_idx else VulkanErrors.InitializingError;
    };
    dbg_print("Selected device index = {d}.\n", .{req_device_idx});

    const queue_families = val:{
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_devices[req_device_idx], &queue_family_count, null);
        const queue_families = try allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_devices[req_device_idx], &queue_family_count, queue_families.ptr);
        break :val queue_families;
    };
    defer allocator.free(queue_families); 

    const graphics_family_index = v: {
        var gfx_idx: u32 = 0;
        for (queue_families, 0..) |qf, i| {
            if (qf.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                gfx_idx = @intCast(i);
                break;
            }
        }
        break :v gfx_idx;
    };

    const presentation_family_index = v:{
        var pres_idx: ?u32 = null;
        for (queue_families, 0..) |_, i| {
            var present_support: vk.VkBool32 = 0;
            try vk_raise_uknown(vk.vkGetPhysicalDeviceSurfaceSupportKHR(
                physical_devices[req_device_idx],
                @intCast(i),
                vk_surface,
                &present_support,
            ));
            if (present_support != 0) {
                pres_idx = @intCast(i);
                break;
            }
        }
        break :v try (pres_idx orelse VulkanErrors.NoPresentationSupport);
    };

    const vk_device: vk.VkDevice = v:{
        var dev: vk.VkDevice = undefined;
        const queues: []const vk.VkDeviceQueueCreateInfo = if (graphics_family_index != presentation_family_index) 
        &[2]vk.VkDeviceQueueCreateInfo{
            .{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = graphics_family_index,
                .queueCount = 1,
                .pQueuePriorities = &@floatCast(1.0),
            },
            .{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = presentation_family_index,
                .queueCount = 1,
                .pQueuePriorities = &@floatCast(1.0),
            }
        } else &[1]vk.VkDeviceQueueCreateInfo{
            .{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = graphics_family_index,
                .queueCount = 1,
                .pQueuePriorities = &@floatCast(1.0),
            }
        };

        try vk_raise(VulkanErrors.InitializingError, vk.vkCreateDevice(
            physical_devices[req_device_idx],
            &vk.VkDeviceCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pQueueCreateInfos = queues.ptr,
                .queueCreateInfoCount = @intCast(queues.len),
                .enabledExtensionCount = needed_device_extensions.len,
                .ppEnabledExtensionNames = &needed_device_extensions,
                .enabledLayerCount = validation_layers.len,     // cannot verify if this works
                .ppEnabledLayerNames  = &validation_layers,     // latest implementations ignore these 2
                .pEnabledFeatures = null,
            },
            null,
            &dev,
        ));
        break :v dev;
    };
    defer vk.vkDestroyDevice(vk_device, null);
    
    var graphics_queue: vk.VkQueue = undefined;
    vk.vkGetDeviceQueue(vk_device, graphics_family_index, 0, &graphics_queue);

    var presentation_queue: vk.VkQueue = undefined;
    vk.vkGetDeviceQueue(vk_device, presentation_family_index, 0, &presentation_queue);

    dbg_print("Created logical device and initialized queues.\n", .{});

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
    NoPresentationSupport,
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

fn vk_raise_uknown(expr_result:vk.VkResult) VulkanErrors!void {
    return vk_raise(VulkanErrors.UnknownError, expr_result);
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

/// This struct abstracts away all biolerplate initalization code.
/// Helps form proper structure.

const std = @import("std");
const main = @import("main.zig");
const Self = @This();

const dbg_print = std.debug.print;

const allocator = main.allocator;
const vk_raise = main.vk_raise;
const get_slice = main.get_slice;
const get_slice_v1 = main.get_slice_v1;
const c = main.c;

vk_instance: c.VkInstance = undefined,
vk_device: c.VkDevice = undefined,
vk_device_queue_family_index: usize = undefined,
physical_devices: []c.VkPhysicalDevice = &.{},
req_device_idx: usize = undefined,

fn supported_extensions() void {
    // std.debug.print("Vulkan extensions supported (count) = {}\n", .{
    //     val:{
    //         var extensions_count: u32 = undefined;
    //         try vk_raise(VulkanErrors.UnknownError, c.vkEnumerateInstanceExtensionProperties(null, &extensions_count, null));
    //         break :val extensions_count;
    //     }
    // });
}

pub fn create_instance(self: *Self) !void {
	const enabled_extensions = [_][*:0]const u8{
		"VK_EXT_debug_utils",
	};

    const validation_layers = [_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
        "VK_LAYER_MESA_device_select",
    };

    try vk_raise(c.vkCreateInstance(
        // TODO: zero initialize properly
        &std.mem.zeroInit(c.VkInstanceCreateInfo, c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &c.VkApplicationInfo{
                .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .applicationVersion = c.VK_MAKE_API_VERSION(1, 0, 0, 0),
                .engineVersion = c.VK_MAKE_API_VERSION(1, 0, 0, 0),
                .apiVersion = c.VK_API_VERSION_1_0,
                .pApplicationName = "idk",
                .pEngineName = "never used",
                // .pNext = null,
            },
            .enabledExtensionCount = @intCast(enabled_extensions.len),
            .ppEnabledExtensionNames = &enabled_extensions,
            .enabledLayerCount = validation_layers.len,
            .ppEnabledLayerNames = &validation_layers,
            .pNext =
        &std.mem.zeroInit(c.VkDebugUtilsMessengerCreateInfoEXT, c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity =
                // c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType =
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = &struct {
                fn callback(
                    severity: c.VkDebugUtilsMessageSeverityFlagsEXT,
                    msg_type: c.VkDebugUtilsMessageTypeFlagBitsEXT,
                    data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
                    user_data: ?*anyopaque
                ) callconv(.c) u32 {
                    _ = user_data;
                    _ = msg_type;
                    // TODO: print these messages in different color.
					const color = v: switch (severity) {
						c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "\u{001b}[34m",
						c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "\u{001b}[32m",
						c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "\u{001b}[33m",
						c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT  => "\u{001b}[31m",
						else => {
							dbg_print("New severity found: {x}\n", .{severity});
							break :v "\u{001b}[34m";
						}
					};
                    dbg_print("{s} validation layer: {s} \u{001b}[0m\n", .{color, data.?.pMessage});
                    return 0;
                }
            }.callback,
        }),
        }),
        // Allocator, and VkInstance
        null, &self.vk_instance));	
}

pub fn get_appropriate_physical_device(self: *Self) !void {
	self.physical_devices = try get_slice_v1(c.vkEnumeratePhysicalDevices, .{self.vk_instance});

	dbg_print("Found {d} devices\n", .{self.physical_devices.len});

    const needed_device_extensions = [_][*:0]const u8{
        c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };

    self.req_device_idx = self.physical_devices.len;
    
    for (self.physical_devices, 0..) |dev, i| {
        var usable = true;
        defer if (usable) {
            self.req_device_idx = i;
        };

        var props: c.VkPhysicalDeviceProperties = undefined;
        var feats: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceProperties(dev, &props);
        c.vkGetPhysicalDeviceFeatures(dev, &feats);
        if (props.deviceType!=c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) {
            dbg_print("rejecting {d}.{s}, is not an iGPU\n", .{i, props.deviceName});
            usable=false;
        }

        const extensions = try get_slice_v1(c.vkEnumerateDeviceExtensionProperties, .{dev, null});
        defer allocator.free(extensions);

        // O(n^2) search
        for (needed_device_extensions) |need_ext| {
            var found = false;
            for (extensions) |ext| {
                if (main.c_std.strcmp(need_ext, &ext.extensionName) == 0) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                usable = false;
                dbg_print("rejecting {d}.{s}, is missing device extension: {s}\n", .{i, props.deviceName, need_ext});
            }
        }
    }           

    if (self.req_device_idx == self.physical_devices.len) {
        return error.NoDeviceSuffices;
    }
	
    dbg_print("Selected device index = {d}.\n", .{self.req_device_idx});
}

pub fn create_device(self: *Self) !void {
	const queues = try get_slice(c.vkGetPhysicalDeviceQueueFamilyProperties, 
		.{self.physical_devices[self.req_device_idx]}, c.VkQueueFamilyProperties);
	defer allocator.free(queues);

	var needed_queue_idx = queues.len;
	for (queues, 0..) |qf, i| {
		if (qf.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
			needed_queue_idx = i;
			break;
		}
	}
	if (needed_queue_idx == queues.len) {
		return error.NoGraphicsQueueFound;
	}

	try vk_raise(c.vkCreateDevice(
		self.physical_devices[self.req_device_idx], 
		&c.VkDeviceCreateInfo {
			.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
			.queueCreateInfoCount = 1,
			.pQueueCreateInfos = &[_]c.VkDeviceQueueCreateInfo{
				.{
					.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
					.queueFamilyIndex = @intCast(needed_queue_idx),
					.queueCount = 1,
					.pQueuePriorities = &@as(f32, 1.0),
				},
			},
			.enabledExtensionCount = 0,
			.ppEnabledExtensionNames = null,
			.pEnabledFeatures = null,
		},
		null, &self.vk_device)
	);	

    self.vk_device_queue_family_index = needed_queue_idx;
}
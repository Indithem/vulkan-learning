const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});

const dbg_print = std.debug.print;


pub fn main() !void {

    try glfw_raise(GLFWErrors.InitializingError, glfw.glfwInit());
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);

    const window: *glfw.GLFWwindow = glfw.glfwCreateWindow(800, 600, "Test Window", null, null)
        orelse return GLFWErrors.InitializingError;
    defer glfw.glfwDestroyWindow(window);

    std.debug.print("Initialized GLFW, window={}.\n", .{window});

    std.debug.print("Vulkan extensions supported (count) = {}\n", .{
        val:{
            var extensions_count: u32 = undefined;
            try vk_raise(VulkanErrors.UnknownError, vk.vkEnumerateInstanceExtensionProperties(null, &extensions_count, null));
            break :val extensions_count;
        }
    });

    // PRETTYFYME:
    // struct type outside the val: block is preffered?
    const glfw_extensions = val:{
        var count: u32 = undefined;
        const c_ext = glfw.glfwGetRequiredInstanceExtensions(&count);

        dbg_print("GLFW extensions needed (count) = {d}\n", .{count});
        for (c_ext, 0..count) |cstr, i| {
            dbg_print("    {d}.{s}\n", .{i+1, cstr});
        }

        break :val struct {count: u32, extensions: [*][*c]const u8} {
            .count = count,
            .extensions = c_ext,
        };
    };

    var vk_instance: vk.VkInstance = undefined;

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
            .enabledExtensionCount = glfw_extensions.count,
            .ppEnabledExtensionNames = glfw_extensions.extensions,
            .enabledLayerCount = 0,
            // .pNext = null,
        },
        // Allocator, and VkInstance
        null, &vk_instance),
    );
    defer vk.vkDestroyInstance(vk_instance, null);

    std.debug.print("Initialized vulkan, instance={?}\n", .{vk_instance});


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
};

const GLFWErrors = error {
    UnknownError,
    InitializingError,
};

fn vk_raise(comptime err_type: VulkanErrors, expr_result:vk.VkResult) VulkanErrors!void {
    return switch (expr_result) {
        vk.VK_SUCCESS => {},
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

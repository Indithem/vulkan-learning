import glfw
import vulkan as vk
from typing import List
from pprint import pprint
from cffi import FFI

ffi = FFI()


def debug_callback(severity, msg_type, data, usr_data):
    message = ffi.string(data.pMessage).decode('utf-8')
    print("Called from debug", message)
    return 0


def main():
    glfw.init()

    glfw.window_hint(glfw.CLIENT_API, glfw.NO_API)
    glfw.window_hint(glfw.RESIZABLE, glfw.FALSE)

    window = glfw.create_window(800, 600, "Title of window", None, None)

    print("Made a glfw window", window)

    needed_extensions: List[str] = glfw.get_required_instance_extensions()
    needed_extensions.append("VK_EXT_debug_utils")

    vk_layers_available = vk.vkEnumerateInstanceLayerProperties()
    vk_layers_available = [str(i.layerName) for i in vk_layers_available]
    # pprint(vk_layers_available)
    vk_layers_needed = [
        "VK_LAYER_KHRONOS_validation",
        "VK_LAYER_MESA_device_select",
    ]
    for i in vk_layers_needed:
        if i not in vk_layers_available:
            print(i, "is not available.")
            pprint(vk_layers_available)

    instance = vk.vkCreateInstance(
        vk.VkInstanceCreateInfo(
            pApplicationInfo=vk.VkApplicationInfo(
                pApplicationName="app name",
                pEngineName="engine name",
            ),
            ppEnabledExtensionNames=needed_extensions,
            ppEnabledLayerNames=vk_layers_needed,
            pNext=vk.VkDebugUtilsMessengerCreateInfoEXT(
                messageSeverity=vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
                messageType=vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                            vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                            vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                pfnUserCallback=debug_callback,
            )
        ), None
    )

    print("Made vulkan instance", instance)

    physical_devices = list(vk.vkEnumeratePhysicalDevices(instance))
    physical_devices_properties = [vk.vkGetPhysicalDeviceProperties(dev) for dev in physical_devices]
    physical_devices_features = [vk.vkGetPhysicalDeviceFeatures(dev) for dev in physical_devices]

    for i, (dev, prop, feat) in enumerate(
            zip(physical_devices, physical_devices_properties, physical_devices_features)):
        print(
            f"\t{i + 1}. Name = {prop.deviceName} (Integrated={prop.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU})")

    glfw.terminate()


if __name__ == "__main__":
    main()

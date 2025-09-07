#include <GLFW/glfw3.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

unsigned int validation_layer_callback(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    VkDebugUtilsMessageTypeFlagBitsEXT msg_type,
    const struct VkDebugUtilsMessengerCallbackDataEXT *data, void *usr_data) {

  printf("Validation layer: %s\n", data->pMessage);

  return 0;
}

int main() {
  glfwInit();

  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

  GLFWwindow *const window =
      glfwCreateWindow(800, 600, "Fancy Title!", NULL, NULL);

  const char *validation_layers[] = {
      "VK_LAYER_KHRONOS_validation",
      "VK_LAYER_MESA_device_select",
  };
  const uint32_t validation_layers_cnt =
      sizeof(validation_layers) / sizeof(char *);

  // printf("needed extensions:\n");
  // for (int i=0; i<needed_extensions_cnt; i++)
  //     printf("%s\n", needed_extensions[i]);

  uint32_t vk_layers_cnt;
  VkLayerProperties *vk_layers;
  vkEnumerateInstanceLayerProperties(&vk_layers_cnt, NULL);
  vk_layers = malloc(vk_layers_cnt * sizeof(VkLayerProperties));
  vkEnumerateInstanceLayerProperties(&vk_layers_cnt, vk_layers);

  // uint32_t vk_extensions_cnt;
  // VkExtensionProperties *vk_extensions;
  // vkEnumerateDeviceExtensionProperties(, const char *pLayerName, uint32_t
  // *pPropertyCount, VkExtensionProperties *pProperties)

  // printf("available layers:\n");
  // for (int i = 0; i < vk_layers_cnt; i++)
  //   printf("%s\n", vk_layers[i].layerName);

  for (int it_needed = 0; it_needed < validation_layers_cnt; it_needed++) {
    int found = 0;
    for (int it_aval = 0; it_aval < vk_layers_cnt; it_aval++)
      if (strcmp(vk_layers[it_aval].layerName, validation_layers[it_needed]) ==
          0) {
        found = 1;
        break;
      }
    if (!found) {
      printf("Couldn't have layer %s\n", validation_layers[it_needed]);
      exit(1);
    }
  }

  uint32_t needed_extensions_cnt;
  const char **glfw_needed_extensions =
      glfwGetRequiredInstanceExtensions(&needed_extensions_cnt);
  const char **needed_extensions =
      malloc((needed_extensions_cnt + 1) * sizeof(char *));
  for (int i = 0; i < needed_extensions_cnt; i++)
    needed_extensions[i] = glfw_needed_extensions[i];
  needed_extensions[needed_extensions_cnt++] = "VK_EXT_debug_utils";


  VkInstance instance;
  vkCreateInstance(
      &(VkInstanceCreateInfo){
          .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
          .pApplicationInfo =
              &(VkApplicationInfo){
                  .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                  .applicationVersion = VK_API_VERSION_1_0,
                  .pApplicationName = "app name",
                  .pEngineName = "engine name",
              },
          .enabledExtensionCount = needed_extensions_cnt,
          .ppEnabledExtensionNames = needed_extensions,
          .enabledLayerCount = sizeof(validation_layers) / sizeof(char *),
          .ppEnabledLayerNames = validation_layers,
          .pNext =
              &(VkDebugUtilsMessengerCreateInfoEXT){
                  .sType =
                      VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                  .messageSeverity =
                      VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                      VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
                  .messageType =
                      VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                      VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                      VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                  .pfnUserCallback = validation_layer_callback,
              },
      },
      NULL, &instance);

  vkDestroyInstance(instance, NULL);
  glfwDestroyWindow(window);
}

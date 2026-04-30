Below is **high-level, step-by-step pseudocode** for rendering a **triangle into a CPU-accessible image buffer using Vulkan shaders**, assuming:

* `VkInstance`, `VkPhysicalDevice`, and `VkDevice` already exist
* You want **offscreen rendering** (no swapchain)
* Final pixels are readable on CPU

I’ll keep this **conceptual + ordered**, not API-noisy.

---

## Part 1 — Render a triangle into a CPU-accessible image

### 0. Choose queue + command infrastructure

```
select graphics queue family
get VkQueue (graphics)

create command pool (graphics queue family)
allocate primary command buffer
```

---

### 1. Create target image (CPU-readable)

Goal: an image you can copy back to CPU.

```
create VkImage:
    format = RGBA8 (or similar)
    usage = COLOR_ATTACHMENT | TRANSFER_SRC
    tiling = OPTIMAL
    extent = (width, height, 1)

allocate device-local memory
bind image memory
```

Create a **staging buffer** for readback:

```
create VkBuffer:
    usage = TRANSFER_DST
    size = width * height * 4

allocate HOST_VISIBLE | HOST_COHERENT memory
bind buffer memory
```

---

### 2. Create image view

```
create VkImageView for the color image
```

---

### 3. Create render pass (offscreen)

```
attachment:
    format = RGBA8
    loadOp = CLEAR
    storeOp = STORE
    initialLayout = UNDEFINED
    finalLayout = TRANSFER_SRC_OPTIMAL

subpass:
    color attachment = attachment 0
```

---

### 4. Create framebuffer

```
framebuffer:
    renderPass
    attachments = [image view]
    extent = (width, height)
```

---

### 5. Create shaders

You need SPIR-V.

**Vertex shader (triangle positions hardcoded or via vertex buffer)**

```
inputs: vertex position
outputs: clip-space position
```

**Fragment shader**

```
output constant color
```

Load shaders:

```
create VkShaderModule (vertex)
create VkShaderModule (fragment)
```

---

### 6. Pipeline layout

No descriptors needed for now.

```
create VkPipelineLayout (empty)
```

---

### 7. Graphics pipeline

```
pipeline stages:
    vertex shader
    fragment shader

fixed function:
    input assembly = TRIANGLE_LIST
    viewport = full image
    scissor = full image
    rasterizer = fill
    multisampling = off
    color blend = disabled

renderPass = offscreen render pass
subpass = 0
```

---

### 8. Record command buffer

```
begin command buffer

transition image:
    UNDEFINED → COLOR_ATTACHMENT_OPTIMAL

begin render pass
    clear color buffer
    bind graphics pipeline
    draw 3 vertices
end render pass

transition image:
    COLOR_ATTACHMENT_OPTIMAL → TRANSFER_SRC_OPTIMAL

copy image → staging buffer

end command buffer
```

---

### 9. Submit and wait

```
submit command buffer to graphics queue
wait for queue idle
```

---

### 10. Read pixels on CPU

```
map staging buffer memory
read RGBA pixels
unmap memory
```

You now have a triangle rendered fully on GPU, readable by CPU.

---

## Part 2 — Change triangle into a rotating cube

### A. Add vertex + index buffers

```
create vertex buffer:
    positions (8 cube vertices)
    optional colors

create index buffer:
    36 indices (12 triangles)
```

Upload data using staging buffer.

---

### B. Add uniform buffer (for transform)

```
struct UBO:
    mat4 MVP

create uniform buffer (HOST_VISIBLE)
```

---

### C. Descriptor set

```
descriptor set layout:
    binding 0 = UNIFORM_BUFFER (vertex shader)

create descriptor pool
allocate descriptor set
update descriptor set with UBO
```

Update pipeline layout:

```
pipeline layout includes descriptor set layout
```

---

### D. Update vertex shader

```
input: position
uniform: MVP matrix
output: MVP * position
```

---

### E. Per-frame CPU update

For each frame:

```
angle += delta_time
model = rotation(angle)
view = camera
proj = perspective

MVP = proj * view * model

map uniform buffer
write MVP
unmap
```

---

### F. Record draw (cube)

```
bind vertex buffer
bind index buffer
bind descriptor set
draw indexed (36)
```

---

### G. Result

You now have:

* Offscreen Vulkan renderer
* Shader-based pipeline
* CPU-readable output
* Animated rotating cube

---

If you want next:

* Minimal SPIR-V shaders
* Vulkan-without-renderpass (dynamic rendering)
* Pure compute-based rasterization
* Zig-specific Vulkan struct layout

Say which direction to continue.

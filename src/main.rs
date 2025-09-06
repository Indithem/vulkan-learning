#![feature(cstr_display)]
use std::ffi::{c_void, CStr, CString};

use anyhow::{anyhow, Result};
use ash::{
    vk::{self},
    Entry,
};
use winit::{
    application::ApplicationHandler,
    event::WindowEvent,
    event_loop::{ActiveEventLoop, ControlFlow, EventLoop},
    window::{Window, WindowId},
};

fn main() -> Result<()> {
    let entry;
    let instance;
    let available_vk_layers: Vec<vk::LayerProperties>;

    let needed_vaildation_layers: Vec<CString> = vec![
        "VK_LAYER_KHRONOS_validation",
        "VK_LAYER_MESA_device_select",
        // "TEST",
        // "TEST1",
        // "TEST2",
    ]
    .into_iter()
    .map(CString::new)
    .collect::<Result<_, _>>()?;

    let needed_calidation_layer_ptrs = needed_vaildation_layers
        .iter()
        .map(|s| s.as_ptr())
        .collect::<Vec<*const i8>>();

    unsafe {
        entry = Entry::load()?;

        available_vk_layers = entry.enumerate_instance_layer_properties()?;
    }

    let available_vk_layers_strings: Vec<_> = available_vk_layers
        .iter()
        .map(vk::LayerProperties::layer_name_as_c_str)
        .collect::<Result<_, _>>()?;

    // for i in available_vk_layers_strings.iter() {
    //     println!("{}", i.display());
    // }

    needed_vaildation_layers
        .iter()
        .filter_map(|needed| {
            Some(needed).filter(|_| {
                !available_vk_layers_strings
                    .iter()
                    .any(|avail| avail == &needed)
            })
        })
        .inspect(|missed| eprintln!("Not found layer: {}", missed.display()))
        .map(|_| Err(anyhow!("Some layers were not found!")))
        .collect::<Vec<Result<()>>>()
        .into_iter()
        .collect::<Result<()>>()?;

    unsafe {
        instance = entry.create_instance(
            &vk::InstanceCreateInfo {
                p_application_info: &vk::ApplicationInfo {
                    api_version: vk::make_api_version(0, 1, 0, 0),
                    p_application_name: CString::new("app name")?.as_ptr(),
                    p_engine_name: CString::new("engine name")?.as_ptr(),
                    ..Default::default()
                },
                enabled_layer_count: needed_vaildation_layers.len().try_into()?,
                pp_enabled_layer_names: needed_calidation_layer_ptrs.as_ptr(),
                p_next: &vk::DebugUtilsMessengerCreateInfoEXT {
                    message_severity: vk::DebugUtilsMessageSeverityFlagsEXT::WARNING
                        | vk::DebugUtilsMessageSeverityFlagsEXT::ERROR,
                    message_type: vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                        | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE
                        | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION,
                    ..Default::default()
                } as *const _ as *const c_void,
                ..Default::default()
            },
            None,
        )?;
    }

    println!("Initialized vulkan.");

    let event_loop = EventLoop::new()?;
    event_loop.set_control_flow(ControlFlow::Wait);

    let mut app = App::default();
    event_loop.run_app(&mut app)?;

    println!("Done.");

    Ok(())
}

#[derive(Default)]
struct App {
    window: Option<Window>,
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        self.window = Some(
            event_loop
                .create_window(Window::default_attributes())
                .unwrap(),
        );
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => {
                println!("The close button was pressed; stopping");
                event_loop.exit();
            }
            WindowEvent::RedrawRequested => {
                println!("Initialized winit.");
                let window = self.window.as_ref().unwrap();
                _ = window;

                event_loop.exit();
                // Redraw the application.
                //
                // It's preferable for applications that do not render continuously to render in
                // this event rather than in AboutToWait, since rendering in here allows
                // the program to gracefully handle redraws requested by the OS.

                // Draw.

                // Queue a RedrawRequested event.
                //
                // You only need to call this if you've determined that you need to redraw in
                // applications which do not always need to. Applications that redraw continuously
                // can render here instead.
                // window.request_redraw();
            }
            _ => (),
        }
    }
}

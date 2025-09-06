## Some Rust way of doing things

The following filters unavailable validation layers, prints them all, and produces error if there are any.
```rs
    needed_vaildation_layers
        .iter()
        .filter_map(|needed| {
            Some(needed).filter(|_| {
                !available_vk_layers_strings
                    .iter()
                    .any(|avail| avail == needed)
            })
        })
        .inspect(|missed| eprintln!("Not found layer: {}", missed))
        .map(|_| Err(anyhow!("Some layers were not found!")))
        .collect::<Vec<Result<()>>>()
        // collecting directly into a Result produces lazy evaluation of other layers.
        .into_iter()
        .collect::<Result<()>>()?;
```

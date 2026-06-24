package main

import "core:fmt"
import "core:os"

map_to_symbols :: proc(data: $T) -> [dynamic]u8 {
    ret_data := make_dynamic_array_len_cap([dynamic]u8, len(data), len(data))
    for c, i in data {
        if 'a' <= u8(c) && u8(c) <= 'z' {
            ret_data[i] = u8(c) - 'a'
        } else {
            ret_data[i] = 26
        }
    }
    return ret_data
}

main :: proc() {
    data, ok := os.read_entire_file_from_path("./data/text8", context.allocator)
    if ok != 0 {
        return
    }

    symbols := map_to_symbols(data)
    fmt.printfln("Data:         {}", data[:10])
    fmt.printfln("Symbols:      {}", symbols[:10])
    fmt.printfln("Data length:  {}", len(data))

    catalog_context_binning(symbols[:])
}
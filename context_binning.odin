package main
import "core:fmt"


SYMBOLS     :: 27
SYMBOLS4    :: SYMBOLS * SYMBOLS * SYMBOLS * SYMBOLS

mix :: proc(i, j, k, l: u8) -> int{
    return int(l) + 27 * (int(k) + 27 * (int(j) + 27 * int(i)))
}

experiment_context_binning :: proc(symbol_data: []u8) {
    fmt.printfln("experiment")

    freq    :   [SYMBOLS4]u8
    parent  :   [SYMBOLS4]u8

    for i in 3..<len(symbol_data) {
        freq[mix(symbol_data[i-3], symbol_data[i-2], symbol_data[i-1], symbol_data[i])] += 1
    }


}
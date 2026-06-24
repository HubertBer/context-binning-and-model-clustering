package main
import "core:fmt"
import "core:math"

calc_frequencies :: proc(symbol_data: []u8, offset_0 : int = 2, offset_1 : int = 1) -> (freq: [ORDER2_STATES][SYMBOLS]u32) {
    for i in offset_0..<len(symbol_data) {
        freq[mix(symbol_data[i-offset_0], symbol_data[i-offset_1])][symbol_data[i]] += 1
    }
    return
}

context_eval :: proc(symbol_data: []u8, c_map: [ORDER2_STATES]int, c_pr: [$NUM_CONTEXTS][SYMBOLS]f64) -> f64 {
    total_bits : f64 = f64(NUM_CONTEXTS) * 8
    for i in 2..<len(symbol_data) {
        ctx_id := mix(symbol_data[i-2], symbol_data[i-1])
        bin_id := c_map[ctx_id]
        p := c_pr[bin_id][symbol_data[i]]
        total_bits -= math.log2(p)
    }
    fmt.printfln("Theoretical Bits Per Character (BPC) for {} contexts: %f", NUM_CONTEXTS, total_bits / f64(len(symbol_data)))
    return total_bits
}

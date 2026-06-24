package main
import "core:fmt"
import "core:math"

nested_context_eval :: proc(symbol_data: []u8, cmap_far: []int, cmap_near: []int, k_near_size: int, cmap_combined: []int, c_pr: [$K][SYMBOLS]f64) -> f64 {
    total_bits : f64 = 4.0 * 8.0
    for i in 4..<len(symbol_data) {
        far_ctx  := mix(symbol_data[i-4], symbol_data[i-3])
        near_ctx := mix(symbol_data[i-2], symbol_data[i-1])

        far_bin  := cmap_far[far_ctx]
        near_bin := cmap_near[near_ctx]

        combined_id := (far_bin * k_near_size) + near_bin
        final_bin   := cmap_combined[combined_id]

        p := c_pr[final_bin][symbol_data[i]]
        total_bits -= math.log2(p)
    }
    fmt.printfln("Nested Order-4 BPC for %v contexts: %f", K, total_bits / f64(len(symbol_data)))
    return total_bits
}

calc_nested_frequencies :: proc(symbol_data: []u8, cmap_far: []int, cmap_near: []int, $K_NEAR: int, $COMBINED_N: int) -> (freq: [COMBINED_N][SYMBOLS]u32) {
    for i in 4..<len(symbol_data) {
        far_ctx  := mix(symbol_data[i-4], symbol_data[i-3])
        near_ctx := mix(symbol_data[i-2], symbol_data[i-1])

        far_bin  := cmap_far[far_ctx]
        near_bin := cmap_near[near_ctx]

        combined_id := (far_bin * K_NEAR) + near_bin
        freq[combined_id][symbol_data[i]] += 1
    }
    return
}

nested_binning_symmetric :: proc(symbol_data: []u8) {
    freq_12         := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq_12[:])

    L1_BINS             :: 64
    L2_COMBINED_STATES  :: L1_BINS * L1_BINS
    c64                 := pick_k_contexts(parent[:], nodes[:], L1_BINS)
    c_map_64, c_pr_64   := make_context_table(c64, nodes[:], ORDER2_STATES)
    freq24              := calc_nested_frequencies(symbol_data[:], c_map_64[:], c_map_64[:], L1_BINS, L2_COMBINED_STATES)
    parent24, n24       := context_hierarchy(freq24[:])

    run_experiment :: proc (symbol_data: []u8, c_map12: []int, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map24, c_pr24 := make_context_table(contexts, nodes[:], L2_COMBINED_STATES)
        nested_context_eval(symbol_data, c_map12, c_map12, L1_BINS, c_map24[:], c_pr24)
    }

    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 1)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 2)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 4)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 8)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 16)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 32)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 64)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 128)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 256)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 512)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 1024)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 2048)
    run_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 4096)
}

nested_binning_separate :: proc(symbol_data: []u8) {
    freq_12         := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq_12[:])

    L1_BINS             :: 64
    L2_COMBINED_STATES  :: L1_BINS * L1_BINS
    c64                 := pick_k_contexts(parent[:], nodes[:], L1_BINS)
    c_map_64, c_pr_64   := make_context_table(c64, nodes[:], ORDER2_STATES)

    freq_34                 := calc_frequencies(symbol_data[:], 4, 3)
    parent_34, nodes_34     := context_hierarchy(freq_34[:])
    c64_far                 := pick_k_contexts(parent_34[:], nodes_34[:], L1_BINS)
    c_map_64_far, _         := make_context_table(c64_far, nodes_34[:], ORDER2_STATES)
    freq24_sep              := calc_nested_frequencies(symbol_data[:], c_map_64_far[:], c_map_64[:], L1_BINS, L2_COMBINED_STATES)
    parent24_sep, n24_sep   := context_hierarchy(freq24_sep[:])

    run_experiment :: proc (symbol_data: []u8, cmap_far: []int, cmap_near: []int, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map24, c_pr24 := make_context_table(contexts, nodes[:], L2_COMBINED_STATES)
        nested_context_eval(symbol_data, cmap_far, cmap_near, L1_BINS, c_map24[:], c_pr24)
    }

    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 1)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 2)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 4)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 8)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 16)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 32)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 64)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 128)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 256)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 512)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 1024)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 2048)
    run_experiment(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 4096)
}

package main
import "core:math"

no_binning :: proc (freq: ^[ORDER2_STATES][SYMBOLS]u32) -> (context_map: [ORDER2_STATES]int, pr: [ORDER2_STATES][SYMBOLS]f64) {
    for i in 0..<ORDER2_STATES {
        context_map[i] = i
    }
    for i in 0..<ORDER2_STATES {
        smoothed_total := f64(math.sum(freq[i][:])) + f64(SYMBOLS) * .001
        for s in 0..<SYMBOLS {
            pr[i][s] = (f64(freq[i][s]) + .001) / smoothed_total
        }
    }
    return
}

direct_binning :: proc(symbol_data: []u8) {
    freq_12         := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq_12[:])

    run_experiment :: proc (symbol_data: []u8, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map, c_pr     := make_context_table(contexts, nodes[:], ORDER2_STATES)
        context_eval(symbol_data, c_map, c_pr)
    }

    c_map_all, c_pr_all := no_binning(&freq_12)
    context_eval(symbol_data, c_map_all, c_pr_all)
    run_experiment(symbol_data, parent[:], nodes[:], 1)
    run_experiment(symbol_data, parent[:], nodes[:], 2)
    run_experiment(symbol_data, parent[:], nodes[:], 4)
    run_experiment(symbol_data, parent[:], nodes[:], 8)
    run_experiment(symbol_data, parent[:], nodes[:], 16)
    run_experiment(symbol_data, parent[:], nodes[:], 32)
    run_experiment(symbol_data, parent[:], nodes[:], 64)
    run_experiment(symbol_data, parent[:], nodes[:], 128)
    run_experiment(symbol_data, parent[:], nodes[:], 256)
    run_experiment(symbol_data, parent[:], nodes[:], 512)
    run_experiment(symbol_data, parent[:], nodes[:], 725)
    run_experiment(symbol_data, parent[:], nodes[:], 728)
    run_experiment(symbol_data, parent[:], nodes[:], 729)
}

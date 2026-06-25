package main
import "core:fmt"

asymmetric_binning :: proc(symbol_data: []u8) {
    freq_12         := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq_12[:])
    c_map_all, c_pr_all := no_binning(&freq_12)
    freq_34                 := calc_frequencies(symbol_data[:], 4, 3)
    parent_34, nodes_34     := context_hierarchy(freq_34[:])

    K_FAR               :: 16
    K_NEAR              :: ORDER2_STATES
    COMBINED_N_ASYM     :: K_FAR * K_NEAR
    c16_far             := pick_k_contexts(parent_34[:], nodes_34[:], K_FAR)
    cmap_16_far, _      := make_context_table(c16_far, nodes_34[:], ORDER2_STATES)
    freq_asym           := calc_nested_frequencies(symbol_data[:], cmap_16_far[:], c_map_all[:], K_NEAR, COMBINED_N_ASYM)
    parent_asym, n_asym := context_hierarchy(freq_asym[:])

    run_experiment :: proc (symbol_data: []u8, cmap_far: []int, cmap_near: []int, parent: []int, nodes: []node, $K: int) {
        contexts             := pick_k_contexts(parent[:], nodes[:], K)
        c_map_combined, c_pr := make_context_table(contexts, nodes[:], COMBINED_N_ASYM)
        nested_context_eval(symbol_data, cmap_far, cmap_near, K_NEAR, c_map_combined[:], c_pr)
    }

    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 1)
    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 64)
    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 256)
    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 1024)
    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 4096)
    run_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 11664)
}

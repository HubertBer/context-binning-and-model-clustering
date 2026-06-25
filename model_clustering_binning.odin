package main


BinningType :: enum {
    Direct,          
    NestedSymmetric, 
    NestedSeparate,  
    Asymmetric,
}

NESTED_L1_BINS :: 64
NESTED_COMBINED :: NESTED_L1_BINS * NESTED_L1_BINS // 4096
ASYM_K_FAR :: 16
ASYM_K_NEAR :: ORDER2_STATES                       // 729 (near context kept raw)
ASYM_COMBINED :: ASYM_K_FAR * ASYM_K_NEAR          // 11664

Binner :: struct {
    type:        BinningType,
    num_bins:    int,
    min_context: int,

    cmap_far:  []int,
    cmap_near: []int,
    k_near:    int,
    final_map: []int,
}

compute_bin :: proc(b: ^Binner, read: []u8, i: int) -> int {
    switch b.type {
    case .Direct:
        ctx := mix(read[i-2], read[i-1])
        return b.final_map[ctx]
    case .NestedSymmetric, .NestedSeparate:
        far  := mix(read[i-4], read[i-3])
        near := mix(read[i-2], read[i-1])
        combined := b.cmap_far[far] * b.k_near + b.cmap_near[near]
        return b.final_map[combined]
    case .Asymmetric:
        far  := mix(read[i-4], read[i-3])
        near := mix(read[i-2], read[i-1]) // raw order-2 context, no binning
        combined := b.cmap_far[far] * b.k_near + near
        return b.final_map[combined]
    }
    return 0
}

free_binner :: proc(b: ^Binner) {
    delete(b.cmap_far)
    if raw_data(b.cmap_near) != raw_data(b.cmap_far) {
        delete(b.cmap_near)
    }
    delete(b.final_map)
}

build_binner :: proc(symbol_data: []u8, type: BinningType, num_bins: int) -> Binner {
    b: Binner
    b.type = type

    switch type {
    case .Direct:
        freq          := calc_frequencies(symbol_data)
        _, nodes      := context_hierarchy(freq[:])
        ctxs          := pick_k_contexts_dyn(nodes[:], num_bins)
        b.final_map    = make_context_map_dyn(ctxs, nodes[:], ORDER2_STATES)
        b.min_context  = 2
        b.num_bins     = len(ctxs)

    case .NestedSymmetric:
        freq          := calc_frequencies(symbol_data)
        _, nodes      := context_hierarchy(freq[:])
        c_l1          := pick_k_contexts_dyn(nodes[:], NESTED_L1_BINS)
        cmap_l1       := make_context_map_dyn(c_l1, nodes[:], ORDER2_STATES)

        freq24        := calc_nested_frequencies(symbol_data, cmap_l1, cmap_l1, NESTED_L1_BINS, NESTED_COMBINED)
        _, n24        := context_hierarchy(freq24[:])
        ctxs          := pick_k_contexts_dyn(n24[:], num_bins)

        b.cmap_far     = cmap_l1
        b.cmap_near    = cmap_l1
        b.k_near       = NESTED_L1_BINS
        b.final_map    = make_context_map_dyn(ctxs, n24[:], NESTED_COMBINED)
        b.min_context  = 4
        b.num_bins     = len(ctxs)

    case .NestedSeparate:
        freq          := calc_frequencies(symbol_data)
        _, nodes      := context_hierarchy(freq[:])
        c_near        := pick_k_contexts_dyn(nodes[:], NESTED_L1_BINS)
        cmap_near     := make_context_map_dyn(c_near, nodes[:], ORDER2_STATES)

        freq34        := calc_frequencies(symbol_data, 4, 3)
        _, nodes34    := context_hierarchy(freq34[:])
        c_far         := pick_k_contexts_dyn(nodes34[:], NESTED_L1_BINS)
        cmap_far      := make_context_map_dyn(c_far, nodes34[:], ORDER2_STATES)

        freq24        := calc_nested_frequencies(symbol_data, cmap_far, cmap_near, NESTED_L1_BINS, NESTED_COMBINED)
        _, n24        := context_hierarchy(freq24[:])
        ctxs          := pick_k_contexts_dyn(n24[:], num_bins)

        b.cmap_far     = cmap_far
        b.cmap_near    = cmap_near
        b.k_near       = NESTED_L1_BINS
        b.final_map    = make_context_map_dyn(ctxs, n24[:], NESTED_COMBINED)
        b.min_context  = 4
        b.num_bins     = len(ctxs)

    case .Asymmetric:
        freq34        := calc_frequencies(symbol_data, 4, 3)
        _, nodes34    := context_hierarchy(freq34[:])
        c_far         := pick_k_contexts_dyn(nodes34[:], ASYM_K_FAR)
        cmap_far      := make_context_map_dyn(c_far, nodes34[:], ORDER2_STATES)

        // near context is the raw order-2 state -> identity map
        ident := make([]int, ORDER2_STATES)
        for i in 0..<ORDER2_STATES { ident[i] = i }

        freq_asym     := calc_nested_frequencies(symbol_data, cmap_far, ident, ASYM_K_NEAR, ASYM_COMBINED)
        _, n_asym     := context_hierarchy(freq_asym[:])
        ctxs          := pick_k_contexts_dyn(n_asym[:], num_bins)
        delete(ident)

        b.cmap_far     = cmap_far
        b.cmap_near    = nil
        b.k_near       = ASYM_K_NEAR
        b.final_map    = make_context_map_dyn(ctxs, n_asym[:], ASYM_COMBINED)
        b.min_context  = 4
        b.num_bins     = len(ctxs)
    }

    return b
}

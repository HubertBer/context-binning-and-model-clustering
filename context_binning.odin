package main
import "core:fmt"
import "core:slice/heap"
import "core:math"

SYMBOLS         :: 27
ORDER2_STATES   :: SYMBOLS * SYMBOLS

mix :: proc {
    mix2,
    mix3,
    mix4,
}

mix4 :: proc(i, j, k, l: u8) -> int {
    return int(l) + SYMBOLS * (int(k) + SYMBOLS * (int(j) + SYMBOLS * int(i)))
}

mix3 :: proc(i, j, k: u8) -> int {
    return int(k) + SYMBOLS * (int(j) + SYMBOLS * int(i))
}

mix2 :: proc(i, j: u8) -> int {
    return int(j) + SYMBOLS * int(i)
}

add_to_left :: proc (arr0: []$T, arr1: []T) 
    where intrinsics.type_is_numeric(T) {
    assert(len(arr0) == len(arr1))
    for i in 0..<len(arr0) {
        arr0[i] += arr1[i]
    }
}

mul_to_left :: proc (arr0: []$T, arr1: []T) 
    where intrinsics.type_is_numeric(T) {
    assert(len(arr0) == len(arr1))
    for i in 0..<len(arr0) {
        arr0[i] *= arr1[i]
    }
}

sum :: proc (arr0: []$T, arr1: []T, alloc := context.temp_allocator) -> [dynamic]T 
    where intrinsics.type_is_numeric(T) {
    assert(len(arr0) == len(arr1))
    result := make_dynamic_array_len_cap([dynamic]T, len(arr0), len(arr0), alloc)
    for i in 0..<len(arr0) {
        result[i] = arr0[i] + arr1[i]
    }
}

mul :: proc (arr0: []$T, arr1: []T, alloc := context.temp_allocator) -> [dynamic]T 
    where intrinsics.type_is_numeric(T) {
    assert(len(arr0) == len(arr1))
    result := make_dynamic_array_len_cap([dynamic]T, len(arr0), len(arr0), alloc)
    for i in 0..<len(arr0) {
        result[i] = arr0[i] * arr1[i]
    }
}

mul_const_inplace :: proc (arr0: []$T, c: T) 
    where intrinsics.type_is_numeric(T) {
    for &v in arr0 {
        v *= c
    }
}

dot :: proc (arr0: []$T, arr1: []T) -> (result: T)
    where intrinsics.type_is_numeric(T) {
    assert(len(arr0) == len(arr1))
    for i in 0..<len(arr0) {
        result += arr0[i] * arr1[i]
    }
    return result
}

node :: struct {
    freq        : [SYMBOLS]u32,
    total_freq  : u32,
    entropy     : f64,
    children    : [2]int
}

node_pair :: struct {
    delta: f64,
    id: [2]int,
}

xlog2x :: proc(x: u32) -> f64 {
    if x == 0 do return 0.0
    return f64(x) * math.log2(f64(x))
}

calc_entropy :: proc(freq: [SYMBOLS]u32, total_freq: u32) -> f64 {
    if total_freq == 0 do return 0.0

    logs: f64 = 0.0
    for n in freq {
        logs += xlog2x(n)
    }
    
    return xlog2x(total_freq) - logs
}

calc_delta :: proc(n0: node, n1: node) -> f64 {
    if n0.total_freq == 0 && n1.total_freq == 0 do return 0.0
    
    merged_total    := n0.total_freq + n1.total_freq
    merged_freq     := n0.freq + n1.freq 
    merged_entropy := calc_entropy(merged_freq, merged_total)
    
    return merged_entropy - n0.entropy - n1.entropy
}

destruct :: proc {
    destruct2, 
    destruct3
}

destruct3 :: #force_inline proc "contextless" (arr: [3]$T) -> (T, T, T) {
    return arr[0], arr[1], arr[2]
}
destruct2 :: #force_inline proc "contextless" (arr: [2]$T) -> (T, T) {
    return arr[0], arr[1]
}

arr3 :: #force_inline proc "contextless" (arr: []$T) -> [3]T {
    return {arr[0], arr[1], arr[2]}
}

get_split_cost :: proc(n_idx: int, nodes: []node) -> f64 {
    n := nodes[n_idx]
    if n.children == {-1, -1} do return 1000000000000000000.0 
    return n.entropy - nodes[n.children[0]].entropy - nodes[n.children[1]].entropy
}

node_less :: proc(n0, n1: int) -> bool {
    nodes: []node = (cast(^[]node)context.user_ptr)^
    // if nodes[n0].children == {-1, -1} do return true
    // if nodes[n1].children == {-1, -1} do return false
    // return nodes[n0].entropy > nodes[n1].entropy
    return get_split_cost(n0, nodes) > get_split_cost(n1, nodes)
}

less :: proc {
    node_less,
    node_pair_less,
}

node_pair_less :: proc(p0, p1: node_pair) -> bool {
    return p0.delta > p1.delta
}


context_hierarchy :: proc (freq: [][SYMBOLS]u32) -> (parent: [dynamic]int, nodes: [dynamic]node) {
    NUM_STATES := len(freq)
    available   : [dynamic]bool
    node_pairs  : [dynamic]node_pair
    
    empty_nodes    : [dynamic]int
    active_indices : [dynamic]int

    for i in 0..<NUM_STATES {
        fr          := freq[i]
        fr_total    := math.sum(fr[:])
        e           := calc_entropy(fr, fr_total)
        append(&nodes, node{fr, fr_total, e, {-1, -1}})
        append(&available, true)
        append(&parent, -1)
        
        if fr_total == 0 {
            append(&empty_nodes, i)
        } else {
            append(&active_indices, i)
        }
    }

    current_empty := -1
    if len(empty_nodes) > 0 {
        current_empty = empty_nodes[0]
        empty_freq: [SYMBOLS]u32
        
        for i in 1..<len(empty_nodes) {
            u := current_empty
            v := empty_nodes[i]
            
            available[u] = false
            available[v] = false
            parent[u] = len(nodes)
            parent[v] = len(nodes)
            
            append(&nodes, node{empty_freq, 0, 0.0, {u, v}})
            append(&available, true)
            append(&parent, -1)
            
            current_empty = len(nodes) - 1
        }
        append(&active_indices, current_empty) 
    }

    for idx1 in 0..<len(active_indices) {
        for idx2 in (idx1+1)..<len(active_indices) {
            u := active_indices[idx1]
            v := active_indices[idx2]
            delta := calc_delta(nodes[u], nodes[v])
            append(&node_pairs, node_pair{delta, {u, v}})
        }
    }

    heap.make(node_pairs[:], less)
    
    merges_to_do := len(active_indices) - 1
    
    for _ in 0..<merges_to_do {
        heap.pop(node_pairs[:], less)
        min_elem := pop(&node_pairs)
        
        for !available[min_elem.id[0]] || !available[min_elem.id[1]] {
            heap.pop(node_pairs[:], less)
            min_elem = pop(&node_pairs)
        }

        l_id, r_id := destruct(min_elem.id)
        available[l_id] = false
        available[r_id] = false
        parent[l_id] = len(parent)
        parent[r_id] = len(parent)
        append(&parent, len(parent))
        append(&available, true)

        fr          := nodes[l_id].freq + nodes[r_id].freq
        fr_total    := math.sum(fr[:])
        e           := calc_entropy(fr, fr_total)
        append(&nodes, node{fr, fr_total, e, {l_id, r_id}})
        new_id := len(nodes) - 1
        
        for i in 0..<new_id {
            if !available[i] do continue

            delta := calc_delta(nodes[new_id], nodes[i])
            append(&node_pairs, node_pair{delta, {new_id, i}})
            heap.push(node_pairs[:], less)
        }
    }
    return
}

pick_k_contexts :: proc(parent: []int, nodes: []node, $K: int) -> (contexts: [K]int) {
    when K == 0 do return
    nodes := nodes
    context.user_ptr = &nodes
    contexts[0] = len(nodes) - 1

    on_heap := 1
    for on_heap < K {
        heap.pop(contexts[:on_heap], less)
        top_id  := contexts[on_heap - 1]
        top     := nodes[top_id]

        if top.children == {-1, -1} do break

        contexts[on_heap - 1] = top.children[0]
        heap.push(contexts[:on_heap], less)

        contexts[on_heap] = top.children[1]
        on_heap += 1
        heap.push(contexts[:on_heap], less)
    }
    assert(on_heap == K)
    return
}



make_context_table :: proc (contexts: [$TARGET_BINS]int, nodes: []node, $NUM_STATES: int) -> (context_map: [NUM_STATES]int, pr: [TARGET_BINS][SYMBOLS]f64) {
    update_children :: proc "contextless" (context_id: int, v: int, nodes: []node, context_map: ^[$NUM_STATES]int) {
        if v < 0 do return
        if v < NUM_STATES do context_map[v] = context_id
        update_children(context_id, nodes[v].children.x, nodes, context_map)
        update_children(context_id, nodes[v].children.y, nodes, context_map)
    }
    for v, i in contexts {
        update_children(i, v, nodes, &context_map)
        smoothed_total := f64(nodes[v].total_freq) + f64(SYMBOLS) * .001
        for s in 0..<SYMBOLS {
            pr[i][s] = (f64(nodes[v].freq[s]) + .001) / smoothed_total
        }
    }
    return
}

context_eval :: proc(symbol_data: []u8, c_map: [ORDER2_STATES]int, c_pr: [$NUM_CONTEXTS][SYMBOLS]f64) -> f64 {
    total_bits : f64 = f64(NUM_CONTEXTS) * 8// in bits 
    for i in 2..<len(symbol_data) {
        ctx_id := mix(symbol_data[i-2], symbol_data[i-1])
        bin_id := c_map[ctx_id]
        p := c_pr[bin_id][symbol_data[i]]
        total_bits -= math.log2(p)
    }
    fmt.printfln("Theoretical Bits Per Character (BPC) for {} contexts: %f", NUM_CONTEXTS, total_bits / f64(len(symbol_data)))
    return total_bits
}

calc_frequencies :: proc(symbol_data: []u8, offset_0 : int = 2, offset_1 : int = 1) -> (freq: [ORDER2_STATES][SYMBOLS]u32) {
    for i in offset_0..<len(symbol_data) {
        freq[mix(symbol_data[i-offset_0], symbol_data[i-offset_1])][symbol_data[i]] += 1
    }
    return
}

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

experiment_context_binning :: proc(symbol_data: []u8) {
    freq_12         := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq_12[:])
    experiment :: proc (symbol_data: []u8, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map, c_pr     := make_context_table(contexts, nodes[:], ORDER2_STATES)
        context_eval(symbol_data, c_map, c_pr)
    }
    
    fmt.println("DIRECT CONTEXT BINNING")
    c_map_all, c_pr_all := no_binning(&freq_12)
    context_eval(symbol_data, c_map_all, c_pr_all)
    experiment(symbol_data, parent[:], nodes[:], 1)
    experiment(symbol_data, parent[:], nodes[:], 2)
    experiment(symbol_data, parent[:], nodes[:], 4)
    experiment(symbol_data, parent[:], nodes[:], 8)
    experiment(symbol_data, parent[:], nodes[:], 16)
    experiment(symbol_data, parent[:], nodes[:], 32)
    experiment(symbol_data, parent[:], nodes[:], 64)
    experiment(symbol_data, parent[:], nodes[:], 128)
    experiment(symbol_data, parent[:], nodes[:], 256)
    experiment(symbol_data, parent[:], nodes[:], 512)
    experiment(symbol_data, parent[:], nodes[:], 725)
    experiment(symbol_data, parent[:], nodes[:], 728)
    experiment(symbol_data, parent[:], nodes[:], 729)


    fmt.println("NESTED CONTEXT BINNING SYMMETRIC SIMPLE")
    L1_BINS             :: 64 
    L2_COMBINED_STATES  :: L1_BINS * L1_BINS
    c64                 := pick_k_contexts(parent[:], nodes[:], L1_BINS)
    c_map_64, c_pr_64   := make_context_table(c64, nodes[:], ORDER2_STATES)
    freq24              := calc_nested_frequencies(symbol_data[:], c_map_64[:], c_map_64[:], L1_BINS, L2_COMBINED_STATES)
    parent24, n24       := context_hierarchy(freq24[:])

    nested_experiment   :: proc (symbol_data: []u8, c_map12: []int, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map24, c_pr24 := make_context_table(contexts, nodes[:], L2_COMBINED_STATES)
        nested_context_eval(symbol_data, c_map12, c_map12, L1_BINS, c_map24[:], c_pr24)
    }

    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 1)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 2)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 4)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 8)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 16)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 32)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 64)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 128)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 256)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 512)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 1024)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 2048)
    nested_experiment(symbol_data[:], c_map_64[:], parent24[:], n24[:], 4096)
    
    fmt.println("NESTED CONTEXT BINNING SYMMETRIC (SEPARATE MAPS)")
    freq_34                 := calc_frequencies(symbol_data[:], 4, 3)
    parent_34, nodes_34     := context_hierarchy(freq_34[:])
    c64_far                 := pick_k_contexts(parent_34[:], nodes_34[:], L1_BINS)
    c_map_64_far, _         := make_context_table(c64_far, nodes_34[:], ORDER2_STATES)
    freq24_sep              := calc_nested_frequencies(symbol_data[:], c_map_64_far[:], c_map_64[:], L1_BINS, L2_COMBINED_STATES)
    parent24_sep, n24_sep   := context_hierarchy(freq24_sep[:])

    nested_experiment_sep   :: proc (symbol_data: []u8, cmap_far: []int, cmap_near: []int, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map24, c_pr24 := make_context_table(contexts, nodes[:], L2_COMBINED_STATES)
        nested_context_eval(symbol_data, cmap_far, cmap_near, L1_BINS, c_map24[:], c_pr24)
    }
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 1)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 2)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 4)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 8)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 16)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 32)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 64)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 128)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 256)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 512)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 1024)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 2048)
    nested_experiment_sep(symbol_data[:], c_map_64_far[:], c_map_64[:], parent24_sep[:], n24_sep[:], 4096)
 
    
    fmt.println("--- NESTED ASYMMETRIC CONTEXT BINNING ---")

    K_FAR               :: 16
    K_NEAR              :: ORDER2_STATES
    COMBINED_N_ASYM     :: K_FAR * K_NEAR
    c16_far             := pick_k_contexts(parent_34[:], nodes_34[:], K_FAR)
    cmap_16_far, _      := make_context_table(c16_far, nodes_34[:], ORDER2_STATES)
    freq_asym           := calc_nested_frequencies(symbol_data[:], cmap_16_far[:], c_map_all[:], K_NEAR, COMBINED_N_ASYM)
    parent_asym, n_asym := context_hierarchy(freq_asym[:])

    asym_experiment :: proc (symbol_data: []u8, cmap_far: []int, cmap_near: []int, parent: []int, nodes: []node, $K: int) {
        contexts             := pick_k_contexts(parent[:], nodes[:], K)
        c_map_combined, c_pr := make_context_table(contexts, nodes[:], COMBINED_N_ASYM)
        nested_context_eval(symbol_data, cmap_far, cmap_near, K_NEAR, c_map_combined[:], c_pr)
    }

    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 1)
    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 64)
    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 256)
    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 1024)
    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 4096)
    asym_experiment(symbol_data[:], cmap_16_far[:], c_map_all[:], parent_asym[:], n_asym[:], 11664)
}
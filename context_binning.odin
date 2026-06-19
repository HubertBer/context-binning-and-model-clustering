package main
import "core:fmt"
import "core:slice/heap"
import "core:math"

CONTEXTS    :: 2
SYMBOLS     :: 27
SYMBOLS2    :: SYMBOLS * SYMBOLS
SYMBOLS3    :: SYMBOLS * SYMBOLS * SYMBOLS
SYMBOLS4    :: SYMBOLS * SYMBOLS * SYMBOLS * SYMBOLS

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

context_hierarchy :: proc (freq: [SYMBOLS2][SYMBOLS]u32) -> (parent: [dynamic]int, nodes: [dynamic]node) {
    available   :   [dynamic]bool
    node_pairs  :   [dynamic]node_pair

    for i in 0..<SYMBOLS2 {
        fr          := freq[i]
        fr_total    := math.sum(fr[:])
        e           := calc_entropy(fr, fr_total)
        append(&nodes, node{fr, fr_total, e, {-1, -1}})
        append(&available, true)
        append(&parent, -1)
    }

    for i in 0..<SYMBOLS2 {
        for j in (i+1)..<SYMBOLS2 {
            delta := calc_delta(nodes[i], nodes[j])
            append(&node_pairs, node_pair{delta, {i, j}})
        }
    }

    heap.make(node_pairs[:], less)
    initial_node_count := len(nodes)
    for i in 1..<initial_node_count {
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



make_context_table :: proc (contexts: [$K]int, nodes: []node) -> (context_map: [SYMBOLS2]int, pr: [K][SYMBOLS]f64) {
    update_children :: proc "contextless" (context_id: int, v: int, nodes: []node, context_map: ^[SYMBOLS2]int) {
        if v < 0 do return
        if v < SYMBOLS2 do context_map[v] = context_id
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

context_eval :: proc(symbol_data: []u8, c_map: [SYMBOLS2]int, c_pr: [$K][SYMBOLS]f64) -> f64 {
    total_bits : f64 = f64(K) * 8// in bits 
    for i in 2..<len(symbol_data) {
        ctx_id := mix(symbol_data[i-2], symbol_data[i-1])
        bin_id := c_map[ctx_id]
        p := c_pr[bin_id][symbol_data[i]]
        total_bits -= math.log2(p)
    }
    fmt.printfln("Theoretical Bits Per Character (BPC) for {} contexts: %f", K, total_bits / f64(len(symbol_data)))
    return total_bits
}

calc_frequencies :: proc(symbol_data: []u8) -> (freq: [SYMBOLS2][SYMBOLS]u32) {
    for i in CONTEXTS..<len(symbol_data) {
        freq[mix(symbol_data[i-2], symbol_data[i-1])][symbol_data[i]] += 1
    }
    return
}

no_binning :: proc (freq: ^[SYMBOLS2][SYMBOLS]u32) -> (context_map: [SYMBOLS2]int, pr: [SYMBOLS2][SYMBOLS]f64) {
    for i in 0..<SYMBOLS2 {
        context_map[i] = i
    }
    for i in 0..<SYMBOLS2 {
        smoothed_total := f64(math.sum(freq[i][:])) + f64(SYMBOLS) * .001
        for s in 0..<SYMBOLS {
            pr[i][s] = (f64(freq[i][s]) + .001) / smoothed_total
        }
    }
    return
}


experiment_context_binning :: proc(symbol_data: []u8) {
    freq            := calc_frequencies(symbol_data[:])
    parent, nodes   := context_hierarchy(freq)
    experiment :: proc (symbol_data: []u8, parent: []int, nodes: []node, $K: int) {
        contexts        := pick_k_contexts(parent[:], nodes[:], K)
        c_map, c_pr     := make_context_table(contexts, nodes[:])
        context_eval(symbol_data, c_map, c_pr)
    }
    c_map, c_pr := no_binning(&freq)
    context_eval(symbol_data, c_map, c_pr)
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
}
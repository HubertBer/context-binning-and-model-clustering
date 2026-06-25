package main
import "core:slice/heap"
import "core:math"

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

calc_delta :: proc(n0: node, n1: node) -> f64 {
    if n0.total_freq == 0 && n1.total_freq == 0 do return 0.0

    merged_total    := n0.total_freq + n1.total_freq
    merged_freq     := n0.freq + n1.freq
    merged_entropy := calc_entropy(merged_freq, merged_total)

    return merged_entropy - n0.entropy - n1.entropy
}

get_split_cost :: proc(n_idx: int, nodes: []node) -> f64 {
    n := nodes[n_idx]
    if n.children == {-1, -1} do return 1000000000000000000.0
    return n.entropy - nodes[n.children[0]].entropy - nodes[n.children[1]].entropy
}

node_less :: proc(n0, n1: int) -> bool {
    nodes: []node = (cast(^[]node)context.user_ptr)^
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

pick_k_contexts_dyn :: proc(nodes: []node, k: int, alloc := context.allocator) -> []int {
    nodes := nodes
    context.user_ptr = &nodes

    buf := make([]int, k, alloc)
    if k <= 0 do return buf[:0]
    buf[0] = len(nodes) - 1

    on_heap := 1
    for on_heap < k {
        heap.pop(buf[:on_heap], less)
        top_id := buf[on_heap - 1]
        top    := nodes[top_id]

        if top.children == {-1, -1} do break

        buf[on_heap - 1] = top.children[0]
        heap.push(buf[:on_heap], less)

        buf[on_heap] = top.children[1]
        on_heap += 1
        heap.push(buf[:on_heap], less)
    }
    return buf[:on_heap]
}

fill_context_map :: proc(bin_id: int, v: int, nodes: []node, num_states: int, cmap: []int) {
    if v < 0 do return
    if v < num_states do cmap[v] = bin_id
    fill_context_map(bin_id, nodes[v].children.x, nodes, num_states, cmap)
    fill_context_map(bin_id, nodes[v].children.y, nodes, num_states, cmap)
}

make_context_map_dyn :: proc(contexts: []int, nodes: []node, num_states: int, alloc := context.allocator) -> []int {
    cmap := make([]int, num_states, alloc)
    for v, i in contexts {
        fill_context_map(i, v, nodes, num_states, cmap)
    }
    return cmap
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
        smoothed_total := f64(nodes[v].total_freq) + f64(SYMBOLS) * EPSILON
        for s in 0..<SYMBOLS {
            pr[i][s] = (f64(nodes[v].freq[s]) + EPSILON) / smoothed_total
        }
    }
    return
}

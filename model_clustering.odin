package main
import "core:math"
import "core:math/rand"
import "core:fmt"

READ_LENGTH    :: 5120
EPSILON : f64 : 1e-5

// Per-read precomputed count matrix, indexed by context BIN (not raw context):
// counts[bin][current_symbol]. The number of bins comes from the Binner.
ReadStats :: struct {
    counts: [][SYMBOLS]u32,
}

Model :: struct {
    prob_context:  []f64,          // p(bin)
    probabilities: [][SYMBOLS]f64, // p(symbol | bin)
}

free_read_stats :: proc(stats: []ReadStats) {
    for &s in stats { delete(s.counts) }
    delete(stats)
}

free_model :: proc(m: ^Model) {
    delete(m.prob_context)
    delete(m.probabilities)
}

split_into_reads :: proc(data: []u8) -> [dynamic][READ_LENGTH]u8 {
    num_reads := len(data) / READ_LENGTH
    reads := make([dynamic][READ_LENGTH]u8, num_reads, num_reads)
    for i in 0..<num_reads {
        copy(reads[i][:], data[i*READ_LENGTH:(i+1)*READ_LENGTH])
    }
    return reads
}

// Precompute per-read binned count matrices for all reads — called once before
// k-means. Each position is mapped to a context bin via the global Binner.
precompute_stats :: proc(b: ^Binner, reads: [][READ_LENGTH]u8) -> []ReadStats {
    stats := make([]ReadStats, len(reads))
    for &read, i in reads {
        stats[i].counts = make([][SYMBOLS]u32, b.num_bins)
        for j in b.min_context..<READ_LENGTH {
            bin := compute_bin(b, read[:], j)
            stats[i].counts[bin][read[j]] += 1
        }
    }
    return stats
}

// Build a model as the MLE from aggregated raw counts of a subset of reads.
model_from_stats :: proc(all_stats: []ReadStats, indices: []int, num_bins: int) -> Model {
    agg := make([][SYMBOLS]f64, num_bins, context.temp_allocator)
    for idx in indices {
        for bin in 0..<num_bins {
            for sym in 0..<SYMBOLS {
                agg[bin][sym] += f64(all_stats[idx].counts[bin][sym])
            }
        }
    }
    model: Model
    model.prob_context  = make([]f64, num_bins)
    model.probabilities = make([][SYMBOLS]f64, num_bins)
    ctx_total: f64 = 0.0
    for bin in 0..<num_bins {
        row_sum: f64 = 0.0
        for sym in 0..<SYMBOLS { row_sum += agg[bin][sym] }
        smoothed := row_sum + f64(SYMBOLS) * EPSILON
        model.prob_context[bin] = row_sum + EPSILON
        ctx_total += model.prob_context[bin]
        for sym in 0..<SYMBOLS {
            model.probabilities[bin][sym] = (agg[bin][sym] + EPSILON) / smoothed
        }
    }
    for bin in 0..<num_bins { model.prob_context[bin] /= ctx_total }
    return model
}

// Coding cost via dot product of counts with precomputed log-probs.
// log2 is precomputed per model outside the read loop.
assignment_cost :: proc(stats: ^ReadStats, logprobs: [][SYMBOLS]f64) -> f64 {
    cost: f64 = 0.0
    for bin in 0..<len(logprobs) {
        for sym in 0..<SYMBOLS {
            cost -= f64(stats.counts[bin][sym]) * logprobs[bin][sym]
        }
    }
    return cost
}

kmeans_clustering :: proc(K: int, num_bins: int, all_stats: []ReadStats, quiet := false) -> []Model {
    n := len(all_stats)

    perm := make([]int, n)
    defer delete(perm)
    for i in 0..<n { perm[i] = i }
    for i in 0..<K {
        r := rand.int_range(i, n)
        perm[i], perm[r] = perm[r], perm[i]
    }
    models := make([]Model, K)
    for k in 0..<K {
        seed := []int{perm[k]}
        models[k] = model_from_stats(all_stats, seed, num_bins)
    }

    assignments := make([]int, n)
    defer delete(assignments)
    prev_assignments := make([]int, n)
    defer delete(prev_assignments)

    logprobs := make([][][SYMBOLS]f64, K)
    defer {
        for k in 0..<K { delete(logprobs[k]) }
        delete(logprobs)
    }
    for k in 0..<K { logprobs[k] = make([][SYMBOLS]f64, num_bins) }

    for j := 0; ; j += 1 {
        if !quiet do fmt.print("kmeans iteration:", j, "\n")
        // Precompute log-probs for all K models
        for k in 0..<K {
            for bin in 0..<num_bins {
                for sym in 0..<SYMBOLS {
                    logprobs[k][bin][sym] = math.log2(models[k].probabilities[bin][sym])
                }
            }
        }

        copy(prev_assignments, assignments)

        // Assign each read to the model with lowest coding cost
        for i in 0..<n {
            best_k := 0
            best_cost := math.INF_F64
            for k in 0..<K {
                cost := assignment_cost(&all_stats[i], logprobs[k])
                if cost < best_cost {
                    best_cost = cost
                    best_k = k
                }
            }
            assignments[i] = best_k
        }

        cluster_idx := make([][dynamic]int, K, context.temp_allocator)
        for k in 0..<K {
            cluster_idx[k] = make([dynamic]int, 0, 0, context.temp_allocator)
        }
        for i in 0..<n { append(&cluster_idx[assignments[i]], i) }

        for k in 0..<K {
            if len(cluster_idx[k]) > 0 {
                free_model(&models[k])
                models[k] = model_from_stats(all_stats, cluster_idx[k][:], num_bins)
            }
        }
        free_all(context.temp_allocator)

        converged := true
        for i in 0..<n {
            if assignments[i] != prev_assignments[i] {
                converged = false
                break
            }
        }
        if converged { break }
    }

    return models
}

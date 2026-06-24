package main
import "core:math"
import "core:math/rand"

READ_LENGTH    :: 128
CONTEXT_LENGTH :: 1
EPSILON : f64 : 1e-5

// Per-read precomputed count matrix: counts[prev_symbol][current_symbol]
ReadStats :: struct {
    counts: [SYMBOLS][SYMBOLS]u32,
}

Model :: struct {
    prob_context:  [SYMBOLS]f64,          // p(context)
    probabilities: [SYMBOLS][SYMBOLS]f64, // p(symbol | context)
}

split_into_reads :: proc(data: []u8) -> [dynamic][READ_LENGTH]u8 {
    num_reads := len(data) / READ_LENGTH
    reads := make([dynamic][READ_LENGTH]u8, num_reads, num_reads)
    for i in 0..<num_reads {
        copy(reads[i][:], data[i*READ_LENGTH:(i+1)*READ_LENGTH])
    }
    return reads
}

// Precompute count matrices for all reads — called once before k-means.
precompute_stats :: proc(reads: [][READ_LENGTH]u8) -> [dynamic]ReadStats {
    stats := make([dynamic]ReadStats, len(reads))
    for &read, i in reads {
        for j in CONTEXT_LENGTH..<READ_LENGTH {
            ctx := int(read[j-1])
            sym := int(read[j])
            stats[i].counts[ctx][sym] += 1
        }
    }
    return stats
}

// Build a model as the MLE from aggregated raw counts of a subset of reads.
model_from_stats :: proc(all_stats: []ReadStats, indices: []int) -> Model {
    agg: [SYMBOLS][SYMBOLS]f64
    for idx in indices {
        for ctx in 0..<SYMBOLS {
            for sym in 0..<SYMBOLS {
                agg[ctx][sym] += f64(all_stats[idx].counts[ctx][sym])
            }
        }
    }
    model: Model
    ctx_total: f64 = 0.0
    for ctx in 0..<SYMBOLS {
        row_sum: f64 = 0.0
        for sym in 0..<SYMBOLS { row_sum += agg[ctx][sym] }
        smoothed := row_sum + f64(SYMBOLS) * EPSILON
        model.prob_context[ctx] = row_sum + EPSILON
        ctx_total += model.prob_context[ctx]
        for sym in 0..<SYMBOLS {
            model.probabilities[ctx][sym] = (agg[ctx][sym] + EPSILON) / smoothed
        }
    }
    for ctx in 0..<SYMBOLS { model.prob_context[ctx] /= ctx_total }
    return model
}

// Coding cost via dot product of counts with precomputed log-probs.
// O(SYMBOLS^2) with no log2 — log2 is precomputed per model outside the read loop.
assignment_cost :: proc(stats: ^ReadStats, logprobs: ^[SYMBOLS][SYMBOLS]f64) -> f64 {
    cost: f64 = 0.0
    for ctx in 0..<SYMBOLS {
        for sym in 0..<SYMBOLS {
            cost -= f64(stats.counts[ctx][sym]) * logprobs[ctx][sym]
        }
    }
    return cost
}

shannon_entropy :: proc(probs: ^[SYMBOLS]f64) -> f64 {
    h: f64 = 0.0
    for p in probs {
        if p > 0.0 { h -= p * math.log2(p) }
    }
    return h
}

optimized_rate :: proc(model: ^Model) -> f64 {
    rate: f64 = 0.0
    for ctx in 0..<SYMBOLS {
        probs := model.probabilities[ctx]
        rate += model.prob_context[ctx] * shannon_entropy(&probs)
    }
    return rate
}

// K-means on precomputed stats. Pass all_stats from precompute_stats.
kmeans_clustering :: proc($K: u32, all_stats: []ReadStats) -> [K]Model {
    n := len(all_stats)

    // Shuffle to pick K random seed reads
    perm := make([]int, n)
    defer delete(perm)
    for i in 0..<n { perm[i] = i }
    for i in 0..<int(K) {
        r := rand.int_range(i, n)
        perm[i], perm[r] = perm[r], perm[i]
    }
    models: [K]Model
    for k in 0..<K {
        seed := []int{perm[k]}
        models[k] = model_from_stats(all_stats, seed)
    }

    assignments := make([]int, n)
    defer delete(assignments)
    logprobs := make([][SYMBOLS][SYMBOLS]f64, int(K))
    defer delete(logprobs)

    for _ in 0..<25 {
        // Precompute log-probs for all K models (only K*SYMBOLS^2 log2 calls total)
        for k in 0..<K {
            for ctx in 0..<SYMBOLS {
                for sym in 0..<SYMBOLS {
                    logprobs[k][ctx][sym] = math.log2(models[k].probabilities[ctx][sym])
                }
            }
        }

        // Assign each read to the model with lowest coding cost
        for i in 0..<n {
            best_k := 0
            best_cost := math.INF_F64
            for k in 0..<K {
                cost := assignment_cost(&all_stats[i], &logprobs[k])
                if cost < best_cost {
                    best_cost = cost
                    best_k = int(k)
                }
            }
            assignments[i] = best_k
        }

        // Rebuild cluster membership lists
        cluster_idx: [K][dynamic]int
        for k in 0..<K {
            cluster_idx[k] = make([dynamic]int, 0, 0, context.temp_allocator)
        }
        for i in 0..<n { append(&cluster_idx[assignments[i]], i) }

        // Update model for each cluster
        for k in 0..<K {
            if len(cluster_idx[k]) > 0 {
                models[k] = model_from_stats(all_stats, cluster_idx[k][:])
            }
        }
        free_all(context.temp_allocator)
    }

    return models
}

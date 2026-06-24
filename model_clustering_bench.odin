package main
import "core:fmt"
import "core:math"

// Evaluate BPC: for each read, use the best-matching model.
// Overhead: log2(K) bits per read for the cluster index (per paper).
model_eval :: proc(all_stats: []ReadStats, models: []Model, total_chars: int) -> f64 {
    K := len(models)
    logprobs := make([][SYMBOLS][SYMBOLS]f64, K)
    defer delete(logprobs)
    for k in 0..<K {
        for ctx in 0..<SYMBOLS {
            for sym in 0..<SYMBOLS {
                logprobs[k][ctx][sym] = math.log2(models[k].probabilities[ctx][sym])
            }
        }
    }

    total_bits: f64 = 0.0
    for i in 0..<len(all_stats) {
        best_cost := math.INF_F64
        for k in 0..<K {
            cost := assignment_cost(&all_stats[i], &logprobs[k])
            if cost < best_cost { best_cost = cost }
        }
        total_bits += best_cost
    }

    // log2(K) bits per read to store which model was used
    if K > 1 {
        total_bits += f64(len(all_stats)) * math.log2(f64(K))
    }

    bpc := total_bits / f64(total_chars)
    fmt.printfln("BPC for %v models: %f", K, bpc)
    return total_bits
}

catalog_model_clustering :: proc(symbol_data: []u8) {
    fmt.println("\nMODEL CLUSTERING")

    reads := split_into_reads(symbol_data)
    defer delete(reads)
    all_stats := precompute_stats(reads[:])
    defer delete(all_stats)

    run_experiment :: proc(all_stats: []ReadStats, total_chars: int, $K: u32) {
        models := kmeans_clustering(K, all_stats)
        model_eval(all_stats, models[:], total_chars)
    }

    run_experiment(all_stats[:], len(symbol_data), 1)
    run_experiment(all_stats[:], len(symbol_data), 2)
    run_experiment(all_stats[:], len(symbol_data), 4)
    run_experiment(all_stats[:], len(symbol_data), 8)
    run_experiment(all_stats[:], len(symbol_data), 16)
}

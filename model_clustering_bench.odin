package main
import "core:fmt"
import "core:math"

// Evaluate BPC: for each read, use the best-matching model.
// Overhead: log2(K) bits per read for the cluster index (per paper).
model_eval :: proc(all_stats: []ReadStats, models: []Model, num_bins: int, total_chars: int, quiet := false) -> f64 {
    K := len(models)
    logprobs := make([][][SYMBOLS]f64, K)
    defer {
        for k in 0..<K { delete(logprobs[k]) }
        delete(logprobs)
    }
    for k in 0..<K {
        logprobs[k] = make([][SYMBOLS]f64, num_bins)
        for bin in 0..<num_bins {
            for sym in 0..<SYMBOLS {
                logprobs[k][bin][sym] = math.log2(models[k].probabilities[bin][sym])
            }
        }
    }

    total_bits: f64 = 0.0
    for i in 0..<len(all_stats) {
        best_cost := math.INF_F64
        for k in 0..<K {
            cost := assignment_cost(&all_stats[i], logprobs[k])
            if cost < best_cost { best_cost = cost }
        }
        total_bits += best_cost
    }

    // log2(K) bits per read to store which model was used
    if K > 1 {
        total_bits += f64(len(all_stats)) * math.log2(f64(K))
    }

    bpc := total_bits / f64(total_chars)
    if !quiet do fmt.printfln("BPC for %v models: %f", K, bpc)
    return total_bits
}

binning_type_name :: proc(t: BinningType) -> string {
    switch t {
    case .Direct:          return "direct (order-2)"
    case .NestedSymmetric: return "nested symmetric"
    case .NestedSeparate:  return "nested separate"
    case .Asymmetric:      return "asymmetric"
    }
    return "?"
}

run_model_clustering :: proc(symbol_data: []u8, btype: BinningType, num_bins: int, num_models: int) {
    binner := build_binner(symbol_data, btype, num_bins)
    defer free_binner(&binner)
    fmt.printfln("\n[%s] %d bins, %d models", binning_type_name(btype), binner.num_bins, num_models)

    reads := split_into_reads(symbol_data)
    defer delete(reads)
    all_stats := precompute_stats(&binner, reads[:])
    defer free_read_stats(all_stats)

    models := kmeans_clustering(num_models, binner.num_bins, all_stats)
    defer {
        for &m in models { free_model(&m) }
        delete(models)
    }

    model_eval(all_stats, models, binner.num_bins, len(symbol_data))
}

catalog_model_clustering :: proc(symbol_data: []u8) {
    fmt.println("\nMODEL CLUSTERING (context-binned probabilities)")

    // Pick the binning type and number of context bins here, plus the model count.
    BIN_TYPE   :: BinningType.Direct
    NUM_BINS   :: 64

    run_model_clustering(symbol_data, BIN_TYPE, NUM_BINS, 1)
    run_model_clustering(symbol_data, BIN_TYPE, NUM_BINS, 2)
    run_model_clustering(symbol_data, BIN_TYPE, NUM_BINS, 4)
    run_model_clustering(symbol_data, BIN_TYPE, NUM_BINS, 8)
    run_model_clustering(symbol_data, BIN_TYPE, NUM_BINS, 16)
}

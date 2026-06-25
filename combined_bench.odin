package main
import "core:fmt"


run_combined_config :: proc(
    symbol_data: []u8,
    btype: BinningType,
    num_bins: int,
    model_counts: []int,
) {
    binner := build_binner(symbol_data, btype, num_bins)
    defer free_binner(&binner)

    reads := split_into_reads(symbol_data)
    defer delete(reads)
    all_stats := precompute_stats(&binner, reads[:])
    defer free_read_stats(all_stats)

    fmt.printfln("\n[%s] %d bins (%d reads of %d)",
        binning_type_name(btype), binner.num_bins, len(reads), READ_LENGTH)

    for nm in model_counts {
        models := kmeans_clustering(nm, binner.num_bins, all_stats, quiet = true)
        total_bits := model_eval(all_stats, models, binner.num_bins, len(symbol_data), quiet = true)
        bpc := total_bits / f64(len(symbol_data))
        fmt.printfln("    %2d models -> BPC %.4f", nm, bpc)

        for &m in models { free_model(&m) }
        delete(models)
    }
}

catalog_combined :: proc(symbol_data: []u8) {
    fmt.println("\nCOMBINED: CONTEXT BINNING + MODEL CLUSTERING")

    btypes       := []BinningType{.Direct}
    bin_counts   := []int{64, 256, 512, 729} // 729 = full order-2 resolution
    model_counts := []int{1, 2, 4}

    for bt in btypes {
        for nb in bin_counts {
            run_combined_config(symbol_data, bt, nb, model_counts)
        }
    }
}

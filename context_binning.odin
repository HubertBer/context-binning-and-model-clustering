package main
import "core:fmt"

catalog_context_binning :: proc(symbol_data: []u8) {
    fmt.println("DIRECT CONTEXT BINNING")
    direct_binning(symbol_data)

    fmt.println("\nNESTED CONTEXT BINNING SYMMETRIC SIMPLE")
    nested_binning_symmetric(symbol_data)

    fmt.println("\nNESTED CONTEXT BINNING SYMMETRIC (SEPARATE MAPS)")
    nested_binning_separate(symbol_data)

    fmt.println("\n--- NESTED ASYMMETRIC CONTEXT BINNING ---")
    asymmetric_binning(symbol_data)
}
package main
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

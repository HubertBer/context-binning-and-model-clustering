package main
import "core:math"
import "core:math/rand"

K_NUM :: 4
READ_LENGTH :: 128
CONTEXT_SIZE :: 27
CONTEXT_LENGTH :: 1
EPSILON : f64 : 1e-5 

split_into_reads :: proc(data: []u8) -> [dynamic][READ_LENGTH]u8 {
    num_reads := len(data) / READ_LENGTH
    reads := make([dynamic][READ_LENGTH]u8, num_reads, num_reads)
    for i in 0..<num_reads {
        copy(reads[i][:], data[i*READ_LENGTH:(i+1)*READ_LENGTH])
    }
    return reads
}

choose_k_reads :: proc($K: u32, reads: [][READ_LENGTH]u8) -> [K][READ_LENGTH]u8 {
    l_reads := len(reads)

    indices := make([]int, l_reads)
    for i in 0..<l_reads {
        indices[i] := i
    }

    for i in 0..<K {
        r := rand.int_range(i, l_reads)
        indices[i], indices[r] := indices[r], indices[i]
    }

    resize(&indices, K)
    return indices
}

get_context_id :: proc(context_slice: []u8) -> u8 {
    slice := context_slice[len(context_slice)-1] 
    assert(slice < CONTEXT_SIZE)
    return slice 
}

compute_probabilities :: proc(read: ^[READ_LENGTH]u8) -> ([CONTEXT_SIZE]f64, [SYMBOLS][CONTEXT_SIZE]f64) {
    probabilities : [SYMBOLS][CONTEXT_SIZE]f64
    prob_context : [CONTEXT_SIZE]f64
    
    for i in CONTEXT_LENGTH..<READ_LENGTH  {
        ctx := get_context_id(read[i-CONTEXT_LENGTH:i]);
        r := read[i]
        prob_context[ctx] += 1.0
        probabilities[ctx][r] += 1.0
    }
    
    prob_context += EPSILON
    probabilities += EPSILON
    for i in 0..<CONTEXT_SIZE {
        probabilities[i] /= prob_context[i]
    }
    probabilities /= ((READ_LENGTH - CONTEXT_LENGTH - 1)*(EPSILON))
    prob_context /= f64((READ_LENGTH - CONTEXT_LENGTH)*(1+EPSILON))

    return prob_context, probabilities
}

shannon_entropy :: proc(probabilities: ^[SYMBOLS]f64) -> f64 {
    entropy := 0.0
    for i in 0..<SYMBOLS {
        p := probabilities[i]
        if p > 0.0 {
            entropy -= p * math.log2(p)
        }
    }
    return entropy
}

optimized_rate :: proc(prob_context: ^[CONTEXT_SIZE]f64, probabilities: ^[SYMBOLS][CONTEXT_SIZE]f64) -> f64 {
    rate := 0.0
    for ctx in 0..<CONTEXT_SIZE {
        shannon := shannon_entropy(&probabilities[ctx])
        rate += prob_context[ctx] * shannon
    }
    return rate
}

Model :: struct {
    prob_context: [CONTEXT_SIZE]f64,
    probabilities: [SYMBOLS][CONTEXT_SIZE]f64
} 

get_models :: proc($K: u32, reads: [][READ_LENGTH]u8) -> [K]Model {
    models: [K]Model
    k_reads := choose_k_reads(K, reads)
    for i in 0..<K {
        prob_context, probabilites := compute_probabilities(k_reads[i])
        models[i] = Model{prob_context, probabilites}
    }
    return models
}

argmin :: proc(data: []f64) -> (idx: int, value: f64) {
    assert(len(data) > 0)

    idx = 0
    value = data[0]

    for i in 1..<len(data) {
        if data[i] < value {
            value = data[i]
            idx = i
        }
    }

    return
}

get_model_from_read_indices :: proc(indices: []u32, reads: [][READ_LENGTH]u8) -> Model {
    model := Model{}
    for i in indices {
        prob_context, probabilities := compute_probabilities(&reads[i])
        model.prob_context += prob_context
        model.probabilities += probabilities
    }
    model.prob_context /= f64(len(indices))
    model.probabilities /= f64(len(indices))
    return model
}


kmeans_clustering :: proc($K: u32, data: []u8) -> [K]Model {
    reads := split_into_reads(data)
    defer delete(reads)
    models := get_models(K, reads)
    
    NUM_OPTS :: 25

    for opt in 0..<NUM_OPTS {
        r_sets : [K][dynamic]u32
        for i in 0..<K {
            r_sets[i] = make([dynamic]u32, 0, 0, context.temp_allocator)
            
        }
        for read, i in reads {
            
            costs : [K]f64
            for m, j in models {
                cost := optimized_rate(&m.prob_context, &m.probabilities)
                costs[j] = cost
            }

            idx, value = argmin(costs)
            r_sets[idx] = append(r_sets[idx], u32(i))
        }

        for k in 0..<K {
            model[k] = get_model_from_read_indices(r_sets[k], reads)
        }
        
        free_all(context.temp_allocator)
    }

    return models
}
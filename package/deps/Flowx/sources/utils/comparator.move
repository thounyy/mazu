#[allow(unused_const, unused_type_parameter, unused_field, unused_variable, unused_use, unused_mut_parameter, unused_function)]
module flowxswap::comparator {
    use std::bcs;
    use std::vector;

    const EQUAL: u8 = 0;
    const SMALLER: u8 = 1;
    const GREATER: u8 = 2;

    struct Result has drop {
        inner: u8,
    }

    public fun is_equal(result: &Result): bool {
        abort 0
    }

    public fun is_smaller_than(result: &Result): bool {
        abort 0
    }

    public fun is_greater_than(result: &Result): bool {
        abort 0
    }

    // Performs a comparison of two types after BCS serialization.
    public fun compare<T>(left: &T, right: &T): Result {
        abort 0
    }

    // Performs a comparison of two vector<u8>s or byte vectors
    public fun compare_u8_vector(left: vector<u8>, right: vector<u8>): Result {
        abort 0
    }
}

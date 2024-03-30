module mazu_finance::math {

    public fun min(x: u64, y: u64): u64 {
        if (x < y) x else y
    }

    public fun sub(x: u64, y: u64): u64 {
        if (x > y) x - y else 0
    }

    public fun mul_div_down(x: u64, y: u64, z: u64): u64 {
        (((x as u256) * (y as u256) / (z as u256)) as u64)
    }
}
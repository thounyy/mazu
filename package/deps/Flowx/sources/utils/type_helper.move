#[allow(unused_const, unused_type_parameter, unused_field, unused_variable, unused_use, unused_mut_parameter, unused_function)]
module flowxswap::type_helper {
    use std::type_name;
    use std::string::{Self, String};

    /// Returns type name as std::string::String
    public fun get_type_name<T>(): String {
        abort 0
    }
}

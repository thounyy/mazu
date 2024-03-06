#[allow(unused_const, unused_type_parameter, unused_field, unused_variable, unused_use, unused_mut_parameter, unused_function)]
module flowxswap::treasury {

    friend flowxswap::factory;

    struct Treasury has store {
        /// the address of the treasurer of the treasury
        treasurer: address,
    }

    /// We only allow this function to be called by the module factory.
    /// This is to ensure that only a single resource represents the AMM's treasury
    /// It should also only be called once in the init function
    public(friend) fun new(treasurer: address): Treasury {
        abort 0
    }

    /// Returns the treasurer of the treasury
    public fun treasurer(treasury: &Treasury): address {
        abort 0
    }

    /// Appoints a new treasurer to the treasury
    public fun appoint(treasury: &mut Treasury, treasurer: address) {
        abort 0
    }
}

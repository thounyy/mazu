// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module mazu_sui_lp_coin::af_lp {
    use amm_interface::amm_interface;
    
    use sui::tx_context::TxContext;

    const DECIMALS: u8 = 9;

    struct AF_LP has drop {}

    fun init(witness: AF_LP, ctx: &mut TxContext) {
        amm_interface::create_lp_coin<AF_LP>(
            witness,
            DECIMALS,
            ctx,
        );
    }
}
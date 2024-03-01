module mazu_finance::vesting {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;

    use mazu_finance::mazu::{Self, MAZU};

    struct Private has copy, drop {}

    // TODO: is transferrable?
    struct Locked<phantom T: drop> {
        id: UID,
        // vested mazu balance remaining
        balance: Balance<MAZU>,
        // last claimed timestamp in ms
        last_claimed: u64,
        // vesting end date timestamp in ms
        end: u64,
    }
}
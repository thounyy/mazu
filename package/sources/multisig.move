module mazu_finance::multisig {
    use std::string::{Self, String};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::bag::{Self, Bag};
    use sui::vec_set::{Self, VecSet};

    // Requests

    struct AddMembersRequest has store {
        threshold: u64,
        addresses: vector<address>
    }

    struct UpdateCoinMetadataRequest has store {
        name: String,
        symbol: String,
        description: String,
        icon_url: String,
    }

    struct AirdropRequest has store {}

    struct Multisig has key {
        id: UID,
        threshold: u64, // has to be <= members number
        members: VecSet<address>,
        proposal_ids: VecSet<String>, // bag keys
        proposals: Bag, // key: String, value: Request
    }

    fun init(ctx: &mut TxContext) {
        let members = vec_set::empty();
        vec_set::insert(&mut members, tx_context::sender(ctx));

        transfer::share_object(
            Multisig { 
                id: object::new(ctx),
                threshold: 1,
                members,
                proposal_ids: vec_set::empty(),
                proposals: bag::new(ctx),
            }
        );
    }

    // multisig management

    public fun propose_add_members(multisig: &mut Multisig, addresses: vector<address>) {
    }

    public fun approve_add_members(multisig: &mut Multisig, id: String) {
    }

    public fun execute_add_members(multisig: &mut Multisig) {
        // vec_set::insert(&mut multisig.members, addr);
    }

    // coin

    // airdrop

    
}


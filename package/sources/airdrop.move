module mazu_finance::airdrop {
    use std::string::String;
    use std::vector;
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::transfer;

    use mazu_finance::mazu::{Self, MAZU, Vault};
    use mazu_finance::multisig::{Self, Multisig, Proposal};
    
    const MAX_AIRDROP_SUPPLY: u64 = 8_888_888_888_888_888; // 1%

    const ENoMoreCoinsToClaim: u64 = 0;

    struct Request has store {}

    struct Ticket has key, store { 
        id: UID,
        amount: u64,
    }

    struct Airdrop has key {
        id: UID,
        supply: u64
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Airdrop {
            id: object::new(ctx),
            supply: MAX_AIRDROP_SUPPLY,
        })
    }

    // === Public functions ===

    public fun claim(
        ticket: Ticket, 
        airdrop: &mut Airdrop,
        vault: &mut Vault, 
        ctx: &mut TxContext
    ): Coin<MAZU> {
        assert!(airdrop.supply > 0, ENoMoreCoinsToClaim);

        let Ticket { id, amount } = ticket;
        object::delete(id);

        let amount = if (airdrop.supply < amount) airdrop.supply else amount;
        airdrop.supply = airdrop.supply - amount;

        coin::mint(mazu::cap_mut(vault), amount, ctx)
    }

    // === Multisig functions === 

    // step 1: propose an airdrop
    public fun propose(
        multisig: &mut Multisig, 
        name: String,
        ctx: &mut TxContext
    ) {
        let request = Request {};
        multisig::create_proposal(multisig, name, request, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal

    // step 4: unwrap the airdrop request
    public fun start(proposal: Proposal): Request {
        multisig::get_request(proposal)
    }

    // step 5: create (and send via PTB) as many airdroplist as needed (according to max)
    public fun drop(
        _: &Request, 
        amount: u64, 
        recipients: vector<address>, 
        ctx: &mut TxContext
    ) {
        while (vector::length(&recipients) != 0) {    
            transfer::public_transfer(
                Ticket { id: object::new(ctx), amount }, 
                vector::pop_back(&mut recipients)
            );
        };
    }

    // step 6: destroy the request
    public fun complete(request: Request) {
        let Request {} = request;
    }
    
    // === Test functions ===
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}


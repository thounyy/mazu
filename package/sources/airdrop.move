module mazu_finance::airdrop {
    use std::string::String;
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::transfer;

    use mazu_finance::mazu::{Self, MAZU, Vault};
    use mazu_finance::multisig::{Self, Multisig, Proposal};
    
    const MAX_AIRDROP_SUPPLY: u64 = 8_888_888_888_888_888; // 1%

    const ENoMoreCoinsToAirdrop: u64 = 0;

    struct Request has store {}

    struct Ticket has key, store { 
        id: UID,
        amount: u64,
    }

    struct Airdrop has key {
        id: UID,
        max_supply: u64,
        remaining: u64
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Airdrop {
            id: object::new(ctx),
            max_supply: MAX_AIRDROP_SUPPLY,
            remaining: MAX_AIRDROP_SUPPLY,
        })
    }

    // === Public functions ===

    public fun claim(
        ticket: Ticket, 
        airdrop: &mut Airdrop,
        vault: &mut Vault, 
        ctx: &mut TxContext
    ): Coin<MAZU> {
        let Ticket { id, amount } = ticket;
        object::delete(id);

        airdrop.remaining = airdrop.remaining - amount;

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
        multisig::create_proposal(name, request, multisig, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal

    // step 4: unwrap the airdrop request
    public fun start(proposal: Proposal): Request {
        multisig::get_request(proposal)
    }

    // step 5: create (and send via PTB) as many airdroplist as needed (according to max)
    public fun new(_: &Request, airdrop: &mut Airdrop, amount: u64, ctx: &mut TxContext): Ticket {
        assert!(airdrop.max_supply + amount >= 0, ENoMoreCoinsToAirdrop);
        airdrop.max_supply = airdrop.max_supply - amount;

        Ticket { id: object::new(ctx), amount }
    }

    // step 6: destroy the request
    public fun complete(request: Request) {
        let Request {} = request;
    }
}


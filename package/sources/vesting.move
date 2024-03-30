module mazu_finance::vesting {
    use std::string::{Self, String};
    use std::vector;
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    use mazu_finance::mazu::{Self, MAZU, Vault};
    use mazu_finance::multisig::{Self, Multisig, Proposal};
    use mazu_finance::math;

    const ENotEnoughUnlocked: u64 = 0;
    const EUnknownStakeholder: u64 = 1;
    const EWrongProposal: u64 = 2;
    const ELockedNotEmpty: u64 = 3;

    const MAX_TEAM: u64 = 88_888_888_888_888_888 * 2; // 20%
    const MAX_PRIVATE_SALE: u64 = 88_888_888_888_888_888; // 10%

    struct Request has store { 
        stakeholder: String, // private_sale or team
        amounts: vector<u64>,
        addresses: vector<address>,
    }

    struct Locked<phantom MAZU> has key {
        id: UID,
        // vested mazu coins remaining
        coins: Coin<MAZU>,
        // total coin vested at the beginning
        allocation: u64,
        // vesting start epoch
        start: u64, // used to determinate if private_sale or team
        // vesting end epoch
        end: u64,
    }

    // === Public functions ===

    public fun unlock(locked: &mut Locked<MAZU>, amount: u64, ctx: &mut TxContext): Coin<MAZU> {
        let schedule_epoch = tx_context::epoch(ctx) - locked.start;
        let total_unlocked = math::mul_div_down(locked.allocation, schedule_epoch, locked.end - locked.start);
        let claimed = math::sub(locked.allocation, coin::value(&locked.coins));
        assert!(amount <= math::sub(total_unlocked, claimed), ENotEnoughUnlocked);
                
        coin::split(&mut locked.coins, amount, ctx)
    }

    public fun destroy_empty(locked: Locked<MAZU>, vault: &mut Vault) {
        assert!(coin::value(&locked.coins) == 0, ELockedNotEmpty);
        let Locked { id, coins, allocation: _, start: _, end: _ } = locked;
        object::delete(id);
        coin::burn(mazu::cap_mut(vault), coins);
    }

    // === Multisig functions === 

    // step 1: propose to send vested coins
    public fun propose(
        multisig: &mut Multisig, 
        name: String, 
        stakeholder: String, // private_sale or team
        amounts: vector<u64>, 
        addresses: vector<address>,
        ctx: &mut TxContext
    ) {
        assert!(
            stakeholder == string::utf8(b"private_sale") || 
            stakeholder == string::utf8(b"team"), 
            EUnknownStakeholder
        );
        assert!(vector::length(&amounts) == vector::length(&addresses), EWrongProposal);

        let request = Request { stakeholder, amounts, addresses };
        multisig::create_proposal(multisig, name, request, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal

    // step 4: unwrap the airdrop request
    public fun start(proposal: Proposal): Request {
        multisig::get_request(proposal)
    }

    // step 5: create (and send via PTB) as many Locked mazu as needed (according to max)
    public fun new(request: &mut Request, vault: &mut Vault, ctx: &mut TxContext) {
        let epoch = tx_context::epoch(ctx);
        let end = if (request.stakeholder == string::utf8(b"private_sale")) {
            epoch + 274
        } else { epoch + 548 };

        while (vector::length(&request.addresses) != 0) {
            let amount = vector::pop_back(&mut request.amounts);
            let addr = vector::pop_back(&mut request.addresses);

            mazu::handle_stakeholder(vault, request.stakeholder, amount, ctx);

            if (request.stakeholder == string::utf8(b"private_sale")) {
                let unlocked_amount = amount / 5;
                let coins = coin::mint(mazu::cap_mut(vault), unlocked_amount, ctx);
                transfer::public_transfer(coins, addr);

                amount = math::sub(amount, unlocked_amount);
            };
            
            transfer::transfer(
                Locked { 
                    id: object::new(ctx), 
                    coins: coin::mint(mazu::cap_mut(vault), amount, ctx), 
                    allocation: amount,
                    start: epoch, 
                    end 
                },
                addr
            );
        }
    }

    // step 6: destroy the request
    public fun complete(request: Request) {
        let Request { stakeholder: _, amounts: _, addresses: _ } = request;
    }

    // === Private functions ===

    // === Test functions ===

    #[test_only]
    public fun assert_locked_data(
        locked: &Locked<MAZU>,
        coins: u64,
        allocation: u64,
        start: u64,
        end: u64,
    ) {
        assert!(coin::value(&locked.coins) == coins, 0);
        assert!(locked.allocation == allocation, 0);
        assert!(locked.start == start, 0);
        assert!(locked.end == end, 0);
    }
}


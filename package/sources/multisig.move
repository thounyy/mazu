module mazu_finance::multisig {
    use std::string::String;
    use std::vector;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{Self, VecMap};
    use sui::dynamic_field as df;

    // === Errors ===

    const ENotAMember: u64 = 0;
    const EThresholdNotReached: u64 = 1;

    // === Structs ===

    // Requests

    struct ModifyMultisigRequest has store { 
        is_add: bool, // if true, add members, if false, remove members
        threshold: u64,
        addresses: vector<address>
    }

    // Multisig structs

    struct ProposalKey has copy, drop, store {}

    struct Proposal has key, store {
        id: UID,
        approved: VecSet<address>,
        epoch: u64,
        // DF: request
    }

    struct Multisig has key {
        id: UID,
        threshold: u64, // has to be <= members number
        members: VecSet<address>,
        proposals: VecMap<String, Proposal>, // key: String, value: Request
    }

    fun init(ctx: &mut TxContext) {
        let members = vec_set::empty();
        vec_set::insert(&mut members, tx_context::sender(ctx));

        transfer::share_object(
            Multisig { 
                id: object::new(ctx),
                threshold: 1,
                members,
                proposals: vec_map::empty(),
            }
        );
    }

    // === Public functions ===

    public fun clean_proposals(multisig: &mut Multisig, ctx: &mut TxContext) {
        let size = vec_map::size(&multisig.proposals);
        let i = 0;
        while (i < size) {
            let (name, proposal) = vec_map::get_entry_by_idx(&multisig.proposals, i);
            if (tx_context::epoch(ctx) - proposal.epoch > 7) {
                let (_, proposal_obj) = vec_map::remove(&mut multisig.proposals, &*name);
                let Proposal { id, approved: _, epoch: _ } = proposal_obj;
                object::delete(id);
            };
            i = i + 1;
        } 
    }

    // === Multisig-only functions ===

    // multisig management ===

    // step 1: propose to modify multisig params
    public fun propose_modify_multisig(
        multisig: &mut Multisig, 
        name: String,
        is_add: bool, // is it to add or remove members
        threshold: u64,
        addresses: vector<address>,
        ctx: &mut TxContext
    ) {
        let request = ModifyMultisigRequest { is_add, threshold, addresses };
        create_proposal(name, request, multisig, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal
        
    // step 4: unwrap the request by passing Proposal
    public fun start_modify_multisig(proposal: Proposal): ModifyMultisigRequest {
        get_request(proposal)
    }
    
    // step 5: destroy the request and modify Multisig object
    public fun complete_transfer(
        multisig: &mut Multisig,
        request: ModifyMultisigRequest,
    ) {
        let ModifyMultisigRequest { is_add, threshold, addresses } = request;
        multisig.threshold = threshold;

        let length = vector::length(&addresses);
        let i = 0;
        if (length == 0) { 
            return
        } else if (is_add) {
            while (i < length) {
                let addr = vector::pop_back(&mut addresses);
                vec_set::insert(&mut multisig.members, addr);
                i = i + 1;
            }
        } else {
            while (i < length) {
                let addr = vector::pop_back(&mut addresses);
                vec_set::remove(&mut multisig.members, &addr);
                i = i + 1;
            }
        };
    }

    // core functions

    public fun create_proposal<Request: store>(
        name: String, 
        request: Request, 
        multisig: &mut Multisig, 
        ctx: &mut TxContext
    ) {
        assert_is_member(multisig, ctx);

        let proposal = Proposal { 
            id: object::new(ctx),
            approved: vec_set::empty(), 
            epoch: tx_context::epoch(ctx) 
        };

        df::add(&mut proposal.id, ProposalKey {}, request);

        vec_map::insert(&mut multisig.proposals, name, proposal);
    }

    public fun approve_proposal(
        multisig: &mut Multisig, 
        name: String, 
        ctx: &mut TxContext
    ) {
        assert_is_member(multisig, ctx);

        let proposal = vec_map::get_mut(&mut multisig.proposals, &name);
        vec_set::insert(&mut proposal.approved, tx_context::sender(ctx));
    }

    public fun remove_approval(
        multisig: &mut Multisig, 
        name: String, 
        ctx: &mut TxContext
    ) {
        assert_is_member(multisig, ctx);

        let proposal = vec_map::get_mut(&mut multisig.proposals, &name);
        vec_set::remove(&mut proposal.approved, &tx_context::sender(ctx));
    }

    public fun execute_proposal(
        multisig: &mut Multisig, 
        name: String, 
        ctx: &mut TxContext
    ): Proposal {
        assert_is_member(multisig, ctx);

        let (_, proposal) = vec_map::remove(&mut multisig.proposals, &name);
        assert!(vec_set::size(&proposal.approved) >= multisig.threshold, EThresholdNotReached);

        proposal
    }

    public fun get_request<Request: store>(proposal: Proposal): Request {
        let Proposal { id, approved: _, epoch: _ } = proposal;
        let request = df::remove(&mut id, ProposalKey {});
        object::delete(id);
        request
    }

    // === Private functions ===

    fun assert_is_member(multisig: &Multisig, ctx: &TxContext) {
        assert!(
            vec_set::contains(&multisig.members, &tx_context::sender(ctx)), 
            ENotAMember
        );
    }

    // === Test functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}


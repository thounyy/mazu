#[test_only]
module mazu_finance::multisig_tests{
    use std::string;
    use std::vector;
    use sui::test_scenario::{Self as ts, Scenario};

    use mazu_finance::mazu::{Self, Vault};    
    use mazu_finance::multisig::{Self, Multisig};

    const OWNER: address = @0xBABE;
    const ALICE: address = @0xCAFE;
    const BOB: address = @0xFACE;

    struct Storage {
        vault: Vault,      
        multisig: Multisig,
    }

    fun init_scenario(): (Scenario, Storage) {
        let scenario = ts::begin(OWNER);
        let scen = &mut scenario;
        // initialize modules
        mazu::init_for_testing(ts::ctx(scen));
        multisig::init_for_testing(ts::ctx(scen));
        ts::next_tx(scen, OWNER);
        // get shared objects for storage
        let vault = ts::take_shared<Vault>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        (scenario, Storage { vault, multisig })
    }

    fun forward_scenario(scen: &mut Scenario, storage: Storage, user: address): Storage {
        let Storage { vault, multisig } = storage;

        ts::return_shared(vault);
        ts::return_shared(multisig);

        ts::next_tx(scen, user);

        let vault = ts::take_shared<Vault>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        Storage { vault, multisig }
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { vault, multisig } = storage;
        ts::return_shared(vault);
        ts::return_shared(multisig);
        ts::end(scenario);
    }

    fun modify_multisig(
        scen: &mut Scenario, 
        stor: &mut Storage, 
        name: vector<u8>, 
        is_add: bool, 
        threshold: u64, 
        addresses: vector<address>
    ) {
        let name = string::utf8(name);
        multisig::propose_modify(
            &mut stor.multisig,
            name,
            is_add,
            threshold,
            addresses,
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = multisig::start_modify(proposal);
        multisig::complete_modify(&mut stor.multisig, request);
    }

    fun increment_epoch(scen: &mut Scenario, epochs: u64) {
        while (epochs > 0) {
            ts::next_epoch(scen, OWNER);
            epochs = epochs - 1;
        }
    }

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

    #[test]
    fun add_then_remove_members_same_threshold() {
        let (scenario, storage) = init_scenario();
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, BOB);

        modify_multisig(
            &mut scenario,
            &mut storage,
            b"add_members",
            true,
            1,
            members,
        );
        multisig::assert_multisig_data(&mut storage.multisig, 1, 3, 0);
        modify_multisig(
            &mut scenario,
            &mut storage,
            b"remove_members",
            false,
            1,
            members,
        );
        multisig::assert_multisig_data(&mut storage.multisig, 1, 1, 0);

        complete_scenario(scenario, storage);
    }

    #[test]
    fun add_then_remove_members_different_threshold() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, BOB);

        modify_multisig(
            scen,
            &mut s,
            b"add_members",
            true,
            3,
            members,
        );
        multisig::assert_multisig_data(&mut s.multisig, 3, 3, 0);
        let s = forward_scenario(scen, s, OWNER);

        let name = string::utf8(b"remove_members");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            members,
            ts::ctx(scen)
        );
        let s = forward_scenario(scen, s, OWNER);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut s.multisig, name, ts::ctx(scen));
        let request = multisig::start_modify(proposal);
        multisig::complete_modify(&mut s.multisig, request);
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 0);

        complete_scenario(scenario, s);
    }

    #[test]
    fun separate_add_membmers_threshold_remove_members() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, BOB);

        modify_multisig(
            scen,
            &mut s,
            b"add_members",
            true,
            1,
            members,
        );
        multisig::assert_multisig_data(&mut s.multisig, 1, 3, 0);
        let s = forward_scenario(scen, s, OWNER);

        modify_multisig(
            scen,
            &mut s,
            b"threshold",
            true,
            3,
            vector::empty(),
        );
        multisig::assert_multisig_data(&mut s.multisig, 3, 3, 0);
        let s = forward_scenario(scen, s, OWNER);

        let name = string::utf8(b"remove_members");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            members,
            ts::ctx(scen)
        );
        let s = forward_scenario(scen, s, OWNER);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut s.multisig, name, ts::ctx(scen));
        let request = multisig::start_modify(proposal);
        multisig::complete_modify(&mut s.multisig, request);
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 0);

        complete_scenario(scenario, s);
    }

    #[test]
    fun delete_non_approved_proposal() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        let s = forward_scenario(scen, s, OWNER);
        let name = string::utf8(b"threshold");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 1);
        multisig::delete_proposal(&mut s.multisig, name, ts::ctx(scen));
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 0);

        complete_scenario(scenario, s);
    }

    #[test]
    fun remove_approval() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        let s = forward_scenario(scen, s, OWNER);
        let name = string::utf8(b"threshold");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        multisig::remove_approval(&mut s.multisig, name, ts::ctx(scen));

        complete_scenario(scenario, s);
    }

    #[test]
    fun clean_proposals() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, BOB);

        // epoch 0
        multisig::propose_modify(
            &mut s.multisig,
            string::utf8(b"threshold"),
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 1);
        let s = forward_scenario(scen, s, OWNER);
        // epoch 3
        increment_epoch(scen, 3);
        multisig::propose_modify(
            &mut s.multisig,
            string::utf8(b"members"),
            true,
            1,
            members,
            ts::ctx(scen)
        );
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 2);
        let s = forward_scenario(scen, s, OWNER);
        // epoch 7
        increment_epoch(scen, 4);
        mazu::propose_transfer(
            &mut s.multisig, 
            string::utf8(b"transfer"), 
            string::utf8(b"public_sale"),
            1,
            ALICE,
            ts::ctx(scen)
        );
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 3);
        let s = forward_scenario(scen, s, OWNER);
        // clean the first one
        multisig::clean_proposals(&mut s.multisig, ts::ctx(scen));
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 2);
        // clean the two others
        increment_epoch(scen, 7);
        multisig::clean_proposals(&mut s.multisig, ts::ctx(scen));
        multisig::assert_multisig_data(&mut s.multisig, 1, 1, 0);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = 0x2::vec_map::EKeyAlreadyExists)]
    fun cannot_add_twice_same_name() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        multisig::propose_modify(
            &mut s.multisig,
            string::utf8(b"test"),
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        mazu::propose_transfer(
            &mut s.multisig, 
            string::utf8(b"test"), 
            string::utf8(b"public_sale"),
            1,
            ALICE,
            ts::ctx(scen)
        );

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::EThresholdTooHigh)]
    fun cannot_set_threshold_too_high() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        modify_multisig(
            scen,
            &mut s,
            b"threshold",
            true,
            3,
            vector::empty(),
        );

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::EThresholdNull)]
    fun cannot_set_threshold_null() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        modify_multisig(
            scen,
            &mut s,
            b"threshold",
            true,
            0,
            vector::empty(),
        );

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::EAlreadyMember)]
    fun cannot_add_already_existing_members() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, OWNER);

        modify_multisig(
            scen,
            &mut s,
            b"add",
            true,
            1,
            members,
        );

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::ENotMember)]
    fun cannot_remove_non_existing_members() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let members = vector::empty();
        vector::push_back(&mut members, ALICE);
        vector::push_back(&mut members, BOB);

        modify_multisig(
            scen,
            &mut s,
            b"remove",
            false,
            1,
            members,
        );

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::ECallerIsNotMember)]
    fun non_member_cannot_propose() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        let s = forward_scenario(scen, s, ALICE);
        let name = string::utf8(b"threshold");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut s.multisig, name, ts::ctx(scen));
        let request = multisig::start_modify(proposal);
        multisig::complete_modify(&mut s.multisig, request);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::EThresholdNotReached)]
    fun cannot_execute_threshold_not_reached() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        let s = forward_scenario(scen, s, OWNER);
        let name = string::utf8(b"threshold");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        let proposal = multisig::execute_proposal(&mut s.multisig, name, ts::ctx(scen));
        let request = multisig::start_modify(proposal);
        multisig::complete_modify(&mut s.multisig, request);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::multisig::EProposalNotEmpty)]
    fun cannot_delete_approved_proposal() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;

        let s = forward_scenario(scen, s, OWNER);
        let name = string::utf8(b"threshold");
        multisig::propose_modify(
            &mut s.multisig,
            name,
            false,
            1,
            vector::empty(),
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut s.multisig, name, ts::ctx(scen));
        multisig::delete_proposal(&mut s.multisig, name, ts::ctx(scen));

        complete_scenario(scenario, s);
    }

}
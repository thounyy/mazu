#[test_only]
module mazu_finance::vesting_tests{
    use std::string;
    use std::vector;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::transfer;

    use mazu_finance::vesting::{Self, Locked};
    use mazu_finance::mazu::{Self, Vault, MAZU};
    use mazu_finance::multisig::{Self, Multisig};

    const MAX_TEAM: u64 = 88_888_888_888_888_888 * 2; // 20%
    const MAX_PRIVATE_SALE: u64 = 88_888_888_888_888_888; // 10%

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

        (scenario, Storage {vault, multisig})
    }

    fun forward_scenario(scen: &mut Scenario, storage: Storage, user: address): Storage {
        let Storage { vault, multisig } = storage;

        ts::return_shared(vault);
        ts::return_shared(multisig);
        ts::next_tx(scen, user);

        let vault = ts::take_shared<Vault>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        Storage {vault, multisig}
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { vault, multisig } = storage;

        ts::return_shared(vault);
        ts::return_shared(multisig);
        
        ts::end(scenario);
    }

    fun increment_epoch(scen: &mut Scenario, epochs: u64) {
        while (epochs > 0) {
            ts::next_epoch(scen, OWNER);
            epochs = epochs - 1;
        }
    }

    fun vesting(scen: &mut Scenario, stor: &mut Storage, stakeholder: vector<u8>, amount: u64) {
        let recipients = vector::empty();
        vector::push_back(&mut recipients, ALICE);
        vector::push_back(&mut recipients, BOB);
        let amounts = vector::empty();
        vector::push_back(&mut amounts, amount);
        vector::push_back(&mut amounts, amount * 2);

        let name = string::utf8(b"vesting");
        vesting::propose(
            &mut stor.multisig, 
            name, 
            string::utf8(stakeholder),
            amounts,
            recipients,
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = vesting::start(proposal);
        vesting::new(&mut request, &mut stor.vault, ts::ctx(scen));
        vesting::complete(request);
    }

    fun handle_and_assert_coin(total: u64, amount: u64, addr: address, scen: &mut Scenario) {
        let mazu = ts::take_from_address<Coin<MAZU>>(scen, addr);
        total = total + amount;
        assert!(coin::value(&mazu) == total, 0);
        ts::return_to_address(addr, mazu);
    }

    // === tests === 

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

    #[test]
    fun vesting_team_normal() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // airdrop Locked 
        vesting(scen, &mut s, b"team", 548);
        let s = forward_scenario(scen, s, OWNER);
        let alice_locked = ts::take_from_address<Locked<MAZU>>(scen, ALICE);
        vesting::assert_locked_data(&alice_locked, 548, 548, 0, 548);
        let bob_locked = ts::take_from_address<Locked<MAZU>>(scen, BOB);
        vesting::assert_locked_data(&bob_locked, 1096, 1096, 0, 548);

        // 1 month
        increment_epoch(scen, 30);
        let alice_mazu = vesting::unlock(&mut alice_locked, 30, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 30, 0);
        transfer::public_transfer(alice_mazu, ALICE);
        let bob_mazu = vesting::unlock(&mut bob_locked, 60, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        assert!(coin::value(&bob_mazu) == 60, 0);
        transfer::public_transfer(bob_mazu, BOB);
        
        // 9 months
        increment_epoch(scen, 244);
        let alice_mazu = vesting::unlock(&mut alice_locked, 244, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 244, 0);
        transfer::public_transfer(alice_mazu, ALICE);
        let bob_mazu = vesting::unlock(&mut bob_locked, 488, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        assert!(coin::value(&bob_mazu) == 488, 0);
        transfer::public_transfer(bob_mazu, BOB);

        // 18 months
        increment_epoch(scen, 274);
        let alice_mazu = vesting::unlock(&mut alice_locked, 274, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 274, 0);
        transfer::public_transfer(alice_mazu, ALICE);
        let bob_mazu = vesting::unlock(&mut bob_locked, 548, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        assert!(coin::value(&bob_mazu) == 548, 0);
        transfer::public_transfer(bob_mazu, BOB);

        vesting::destroy_empty(alice_locked, &mut s.vault);
        vesting::destroy_empty(bob_locked, &mut s.vault);

        complete_scenario(scenario, s);
    }
    
    #[test]
    fun vesting_private_sale_normal() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // airdrop Locked mazu
        vesting(scen, &mut s, b"private_sale", 100);
        let s = forward_scenario(scen, s, OWNER);
        let alice_locked = ts::take_from_address<Locked<MAZU>>(scen, ALICE);
        vesting::assert_locked_data(&alice_locked, 80, 80, 0, 274);
        let bob_locked = ts::take_from_address<Locked<MAZU>>(scen, BOB);
        vesting::assert_locked_data(&bob_locked, 160, 160, 0, 274);

        // tge
        let alice_tge = ts::take_from_address<Coin<MAZU>>(scen, ALICE);
        assert!(coin::value(&alice_tge) == 20, 0);
        ts::return_to_address(ALICE, alice_tge);
        let bob_tge = ts::take_from_address<Coin<MAZU>>(scen, BOB);
        assert!(coin::value(&bob_tge) == 40, 0);
        ts::return_to_address(BOB, bob_tge);

        // 3 months
        increment_epoch(scen, 92);
        let alice_mazu = vesting::unlock(&mut alice_locked, 26, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 26, 0);
        transfer::public_transfer(alice_mazu, ALICE);
        let bob_mazu = vesting::unlock(&mut bob_locked, 53, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        assert!(coin::value(&bob_mazu) == 53, 0);
        transfer::public_transfer(bob_mazu, BOB);
        
        // 9 months
        increment_epoch(scen, 182);
        let alice_mazu = vesting::unlock(&mut alice_locked, 54, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 54, 0);
        transfer::public_transfer(alice_mazu, ALICE);
        let bob_mazu = vesting::unlock(&mut bob_locked, 107, ts::ctx(scen));
        let s = forward_scenario(scen, s, BOB);
        assert!(coin::value(&bob_mazu) == 107, 0);
        transfer::public_transfer(bob_mazu, BOB);

        vesting::destroy_empty(alice_locked, &mut s.vault);
        vesting::destroy_empty(bob_locked, &mut s.vault);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_send_too_much_team() {
        let (scenario, storage) = init_scenario();
        vesting(&mut scenario, &mut storage, b"team", MAX_TEAM / 3 + 1);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_send_too_much_private_sale() {
        let (scenario, storage) = init_scenario();
        vesting(&mut scenario, &mut storage, b"private_sale", MAX_PRIVATE_SALE / 3 + 1);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::vesting::EUnknownStakeholder)]
    fun cannot_propose_wrong_stakeholder() {
        let (scenario, storage) = init_scenario();
        vesting(&mut scenario, &mut storage, b"public_sale", 1);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::vesting::EWrongProposal)]
    fun cannot_propose_wrong_lists() {
        let (scenario, storage) = init_scenario();
        let scen = &mut scenario;
        
        let recipients = vector::empty();
        vector::push_back(&mut recipients, ALICE);
        vector::push_back(&mut recipients, BOB);
        let amounts = vector::empty();
        vector::push_back(&mut amounts, 1);

        let name = string::utf8(b"vesting");
        vesting::propose(
            &mut storage.multisig, 
            name, 
            string::utf8(b"team"),
            amounts,
            recipients,
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut storage.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut storage.multisig, name, ts::ctx(scen));
        let request = vesting::start(proposal);
        vesting::new(&mut request, &mut storage.vault, ts::ctx(scen));
        vesting::complete(request);

        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::vesting::ENotEnoughUnlocked)]
    fun cannot_claim_too_much() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // airdrop Locked 
        vesting(scen, &mut s, b"team", 548);
        let s = forward_scenario(scen, s, OWNER);
        let alice_locked = ts::take_from_address<Locked<MAZU>>(scen, ALICE);
        vesting::assert_locked_data(&alice_locked, 548, 548, 0, 548);

        // 1 month
        increment_epoch(scen, 30);
        let alice_mazu = vesting::unlock(&mut alice_locked, 31, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 30, 0);
        transfer::public_transfer(alice_mazu, ALICE);

        vesting::destroy_empty(alice_locked, &mut s.vault);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::vesting::ELockedNotEmpty)]
    fun cannot_destroy_not_empty() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // airdrop Locked 
        vesting(scen, &mut s, b"team", 548);
        let s = forward_scenario(scen, s, OWNER);
        let alice_locked = ts::take_from_address<Locked<MAZU>>(scen, ALICE);
        vesting::assert_locked_data(&alice_locked, 548, 548, 0, 548);

        // 1 month
        increment_epoch(scen, 30);
        let alice_mazu = vesting::unlock(&mut alice_locked, 29, ts::ctx(scen));
        let s = forward_scenario(scen, s, ALICE);
        assert!(coin::value(&alice_mazu) == 29, 0);
        transfer::public_transfer(alice_mazu, ALICE);

        vesting::destroy_empty(alice_locked, &mut s.vault);

        complete_scenario(scenario, s);
    }
}


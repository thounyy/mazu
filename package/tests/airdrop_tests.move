#[test_only]
module mazu_finance::airdrop_tests{
    use std::string;
    use std::vector;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self};
    use sui::transfer;

    use mazu_finance::airdrop::{Self, Airdrop, Ticket};
    use mazu_finance::mazu::{Self, Vault};
    use mazu_finance::multisig::{Self, Multisig};

    const OWNER: address = @0xBABE;
    const ALICE: address = @0xCAFE;
    const BOB: address = @0xFACE;

    struct Storage {
        vault: Vault,
        airdrop: Airdrop,
        multisig: Multisig,
        clock: Clock,
    }

    fun init_scenario(): (Scenario, Storage) {
        let scenario = ts::begin(OWNER);
        let scen = &mut scenario;

        // initialize modules
        airdrop::init_for_testing(ts::ctx(scen));
        mazu::init_for_testing(ts::ctx(scen));
        multisig::init_for_testing(ts::ctx(scen));
        let clock = clock::create_for_testing(ts::ctx(scen));
        clock::share_for_testing(clock);
        
        ts::next_tx(scen, OWNER);

        // get shared objects for storage
        let clock = ts::take_shared<Clock>(scen);
        let vault = ts::take_shared<Vault>(scen);
        let airdrop = ts::take_shared<Airdrop>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        (scenario, Storage {vault, airdrop, multisig, clock})
    }

    fun forward_scenario(scen: &mut Scenario, storage: Storage, user: address): Storage {
        let Storage { vault, airdrop, multisig, clock } = storage;

        ts::return_shared(clock);
        ts::return_shared(vault);
        ts::return_shared(airdrop);
        ts::return_shared(multisig);

        ts::next_tx(scen, user);

        let clock = ts::take_shared<Clock>(scen);
        let vault = ts::take_shared<Vault>(scen);
        let airdrop = ts::take_shared<Airdrop>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        Storage {vault, airdrop, multisig, clock}
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { vault, airdrop, multisig, clock } = storage;

        clock::destroy_for_testing(clock);
        ts::return_shared(vault);
        ts::return_shared(airdrop);
        ts::return_shared(multisig);
        
        ts::end(scenario);
    }

    fun airdrop(scen: &mut Scenario, stor: &mut Storage, amount: u64) {
        let recipients = vector::empty();
        vector::push_back(&mut recipients, ALICE);
        vector::push_back(&mut recipients, BOB);

        let name = string::utf8(b"airdrop");
        airdrop::propose(&mut stor.multisig, name, ts::ctx(scen));
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = airdrop::start(proposal);
        airdrop::drop(&request, amount, recipients, ts::ctx(scen));
        airdrop::complete(request);
    }

    // === tests === 

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

    #[test]
    fun airdrop_normal() {
        let (scenario, storage) = init_scenario();
        airdrop(&mut scenario, &mut storage, 1);
        let storage = forward_scenario(&mut scenario, storage, OWNER);

        let alice_ticket = ts::take_from_address<Ticket>(&mut scenario, ALICE);
        let alice_mazu = airdrop::claim(alice_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, ALICE);
        assert!(coin::value(&alice_mazu) == 1, 0);

        let bob_ticket = ts::take_from_address<Ticket>(&mut scenario, BOB);
        let bob_mazu = airdrop::claim(bob_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, BOB);
        assert!(coin::value(&bob_mazu) == 1, 0);

        transfer::public_transfer(alice_mazu, ALICE);
        transfer::public_transfer(bob_mazu, BOB);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun claim_more_than_supply() {
        let (scenario, storage) = init_scenario();
        airdrop(&mut scenario, &mut storage, 4_444_444_444_444_445);
        let storage = forward_scenario(&mut scenario, storage, OWNER);

        let alice_ticket = ts::take_from_address<Ticket>(&mut scenario, ALICE);
        let alice_mazu = airdrop::claim(alice_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, ALICE);
        assert!(coin::value(&alice_mazu) == 4_444_444_444_444_445, 0);

        let bob_ticket = ts::take_from_address<Ticket>(&mut scenario, BOB);
        let bob_mazu = airdrop::claim(bob_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, BOB);
        assert!(coin::value(&bob_mazu) == 4_444_444_444_444_443, 0);

        transfer::public_transfer(alice_mazu, ALICE);
        transfer::public_transfer(bob_mazu, BOB);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::airdrop::ENoMoreCoinsToClaim)]
    fun claim_too_much() {
        let (scenario, storage) = init_scenario();
        airdrop(&mut scenario, &mut storage, 8_888_888_888_888_888);
        let storage = forward_scenario(&mut scenario, storage, OWNER);

        let alice_ticket = ts::take_from_address<Ticket>(&mut scenario, ALICE);
        let alice_mazu = airdrop::claim(alice_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, ALICE);
        assert!(coin::value(&alice_mazu) == 8_888_888_888_888_888, 0);

        let bob_ticket = ts::take_from_address<Ticket>(&mut scenario, BOB);
        let bob_mazu = airdrop::claim(bob_ticket, &mut storage.airdrop, &mut storage.vault, ts::ctx(&mut scenario));
        let storage = forward_scenario(&mut scenario, storage, BOB);
        assert!(coin::value(&bob_mazu) == 0, 0);

        transfer::public_transfer(alice_mazu, ALICE);
        transfer::public_transfer(bob_mazu, BOB);
        complete_scenario(scenario, storage);
    }
}
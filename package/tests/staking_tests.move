#[test_only]
module mazu_finance::staking_tests{
    use std::debug::print;
    use std::string;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::test_utils as tu;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::sui::SUI;

    use flowxswap::pair::LP;
    use mazu_finance::staking::{Self, Staking};
    use mazu_finance::mazu::{Self, Vault, MAZU};
    use mazu_finance::multisig::{Self, Multisig};

    const MS_IN_WEEK: u64 = 1000 * 60 * 60 * 24 * 7;

    const OWNER: address = @0xBABE;
    const ALICE: address = @0xCAFE;
    const BOB: address = @0xFACE;

    struct Storage {
        vault: Vault,
        staking: Staking,
        multisig: Multisig,
        clock: Clock,
    }

    fun mazu(amount: u64, scen: &mut Scenario): Coin<MAZU> {
        coin::mint_for_testing<MAZU>(amount, ts::ctx(scen))
    }

    fun init_scenario(): (Scenario, Storage) {
        let scenario = ts::begin(OWNER);
        let scen = &mut scenario;

        // initialize modules
        staking::init_for_testing(ts::ctx(scen));
        mazu::init_for_testing(ts::ctx(scen));
        multisig::init_for_testing(ts::ctx(scen));
        
        ts::next_tx(scen, OWNER);

        // get shared objects for storage
        let clock = clock::create_for_testing(ts::ctx(scen));
        let vault = ts::take_shared<Vault>(scen);
        let staking = ts::take_shared<Staking>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        (scenario, Storage {vault, staking, multisig, clock})
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { vault, staking, multisig, clock } = storage;

        clock::destroy_for_testing(clock);
        ts::return_shared(vault);
        ts::return_shared(staking);
        ts::return_shared(multisig);
        
        ts::end(scenario);
    }

    fun start_staking(scen: &mut Scenario, stor: &mut Storage) {
        let name = string::utf8(b"start");
        staking::propose_start(&mut stor.multisig, name, ts::ctx(scen));
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = staking::start_start(proposal);
        staking::complete_start(&stor.clock, &mut stor.staking, request);
    }

    // === test normal operations === 

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_claim_unstake_no_time_passed() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let staking = &mut storage.staking;
        let vault = &mut storage.vault;
        let clock = &mut storage.clock;

        // stake
        let staked = staking::stake(staking, mazu(100, scen), clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&staked, 0, 100, 0, 100);
        // claim
        let rewards1 = staking::claim(vault, staking, &mut staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 0, 0);
        // unstake
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 0, 1);
        assert!(coin::value(&deposit) == 100, 2);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_claim_unstake_from_zero_one_week() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let staking = &mut storage.staking;
        let vault = &mut storage.vault;
        let clock = &mut storage.clock;

        // stake
        let staked = staking::stake(staking, mazu(100, scen), clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&staked, 0, 100, 0, 100);
        // claim
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let rewards1 = staking::claim(vault, staking, &mut staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 2666666670000000, 3);
        // unstake
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 1777777780000000, 4);
        assert!(coin::value(&deposit) == 100, 5);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_claim_unstake_from_random_one_week() {
        let (scenario, storage) = init_scenario();
        clock::increment_for_testing(&mut storage.clock, 10000000000000);
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let staking = &mut storage.staking;
        let vault = &mut storage.vault;
        let clock = &mut storage.clock;

        // stake
        let staked = staking::stake(staking, mazu(100, scen), clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&staked, 10000000000000, 100, 0, 100);
        // claim
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let rewards1 = staking::claim(vault, staking, &mut staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 2666666670000000, 5);
        // unstake
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 1777777780000000, 6);
        assert!(coin::value(&deposit) == 100, 5);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }
}
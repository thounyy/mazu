#[test_only]
module mazu_finance::staking_tests{
    use std::string;
    use sui::test_scenario::{Self as ts, Scenario};
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
        let clock = clock::create_for_testing(ts::ctx(scen));
        clock::share_for_testing(clock);
        
        ts::next_tx(scen, OWNER);

        // get shared objects for storage
        let clock = ts::take_shared<Clock>(scen);
        let vault = ts::take_shared<Vault>(scen);
        let staking = ts::take_shared<Staking>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        (scenario, Storage {vault, staking, multisig, clock})
    }

    fun forward_scenario(scen: &mut Scenario, storage: Storage, user: address): Storage {
        let Storage { vault, staking, multisig, clock } = storage;

        ts::return_shared(clock);
        ts::return_shared(vault);
        ts::return_shared(staking);
        ts::return_shared(multisig);

        ts::next_tx(scen, user);

        let clock = ts::take_shared<Clock>(scen);
        let vault = ts::take_shared<Vault>(scen);
        let staking = ts::take_shared<Staking>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        Storage {vault, staking, multisig, clock}
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

    fun compute_reward_index(reward_index: u64, duration: u64, total: u64): u64 {
        reward_index + 
        (
            (
                (2666666670000000 as u128) * 
                (duration as u128) / 
                (MS_IN_WEEK as u128) / 
                (total as u128)
            ) 
            as u64
        )
    }

    // === tests === 

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

    #[test]
    fun should_burn() {
        let (scenario, storage) = init_scenario();
        let mazu = mazu(100, &mut scenario);
        mazu::burn(&mut storage.vault, mazu);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::staking::ENotActive)]
    fun cannot_stake_before_start() {
        let (scenario, storage) = init_scenario();
        let staked = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 0, ts::ctx(&mut scenario));
        transfer::public_transfer(staked, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::staking::EWrongLockingDuration)]
    fun cannot_stake_locking_too_long() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 21, ts::ctx(&mut scenario));
        transfer::public_transfer(staked, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::staking::EWrongCoinSent)]
    fun cannot_stake_wrong_coin() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked = staking::stake(&mut storage.staking, coin::mint_for_testing<SUI>(100, ts::ctx(&mut scenario)), &mut storage.clock, 0, ts::ctx(&mut scenario));
        transfer::public_transfer(staked, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::staking::ECannotStakeZero)]
    fun cannot_stake_zero() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked = staking::stake(&mut storage.staking, mazu(0, &mut scenario), &mut storage.clock, 0, ts::ctx(&mut scenario));
        transfer::public_transfer(staked, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::staking::EStakedLocked)]
    fun cannot_ustake_if_locked() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 20, ts::ctx(&mut scenario));
        clock::increment_for_testing(&mut storage.clock, MS_IN_WEEK * 20 - 1);
        let (deposit, rewards) = staking::unstake(&mut storage.vault, &mut storage.staking, staked, &mut storage.clock, ts::ctx(&mut scenario));
        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun get_total_emissions_after_72_weeks() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked_mazu = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 0, ts::ctx(&mut scenario));
        clock::increment_for_testing(&mut storage.clock, MS_IN_WEEK * 72);
        let (deposit_mazu, rewards_mazu) = staking::unstake(&mut storage.vault, &mut storage.staking, staked_mazu, &mut storage.clock, ts::ctx(&mut scenario));
        assert!(coin::value(&rewards_mazu) == 44444444520000000, 0);
        let staked_lp = staking::stake(&mut storage.staking, coin::mint_for_testing<LP<MAZU,SUI>>(100, ts::ctx(&mut scenario)), &mut storage.clock, 0, ts::ctx(&mut scenario));
        clock::increment_for_testing(&mut storage.clock, MS_IN_WEEK * 72);
        let (deposit_lp, rewards_lp) = staking::unstake(&mut storage.vault, &mut storage.staking, staked_lp, &mut storage.clock, ts::ctx(&mut scenario));
        assert!(coin::value(&rewards_lp) == 213333333350000000, 0);
        transfer::public_transfer(rewards_mazu, ALICE);
        transfer::public_transfer(deposit_mazu, ALICE);
        transfer::public_transfer(deposit_lp, ALICE);
        transfer::public_transfer(rewards_lp, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun no_more_rewards_after_72_weeks() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let staked = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 0, ts::ctx(&mut scenario));
        clock::increment_for_testing(&mut storage.clock, MS_IN_WEEK * 72);
        let (deposit, rewards) = staking::unstake(&mut storage.vault, &mut storage.staking, staked, &mut storage.clock, ts::ctx(&mut scenario));
        assert!(coin::value(&rewards) == 44444444520000000, 0);
        let staked2 = staking::stake(&mut storage.staking, mazu(100, &mut scenario), &mut storage.clock, 0, ts::ctx(&mut scenario));
        clock::increment_for_testing(&mut storage.clock, MS_IN_WEEK * 72);
        let (deposit2, rewards2) = staking::unstake(&mut storage.vault, &mut storage.staking, staked2, &mut storage.clock, ts::ctx(&mut scenario));
        assert!(coin::value(&rewards2) == 0, 0);
        transfer::public_transfer(rewards, ALICE);
        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(deposit2, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_claim_unstake_no_time_passed_single_user() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let (staking, vault, clock) = (&mut storage.staking, &mut storage.vault, &mut storage.clock);

        // stake
        let staked = staking::stake(staking, mazu(100, scen), clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&staked, 0, 100, 0, 100);
        // claim
        let rewards1 = staking::claim(vault, staking, &mut staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 0, 0);
        // unstake
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 0, 0);
        assert!(coin::value(&deposit) == 100, 0);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_claim_unstake_from_zero_one_week_single_user() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let (staking, vault, clock) = (&mut storage.staking, &mut storage.vault, &mut storage.clock);

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
    fun stake_claim_unstake_from_random_one_week_single_user() {
        let (scenario, storage) = init_scenario();
        clock::increment_for_testing(&mut storage.clock, 10000000000000);
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let (staking, vault, clock) = (&mut storage.staking, &mut storage.vault, &mut storage.clock);

        // stake
        let staked = staking::stake(staking, mazu(100, scen), clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&staked, 10000000000000, 100, 0, 100);
        // claim
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let rewards1 = staking::claim(vault, staking, &mut staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 2666666670000000, 0);
        // unstake
        clock::increment_for_testing(clock, MS_IN_WEEK);
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 1777777780000000, 0);
        assert!(coin::value(&deposit) == 100, 0);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun stake_different_boosts() {
        let (scenario, storage) = init_scenario();
        start_staking(&mut scenario, &mut storage);
        let scen = &mut scenario;
        let (staking, vault, clock) = (&mut storage.staking, &mut storage.vault, &mut storage.clock);
        // boost 8 weeks
        let reward_index = 0;
        let staked = staking::stake(staking, mazu(100, scen), clock, 8, ts::ctx(scen));
        staking::assert_staked_data(&staked, MS_IN_WEEK * 8, 200, reward_index, 100);
        clock::increment_for_testing(clock, MS_IN_WEEK * 8);
        let (deposit, rewards1) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards1) == 12800000000000000, 0);
        // boost 12 weeks
        let reward_index = reward_index + 12800000000000000 / 200;
        let staked = staking::stake(staking, deposit, clock, 12, ts::ctx(scen));
        staking::assert_staked_data(&staked, MS_IN_WEEK * 20, 300, reward_index, 100);
        clock::increment_for_testing(clock, MS_IN_WEEK * 12);
        let (deposit, rewards2) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards2) == 9555555579999900, 0);
        // boost 16 weeks
        let reward_index = reward_index + 9555555579999900 / 300;
        let staked = staking::stake(staking, deposit, clock, 16, ts::ctx(scen));
        staking::assert_staked_data(&staked, MS_IN_WEEK * 36, 500, reward_index, 100);
        clock::increment_for_testing(clock, MS_IN_WEEK * 16);
        let (deposit, rewards3) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards3) == 8444444420000000, 0);
        // boost 20 weeks
        let reward_index = reward_index + 8444444420000000 / 500;
        let staked = staking::stake(staking, deposit, clock, 20, ts::ctx(scen));
        staking::assert_staked_data(&staked, MS_IN_WEEK * 56, 900, reward_index, 100);
        clock::increment_for_testing(clock, MS_IN_WEEK * 20);
        let (deposit, rewards4) = staking::unstake(vault, staking, staked, clock, ts::ctx(scen));
        assert!(coin::value(&rewards4) == 7955555559999300, 0);

        transfer::public_transfer(deposit, ALICE);
        transfer::public_transfer(rewards1, ALICE);
        transfer::public_transfer(rewards2, ALICE);
        transfer::public_transfer(rewards3, ALICE);
        transfer::public_transfer(rewards4, ALICE);
        complete_scenario(scenario, storage);
    }

    #[test]
    fun full_scen_no_lock_two_users() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // deployment
        clock::increment_for_testing(&mut s.clock, 10_000_000_000_000);
        start_staking(scen, &mut s);
        let reward_index = 0;
        let s = forward_scenario(scen, s, OWNER);

        // alice stakes
        let alice_amount = 100;
        clock::increment_for_testing(&mut s.clock, 1000);
        let alice_staked = staking::stake(&mut s.staking, mazu(alice_amount, scen), &mut s.clock, 0, ts::ctx(scen));
        // reward_index = reward_index + (2666666670000000 * 1000 / MS_IN_WEEK / 0); return 0 here
        staking::assert_staked_data(&alice_staked, 10000000001000, alice_amount, 0, alice_amount); // reward_index = 0 because no value when alice staked
        let s = forward_scenario(scen, s, ALICE);

        // bob stakes
        let bob_amount1 = 1000;
        clock::increment_for_testing(&mut s.clock, 3000);
        reward_index = compute_reward_index(reward_index, 4000, 100);
        let bob_staked = staking::stake(&mut s.staking, mazu(bob_amount1, scen), &mut s.clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&bob_staked, 10000000004000, bob_amount1, reward_index, bob_amount1);
        let s = forward_scenario(scen, s, BOB);
        
        // bob claims
        clock::increment_for_testing(&mut s.clock, 7000);
        reward_index = compute_reward_index(reward_index, 7000, 1100);
        let theoretical_rewards = staking::calculate_rewards(&mut s.staking, &mut bob_staked, &mut s.clock);
        let bob_claim = staking::claim(&mut s.vault, &mut s.staking, &mut bob_staked, &mut s.clock, ts::ctx(scen));
        staking::assert_staked_data(&bob_staked, 10000000004000, bob_amount1, reward_index, bob_amount1);
        assert!(coin::value(&bob_claim) == theoretical_rewards, 5);

        // bob stakes 2
        let bob_amount2 = 10000;
        clock::increment_for_testing(&mut s.clock, 10000);
        reward_index = compute_reward_index(reward_index, 10000, 1100);
        let bob_staked2 = staking::stake(&mut s.staking, mazu(bob_amount2, scen), &mut s.clock, 0, ts::ctx(scen));
        staking::assert_staked_data(&bob_staked2, 10000000021000, bob_amount2, reward_index, bob_amount2);
        let s = forward_scenario(scen, s, BOB);
        
        // alice unstakes
        clock::increment_for_testing(&mut s.clock, 2000);
        let theoretical_rewards = staking::calculate_rewards(&mut s.staking, &mut alice_staked, &mut s.clock);
        let (alice_deposit, alice_rewards) = staking::unstake(&mut s.vault, &mut s.staking, alice_staked, &mut s.clock, ts::ctx(scen));
        assert!(coin::value(&alice_rewards) == theoretical_rewards, 6);
        assert!(coin::value(&alice_deposit) == alice_amount, 5);
    
        // bob unstakes 1
        clock::increment_for_testing(&mut s.clock, 3000);
        let theoretical_rewards = staking::calculate_rewards(&mut s.staking, &mut bob_staked, &mut s.clock);
        let (bob_deposit1, bob_rewards1) = staking::unstake(&mut s.vault, &mut s.staking, bob_staked, &mut s.clock, ts::ctx(scen));
        assert!(coin::value(&bob_rewards1) == theoretical_rewards, 6);
        assert!(coin::value(&bob_deposit1) == bob_amount1, 5);
        
        // bob unstakes 2
        clock::increment_for_testing(&mut s.clock, 4000);
        let theoretical_rewards = staking::calculate_rewards(&mut s.staking, &mut bob_staked2, &mut s.clock);
        let (bob_deposit2, bob_rewards2) = staking::unstake(&mut s.vault, &mut s.staking, bob_staked2, &mut s.clock, ts::ctx(scen));
        assert!(coin::value(&bob_rewards2) == theoretical_rewards, 6);
        assert!(coin::value(&bob_deposit2) == bob_amount2, 5);

        transfer::public_transfer(bob_claim, BOB);
        transfer::public_transfer(bob_deposit1, BOB);
        transfer::public_transfer(bob_deposit2, BOB);
        transfer::public_transfer(bob_rewards1, BOB);
        transfer::public_transfer(bob_rewards2, BOB);
        transfer::public_transfer(alice_deposit, ALICE);
        transfer::public_transfer(alice_rewards, ALICE);
        complete_scenario(scenario, s);
    }
}
#[test_only]
module mazu_finance::mazu_tests{
    use std::string;
    use std::ascii;
    use sui::url;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin, CoinMetadata};

    use mazu_finance::mazu::{Self, Vault, MAZU};    
    use mazu_finance::multisig::{Self, Multisig};

    const MAX_COMMUNITY_INCENTIVES: u64 = 124_444_444__444_444_444 + 90 + 94; // 14%
    // const MAX_TEAM: u64 = 106_666_666__666_666_667; // 12%
    const MAX_STRATEGY: u64 = 128_000_000__000_000_000; // 14.4%
    // const MAX_PRIVATE_SALE: u64 = 75_822_222__222_222_222; // 8.53%
    const MAX_PUBLIC_SALE: u64 = 133_333_333__333_333_333; // 15%
    const BURN_AMOUNT: u64 = 6_222_222__222_222_222; // 0.07%  
    
    const OWNER: address = @0xBABE;
    const COMMUNITY: address = @0x1;
    const TEAM: address = @0x2;
    const STRATEGY: address = @0x3;
    const PRIVATE_SALE: address = @0x4;
    const PUBLIC_SALE: address = @0x5;

    public struct Storage {
        vault: Vault,
        metadata: CoinMetadata<MAZU>,        
        multisig: Multisig,
    }

    fun init_scenario(): (Scenario, Storage) {
        let mut scenario = ts::begin(OWNER);
        let scen = &mut scenario;
        // initialize modules
        mazu::init_for_testing(ts::ctx(scen));
        multisig::init_for_testing(ts::ctx(scen));
        ts::next_tx(scen, OWNER);
        // get shared objects for storage
        let vault = ts::take_shared<Vault>(scen);
        let metadata = ts::take_shared<CoinMetadata<MAZU>>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        (scenario, Storage { vault, metadata, multisig })
    }

    fun forward_scenario(scen: &mut Scenario, storage: Storage, user: address): Storage {
        let Storage { vault, metadata, multisig } = storage;

        ts::return_shared(vault);
        ts::return_shared(metadata);
        ts::return_shared(multisig);

        ts::next_tx(scen, user);

        let vault = ts::take_shared<Vault>(scen);
        let metadata = ts::take_shared<CoinMetadata<MAZU>>(scen);
        let multisig = ts::take_shared<Multisig>(scen);

        Storage { vault, metadata, multisig }
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { vault, metadata, multisig } = storage;
        ts::return_shared(vault);
        ts::return_shared(metadata);
        ts::return_shared(multisig);
        ts::end(scenario);
    }

    fun update_metadata(scen: &mut Scenario, stor: &mut Storage) {
        let name = string::utf8(b"metadata");
        mazu::propose_update_metadata(
            &mut stor.multisig, 
            name, 
            string::utf8(b"new name"),
            string::utf8(b"new symbol"),
            string::utf8(b"new description"),
            string::utf8(b"new icon url"),
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = mazu::start_update_metadata(proposal);
        mazu::complete_update_metadata(&stor.vault, &mut stor.metadata, request);
    }

    fun transfer(
        scen: &mut Scenario, 
        stor: &mut Storage, 
        stakeholder: vector<u8>, 
        addr: address, 
        amount: u64
    ) {
        let name = string::utf8(b"transfer");
        mazu::propose_transfer(
            &mut stor.multisig, 
            name, 
            string::utf8(stakeholder),
            amount,
            addr,
            ts::ctx(scen)
        );
        multisig::approve_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let proposal = multisig::execute_proposal(&mut stor.multisig, name, ts::ctx(scen));
        let request = mazu::start_transfer(proposal);
        mazu::complete_transfer(&mut stor.vault, request, ts::ctx(scen));
    }

    fun handle_and_assert_coin(mut total: u64, amount: u64, addr: address, scen: &Scenario) {
        let mazu = ts::take_from_address<Coin<MAZU>>(scen, addr);
        total = total + amount;
        assert!(coin::value(&mazu) == total, 0);
        ts::return_to_address(addr, mazu);
    }

    fun increment_epoch(scen: &mut Scenario, mut epochs: u64) {
        while (epochs > 0) {
            ts::next_epoch(scen, OWNER);
            epochs = epochs - 1;
        }
    }

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();

        let coin = scenario.take_from_address<Coin<MAZU>>(@0x0);
        assert!(coin::value(&coin) == BURN_AMOUNT, 0);
        ts::return_to_address(@0x0, coin);

        complete_scenario(scenario, storage);
    }

    #[test]
    fun update_metadata_normal() {
        let (mut scenario, mut storage) = init_scenario();
        update_metadata(&mut scenario, &mut storage);
        assert!(
            coin::get_name(&storage.metadata) == string::utf8(b"new name")
            && coin::get_symbol(&storage.metadata) == ascii::string(b"new symbol")
            && coin::get_description(&storage.metadata) == string::utf8(b"new description")
            && coin::get_icon_url(&storage.metadata) == option::some(url::new_unsafe(ascii::string(b"new icon url"))),
            0
        );
        complete_scenario(scenario, storage);
    }

    #[test]
    fun should_burn() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, 1);   
        let mut s = forward_scenario(scen, s, PUBLIC_SALE);
        let mazu = ts::take_from_address<Coin<MAZU>>(scen, PUBLIC_SALE);
        mazu::burn(&mut s.vault, mazu);
        complete_scenario(scenario, s);
    }

    #[test]
    fun transfer_everything_normal() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;
        let total = 0;

        // === TGE ===
        // community
        let tge_community = MAX_COMMUNITY_INCENTIVES / 20;
        transfer(scen, &mut s, b"community", COMMUNITY, tge_community);        
        let mut s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_community, COMMUNITY, scen);
        // strategy
        let tge_strategy = MAX_STRATEGY;
        transfer(scen, &mut s, b"strategy", STRATEGY, tge_strategy);        
        let mut s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_strategy, STRATEGY, scen);
        // public
        let tge_public = MAX_PUBLIC_SALE;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, tge_public);        
        let mut s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_public, PUBLIC_SALE, scen);

        // === 18 months ===
        increment_epoch(scen, 1096 / 2);
        // community
        let community_18 = (MAX_COMMUNITY_INCENTIVES - tge_community) / 2;
        transfer(scen, &mut s, b"community", COMMUNITY, community_18);        
        let mut s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, community_18, COMMUNITY, scen);

        // === 36 months ===
        increment_epoch(scen, 1096 / 2);
        // community
        let community_36 = (MAX_COMMUNITY_INCENTIVES - tge_community - community_18);
        transfer(scen, &mut s, b"community", COMMUNITY, community_36);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, community_36, COMMUNITY, scen);

        complete_scenario(scenario, s);
    }

    #[test]
    fun transfer_everything_normal_after_vesting_ended() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 1200);
        // community
        let mazu_community = MAX_COMMUNITY_INCENTIVES;
        transfer(scen, &mut s, b"community", COMMUNITY, mazu_community);        
        let mut s = forward_scenario(scen, s, OWNER);
        // public
        let mazu_public = MAX_PUBLIC_SALE;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, mazu_public);        
        let mut s = forward_scenario(scen, s, OWNER);
        // strategy
        let mazu_strategy = MAX_STRATEGY;
        transfer(scen, &mut s, b"strategy", STRATEGY, mazu_strategy);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]    
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_community() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 1200);
        // community
        let mazu_community = MAX_COMMUNITY_INCENTIVES + 1;
        transfer(scen, &mut s, b"community", COMMUNITY, mazu_community);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_public_sale() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 10);
        // public
        let mazu_public = MAX_PUBLIC_SALE + 1;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, mazu_public);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_strategy() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 10);
        // strategy
        let mazu_strategy = MAX_STRATEGY + 1;
        transfer(scen, &mut s, b"strategy", STRATEGY, mazu_strategy);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::EStakeholderNotInVault)]
    fun cannot_transfer_private_sale() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 10);
        // private sale
        let mazu_private_sale = 1;
        transfer(scen, &mut s, b"private_sale", PRIVATE_SALE, mazu_private_sale);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::EStakeholderNotInVault)]
    fun cannot_transfer_team() {
        let (mut scenario, mut s) = init_scenario();
        let scen = &mut scenario;

        increment_epoch(scen, 10);
        // private sale
        let mazu_team = 1;
        transfer(scen, &mut s, b"team", TEAM, mazu_team);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

}


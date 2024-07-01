#[test_only]
module mazu_finance::mazu_tests{
    use std::string;
    use std::ascii;
    use std::option;
    use sui::url;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin, CoinMetadata};

    use mazu_finance::mazu::{Self, Vault, MAZU};    
    use mazu_finance::multisig::{Self, Multisig};

    // const MAX_TEAM: u64 = 88_888_888_888_888_888 * 2; // 20%
    const MAX_STRATEGY: u64 = 142_222_222_222_222_222; // 16%
    // const MAX_PRIVATE_SALE: u64 = 88_888_888_888_888_888; // 10%
    const MAX_PUBLIC_SALE: u64 = 88_888_888_888_888_888; // 10%
    const MAX_MARKETING: u64 = 26_666_666_666_666_664; // 3%
    const MAX_COMMUNITY_INCENTIVES: u64 = 88_888_888_888_888_888; // 10%    
    
    const OWNER: address = @0xBABE;
    const COMMUNITY: address = @0x1;
    const TEAM: address = @0x2;
    const STRATEGY: address = @0x3;
    const PRIVATE_SALE: address = @0x4;
    const PUBLIC_SALE: address = @0x5;
    const MARKETING: address = @0x6;

    struct Storage {
        vault: Vault,
        metadata: CoinMetadata<MAZU>,        
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

    fun handle_and_assert_coin(total: u64, amount: u64, addr: address, scen: &Scenario) {
        let mazu = ts::take_from_address<Coin<MAZU>>(scen, addr);
        total = total + amount;
        assert!(coin::value(&mazu) == total, 0);
        ts::return_to_address(addr, mazu);
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
    fun update_metadata_normal() {
        let (scenario, storage) = init_scenario();
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
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, 1);   
        let s = forward_scenario(scen, s, PUBLIC_SALE);
        let mazu = ts::take_from_address<Coin<MAZU>>(scen, PUBLIC_SALE);
        mazu::burn(&mut s.vault, mazu);
        complete_scenario(scenario, s);
    }

    #[test]
    fun transfer_everything_normal() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        let total = 0;

        // === TGE ===
        // community
        let tge_community = MAX_COMMUNITY_INCENTIVES / 10;
        transfer(scen, &mut s, b"community", COMMUNITY, tge_community);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_community, COMMUNITY, scen);
        // strategy
        let tge_strategy = MAX_STRATEGY / 2;
        transfer(scen, &mut s, b"strategy", STRATEGY, tge_strategy);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_strategy, STRATEGY, scen);
        // public
        let tge_public = MAX_PUBLIC_SALE;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, tge_public);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_public, PUBLIC_SALE, scen);
        // marketing
        let tge_marketing = MAX_MARKETING / 4;
        transfer(scen, &mut s, b"marketing", MARKETING, tge_marketing);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, tge_marketing, MARKETING, scen);

        // === 9 months ===
        increment_epoch(scen, 274);
        // community
        let nine_community = (MAX_COMMUNITY_INCENTIVES - tge_community) / 2;
        transfer(scen, &mut s, b"community", COMMUNITY, nine_community);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, nine_community, COMMUNITY, scen);
        // strategy
        let nine_strategy = (MAX_STRATEGY - tge_strategy) / 2;
        transfer(scen, &mut s, b"strategy", STRATEGY, nine_strategy);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, nine_strategy, STRATEGY, scen);
        // marketing
        let nine_marketing = (MAX_MARKETING - tge_marketing) / 2;
        transfer(scen, &mut s, b"marketing", MARKETING, nine_marketing);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, nine_marketing, MARKETING, scen);

        // === 18 months ===
        increment_epoch(scen, 274);
        // community
        let eighteen_community = (MAX_COMMUNITY_INCENTIVES - tge_community - nine_community);
        transfer(scen, &mut s, b"community", COMMUNITY, eighteen_community);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, eighteen_community, COMMUNITY, scen);
        // strategy
        let eighteen_strategy = (MAX_STRATEGY - tge_strategy - nine_strategy);
        transfer(scen, &mut s, b"strategy", STRATEGY, eighteen_strategy);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, eighteen_strategy, STRATEGY, scen);
        // marketing
        let eighteen_marketing = (MAX_MARKETING - tge_marketing - nine_marketing);
        transfer(scen, &mut s, b"marketing", MARKETING, eighteen_marketing);        
        let s = forward_scenario(scen, s, OWNER);
        handle_and_assert_coin(total, eighteen_marketing, MARKETING, scen);

        complete_scenario(scenario, s);
    }

    #[test]
    fun transfer_everything_normal_after_vesting_ended() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 1000);
        // community
        let mazu_community = MAX_COMMUNITY_INCENTIVES;
        transfer(scen, &mut s, b"community", COMMUNITY, mazu_community);        
        let s = forward_scenario(scen, s, OWNER);
        // public
        let mazu_public = MAX_PUBLIC_SALE;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, mazu_public);        
        let s = forward_scenario(scen, s, OWNER);
        // strategy
        let mazu_strategy = MAX_STRATEGY;
        transfer(scen, &mut s, b"strategy", STRATEGY, mazu_strategy);        
        let s = forward_scenario(scen, s, OWNER);
        // marketing
        let mazu_marketing = MAX_MARKETING;
        transfer(scen, &mut s, b"marketing", MARKETING, mazu_marketing);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]    
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_community() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // community
        let mazu_community = MAX_COMMUNITY_INCENTIVES + 1;
        transfer(scen, &mut s, b"community", COMMUNITY, mazu_community);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_public_sale() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // public
        let mazu_public = MAX_PUBLIC_SALE + 1;
        transfer(scen, &mut s, b"public_sale", PUBLIC_SALE, mazu_public);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_strategy() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // strategy
        let mazu_strategy = MAX_STRATEGY + 1;
        transfer(scen, &mut s, b"strategy", STRATEGY, mazu_strategy);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::ENotEnoughFundsUnlocked)]
    fun cannot_transfer_more_marketing() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // marketing
        let mazu_marketing = MAX_MARKETING + 1;
        transfer(scen, &mut s, b"marketing", MARKETING, mazu_marketing);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::EStakeholderNotInVault)]
    fun cannot_transfer_private_sale() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // private sale
        let mazu_private_sale = 1;
        transfer(scen, &mut s, b"private_sale", PRIVATE_SALE, mazu_private_sale);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

    #[test]
    #[expected_failure(abort_code = mazu_finance::mazu::EStakeholderNotInVault)]
    fun cannot_transfer_team() {
        let (scenario, s) = init_scenario();
        let scen = &mut scenario;
        // === 18 months ===
        increment_epoch(scen, 548);
        // private sale
        let mazu_team = 1;
        transfer(scen, &mut s, b"team", TEAM, mazu_team);        
        let s = forward_scenario(scen, s, OWNER);

        complete_scenario(scenario, s);
    }

}


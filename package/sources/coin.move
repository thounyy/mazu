module mazu_finance::mazu {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::balance::Supply;
    use sui::url;

    use mazu_finance::multisig::{Self, Multisig, Proposal};
    use mazu_finance::math;

    // === Constants ===

    // const MAX_SUPPLY: u64 = 888_888_888__888_888_888; // 100%
    // const TOTAL_COMMUNITY_INCENTIVES: u64 = 444_444_444__444_444_444; // 50%
    const MAX_COMMUNITY_INCENTIVES: u64 = 124_444_444__444_444_444 + 94 + 90; // 14% (+ rest from staking)
    
    const MAX_TEAM: u64 = 106_666_666__666_666_667; // 12%
    const MAX_STRATEGY: u64 = 128_000_000__000_000_000; // 14.4%
    const MAX_PRIVATE_SALE: u64 = 75_822_222__222_222_222; // 8.53%
    const MAX_PUBLIC_SALE: u64 = 133_333_333__333_333_333; // 15%
    const BURN_AMOUNT: u64 = 6_222_222__222_222_222; // 0.07%
    const URL: vector<u8> = b"https://i.ibb.co/7KgZBFW/mazu-logo.png";

    // === Errors ===

    const ENotEnoughFundsUnlocked: u64 = 0;
    const EStakeholderNotInVault: u64 = 1;

    // === Structs ===

    public struct MAZU has drop {}

    public struct TransferRequest has store {
        stakeholder: String, // one of the vault fields
        amount: u64,
        recipient: address,
    }

    public struct UpdateMetadataRequest has store { 
        name: String,
        symbol: String,
        description: String,
        icon_url: String,
    }

    public struct Vault has key {
        id: UID,
        cap: TreasuryCap<MAZU>,
        start: u64, // start epoch
        community: u64,
        team: u64,
        strategy: u64,
        private_sale: u64,
        public_sale: u64,
    }

    #[allow(lint(share_owned))]
    fun init(
        otw: MAZU, 
        ctx: &mut TxContext
    ) {
        let (mut cap, metadata) = coin::create_currency<MAZU>(
            otw, 
            9, 
            b"MAZU", 
            b"Mazu", 
            b"Simplifying Yield Farming in the Sui Ecosystem",  
            option::some(url::new_unsafe_from_bytes(URL)), 
            ctx
        );

        cap.mint_and_transfer(BURN_AMOUNT, @0x0, ctx);

        transfer::public_share_object(metadata);
        
        transfer::share_object(Vault {
            id: object::new(ctx),
            cap,
            start: tx_context::epoch(ctx),
            community: MAX_COMMUNITY_INCENTIVES,
            team: MAX_TEAM,
            strategy: MAX_STRATEGY,
            private_sale: MAX_PRIVATE_SALE,
            public_sale: MAX_PUBLIC_SALE,
        });
    }

    // === Public functions ===

    public fun burn(
        vault: &mut Vault, 
        coin: Coin<MAZU>
    ) {
        coin::burn(&mut vault.cap, coin);
    }

    // === Multisig functions ===

    // step 1: propose to transfer funds for stakeholder in vault
    public fun propose_transfer(
        multisig: &mut Multisig, 
        name: String,
        stakeholder: String, 
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert_in_vault(stakeholder);
        let request = TransferRequest { stakeholder, amount, recipient };
        multisig::create_proposal(multisig, name, request, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal

    // step 4: unwrap the request by passing Proposal
    public fun start_transfer(proposal: Proposal): TransferRequest {
        multisig::get_request(proposal)
    }

    // step 5: destroy the request
    public fun complete_transfer(
        vault: &mut Vault,
        request: TransferRequest,
        ctx: &mut TxContext
    ) {
        let TransferRequest { stakeholder, amount, recipient } = request;
        handle_stakeholder(vault, stakeholder, amount, ctx);

        let coin = coin::mint<MAZU>(&mut vault.cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    // step 1: propose to update coin metadata
    public fun propose_update_metadata(
        multisig: &mut Multisig, 
        proposal_name: String,
        name: String, 
        symbol: String, 
        description: String, 
        icon_url: String, 
        ctx: &mut TxContext
    ) {
        let request = UpdateMetadataRequest { name, symbol, description, icon_url };
        multisig::create_proposal(multisig, proposal_name, request, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal

    // step 4: unwrap the request by passing Proposal
    public fun start_update_metadata(proposal: Proposal): UpdateMetadataRequest {
        multisig::get_request(proposal)
    }

    // step 5: destroy the request
    public fun complete_update_metadata(
        vault: &Vault, 
        metadata: &mut CoinMetadata<MAZU>, 
        request: UpdateMetadataRequest
    ) {
        let UpdateMetadataRequest { name, symbol, description, icon_url } = request;

        coin::update_name(&vault.cap, metadata, name);
        coin::update_symbol(&vault.cap, metadata, string::to_ascii(symbol));
        coin::update_description(&vault.cap, metadata, description);
        coin::update_icon_url(&vault.cap, metadata, string::to_ascii(icon_url));
    }

    // === Friend functions ===    
    
    public(package) fun cap_mut(vault: &mut Vault): &mut TreasuryCap<MAZU> {
        &mut vault.cap
    }
    
    public(package) fun supply_mut(vault: &mut Vault): &mut Supply<MAZU> {
        coin::supply_mut(&mut vault.cap)
    }

    public(package) fun handle_stakeholder(
        vault: &mut Vault, 
        stakeholder: String, 
        amount: u64, 
        ctx: &TxContext
    ) {
        let (tge, vesting, period) = vesting_for_stakeholder(stakeholder);

        let duration = if (tx_context::epoch(ctx) - vault.start < period) {
            tx_context::epoch(ctx) - vault.start
        } else { period }; // cannot be more than vesting period

        let unlocked_amount = tge + math::mul_div_down(duration, vesting, period);

        if (stakeholder == string::utf8(b"community")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_COMMUNITY_INCENTIVES, vault.community)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.community = math::sub(vault.community, amount);
        } else if (stakeholder == string::utf8(b"team")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_TEAM, vault.team)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.team = math::sub(vault.team, amount);
        } else if (stakeholder == string::utf8(b"strategy")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_STRATEGY, vault.strategy)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.strategy = math::sub(vault.strategy, amount);
        } else if (stakeholder == string::utf8(b"private_sale")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_PRIVATE_SALE, vault.private_sale)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.private_sale = math::sub(vault.private_sale, amount);
        } else if (stakeholder == string::utf8(b"public_sale")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_PUBLIC_SALE, vault.public_sale)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.public_sale = math::sub(vault.public_sale, amount);
        };
    }

    // returns (amount TGE, amount vesting, period vesting)
    public(package) fun vesting_for_stakeholder(stakeholder: String): (u64, u64, u64) {
        let (mut tge, mut vesting, mut period) = (0, 0, 0);

        if (stakeholder == string::utf8(b"community")) {
            tge = MAX_COMMUNITY_INCENTIVES / 20;
            vesting = MAX_COMMUNITY_INCENTIVES - tge;
            period = 1096;
        } else if (stakeholder == string::utf8(b"team")) {
            tge = MAX_TEAM;
            period = 1;
            // vesting managed in vesting module
        } else if (stakeholder == string::utf8(b"strategy")) {
            tge = MAX_STRATEGY;
            period = 1;
            // vesting = 0;
        } else if (stakeholder == string::utf8(b"private_sale")) {
            tge = MAX_PRIVATE_SALE;
            period = 1;
            // vesting managed in vesting module
        } else if (stakeholder == string::utf8(b"public_sale")) {
            tge = MAX_PUBLIC_SALE; 
            period = 1;
            // vesting = 0
        };

        (tge, vesting, period)
    }

    // === Private functions ===

    fun assert_in_vault(name: String) {
        assert!(
            name == string::utf8(b"community") ||
            // name == string::utf8(b"team") ||
            name == string::utf8(b"strategy") ||
            // name == string::utf8(b"private_sale") ||
            name == string::utf8(b"public_sale"),
            EStakeholderNotInVault
        )
    }

    // === Test functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MAZU {}, ctx);
    }
}

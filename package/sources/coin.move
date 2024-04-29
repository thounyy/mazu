module mazu_finance::mazu {
    use std::option;
    use std::string::{Self, String};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::transfer;
    use sui::url;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    use mazu_finance::multisig::{Self, Multisig, Proposal};
    use mazu_finance::math;

    friend mazu_finance::airdrop;
    friend mazu_finance::staking;
    friend mazu_finance::vesting;

    // === Constants ===

    // const MAX_SUPPLY: u64 = 888_888_888_888_888_888;
    
    const MAX_TEAM: u64 = 88_888_888_888_888_888 * 2; // 20%
    const MAX_STRATEGY: u64 = 142_222_222_222_222_222; // 16%
    const MAX_PRIVATE_SALE: u64 = 88_888_888_888_888_888; // 10%
    const MAX_PUBLIC_SALE: u64 = 88_888_888_888_888_888; // 10%
    const MAX_MARKETING: u64 = 35_555_555_555_555_552; // 4%
    const MAX_COMMUNITY_INCENTIVES: u64 = 88_888_888_888_888_888; // 10%

    // === Errors ===

    const ENotEnoughFundsUnlocked: u64 = 0;
    const EStakeholderNotInVault: u64 = 1;

    // === Structs ===

    struct MAZU has drop {}

    struct TransferRequest has store {
        stakeholder: String, // one of the vault fields
        amount: u64,
        recipient: address,
    }

    struct UpdateMetadataRequest has store { 
        name: String,
        symbol: String,
        description: String,
        icon_url: String,
    }

    struct Vault has key {
        id: UID,
        cap: TreasuryCap<MAZU>,
        start: u64, // start epoch
        community: u64,
        team: u64,
        strategy: u64,
        private_sale: u64,
        public_sale: u64,
        marketing: u64,
    }

    #[allow(lint(share_owned))]
    fun init(
        otw: MAZU, 
        ctx: &mut TxContext
    ) {
        let (cap, metadata) = coin::create_currency<MAZU>(
            otw, 
            9, 
            b"MAZU", 
            b"Mazu", 
            b"Simplifying Yield Farming in the Sui Ecosystem",  
            option::some(url::new_unsafe_from_bytes(b"https://twitter.com/mazufinance/photo")), 
            ctx
        );

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
            marketing: MAX_MARKETING,
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
    
    public(friend) fun cap_mut(vault: &mut Vault): &mut TreasuryCap<MAZU> {
        &mut vault.cap
    }

    public(friend) fun handle_stakeholder(
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
        } else if (stakeholder == string::utf8(b"marketing")) {
            assert!(
                math::sub(unlocked_amount, math::sub(MAX_MARKETING, vault.marketing)) >= amount, 
                ENotEnoughFundsUnlocked
            );
            vault.marketing = math::sub(vault.marketing, amount);
        };
    }

    // returns (amount TGE, amount vesting, period vesting)
    public(friend) fun vesting_for_stakeholder(stakeholder: String): (u64, u64, u64) {
        let (tge, vesting, period) = (0, 0, 0);

        if (stakeholder == string::utf8(b"community")) {
            tge = MAX_COMMUNITY_INCENTIVES / 10;
            vesting = MAX_COMMUNITY_INCENTIVES - tge;
            period = 548;
        } else if (stakeholder == string::utf8(b"team")) {
            tge = MAX_TEAM;
            period = 1;
            // vesting managed in vesting module
        } else if (stakeholder == string::utf8(b"strategy")) {
            tge = MAX_STRATEGY / 2;
            vesting = tge;
            period = 548;
        } else if (stakeholder == string::utf8(b"private_sale")) {
            tge = MAX_PRIVATE_SALE;
            period = 1;
            // vesting managed in vesting module
        } else if (stakeholder == string::utf8(b"public_sale")) {
            tge = MAX_PUBLIC_SALE; 
            period = 1;
            // vesting = 0
        } else if (stakeholder == string::utf8(b"marketing")) {
            tge = MAX_MARKETING / 4;
            vesting = MAX_MARKETING - tge;
            period = 548;
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
            name == string::utf8(b"public_sale") ||
            name == string::utf8(b"marketing"),
            EStakeholderNotInVault
        )
    }

    // === Test functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MAZU {}, ctx);
    }
}

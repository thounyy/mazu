module mazu_finance::mazu {
    use std::option;
    use std::string::{Self, String};

    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::url;
    use sui::object::{Self, UID};

    friend mazu_finance::airdrop;
    friend mazu_finance::multisig;
    friend mazu_finance::staking;

    // === Constants ===

    const MAX_SUPPLY: u64 = 888_888_888_888_888_888;
    
    const MAX_COMMUNITY: u64 = 355_555_555_555_555_552;
    const MAX_TEAM: u64 = 177_777_777_777_777_776;
    const MAX_STRATEGY: u64 = 142_222_222_222_222_222;
    const MAX_PRIVATE: u64 = 88_888_888_888_888_888;
    const MAX_PUBLIC: u64 = 88_888_888_888_888_888;
    const MAX_MARKETING: u64 = 35_555_555_555_555_552;

    const MAX_COMMUNITY_WITHOUT_STAKING: u64 = 
        355_555_555_555_555_552 - 222_222_222_222_222_222 - 44_444_444_444_444_444;

    // === Structs ===

    struct MAZU has drop {}

    struct Vault has key {
        id: UID,
        cap: TreasuryCap<MAZU>,
        community: u64,
        team: u64,
        strategy: u64,
        private_sale: u64,
        public_sale: u64,
        marketing: u64,
    }

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
            community: MAX_COMMUNITY_WITHOUT_STAKING,
            team: MAX_TEAM,
            strategy: MAX_STRATEGY,
            private_sale: MAX_PRIVATE,
            public_sale: MAX_PUBLIC,
            marketing: MAX_MARKETING,
        });
    }

    // === Public functions ===

    public fun burn(
        manager: &mut Vault, 
        coin: Coin<MAZU>
    ) {
        coin::burn(&mut manager.cap, coin);
    }


    // === Admin only ===

    // entry fun withdraw_and_send_coins(
    //     _: &AdminCap, 
    //     manager: &mut Vault, 
    //     amount: u64,
    //     receiver: address, 
    //     ctx: &mut TxContext
    // ) {
    //     transfer::public_transfer(
    //         coin::split(&mut manager.coins, amount, ctx),
    //         receiver
    //     );
    // }

    // === Friend functions ===    
    
    public(friend) fun cap_mut(vault: &mut Vault): &mut TreasuryCap<MAZU> {
        &mut vault.cap
    }

    public(friend) fun update_metadata(
        manager: &Vault, 
        metadata: &mut CoinMetadata<MAZU>, 
        name: String,
        symbol: String,
        description: String,
        icon_url: String,
    ) {
        coin::update_name(&manager.cap, metadata, name);
        coin::update_symbol(&manager.cap, metadata, string::to_ascii(symbol));
        coin::update_description(&manager.cap, metadata, description);
        coin::update_icon_url(&manager.cap, metadata, string::to_ascii(icon_url));
    }

    // === Test functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MAZU {}, ctx);
    }
}

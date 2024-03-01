module mazu_finance::airdrop {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;

    use mazu_finance::mazu::{Self, MAZU, Vault};
    
    friend mazu_finance::multisig;

    struct AirdropList { id: UID }

    public(friend) fun new(ctx: &mut TxContext): AirdropList {
        AirdropList { id: object::new(ctx) }
    }

    public fun claim(
        airdrop_list: AirdropList, 
        manager: &mut Vault, 
        ctx: &mut TxContext
    ): Coin<MAZU> {
        let AirdropList { id } = airdrop_list;
        object::delete(id);

        coin::mint(mazu::cap_mut(manager), 1000, ctx) // TODO: change amount
    }
}


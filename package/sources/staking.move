module mazu_finance::staking {
    use std::vector;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::dynamic_field as df;
    use sui::clock::{Self, Clock};

    use flowxswap::pair::LP;

    use mazu_finance::math;
    use mazu_finance::mazu::{Self, MAZU, Vault};
    use mazu_finance::multisig::{Self, Multisig, Proposal};

    // === Constants ===

    const VERSION: u64 = 1;

    const MUL: u64 = 1_000_000_000;
    const MS_IN_WEEK: u64 = 1000 * 60 * 60 * 24 * 7;

    // === Errors ===

    const EWrongCoinSent: u64 = 0;
    const ECannotStakeZero: u64 = 1;
    const ENotActive: u64 = 2;
    const EStakedLocked: u64 = 3;
    const EWrongLockingDuration: u64 = 4;
    const EWrongVersion: u64 = 5;

    // === Structs ===

    struct StartRequest has store {}

    struct PoolKey<phantom T> has copy, drop, store {}

    // shared
    struct Staking has key { 
        id: UID,
        version: u64,
        start: u64, // start timestamp to get week
        active: bool,
        // DF Pool
    }

    struct Pool has store {
        total_value: u64, // total value (amount * boost) staked
        total_staked: u64, // total amount staked
        emissions: vector<u64>, // per week
        reward_index: u128,
        last_updated: u64
    }

    // owned
    struct Staked<phantom T> has key, store {
        id: UID,
        end: u64, // end timestamp in ms (same if no lock)
        value: u64, // coin_amount * boost
        reward_index: u128, // reward index when updated
        balance: Balance<T>, // MAZU or LP<MAZU,SUI>
    }

    fun init(ctx: &mut TxContext) {
        let staking = Staking { 
            id: object::new(ctx),
            version: VERSION,
            start: 0,
            active: false,
        };
        
        df::add(
            &mut staking.id, 
            PoolKey<MAZU> {}, 
            Pool {
                total_value: 0,
                total_staked: 0,
                emissions: init_mazu_emissions(),
                reward_index: 0,
                last_updated: 0
            }
        );
        df::add(
            &mut staking.id, 
            PoolKey<LP<MAZU,SUI>> {}, 
            Pool {
                total_value: 0,
                total_staked: 0,
                emissions: init_lp_emissions(),
                reward_index: 0,
                last_updated: 0
            }
        );

        transfer::share_object(staking);
    }

    // === Public-Mutative Functions ===

    public fun stake<T: drop>(
        staking: &mut Staking, 
        coin: Coin<T>, 
        clock: &Clock,
        weeks: u64, // locked duration in weeks
        ctx: &mut TxContext
    ): Staked<T> {
        assert_active(staking);
        assert_last_version(staking);
        assert!(df::exists_(&staking.id, PoolKey<T> {}), EWrongCoinSent);
        assert!(coin::value(&coin) != 0, ECannotStakeZero);

        let now = clock::timestamp_ms(clock);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        let value = math::mul_div_down(coin::value(&coin), get_boost(weeks), MUL);

        update_rewards(pool, now, staking.start);
        pool.total_value = pool.total_value + value;
        pool.total_staked = pool.total_staked + coin::value(&coin);

        Staked<T> {
            id: object::new(ctx),
            end: now + MS_IN_WEEK * weeks,
            value,
            reward_index: pool.reward_index,
            balance: coin::into_balance(coin)
        }
    }

    public fun claim<T: drop>(
        vault: &mut Vault,
        staking: &mut Staking, 
        staked: &mut Staked<T>, 
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<MAZU> {
        assert_active(staking);
        assert_last_version(staking);
        let now = clock::timestamp_ms(clock);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        // update global and user indexes
        update_rewards(pool, now, staking.start);
        // get rewards
        let rewards =
            (math::sub_u128(pool.reward_index, staked.reward_index) *
            (staked.value as u128) / 
            (MUL as u128) as u64);
        
        staked.reward_index = pool.reward_index;
        coin::mint(mazu::cap_mut(vault), rewards, ctx)
    }

    public fun unstake<T: drop>(
        vault: &mut Vault,
        staking: &mut Staking, 
        staked: Staked<T>, 
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<T>, Coin<MAZU>) {
        assert_active(staking);
        assert_last_version(staking);
        let now = clock::timestamp_ms(clock);
        let Staked { id, end, value, reward_index, balance } = staked;
        object::delete(id);
        
        assert!(
            end <= now  || 
            (now - staking.start) / MS_IN_WEEK >= 72, // if emissions are over 
            EStakedLocked
        );

        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        // update global and user indexes
        update_rewards(pool, now, staking.start);
        // get rewards
        let rewards =
            (math::sub_u128(pool.reward_index, reward_index) *
            (value as u128) / 
            (MUL as u128) as u64);
        
        pool.total_value = math::sub(pool.total_value, value);
        pool.total_staked = math::sub(pool.total_staked, balance::value(&balance));
        // return both staked coin and rewards
        let mazu = coin::mint(mazu::cap_mut(vault), rewards, ctx);
        (coin::from_balance(balance, ctx), mazu)
    }

    public fun calculate_rewards<T: drop>(
        staking: &mut Staking, 
        staked: &mut Staked<T>, 
        clock: &Clock,
    ): u64 {
        assert_last_version(staking);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        update_rewards(pool, clock::timestamp_ms(clock), staking.start);
        let rewards = math::mul_div_down(
            (math::sub_u128(pool.reward_index, staked.reward_index) as u64), 
            staked.value, 
            MUL
        );        
        rewards
    }

    // === Multisig Functions ===

    // step 1: propose to start staking 
    public fun propose_start(
        multisig: &mut Multisig, 
        name: String,
        ctx: &mut TxContext
    ) {
        multisig::create_proposal(multisig, name, StartRequest {}, ctx);
    }

    // step 2: multiple members have to approve the proposal
    // step 3: someone has to execute the proposal to get Proposal
        
    // step 4: unwrap the request by passing Proposal
    public fun start_start(proposal: Proposal): StartRequest {
        multisig::get_request(proposal)
    }

    // step 5: destroy the request and modify Staking object
    public fun complete_start(clock: &Clock, staking: &mut Staking, request: StartRequest) {
        let StartRequest {} = request;
        staking.active = true;
        let now = clock::timestamp_ms(clock);
        staking.start = now;
        let mazu = df::borrow_mut<PoolKey<MAZU>, Pool>(&mut staking.id, PoolKey<MAZU> {});
        mazu.last_updated = now;
        let lp = df::borrow_mut<PoolKey<LP<MAZU,SUI>>, Pool>(&mut staking.id, PoolKey<LP<MAZU,SUI>> {});
        lp.last_updated = now;
    }

    // === Private Functions ===

    fun update_rewards(
        pool: &mut Pool,
        now: u64,
        start: u64,
    ) {
        if (pool.total_value == 0) return;

        let claimable_reward_index = 
            (get_emitted(pool, start, now) as u128) * 
            (MUL as u128) / 
            (pool.total_value as u128);
        
        pool.reward_index = claimable_reward_index + pool.reward_index;
        pool.last_updated = now;
    }

    // get mazu emission for current week 
    fun get_emitted(pool: &Pool, start: u64, now: u64): u64 {
        let last_week = math::min((pool.last_updated - start) / MS_IN_WEEK, 71);
        let current_week = math::min((now - start) / MS_IN_WEEK, 71);
        let emitted = 0;
        let i = last_week;

        while (i < current_week + 1) {
            let emitted_this_week = *vector::borrow<u64>(&pool.emissions, i);
            // if it's a full week or last week we add everything
            if (i != current_week) {
                emitted = emitted + emitted_this_week;
            };
            // add everything emitted since start
            if (i == current_week) {
                let ms_current_week = math::min(now - start - (current_week * MS_IN_WEEK), MS_IN_WEEK);
                emitted = emitted + math::mul_div_down(emitted_this_week, ms_current_week, MS_IN_WEEK);
            }; 
            // remove everything emitted since last updated for the week
            if (i == last_week) {
                let ms_last_week = math::min(pool.last_updated - start - (last_week * MS_IN_WEEK), MS_IN_WEEK);
                emitted = emitted - math::mul_div_down(emitted_this_week, ms_last_week, MS_IN_WEEK);
            };
            i = i + 1;
        };
        
        emitted
    }

    fun get_boost(weeks: u64): u64 {
        if (weeks == 0) {
            MUL
        } else if (weeks <= 8) {
            MUL + weeks * MUL / 8
        } else if (weeks <= 12) {
            2 * MUL + (weeks - 8) * MUL / 4
        } else if (weeks <= 16) {
            3 * MUL + (weeks - 12) * MUL / 2
        } else if (weeks <= 20) {
            5 * MUL + (weeks - 16) * MUL
        } else {
            abort EWrongLockingDuration
        }
    }

    fun assert_active(staking: &Staking) {
        assert!(staking.active, ENotActive);
    }

    fun assert_last_version(staking: &Staking) {
        assert!(staking.version == VERSION, EWrongVersion);
    }

    fun init_mazu_emissions(): vector<u64> {
        let v = vector::empty();
        vector::push_back(&mut v, 2666666670000000);
        vector::push_back(&mut v, 1777777780000000);
        vector::push_back(&mut v, 1688888890000000);
        vector::push_back(&mut v, 1555555560000000);
        vector::push_back(&mut v, 1444444440000000);
        vector::push_back(&mut v, 1333333330000000);
        vector::push_back(&mut v, 1222222220000000);
        vector::push_back(&mut v, 1111111110000000);
        vector::push_back(&mut v, 1000000000000000);
        vector::push_back(&mut v, 888888890000000);
        vector::push_back(&mut v, 888888890000000);
        vector::push_back(&mut v, 888888890000000);
        vector::push_back(&mut v, 777777780000000);
        vector::push_back(&mut v, 777777780000000);
        vector::push_back(&mut v, 777777780000000);
        vector::push_back(&mut v, 777777780000000);
        vector::push_back(&mut v, 777777780000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 666666670000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 444444440000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 400000000000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        vector::push_back(&mut v, 355555560000000);
        return v
    }

    fun init_lp_emissions(): vector<u64> {
        let v = vector::empty();
        vector::push_back(&mut v, 12800000000000000);
        vector::push_back(&mut v, 8533333330000000);
        vector::push_back(&mut v, 8106666670000000);
        vector::push_back(&mut v, 7466666670000000);
        vector::push_back(&mut v, 6933333330000000);
        vector::push_back(&mut v, 6400000000000000);
        vector::push_back(&mut v, 5866666670000000);
        vector::push_back(&mut v, 5333333330000000);
        vector::push_back(&mut v, 4800000000000000);
        vector::push_back(&mut v, 4266666670000000);
        vector::push_back(&mut v, 4266666670000000);
        vector::push_back(&mut v, 4266666670000000);
        vector::push_back(&mut v, 3733333330000000);
        vector::push_back(&mut v, 3733333330000000);
        vector::push_back(&mut v, 3733333330000000);
        vector::push_back(&mut v, 3733333330000000);
        vector::push_back(&mut v, 3733333330000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 3200000000000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 2133333330000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1920000000000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        vector::push_back(&mut v, 1706666670000000);
        return v
    }

    // === Test Functions ===

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun assert_staked_data<T: drop>(
        staked: &Staked<T>,
        end: u64,
        value: u64,
        reward_index: u128,
        balance: u64,
    ) {
        assert!(end == staked.end, 105);
        assert!(value == staked.value, 106);
        assert!(reward_index == staked.reward_index, 107);
        assert!(balance == balance::value(&staked.balance), 108);
    }
}


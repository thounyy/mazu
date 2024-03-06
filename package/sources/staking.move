module mazu_finance::staking {
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::dynamic_field as df;
    use sui::clock::{Self, Clock};

    use flowxswap::pair::LP;

    use mazu_finance::math64;
    use mazu_finance::mazu::{Self, MAZU, Vault};

    // === Constants ===

    const MUL: u64 = 1_000_000_000;
    const MS_IN_WEEK: u64 = 1000 * 60 * 60 * 24 * 7;
    const MAX_MAZU_POOL: u64 = 44_444_444_444_444_444; // 5% max supply
    const MAX_LP_POOL: u64 = 213_333_333_333_333_300; // 24% max supply

    // === Errors ===

    const EWrongCoinSent: u64 = 0;
    const ECannotStakeZero: u64 = 1;
    const ENotActive: u64 = 2;
    const EStakedLocked: u64 = 3;

    // === Structs ===

    struct PoolKey<phantom T> has copy, drop, store {}

    // shared
    struct Staking has key { 
        id: UID,
        start: u64, // start timestamp to get week
        active: bool,
        // DF Pool
    }

    struct Pool has store {
        total_staked: u64, // total value (not amount) staked
        supply_left: u64,
        emissions: vector<u64>, // per week
        reward_index: u64,
        last_updated: u64
    }

    // owned
    struct Staked<phantom T> has key, store {
        id: UID,
        end: u64, // end timestamp in ms (same if no lock)
        value: u64, // coin_amount * boost
        reward_index: u64, // reward index when updated
        coin: Coin<T>, // MAZU or LP<MAZU,SUI>
    }

    fun init(ctx: &mut TxContext) {
        let staking = Staking { 
            id: object::new(ctx),
            start: 0,
            active: false,
        };
        
        df::add(
            &mut staking.id, 
            PoolKey<MAZU> {}, 
            Pool {
                total_staked: 0,
                supply_left: MAX_MAZU_POOL,
                emissions: init_mazu_emissions(),
                reward_index: 0,
                last_updated: 0
            }
        );
        df::add(
            &mut staking.id, 
            PoolKey<LP<MAZU,SUI>> {}, 
            Pool {
                total_staked: 0,
                supply_left: MAX_LP_POOL,
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
        weeks_locked: u64, // locked duration in weeks
        ctx: &mut TxContext
    ): Staked<T> {
        assert_active(staking);
        assert!(df::exists_(&mut staking.id, PoolKey<T> {}), EWrongCoinSent);
        assert!(coin::value(&coin) != 0, ECannotStakeZero);

        let now = clock::timestamp_ms(clock);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        let value = coin::value(&coin) * get_boost(weeks_locked);
        
        update_rewards(pool, staking.start, now);
        pool.total_staked = pool.total_staked + value;

        Staked<T> {
            id: object::new(ctx),
            end: now + MS_IN_WEEK * get_boost(weeks_locked),
            value,
            reward_index: pool.reward_index,
            coin
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
        let now = clock::timestamp_ms(clock);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        // update global and user indexes
        update_rewards(pool, staking.start, now);
        // get rewards
        let rewards = math64::mul_div_down(
            pool.reward_index - staked.reward_index, 
            staked.value,
            MUL,    
        );
        staked.reward_index = pool.reward_index;
        pool.supply_left = pool.supply_left - rewards;
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
        let now = clock::timestamp_ms(clock);
        let Staked { id, end, value, reward_index, coin } = staked;
        object::delete(id);
        assert!(end < now, EStakedLocked);
        let pool = df::borrow_mut(&mut staking.id, PoolKey<T> {});
        // update global and user indexes
        update_rewards(pool, staking.start, now);
        // get rewards
        let rewards = math64::mul_div_down(
            pool.reward_index - reward_index, 
            value,
            MUL,    
        );
        pool.supply_left = pool.supply_left - rewards;
        pool.total_staked = pool.total_staked - coin::value(&coin);
        // return both staked coin and rewards
        let mazu = coin::mint(mazu::cap_mut(vault), rewards, ctx);
        (coin, mazu)
    }

    // === Public-Friend Functions ===

    // === Admin Functions ===

    // public(friend) fun start_staking() {}

    // === Private Functions ===

    fun update_rewards(
        pool: &mut Pool,
        start: u64,
        now: u64,
    ) {
        if (pool.total_staked == 0) return;
        let duration = now - pool.last_updated;

        let total_claimable_rewards = math64::mul_div_down(
            get_emission(pool, start, now), 
            duration, 
            MS_IN_WEEK
        );
        let claimable_reward_index = math64::mul_div_down(
            total_claimable_rewards, 
            MUL, 
            pool.total_staked
        );

        pool.reward_index = claimable_reward_index + pool.reward_index;
        pool.last_updated = now;
    }

    // get mazu emission for current week 
    fun get_emission(pool: &Pool, start: u64, now: u64): u64 {
        let week = (now - start) / MS_IN_WEEK;
        *vector::borrow<u64>(&pool.emissions, week)
    }

    // TODO: change impl
    // get boost multiplier for duration
    fun get_boost(weeks_locked: u64): u64 {
        weeks_locked
    } 

    fun assert_active(staking: &Staking) {
        assert!(staking.active, ENotActive);
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
}
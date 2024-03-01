#[test_only]
module mazu_finance::mazu_tests{
    use std::debug::print;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::test_utils as tu;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::sui::SUI;

    use mazu_finance::mazu::{Self, Vault};

    const OWNER: address = @0xBABE;
    const ALICE: address = @0xCAFE;
    const BOB: address = @0xFACE;

    struct Storage {
        clock: Clock,
        manager: Vault,
    }

    fun init_scenario(): (Scenario, Storage) {
        let scenario = ts::begin(OWNER);
        let scen = &mut scenario;

        // initialize modules
        mazu::init_for_testing(ts::ctx(scen));

        ts::next_tx(scen, OWNER);

        // get shared objects for storage
        let clock = clock::create_for_testing(ts::ctx(scen));
        let manager = ts::take_shared<Vault>(scen);

        (scenario, Storage { clock, manager })
    }

    fun complete_scenario(scenario: Scenario, storage: Storage) {
        let Storage { clock, manager } = storage;

        clock::destroy_for_testing(clock);
        ts::return_shared(manager);
        
        ts::end(scenario);
    }

    #[test]
    fun publish_package() {
        let (scenario, storage) = init_scenario();
        complete_scenario(scenario, storage);
    }

}
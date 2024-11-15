module mazu_finance::af_lp {
    use amm_interface::amm_interface;
    
    public struct AF_LP has drop {}

    fun init(otw: AF_LP, ctx: &mut TxContext) {
        amm_interface::create_lp_coin<AF_LP>(otw, 9, ctx);
    }
}

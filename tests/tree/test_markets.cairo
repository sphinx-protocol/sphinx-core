%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.markets import (
    create_market, create_bid
)

@external
func test_markets{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Deploy contracts
    local orders_contract_address: felt;
    local limits_contract_address: felt;
    %{ ids.orders_contract_address = deploy_contract("./src/tree/orders.cairo").contract_address %}
    %{ ids.limits_contract_address = deploy_contract("./src/tree/limits.cairo").contract_address %}

    let (new_market) = create_market(base_asset=123213123123, quote_asset=788978978998);
    create_bid(orders_addr=orders_contract_address, limits_addr=limits_contract_address, market_id=new_market.id, 
    is_buy=1, price=95, amount=1000);

    
    return ();
}
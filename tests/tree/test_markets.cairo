%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.markets import (
    curr_market_id, curr_tree_id, create_market, create_bid
)

@external
func test_markets{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Start prank - set caller address
    %{ stop_prank_callable = start_prank(123456789) %}

    // Constructor
    curr_market_id.write(1);
    curr_tree_id.write(1);

    // Deploy contracts
    local orders_contract_address: felt;
    local limits_contract_address: felt;
    %{ ids.orders_contract_address = deploy_contract("./src/tree/orders.cairo").contract_address %}
    %{ ids.limits_contract_address = deploy_contract("./src/tree/limits.cairo").contract_address %}

    %{ expect_events({"name": "log_create_market", "data": [1, 1, 2, 0, 0, 123213123123, 788978978998, 123456789]}) %}
    let (new_market) = create_market(base_asset=123213123123, quote_asset=788978978998);
    create_bid(orders_addr=orders_contract_address, limits_addr=limits_contract_address, market_id=new_market.id, 
    price=95, amount=1000);
    create_bid(orders_addr=orders_contract_address, limits_addr=limits_contract_address, market_id=new_market.id, 
    price=95, amount=200);

    

    %{ stop_prank_callable() %}
    return ();
}
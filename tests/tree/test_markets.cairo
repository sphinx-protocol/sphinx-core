%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.markets import (
    curr_market_id, curr_tree_id, create_market, create_bid
)

@contract_interface
namespace IBalancesContract {
    // Getter for user balances
    func get_balance(user : felt, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // Setter for user balances
    func set_balance(user : felt, asset : felt, in_account : felt, new_amount : felt) {
    }
    // Transfer balance from one user to another.
    func transfer_balance(sender : felt, recipient : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer account balance to order balance.
    func transfer_to_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer order balance to account balance.
    func transfer_from_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
}

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
    local balances_contract_address: felt;
    %{ ids.orders_contract_address = deploy_contract("./src/tree/orders.cairo").contract_address %}
    %{ ids.limits_contract_address = deploy_contract("./src/tree/limits.cairo").contract_address %}
    %{ ids.balances_contract_address = deploy_contract("./src/tree/balances.cairo").contract_address %}

    %{ expect_events({"name": "log_create_market", "data": [1, 1, 2, 0, 0, 123213123123, 788978978998, 123456789]}) %}
    let (new_market) = create_market(base_asset=123213123123, quote_asset=788978978998);
    IBalancesContract.set_balance(balances_contract_address, 123456789, 123213123123, 1, 5000);
    create_bid(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, price=95, amount=1000);
    create_bid(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, price=95, amount=200);

    %{ stop_prank_callable() %}
    return ();
}
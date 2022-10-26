%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.markets import (
    curr_market_id, curr_tree_id, create_market, create_bid, create_ask, buy
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

    // Set params
    const deployer = 31678259801237;
    const buyer = 123456789;
    const seller = 666666666;
    const base_asset = 123213123123;
    const quote_asset = 788978978998;

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

    %{ stop_prank_callable = start_prank(ids.deployer) %}
    let (new_market) = create_market(base_asset, quote_asset);
    IBalancesContract.set_balance(balances_contract_address, buyer, base_asset, 1, 5000);
    IBalancesContract.set_balance(balances_contract_address, seller, quote_asset, 1, 5000);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.buyer) %}
    %{ stop_warp = warp(200) %}
    create_bid(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, 1, 1000, 1);
    %{ stop_warp = warp(220) %}
    create_bid(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, 1, 200, 1);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.seller) %}
    %{ stop_warp = warp(321) %}
    create_ask(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, 1, 500, 0);
    %{ stop_warp = warp(335) %}
    create_ask(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, 1, 300, 0);
    %{ stop_warp = warp(350) %}
    create_ask(orders_contract_address, limits_contract_address, balances_contract_address, new_market.id, 1, 300, 0);
    %{ stop_warp %}
    %{ stop_prank_callable() %}

    let (buyer_base_account_balance) = IBalancesContract.get_balance(balances_contract_address, buyer, base_asset, 1);
    let (buyer_base_locked_balance) = IBalancesContract.get_balance(balances_contract_address, buyer, base_asset, 0);
    let (buyer_quote_account_balance) = IBalancesContract.get_balance(balances_contract_address, buyer, quote_asset, 1);
    let (buyer_quote_locked_balance) = IBalancesContract.get_balance(balances_contract_address, buyer, quote_asset, 0);
    let (seller_base_account_balance) = IBalancesContract.get_balance(balances_contract_address, seller, base_asset, 1);
    let (seller_base_locked_balance) = IBalancesContract.get_balance(balances_contract_address, seller, base_asset, 0);
    let (seller_quote_account_balance) = IBalancesContract.get_balance(balances_contract_address, seller, quote_asset, 1);
    let (seller_quote_locked_balance) = IBalancesContract.get_balance(balances_contract_address, seller, quote_asset, 0);

    %{ print("[test_markets.cairo] buyer_base_account_balance: {}, buyer_base_locked_balance: {}, buyer_quote_account_balance: {}, buyer_quote_locked_balance: {}".format(ids.buyer_base_account_balance, ids.buyer_base_locked_balance, ids.buyer_quote_account_balance, ids.buyer_quote_locked_balance)) %}
    %{ print("[test_markets.cairo] seller_base_account_balance: {}, seller_base_locked_balance: {}, seller_quote_account_balance: {}, seller_quote_locked_balance: {}".format(ids.seller_base_account_balance, ids.seller_base_locked_balance, ids.seller_quote_account_balance, ids.seller_quote_locked_balance)) %}

    

    return ();
}
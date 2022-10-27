%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.structs import Market

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

@contract_interface
namespace IMarketsContract {
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func delete(order_id : felt) {
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

    // Deploy contracts
    local orders_addr: felt;
    local limits_addr: felt;
    local balances_addr: felt;
    local markets_addr: felt;
    %{ ids.orders_addr = deploy_contract("./src/tree/orders.cairo").contract_address %}
    %{ ids.limits_addr = deploy_contract("./src/tree/limits.cairo").contract_address %}
    %{ ids.balances_addr = deploy_contract("./src/tree/balances.cairo").contract_address %}
    %{ ids.markets_addr = deploy_contract("./src/tree/markets.cairo", [ids.orders_addr, ids.limits_addr, ids.balances_addr]).contract_address %}

    %{ stop_prank_callable = start_prank(ids.deployer) %}
    let (new_market) = IMarketsContract.create_market(markets_addr, base_asset, quote_asset);
    IBalancesContract.set_balance(balances_addr, buyer, base_asset, 1, 5000);
    IBalancesContract.set_balance(balances_addr, seller, quote_asset, 1, 5000);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.markets_addr) %}
    %{ stop_warp = warp(200) %}
    IMarketsContract.create_bid(markets_addr, new_market.id, 1, 1000, 1);
    %{ stop_warp = warp(220) %}
    IMarketsContract.create_bid(markets_addr, new_market.id, 1, 200, 1);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.markets_addr) %}
    %{ stop_warp = warp(321) %}
    IMarketsContract.create_ask(markets_addr, new_market.id, 1, 500, 0);
    %{ stop_warp = warp(335) %}
    IMarketsContract.create_ask(markets_addr, new_market.id, 1, 300, 0);
    %{ stop_warp = warp(350) %}
    IMarketsContract.create_ask(markets_addr, new_market.id, 1, 300, 0);
    %{ stop_warp %}
    %{ stop_prank_callable() %}

    let (buyer_base_account_balance) = IBalancesContract.get_balance(balances_addr, buyer, base_asset, 1);
    let (buyer_base_locked_balance) = IBalancesContract.get_balance(balances_addr, buyer, base_asset, 0);
    let (buyer_quote_account_balance) = IBalancesContract.get_balance(balances_addr, buyer, quote_asset, 1);
    let (buyer_quote_locked_balance) = IBalancesContract.get_balance(balances_addr, buyer, quote_asset, 0);
    let (seller_base_account_balance) = IBalancesContract.get_balance(balances_addr, seller, base_asset, 1);
    let (seller_base_locked_balance) = IBalancesContract.get_balance(balances_addr, seller, base_asset, 0);
    let (seller_quote_account_balance) = IBalancesContract.get_balance(balances_addr, seller, quote_asset, 1);
    let (seller_quote_locked_balance) = IBalancesContract.get_balance(balances_addr, seller, quote_asset, 0);

    %{ print("[test_markets.cairo] buyer_base_account_balance: {}, buyer_base_locked_balance: {}, buyer_quote_account_balance: {}, buyer_quote_locked_balance: {}".format(ids.buyer_base_account_balance, ids.buyer_base_locked_balance, ids.buyer_quote_account_balance, ids.buyer_quote_locked_balance)) %}
    %{ print("[test_markets.cairo] seller_base_account_balance: {}, seller_base_locked_balance: {}, seller_quote_account_balance: {}, seller_quote_locked_balance: {}".format(ids.seller_base_account_balance, ids.seller_base_locked_balance, ids.seller_quote_account_balance, ids.seller_quote_locked_balance)) %}

    

    return ();
}
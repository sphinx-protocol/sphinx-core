%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Market

@contract_interface
namespace IGatewayContract {
    // Set MarketsContract address
    func set_markets_addr(_markets_addr : felt) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(
    base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new market buy to a given market.
    func market_buy(base_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Submit a new market sell to a given market.
    func market_sell(base_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func cancel_order(order_id : felt) {
    }
    // Deposit ERC20 token to exchange
    func deposit(asset : felt, amount : felt) {
    }
    // Withdraw exchange balance as ERC20 token
    func withdraw(asset : felt, amount : felt) {
    }
}

@external
func test_gateway{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner_addr = 31678259801237;
    const markets_addr = 1123123123;
    const buyer = 123456789;
    const seller = 666666666;
    const base_asset = 123213123123;
    const quote_asset = 788978978998;

    local balances_addr: felt;
    local gateway_addr: felt;
    %{ ids.balances_addr = deploy_contract("./src/dex/balances.cairo", [ids.owner_addr]).contract_address %}
    %{ ids.gateway_addr = deploy_contract("./src/dex/gateway.cairo", [ids.owner_addr, ids.balances_addr]).contract_address %}

    %{ stop_prank_callable = start_prank(ids.owner_addr, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.set_markets_addr(gateway_addr, markets_addr);
    %{ stop_prank_callable() %}

    return ();
}
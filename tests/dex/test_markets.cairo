%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.balances import Balances
from src.dex.markets import Markets
from src.dex.structs import Market

@external
func test_markets{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;
    
    // Set contract addresses
    const buyer = 123456789;
    const seller = 666666666;
    const base_asset = 123213123123;
    const quote_asset = 788978978998;

    // Create new market
    let (new_market) = Markets.create_market(base_asset, quote_asset);

    // Fund user balances (fake deposit)
    Balances.set_balance(buyer, base_asset, 1, 5000);
    Balances.set_balance(seller, quote_asset, 1, 5000);

    // Place orders
    Markets.create_bid(base_asset, quote_asset, 1, 1000, 1);
    %{ stop_warp = warp(200) %}
    Markets.create_bid(base_asset, quote_asset, 1, 1000, 1);
    %{ stop_warp = warp(220) %}
    Markets.create_bid(base_asset, quote_asset, 1, 200, 1);
    %{ stop_warp = warp(321) %}

    Markets.create_ask(base_asset, quote_asset, 1, 500, 0);
    %{ stop_warp = warp(335) %}
    Markets.create_ask(base_asset, quote_asset, 1, 300, 0);
    %{ stop_warp = warp(350) %}
    Markets.create_ask(base_asset, quote_asset, 1, 300, 0);
    %{ stop_warp %}

    return ();
}
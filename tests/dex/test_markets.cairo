%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.balances import Balances
from src.dex.markets import Markets
from src.dex.limits import Limits
from src.dex.orders import Orders
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
    %{ print("market_id: {}, bid_tree_id: {}, ask_tree_id: {}".format(ids.new_market.id, ids.new_market.bid_tree_id, ids.new_market.ask_tree_id))%}

    // Fund user balances (fake deposit)
    Balances.set_balance(buyer, base_asset, 1, 5000);
    Balances.set_balance(seller, quote_asset, 1, 5000);

    // Place orders
    Markets.create_bid(base_asset, quote_asset, 900 * 1000000000000000000, 1000 * 1000000000000000, 1);
    %{ stop_warp = warp(200) %}
    Markets.create_bid(base_asset, quote_asset, 800 * 1000000000000000000, 1000 * 1000000000000000, 1);
    %{ stop_warp = warp(220) %}
    Markets.create_bid(base_asset, quote_asset, 700 * 1000000000000000000, 200 * 1000000000000000, 1);
    %{ stop_warp = warp(321) %}

    Markets.create_ask(base_asset, quote_asset, 1000 * 1000000000000000000, 500 * 1000000000000000, 0);
    %{ stop_warp = warp(335) %}
    Markets.create_ask(base_asset, quote_asset, 1500 * 1000000000000000000, 300 * 1000000000000000, 0);
    %{ stop_warp = warp(350) %}
    Markets.create_ask(base_asset, quote_asset, 2000 * 1000000000000000000, 300 * 1000000000000000, 0);
    %{ stop_warp %}

    let (price) = Markets.fetch_quote(base_asset, quote_asset, 1, 700);
    %{ print(ids.price) %}

    return ();
}
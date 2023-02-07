// This contract is a wrapper on the StarkNet DEX Markets contract to allow unit testing.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.dex.orders import Orders
from src.dex.markets import Markets
from src.dex.structs import Order, Market

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (storage_addr : felt) {
    Orders.initialise(storage_addr);
    return ();
}

//
// Functions
//

@external
func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt
) -> (new_market : Market) {
    let (new_market) = Markets.create_market(base_asset, quote_asset);
    return (new_market=new_market);
}

@view
func get_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt) -> (market_id : felt
) {
    let (market_id) = Markets.get_market_id(base_asset, quote_asset);
    return (market_id=market_id);
}

@external
func update_inside_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, lowest_ask : felt, highest_bid : felt
) {
    Markets.update_inside_quote(market_id, lowest_ask, highest_bid);
    return ();
}

@external
func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    caller : felt, market_id : felt, price : felt, quote_amount : felt, post_only : felt
) {
    Markets.create_bid(caller, market_id, price, quote_amount, post_only);
    return ();
}

@external
func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    caller : felt, market_id : felt, price : felt, quote_amount : felt, post_only : felt
) {
    Markets.create_ask(caller, market_id, price, quote_amount, post_only);
    return ();
}

@external
func buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    caller : felt, market_id : felt, max_price : felt, filled : felt, quote_amount : felt
) {
    Markets.buy(caller, market_id, max_price, filled, quote_amount);
    return ();
}

@external
func sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    caller : felt, market_id : felt, min_price : felt, filled : felt, quote_amount : felt
) {
    Markets.sell(caller, market_id, min_price, filled, quote_amount);
    return ();
}

@external
func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (
    order_id : felt, limit_id : felt, market_id : felt, datetime : felt, owner : felt, 
    base_asset : felt, quote_asset : felt, price : felt, amount : felt, filled : felt
) {
    let (order_id, limit_id, market_id, datetime, owner, base_asset, quote_asset, price, amount, filled) = Markets.delete(order_id);
    return (order_id=order_id, limit_id=limit_id, market_id=market_id, datetime=datetime, owner=owner, base_asset=base_asset, quote_asset=quote_asset, price=price, amount=amount, filled=filled);
}

@view
func fetch_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, is_bid : felt, amount : felt
) -> (price : felt, base_amount : felt, quote_amount : felt) {
    let (price, base_amount, quote_amount) = Markets.fetch_quote(base_asset, quote_asset, is_bid, amount);
    return (price=price, base_amount=base_amount, quote_amount=quote_amount);
}
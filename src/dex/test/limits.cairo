// This contract is a wrapper on the StarkNet DEX Limits contract to allow unit testing.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.dex.orders import Orders
from src.dex.limits import Limits
from src.dex.structs import Order, Limit

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
func insert{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt, market_id : felt
) -> (new_limit : Limit) {
    let (new_limit) = Limits.insert(price, tree_id, market_id);
    return (new_limit=new_limit);
}

@view
func find{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt
) -> (limit : Limit, parent : Limit) {
    let (limit, parent) = Limits.find(price, tree_id);
    return (limit=limit, parent=parent);
}

@external
func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt, market_id : felt
) -> (del : Limit) {
    let (del) = Limits.delete(price, tree_id, market_id);
    return (del=del);
}

@view
func get_min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (tree_id : felt) -> (min : Limit) {
    let (min) = Limits.get_min(tree_id);
    return (min=min);
}

@view
func get_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (tree_id : felt) -> (max : Limit) {
    let (max) = Limits.get_max(tree_id);
    return (max=max);
}

@external
func update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, total_vol : felt, length : felt
) {
    Limits.update(limit_id, total_vol, length);
    return ();
}

@external
func view_limit_tree{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt
) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) {
    let (prices, amounts, length) = Limits.view_limit_tree(tree_id);
    return (prices_len=length, prices=prices, amounts_len=length, amounts=amounts);
}

@external
func view_limit_tree_orders{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (tree_id : felt) -> (
    prices_len : felt, 
    prices : felt*, 
    amounts_len : felt, 
    amounts : felt*, 
    owners_len : felt,
    owners : felt*,
    ids_len : felt,
    ids : felt*
) {
    let (prices, amounts, owners, ids, length) = Limits.view_limit_tree_orders(tree_id);
    return (prices_len=length, prices=prices, amounts_len=length, amounts=amounts, owners_len=length, owners=owners, ids_len=length, ids=ids);
}


@external
func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    is_bid : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt
) -> (new_order : Order) {
    let (new_order) = Orders.push(is_bid, price, amount, datetime, owner, limit_id);
    return (new_order=new_order);
}
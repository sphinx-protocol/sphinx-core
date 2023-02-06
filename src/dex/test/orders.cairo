// This contract is a wrapper on the StarkNet DEX Orders contract to allow unit testing.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.dex.structs import Order
from src.dex.orders import Orders

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
func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    is_bid : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt
) -> (new_order : Order) {
    let (new_order) = Orders.push(is_bid, price, amount, datetime, owner, limit_id);
    return (new_order=new_order);
}

@external
func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
    let (del) = Orders.shift(limit_id);
    return (del=del);
}

@external
func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
    let (del) = Orders.pop(limit_id);
    return (del=del);
}

@external
func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (del : Order) {
    let (del) = Orders.remove(order_id);
    return (del=del);
}
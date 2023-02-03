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
    is_buy : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt
) -> (new_order : Order) {
    let (new_order) = Orders.push(is_buy, price, amount, datetime, owner, limit_id);
    return (new_order=new_order);
}

@external
func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
    let (del) = Orders.shift(limit_id);
    return (del=del);
}

@external
func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (success : felt) {
    let (success) = Orders.remove(order_id);
    return (success=success);
}
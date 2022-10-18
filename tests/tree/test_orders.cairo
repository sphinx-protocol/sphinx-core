%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.orders import (
    Node, Order, curr_id, push, pop, shift, get, set, remove
)

// @external
// func test_push_order{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
//     order_push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
//     return ();
// }

// @external
// func setup_get_order{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
//     order_push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
//     return ();
// }

// @external
// func test_get_order{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
//     let (order) = order_get(limit_id=1, idx=0);
//     return ();
// }

// @external
// func setup_consume_order{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
//     order_push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
//     return ();
// }

// @external
// func test_consume_order{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
//     order_consume(limit_id=1);
//     return ();
// }

@external
func test_orders{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Constructor
    curr_id.write(1);

    // Add orders to queue
    push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
    push(is_buy=0, price=24, amount=500, dt=1666091888, owner=456789, limit_id=2);
    push(is_buy=1, price=25, amount=750, dt=1666091950, owner=789123, limit_id=1);
    push(is_buy=1, price=24, amount=400, dt=1666092048, owner=123456, limit_id=2);

    remove(limit_id=1, idx=1);
    remove(limit_id=1, idx=0);

    tempvar new_order : Order* = new Order(id=0, is_buy=0, price=0, amount=0, dt=0, owner=0, limit_id=0);
    set(limit_id=2, idx=0, new_order=[new_order]);

    get(limit_id=2, idx=0);

    return ();
}
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.orders import (
    Order, curr_order_id, push, pop, shift, get, remove
)

@external
func test_orders{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Constructor
    curr_order_id.write(1);

    // Add orders to queue
    push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
    push(is_buy=0, price=24, amount=500, dt=1666091888, owner=456789, limit_id=2);
    push(is_buy=1, price=25, amount=750, dt=1666091950, owner=789123, limit_id=1);
    push(is_buy=1, price=24, amount=400, dt=1666092048, owner=123456, limit_id=2);

    remove(3);
    remove(1);

    get(limit_id=2, idx=1);

    return ();
}
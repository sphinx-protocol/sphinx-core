%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from src.dex.structs import Order
from src.dex.bitpacking import pack_order, unpack_slab_in_range, retrieve_order_id

@external
func test_bitpacking{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;

    local order : Order* = Order(
        order_id=9874,
        next_id=9876,
        price=120000000000000,
        amount=50000000000000,
        filled=1,
        owner_id=235,
        limit_id=777,
        is_bid=1,
    );

    let (order_slab0, order_slab1) = pack_order(order=order);

    let (order_id) = retrieve_order_id(order_slab0);
    %{ print("order_id: {}".format(ids.order_id)) %}

    return ();
}
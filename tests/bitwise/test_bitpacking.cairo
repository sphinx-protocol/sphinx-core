%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from src.bitwise.bitpacking import pack_order, unpack_slab_in_range, retrieve_order_id

@external
func test_bitpacking{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;

    local order_id : felt = 9874;
    local next_id : felt = 9876;
    local price : felt = 120000000000000;
    local amount : felt = 50000000000000;
    local filled : felt = 1;
    local owner_id : felt = 235;
    local limit_id : felt = 777;
    local is_buy : felt = 1;

    let (order_slab0, order_slab1) = pack_order(order_id, next_id, price, amount, filled, owner_id, limit_id, is_buy);

    let (order_id) = retrieve_order_id(order_slab0);
    %{ print("order_id: {}".format(ids.order_id)) %}

    return ();
}
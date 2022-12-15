%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from lib.openzeppelin.access.ownable.library import Ownable
from src.dex.orders import Orders
from src.dex.structs import Order

@external
func test_orders{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner = 456456456;
    const user = 123123123;
    const markets_addr = 7878787878;
    const storage_addr = 3453453453;

    Orders.push(is_buy=1, price=25, amount=1000, dt=1666091715, owner=user, limit_id=1);
    Orders.push(is_buy=0, price=24, amount=500, dt=1666091888, owner=user, limit_id=2);
    Orders.push(is_buy=1, price=25, amount=750, dt=1666091950, owner=user, limit_id=1);

    Orders.push(is_buy=1, price=24, amount=400, dt=1666092048, owner=user, limit_id=2);
    Orders.remove(3);
    Orders.remove(1);
    Orders.get(limit_id=2, idx=1);

    return ();
}
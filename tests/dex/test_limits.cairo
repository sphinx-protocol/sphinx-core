%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Limit
from src.dex.limits import Limits

@external
func test_limits{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner_addr = 456456456;
    const markets_addr = 7878787878;

    // Add limits to tree
    Limits.insert(50, 0, 0);
    Limits.insert(40, 0, 0);
    Limits.insert(70, 0, 0);
    Limits.insert(60, 0, 0);
    Limits.insert(80, 0, 0);
    Limits.delete(50, 0, 0);
    Limits.delete(25, 0, 0);
    Limits.delete(70, 0, 0);

    return ();
}
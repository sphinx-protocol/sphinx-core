%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.limits import (
    Limit, curr_id, insert, find, delete
)

@external
func test_limits{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Constructor
    curr_id.write(1);

    // Add limits to tree
    insert(50, 0);
    insert(40, 0);
    insert(70, 0);
    insert(60, 0);
    insert(80, 0);

    delete(50, 0);
    delete(25, 0);
    delete(70, 0);

    return ();
}
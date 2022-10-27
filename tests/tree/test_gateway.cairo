%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@external
func test_gateway{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    

    return ();
}
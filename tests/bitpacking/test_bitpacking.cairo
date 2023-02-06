%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.bitpacking.bitpacking import test

@external
func test_bitpacking{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() {
    test();
    return ();
}
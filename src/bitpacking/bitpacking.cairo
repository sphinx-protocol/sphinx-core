%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from lib.cairo_math_64x61.contracts.cairo_math_64x61.math64x61 import Math64x61

@external
func test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let val = Math64x61.div(1000, 7);
    let val_felt = Math64x61.toFelt(val);
    %{ print("val_felt: {}".format(ids.val_felt)) %}
    return ();
}
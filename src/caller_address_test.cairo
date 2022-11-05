%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func caller_address() -> (res: felt) {
}

@external
func store_caller_addr{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    alloc_locals;
    let (caller) = get_caller_address();
    caller_address.write(caller);
    return ();
}

@view
func get_caller_addr{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (caller : felt) {
    alloc_locals;
    let (caller) = caller_address.read();
    return (caller=caller);
}
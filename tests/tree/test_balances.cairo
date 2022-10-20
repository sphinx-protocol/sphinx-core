%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.balances import (
    get_balance, set_balance, transfer_balance, transfer_to_order, transfer_from_order
)

@external
func test_balances{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    set_balance(123456, 1, 1, 1000);
    let (amount) = get_balance(123456, 1, 1);
    assert amount = 1000;

    let (success) = transfer_balance(123456, 456789, 1, 500);
    assert success = 1;

    transfer_to_order(123456, 1, 250);
    let (locked) = get_balance(123456, 1, 0);
    assert locked = 250;
    transfer_from_order(123456, 1, 250);

    let (amount_sender) = get_balance(123456, 1, 1);
    let (amount_recipient) = get_balance(456789, 1, 1);
    assert amount_sender = 500;
    assert amount_recipient = 500;

    return ();
}
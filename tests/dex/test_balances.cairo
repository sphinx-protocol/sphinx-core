%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.balances import Balances

@external
func test_balances{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () {
    alloc_locals;

    const owner_addr = 456456456;
    const markets_addr = 7878787878;
    const gateway_addr = 101010010;
    const user_a = 123456;
    const user_b = 456789;

    Balances.set_balance(user_a, 1, 1, 1000);
    let (amount) = Balances.get_balance(user_a, 1, 1);
    assert amount = 1000;
    let (success) = Balances.transfer_balance(user_a, user_b, 1, 500);
    assert success = 1;

    Balances.transfer_to_order(user_a, 1, 250);
    let (locked) = Balances.get_balance(user_a, 1, 0);
    assert locked = 250;
    Balances.transfer_from_order(user_a, 1, 250);

    let (amount_sender) = Balances.get_balance(user_a, 1, 1);
    let (amount_recipient) = Balances.get_balance(user_b, 1, 1);
    assert amount_sender = 500;
    assert amount_recipient = 500;

    return ();
}
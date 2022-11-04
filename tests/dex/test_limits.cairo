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

    Limits.initialise();

    // Add limits to tree
    Limits.insert(50, 1, 1);
    Limits.insert(40, 1, 1);
    Limits.insert(70, 1, 1);
    Limits.insert(60, 1, 1);
    Limits.insert(80, 1, 1);
    Limits.insert(30, 1, 1);
    Limits.insert(55, 1, 1);
    Limits.insert(20, 1, 1);
    Limits.delete(50, 1, 1);
    Limits.delete(25, 1, 1);
    Limits.delete(70, 1, 1);

    let (prices, amounts, length) = Limits.view_limit_tree(1);
    %{ print("Prices:") %}
    print_list(prices, length);
    %{ print("Amounts:") %}
    print_list(amounts, length);

    return ();
}


func print_list{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} (array : felt*, idx : felt) {
    alloc_locals;

    if (idx == 0) {
        return ();
    }
    let value = array[idx - 1];
    %{ print("[{}]: {}".format(ids.idx - 1, ids.value)) %}
    print_list(array, idx - 1);
    
    return ();
}
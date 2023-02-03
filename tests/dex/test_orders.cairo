%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.dex.structs import Order

@contract_interface
namespace IOrdersContract {
    // Insert new order to the end of the list.
    func push(is_buy : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt) -> (new_order : Order) {
    }
    // Remove order from head of list
    func shift(limit_id : felt) -> (del : Order) {
    }
    // Remove order by ID.
    func remove(order_id : felt) -> (success : felt) {
    }
}

@contract_interface
namespace IStorageContract {
    // Set external contract address
    func set_gateway_address(_l2_gateway_contract_address : felt) {
    }
    // Get order by order ID
    func get_order(order_id : felt) -> (order : Order) {
    }
}


@external
func test_orders{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;
    
    // Set contract addresses
    const owner = 456456456;
    const user = 123123123;

    // Deploy contracts
    const gateway_addr = 789789789;
    local storage_addr : felt;
    local orders_addr : felt;
    %{ ids.storage_addr = deploy_contract("./src/dex/storage.cairo", [ids.owner]).contract_address %}
    %{ ids.orders_addr = deploy_contract("./src/dex/test/orders.cairo", [ids.storage_addr]).contract_address %}

    // Invoke functions
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.storage_addr) %}
    IStorageContract.set_gateway_address(storage_addr, gateway_addr);
    %{ stop_prank_callable() %}

    // Test 1: Should push orders to queue correctly
    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.storage_addr) %}
    let (order_1) = IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=1000, datetime=1666091715, owner=user, limit_id=1);
    print_order(order_1);
    let (order_2) = IOrdersContract.push(orders_addr, is_buy=1, price=24, amount=500, datetime=1666091888, owner=user, limit_id=1);
    print_order(order_2);
    let (order_3) = IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=750, datetime=1666091950, owner=user, limit_id=1);
    print_order(order_3);
    let (del_order_1) = IOrdersContract.shift(orders_addr, limit_id=1);
    print_order(del_order_1);
    let (success_1) = IOrdersContract.remove(orders_addr, 3);
    print_order_list(storage_addr, 1, 2, 1);
    %{ stop_prank_callable() %}

    return ();
}

// Utility function for printing order.
func print_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order : Order) {
    %{
        print("    ", end="")
        print("order_id: {}, next_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, datetime: {}, owner: {}, limit_id: {}".format(ids.order.order_id, ids.order.next_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.datetime, ids.order.owner, ids.order.limit_id))
    %}
    return ();
}

// Utility function for printing list of orders.
func print_order_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    storage_addr : felt, node_loc : felt, idx: felt, first_iter : felt
) {
    if (first_iter == 1) {
        %{
            print("Orders:")
        %}
        tempvar temp;
    }
    if (idx == 0) {
        %{
            print("")
        %}
        return ();
    }
    let (order) = IStorageContract.get_order(storage_addr, node_loc);
    %{
        print("    ", end="")
        print("order_id: {}, next_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, datetime: {}, owner: {}, limit_id: {}".format(ids.order.order_id, ids.order.next_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.datetime, ids.order.owner, ids.order.limit_id))
    %}
    return print_order_list(storage_addr, order.next_id, idx - 1, 0);
}
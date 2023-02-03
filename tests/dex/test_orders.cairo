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
    // Remove order from end of the list
    func pop(limit_id : felt) -> (del : Order) {
    }
    // Remove order by ID.
    func remove(order_id : felt) -> (del : Order) {
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
    // Get head order by limit ID
    func get_head(limit_id : felt) -> (id : felt) {
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

    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.storage_addr) %}

    // Test 1: Should push orders to queue correctly
    let (order_1) = IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=1000, datetime=1666091715, owner=user, limit_id=1);
    let (order_2) = IOrdersContract.push(orders_addr, is_buy=1, price=24, amount=500, datetime=1666091888, owner=user, limit_id=1);
    let (order_3) = IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=750, datetime=1666091950, owner=user, limit_id=1);
    let (first) = IStorageContract.get_order(storage_addr, 1);
    assert first.order_id = 1;
    assert first.next_id = 2;
    let (second) = IStorageContract.get_order(storage_addr, 2);
    assert second.next_id = 3;
    let (third) = IStorageContract.get_order(storage_addr, 3);
    assert third.next_id = 0;

    // Test 2 : should shift orders from queue correctly
    let (del_order_1) = IOrdersContract.shift(orders_addr, limit_id=1);
    assert del_order_1.order_id = 1;
    let (head_id) = IStorageContract.get_head(storage_addr, 1);
    let (head) = IStorageContract.get_order(storage_addr, head_id);
    assert head_id = 2;
    assert head.next_id = 3;
    IOrdersContract.shift(orders_addr, limit_id=1);
    let (del_order_2) = IOrdersContract.shift(orders_addr, limit_id=1);
    assert del_order_2.order_id = 3;
    let (empty_order) = IOrdersContract.shift(orders_addr, limit_id=1);
    assert empty_order.order_id = 0;

    // Test 3 : should pop orders from queue correctly
    let (order) = IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=1000, datetime=1666091715, owner=user, limit_id=1);
    IOrdersContract.push(orders_addr, is_buy=1, price=24, amount=500, datetime=1666091888, owner=user, limit_id=1);
    IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=750, datetime=1666091950, owner=user, limit_id=1);

    let (del_order_3) = IOrdersContract.pop(orders_addr, limit_id=1);
    assert del_order_3.order_id = 6;
    let (new_head_id) = IStorageContract.get_head(storage_addr, 1);
    let (new_head) = IStorageContract.get_order(storage_addr, new_head_id);
    assert new_head_id = 4;
    assert new_head.next_id = 5;
    IOrdersContract.pop(orders_addr, limit_id=1);
    let (del_order_4) = IOrdersContract.pop(orders_addr, limit_id=1);
    assert del_order_4.order_id = 4;
    let (del_order_5) = IOrdersContract.pop(orders_addr, limit_id=1);
    assert del_order_5.order_id = 0;

    // Test 4 : should delete orders from queue correctly
    IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=1000, datetime=1666091715, owner=user, limit_id=1);
    IOrdersContract.push(orders_addr, is_buy=1, price=24, amount=500, datetime=1666091888, owner=user, limit_id=1);
    IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=750, datetime=1666091950, owner=user, limit_id=1);
    
    let (del_order_6) = IOrdersContract.remove(orders_addr, 7);
    assert del_order_6.amount = 1000;
    let (new_head_id_2) = IStorageContract.get_head(storage_addr, 1);
    assert new_head_id_2 = 8;
    let (empty_order_2) = IOrdersContract.remove(orders_addr, 10);
    assert empty_order_2.order_id = 0;

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
    storage_addr : felt, order_id : felt, idx: felt, first_iter : felt
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
    let (order) = IStorageContract.get_order(storage_addr, order_id);
    %{
        print("    ", end="")
        print("order_id: {}, next_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, datetime: {}, owner: {}, limit_id: {}".format(ids.order.order_id, ids.order.next_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.datetime, ids.order.owner, ids.order.limit_id))
    %}
    return print_order_list(storage_addr, order.next_id, idx - 1, 0);
}
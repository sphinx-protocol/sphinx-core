%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.tree.structs import Order

@contract_interface
namespace IOrdersContract {
    // Set MarketsContract address.
    func set_markets_addr(_markets_addr : felt) {
    }
    // Getter for head ID and tail ID.
    func get_head_and_tail(limit_id : felt) -> (head_id : felt, tail_id : felt) {
    }
    // Getter for particular order.
    func get_order(id : felt) -> (order : Order) {
    }
    // Insert new order to the list.
    func push(is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt) -> (new_order : Order) {
    }
    // Retrieve order at particular position in the list.
    func get(limit_id : felt, idx : felt) -> (order : Order) {
    }
    // Update filled amount of order.
    func set_filled(id : felt, filled : felt) -> (success : felt) {  
    }
    // Remove order by ID.
    func remove(order_id : felt) -> (success : felt) {
    }
}

@external
func test_orders{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner_addr = 456456456;
    const markets_addr = 7878787878;

    local orders_addr: felt;
    %{ ids.orders_addr = deploy_contract("./src/tree/orders.cairo", [ids.owner_addr]).contract_address %}

    %{ stop_prank_callable = start_prank(ids.owner_addr, target_contract_address=ids.orders_addr) %}
    IOrdersContract.set_markets_addr(orders_addr, markets_addr);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.markets_addr, target_contract_address=ids.orders_addr) %}
    IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=1000, dt=1666091715, owner=123456, limit_id=1);
    IOrdersContract.push(orders_addr, is_buy=0, price=24, amount=500, dt=1666091888, owner=456789, limit_id=2);
    IOrdersContract.push(orders_addr, is_buy=1, price=25, amount=750, dt=1666091950, owner=789123, limit_id=1);
    %{ stop_prank_callable() %}
    
    %{ stop_prank_callable = start_prank(ids.owner_addr, target_contract_address=ids.orders_addr) %}
    IOrdersContract.push(orders_addr, is_buy=1, price=24, amount=400, dt=1666092048, owner=123456, limit_id=2);
    IOrdersContract.remove(orders_addr, 3);
    IOrdersContract.remove(orders_addr, 1);
    IOrdersContract.get(orders_addr, limit_id=2, idx=1);
    %{ stop_prank_callable() %}

    return ();
}
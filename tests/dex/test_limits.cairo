%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.limits import Limits
from src.dex.structs import Order, Limit

@contract_interface
namespace ILimitsContract {
    // Insert new limit price into BST.
    func insert(price : felt, tree_id : felt, market_id : felt) -> (new_limit : Limit) {
    }
    // Find a limit price in binary search tree.
    func find(price : felt, tree_id : felt) -> (limit : Limit, parent : Limit) {
    }
    // Deletes limit price from BST
    func delete(price : felt, tree_id : felt, market_id : felt) -> (del : Limit) {
    }
    // Getter for lowest limit price in the tree
    func get_min(tree_id : felt) -> (min : Limit) {
    }
    // Getter for highest limit price in the tree
    func get_max(tree_id : felt) -> (max : Limit) {
    }
    // Setter function to update details of limit price
    func update(limit_id : felt, amount : felt, length : felt) {
    }
    // View limit tree.
    func view_limit_tree(tree_id : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) {
    }
    // View limit tree orders.
    func view_limit_tree_orders(tree_id : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*, owners_len : felt, owners : felt*, ids_len : felt, ids : felt*) {
    }
    // Insert new order to the end of the list.
    func push(is_bid : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt) -> (new_order : Order) {
    }
}

@contract_interface
namespace IStorageContract {
    // Set external contract address
    func set_gateway_address(_l2_gateway_contract_address : felt) {
    }
    // Get limit by limit ID
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
}

@external
func test_limits{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Set contract addresses
    const owner = 456456456;

    // Deploy contracts
    const gateway_addr = 789789789;
    local storage_addr : felt;
    local limits_addr : felt;
    %{ ids.storage_addr = deploy_contract("./src/dex/storage.cairo", [ids.owner]).contract_address %}
    %{ ids.limits_addr = deploy_contract("./src/dex/test/limits.cairo", [ids.storage_addr]).contract_address %}

    // Invoke functions
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.storage_addr) %}
    IStorageContract.set_gateway_address(storage_addr, gateway_addr);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.storage_addr) %}

    // Test 1 : Should add limits to tree
    ILimitsContract.insert(limits_addr, 50, 1, 1);
    ILimitsContract.insert(limits_addr, 40, 1, 1);
    ILimitsContract.insert(limits_addr, 70, 1, 1);
    ILimitsContract.insert(limits_addr, 60, 1, 1);
    ILimitsContract.insert(limits_addr, 80, 1, 1);
    ILimitsContract.insert(limits_addr, 20, 2, 1);
    let (prices_len, prices, amounts_len, amounts) = ILimitsContract.view_limit_tree(limits_addr, 1);
    assert prices_len = 5;
    assert prices[0] = 40;
    assert prices[1] = 50;
    assert prices[2] = 60;
    assert prices[3] = 70;
    assert prices[4] = 80;

    // Test 2 : Should find limit in tree
    let (limit, parent) = ILimitsContract.find(limits_addr, 40, 1);
    assert limit.limit_id = 2;
    assert parent.limit_id = 1;

    // Test 3 : Should fetch minimum price in tree
    let (min_limit) = ILimitsContract.get_min(limits_addr, 1);
    assert min_limit.price = 40;

    // Test 4 : Should fetch maximum price in tree
    let (max_limit) = ILimitsContract.get_max(limits_addr, 1);
    assert max_limit.price = 80;

    // Test 5 : Should update limit price
    ILimitsContract.update(limits_addr, 1, 1000, 5);
    let (limit_1) = IStorageContract.get_limit(storage_addr, 1);
    assert limit_1.amount = 1000;
    assert limit_1.length = 5;

    // Test 6 : view_limit_tree should fetch limit tree properly
    let (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) = ILimitsContract.view_limit_tree(limits_addr, 1);
    assert prices[0] = 40;
    assert prices[1] = 50;
    assert prices[2] = 60;
    assert prices[3] = 70;
    assert prices[4] = 80;
    assert amounts[1] = 1000;

    // Test 7 : view_limit_tree_orders should fetch limit tree orders properly
    ILimitsContract.push(limits_addr, is_bid=1, price=40, amount=500, datetime=12412424, owner=owner, limit_id=1);
    ILimitsContract.push(limits_addr, is_bid=1, price=40, amount=700, datetime=12412424, owner=owner, limit_id=1);
    
    let (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*, owners_len : felt, owners : felt*, ids_len : felt, ids : felt*) = ILimitsContract.view_limit_tree_orders(limits_addr, 1);
    assert prices[0] = 40;
    assert amounts[1] = 700;
    assert owners[1] = owner;

    // Test 8 : Should delete limit price from BST
    let (del_1) = ILimitsContract.delete(limits_addr, 70, 1, 1);
    assert del_1.limit_id = 3;
    ILimitsContract.delete(limits_addr, 40, 1, 1);
    ILimitsContract.delete(limits_addr, 60, 1, 1);
    ILimitsContract.delete(limits_addr, 80, 1, 1);
    ILimitsContract.delete(limits_addr, 50, 1, 1);
    let (empty_limit) = ILimitsContract.delete(limits_addr, 70, 1, 1);
    assert empty_limit.limit_id = 0;

    // Print limit orders
    // %{ print("Prices:") %}
    // print_array(prices, prices_len);
    // %{ print("Amounts:") %}
    // print_array(amounts, amounts_len);

    %{ stop_prank_callable() %}

    return ();
}

// Utility function to print an array
func print_array{
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
    print_array(array, idx - 1);
    
    return ();
}
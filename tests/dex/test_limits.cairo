%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Limit
from src.dex.limits import Limits

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
    func update(limit_id : felt, total_vol : felt, length : felt) {
    }
    // View limit tree.
    func view_limit_tree(tree_id : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) {
    }
    // Helper function to retrieve limit tree
    func view_limit_tree_helper(tree_id : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*, owners_len : felt, owners : felt*, ids_len : felt, ids : felt*) {
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
    // Set limit by limit ID
    func set_limit(limit_id : felt, new_limit : Limit) {
    }
    // Get root node by tree ID
    func get_root(tree_id : felt) -> (id : felt) {
    }
    // Set root node by tree ID
    func set_root(tree_id : felt, new_id : felt) {
    }
    // Get latest limit id
    func get_curr_limit_id() -> (id : felt) {
    }
    // Set latest limit id
    func set_curr_limit_id(new_id : felt) {
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
    
    
    %{ print("Prices:") %}
    print_array(prices, prices_len);
    %{ print("Amounts:") %}
    print_array(amounts, amounts_len);

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
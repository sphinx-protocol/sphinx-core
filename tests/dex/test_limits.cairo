%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Limit

@contract_interface
namespace ILimitsContract {
    // Set MarketsContract address.
    func set_markets_addr(_markets_addr : felt) {
    }
    // Getter for limit price
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
    // Getter for highest limit price within tree
    func get_max(tree_id : felt) -> (max : Limit) {
    }
    // Insert new limit price into BST.
    func insert(price : felt, tree_id : felt, market_id : felt) -> (new_limit : Limit) {
    }
    // Find a limit price in binary search tree.
    func find(price : felt, tree_id : felt) -> (limit : Limit, parent : Limit) {    
    }
    // Deletes limit price from BST
    func delete(price : felt, tree_id : felt, market_id : felt) -> (del : Limit) {
    }
    // Setter function to update details of a limit price.
    func update(limit_id : felt, total_vol : felt, length : felt, head_id : felt, tail_id : felt ) -> (success : felt) {
    }   
}

@external
func test_limits{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner_addr = 456456456;
    const markets_addr = 7878787878;

    local limits_addr: felt;
    %{ ids.limits_addr = deploy_contract("./src/dex/limits.cairo", [ids.owner_addr]).contract_address %}

    %{ stop_prank_callable = start_prank(ids.owner_addr, target_contract_address=ids.limits_addr) %}
    ILimitsContract.set_markets_addr(limits_addr, markets_addr);
    %{ stop_prank_callable() %}

    // Add limits to tree
    %{ stop_prank_callable = start_prank(ids.markets_addr, target_contract_address=ids.limits_addr) %}
    ILimitsContract.insert(limits_addr, 50, 0, 0);
    ILimitsContract.insert(limits_addr, 40, 0, 0);
    ILimitsContract.insert(limits_addr, 70, 0, 0);
    ILimitsContract.insert(limits_addr, 60, 0, 0);
    ILimitsContract.insert(limits_addr, 80, 0, 0);
    ILimitsContract.delete(limits_addr, 50, 0, 0);
    ILimitsContract.delete(limits_addr, 25, 0, 0);
    ILimitsContract.delete(limits_addr, 70, 0, 0);
    %{ stop_prank_callable() %}

    return ();
}
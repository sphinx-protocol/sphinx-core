%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le

// Utility function for printing list of orders.
@view
func print_order_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    node_loc : felt, idx: felt, first_iter : felt
) {
    if (first_iter == 1) {
        %{
            print("[orders.cairo] Orders:")
        %}
        tempvar temp;
    }
    if (idx == 0) {
        %{
            print("")
        %}
        return ();
    }
    let (order) = orders.read(node_loc);
    %{
        print("    ", end="")
        print("id: {}, next_id: {}, prev_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, dt: {}, owner: {}, limit_id: {}".format(ids.order.id, ids.order.next_id, ids.order.prev_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.dt, ids.order.owner, ids.order.limit_id))
    %}
    return print_order_list(order.next_id, idx - 1, 0);
}

// Utility function for printing order.
@view
func print_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order : Order) {
    %{
        print("    ", end="")
        print("id: {}, next_id: {}, prev_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, dt: {}, owner: {}, limit_id: {}".format(ids.order.id, ids.order.next_id, ids.order.prev_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.dt, ids.order.owner, ids.order.limit_id))
    %}
    return ();
}

// Utility function to handle printing of deleted order and remaining orders in list
@view
func print_del_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    old_head : Order, limit_id : felt, length : felt
) {
    %{ print("Deleted order: ") %}
    print_order(old_head);
    let (head_id) = heads.read(limit_id);
    let length_positive = is_le(1, length - 1);
    if (length_positive == 1) {
        print_order_list(head_id, length - 1, 1);
        handle_revoked_refs();
    } else {
        %{ 
            print("No orders remaining") 
            print("") 
        %}
        handle_revoked_refs();
    }
    return ();
}

// Utility function to handle printing of nodes in a limit tree from left to right order.
@view
func print_limit_tree{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (root : Limit, iter : felt) {
    alloc_locals;
    if (iter == 1) {
        %{ 
            print("")
            print("Tree (DFS In Order):") 
        %}
        tempvar temp;
    }

    let left_exists = is_le(1, root.left_id);
    let right_exists = is_le(1, root.right_id);
    
    if (left_exists == 1) {
        let (left) = limits.read(root.left_id);
        print_limit_tree(left, 0);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
    %{ 
        print("    ", end="")
        print("id: {}, left_id: {}, right_id: {}, price: {}, total_vol: {}, length: {}, head_id: {}, tail_id: {}, tree_id: {}, market_id: {}".format(ids.root.id, ids.root.left_id, ids.root.right_id, ids.root.price, ids.root.total_vol, ids.root.length, ids.root.head_id, ids.root.tail_id, ids.root.tree_id, ids.root.market_id))
    %}
    if (right_exists == 1) {
        let (right) = limits.read(root.right_id);
        print_limit_tree(right, 0);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
    return ();
}

// Utility function to handle printing info about a limit price.
@view
func print_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit : Limit) {
    %{ 
        print("id: {}, left_id: {}, right_id: {}, price: {}, total_vol: {}, length: {}, head_id: {}, tail_id: {}, tree_id: {}".format(ids.limit.id, ids.limit.left_id, ids.limit.right_id, ids.limit.price, ids.limit.total_vol, ids.limit.length, ids.limit.head_id, ids.limit.tail_id, ids.limit.tree_id, ids.limit.market_id)) 
    %}
    return ();
}

// Utility function to print information about a market.
func print_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (market : Market) {
    %{ 
        print("id: {}, bid_tree_id: {}, ask_tree_id: {}, lowest_ask: {}, highest_bid: {}, base_asset: {}, quote_asset: {}, controller: {}".format(ids.market.id, ids.market.bid_tree_id, ids.market.ask_tree_id, ids.market.lowest_ask, ids.market.highest_bid, ids.market.base_asset, ids.market.quote_asset, ids.market.controller)) 
    %}
    return ();
}
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from src.dex.structs import Order
from lib.openzeppelin.access.ownable.library import Ownable
// from src.dex.print import print_order_list, print_order, print_del_order

// Stores orders in doubly linked lists.
@storage_var
func orders(id : felt) -> (order : Order) {
}
// Stores heads of doubly linked lists.
@storage_var
func heads(limit_id : felt) -> (id : felt) {
}
// Stores tails of doubly linked lists.
@storage_var
func tails(limit_id : felt) -> (id : felt) {
}
// Stores lengths of doubly linked lists.
@storage_var
func lengths(limit_id : felt) -> (len : felt) {
}
// Stores latest order id.
@storage_var
func curr_order_id() -> (id : felt) {
}
// Stores contract address of MarketsContract.
@storage_var
func markets_addr() -> (id : felt) {
}
// 1 if markets_addr has been set, 0 otherwise
@storage_var
func is_markets_addr_set() -> (bool : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    owner : felt
) {
    curr_order_id.write(1);
    Ownable.initializer(owner);
    return ();
}

// Set MarketsContract address.
// @dev Can only be called by contract owner and is write once.
@external
func set_markets_addr{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (_markets_addr : felt) {
    Ownable.assert_only_owner();
    let (is_set) = is_markets_addr_set.read();
    if (is_set == 0) {
        markets_addr.write(_markets_addr);
        is_markets_addr_set.write(1);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
    return ();
}

// Getter for head ID and tail ID.
@view
func get_head_and_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt
) -> (head_id : felt, tail_id : felt) {
    let (head_id) = heads.read(limit_id);
    let (tail_id) = tails.read(limit_id);
    return (head_id=head_id, tail_id=tail_id);
}

// Getter for list length.
@view
func get_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (len : felt) {
    let (len) = lengths.read(limit_id);
    return (len=len);
}

// Getter for particular order.
// @dev To be distinguished from get(), which retrieves order at particular position of a list. 
// @param id : order ID
// @return order : returned order
@view
func get_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (id : felt) -> (order : Order) {
    let (order) = orders.read(id);
    return (order=order);
}

// Insert new order to the list.
// @param is_buy : 1 if buy order, 0 if sell order
// @param price : limit price
// @param amount : amount of order
// @param dt : datetime of order entry
// @param owner : owner of order
// @param limit_id : ID of limit price corresponding to order
@external
func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt
) -> (new_order : Order) {
    alloc_locals;
    check_permissions();

    let (id) = curr_order_id.read();
    tempvar new_order: Order* = new Order(
        id=id, next_id=0, prev_id=0, is_buy=is_buy, price=price, amount=amount, filled=0, dt=dt, owner=owner, limit_id=limit_id
    );
    orders.write(id, [new_order]);
    curr_order_id.write(id + 1);

    let (length) = lengths.read(limit_id);
    lengths.write(limit_id, length + 1);
    if (length == 0) {
        heads.write(limit_id, new_order.id);
        tails.write(limit_id, new_order.id);
        handle_revoked_refs();

        // Diagnostics
        // %{ print("Pushed order") %}
        // let (head_id) = heads.read(limit_id);
        // print_order_list(head_id, length + 1, 1);

        return (new_order=[new_order]);
    } else {
        let (tail_id) = tails.read(limit_id);
        let (tail) = orders.read(tail_id);
        tempvar new_tail: Order* = new Order(
            id=tail.id, next_id=new_order.id, prev_id=tail.prev_id, is_buy=tail.is_buy, 
            price=tail.price, amount=tail.amount, filled=tail.filled, dt=tail.dt, owner=tail.owner, limit_id=tail.limit_id
        );
        orders.write(tail_id, [new_tail]);
        tempvar new_order_updated: Order* = new Order(
            id=new_order.id, next_id=0, prev_id=tail_id, is_buy=new_order.is_buy, 
            price=new_order.price, amount=new_order.amount, filled=new_order.filled, dt=new_order.dt, 
            owner=new_order.owner, limit_id=new_order.limit_id
        );
        orders.write(new_order.id, [new_order_updated]);
        tails.write(limit_id, new_order.id);
        handle_revoked_refs();

        // Diagnostics
        // %{ print("Pushed order") %}
        // let (head_id) = heads.read(limit_id);
        // print_order_list(head_id, length + 1, 1);

        return (new_order=[new_order_updated]);
    }
}

// Remove order from the end of the list.
// @param limit_id : limit ID of order list being amended
// @return del : order deleted from list (or empty order if list is empty)
@external
func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
    alloc_locals;
    check_permissions();
    
    let (length) = lengths.read(limit_id);
    tempvar empty_order: Order* = new Order(
        id=0, next_id=0, prev_id=0, is_buy=0, price=0, amount=0, filled=0, dt=0, owner=0, limit_id=0
    );
    if (length == 0) {
        return (del=[empty_order]);
    }

    let (head_id) = heads.read(limit_id);
    let (old_tail_id) = tails.read(limit_id);
    let (old_tail) = orders.read(old_tail_id);

    if (length - 1 == 0) {
        orders.write(head_id, [empty_order]);
        orders.write(old_tail_id, [empty_order]);
        heads.write(limit_id, 0);
        tails.write(limit_id, 0);
        handle_revoked_refs();
    } else {
        tails.write(limit_id, old_tail.prev_id);
        let (new_tail) = orders.read(old_tail.prev_id);
        tempvar new_tail_updated: Order* = new Order(
            id=new_tail.id, next_id=0, prev_id=new_tail.prev_id, is_buy=new_tail.is_buy, price=new_tail.price,  
            amount=new_tail.amount, filled=new_tail.filled, dt=new_tail.dt, owner=new_tail.owner, 
            limit_id=new_tail.limit_id
        );
        orders.write(new_tail.id, [new_tail_updated]);
        handle_revoked_refs();
    }

    lengths.write(limit_id, length - 1);

    // Diagnostics
    // %{ print("Deleted: ") %}
    // print_order(old_tail);
    // print_order_list(head_id, length - 1, 1);

    return (del=old_tail);
}

// Remove order from head of list
// @param limit_id : limit ID of order list being amended
// @return del : deleted order
@external
func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
    alloc_locals;
    check_permissions();

    let (length) = lengths.read(limit_id);
    tempvar empty_order: Order* = new Order(
        id=0, next_id=0, prev_id=0, is_buy=0, price=0, amount=0, filled=0, dt=0, owner=0, limit_id=0
    );
    if (length == 0) {
        return (del=[empty_order]);
    }

    let (old_head_id) = heads.read(limit_id);
    let (old_head) = orders.read(old_head_id);

    if (length - 1 == 0) {
        heads.write(limit_id, 0);
        tails.write(limit_id, 0);
        handle_revoked_refs();
    } else {
        heads.write(limit_id, old_head.next_id);
        let (new_head) = orders.read(old_head.next_id);
        tempvar new_head_updated: Order* = new Order(
            id=new_head.id, next_id=new_head.next_id, prev_id=0, is_buy=new_head.is_buy, price=new_head.price, 
            amount=new_head.amount, filled=new_head.filled, dt=new_head.dt, owner=new_head.owner, 
            limit_id=new_head.limit_id
        );
        orders.write(new_head.id, [new_head_updated]);
        handle_revoked_refs();
    }

    lengths.write(limit_id, length - 1);

    // Diagnostics
    // print_del_order(old_head, limit_id, length);

    return (del=old_head);
} 

// Retrieve order at particular position in the list.
// @param limit_id : limit ID of order list being amended
// @param idx : order to retrieve
// @return order : retrieved order
@view
func get{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt, idx : felt) -> (order : Order) {
    alloc_locals;
    check_permissions();
    
    tempvar empty_order: Order* = new Order(
        id=0, next_id=0, prev_id=0, is_buy=0, price=0, amount=0, filled=0, dt=0, owner=0, limit_id=0
    );
    let (in_range) = validate_idx(limit_id, idx);
    if (in_range == 0) {
        return (order=[empty_order]);
    }

    let (head_id) = heads.read(limit_id);
    let (head) = orders.read(head_id);
    let (tail_id) = tails.read(limit_id);
    let (tail) = orders.read(tail_id);

    let (length) = lengths.read(limit_id);
    let (half_length, _) = unsigned_div_rem(length, 2);
    let less_than_half = is_le(idx, half_length);

    if (less_than_half == 1) {
        let (order) = locate_item_from_head(i=0, idx=idx, curr=head);
        return (order=order);
    } else {
        let (order) = locate_item_from_tail(i=length-1, idx=idx, curr=tail);
        return (order=order);
    }
}

// Iterate through list to find item from head element.
// @param i : current iteration
// @param idx : list position to be found
// @param curr : order in current iteration of the list
func locate_item_from_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    i : felt, idx : felt, curr : Order
) -> (order : Order) {
    if (i == idx) {
        return (order=curr);
    }
    let (next) = orders.read(curr.next_id);
    return locate_item_from_head(i + 1, idx, next);
}

// Iterate through list to find item from tail element.
// @param i : current iteration
// @param idx : list position to be found
// @param curr : order in current iteration of the list
func locate_item_from_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    i : felt, idx : felt, curr : Order
) -> (order : Order) {
    if (i == idx) {
        return (order=curr);
    }
    let (prev) = orders.read(curr.prev_id);
    return locate_item_from_tail(i - 1, idx, prev);
}

// Update order at particular position in the list.
// @param limit_id : limit ID of order list being amended
// @param idx : position of list to insert new value
// @param is_buy : 1 if buy order, 0 if sell order
// @param price : limit price
// @param amount : amount of order
// @param filled : amount of order that has been filled
// @param dt : datetime of order entry
// @param owner : owner of order
// @return success : 1 if insertion was successful, 0 otherwise
// @external
// func set{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
//     limit_id : felt, idx : felt, is_buy : felt, price : felt, amount : felt, filled : felt, dt : felt, owner : felt
//         ) -> (
//     success : felt
// ) {
//     let (in_range) = validate_idx(limit_id, idx);
//     if (in_range == 0) {
//         return (success=0);
//     }
//     let (order) = orders.read(idx);
//     tempvar new_order : Order* = new Order(
//         id=order.id, next_id=order.next_id, prev_id=order.prev_id, is_buy=is_buy, price=price, 
//         amount=amount, filled=filled, dt=dt, owner=owner, limit_id=limit_id
//     );
//     orders.write(order.id, [new_order]);

//     // Diagnostics
    // %{ print("Set order") %}
    // let (head_id) = heads.read(limit_id);
    // let (length) = lengths.read(limit_id);
    // print_order_list(head_id, length, 1);

//     return (success=1);
// }

// Update filled amount of order.
// @param id : order ID
// @param filled : updated filled amount of order
// @return success : 1 if update was successful, 0 otherwise
@external
func set_filled{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    id : felt, filled : felt
) -> (success : felt) {
    check_permissions();
    let (order) = orders.read(id);
    let is_valid = is_le(filled, order.amount);
    let is_incremental = is_le(order.filled, filled - 1);
    let is_positive = is_le(1, filled);
    if (is_valid + is_incremental + is_positive == 3) {
        tempvar new_order : Order* = new Order(
            id=order.id, next_id=order.next_id, prev_id=order.prev_id, is_buy=order.is_buy, price=order.price, 
            amount=order.amount, filled=filled, dt=order.dt, owner=order.owner, limit_id=order.limit_id
        );
        orders.write(order.id, [new_order]);
        handle_revoked_refs();
        return (success=1);
    } else {
        handle_revoked_refs();
        return (success=0);
    }    
}

// Remove order by ID.
// @param order_id : ID of order being amended
// @return success : 1 if successful, 0 otherwise
@external
func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (success : felt) {
    alloc_locals;
    check_permissions();
    
    let (removed) = get_order(order_id);
    tempvar empty_order: Order* = new Order(
        id=0, next_id=0, prev_id=0, is_buy=0, price=0, amount=0, filled=0, dt=0, owner=0, limit_id=0
    ); 
    let is_valid = is_le(1, order_id); 
    if (is_valid == 0) {
        return (success=0);
    }
    
    if (removed.next_id == 0) {
        pop(removed.limit_id);
        return (success=1);
    }
    if (removed.prev_id == 0) {
        shift(removed.limit_id);
        return (success=1);
    }

    let (removed_prev) = orders.read(removed.prev_id);
    tempvar updated_removed_prev: Order* = new Order(
        id=removed_prev.id, next_id=removed.next_id, prev_id=removed_prev.prev_id, is_buy=removed_prev.is_buy, 
        price=removed_prev.price, amount=removed_prev.amount, filled=removed_prev.filled, dt=removed_prev.dt, 
        owner=removed_prev.owner, limit_id=removed_prev.limit_id
    ); 
    orders.write(removed_prev.id, [updated_removed_prev]);

    let (removed_next) = orders.read(removed.next_id);
    tempvar updated_removed_next: Order* = new Order(
        id=removed_next.id, next_id=removed_next.next_id, prev_id=removed.prev_id, is_buy=removed_next.is_buy, 
        price=removed_next.price, amount=removed_next.amount, filled=removed_next.filled, dt=removed_next.dt, 
        owner=removed_next.owner, limit_id=removed_next.limit_id
    ); 
    orders.write(removed_next.id, [updated_removed_next]);

    let (length) = lengths.read(removed.limit_id);
    lengths.write(removed.limit_id, length - 1);

    // Diagnostics
    // %{ print("Removed order") %}
    // let (head_id) = heads.read(removed.limit_id);
    // print_order_list(head_id, length + 1, 1);

    return (success=1);
}

// Utility function to check idx is not out of bounds.
// @param idx : index to check
// @return in_range : 1 if idx in range, 0 otherwise
func validate_idx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, idx : felt
) -> (in_range : felt) {
    alloc_locals;
    
    let (length) = lengths.read(limit_id);
    let idx_negative = is_le(idx, -1);
    let idx_out_of_bounds = is_le(length, idx);

    if ((idx_negative - 1) * (idx_out_of_bounds - 1) == 0) {
        handle_revoked_refs();
        return (in_range=0);
    } else {
        handle_revoked_refs();
        return (in_range=1);
    }
}

// Utility function to check that caller is either contract owner or markets contract.
@view
func check_permissions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    if (caller == _markets_addr) {
        return ();
    }
    with_attr error_message("Caller does not have permission to call this function.") {
        assert 1 = 0;
    }
    return ();
}

// Utility function to handle revoked implicit references.
func handle_revoked_refs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
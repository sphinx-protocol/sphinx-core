%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from src.dex.structs import Order, Limit
from src.utils.handle_revoked_refs import handle_revoked_refs


@contract_interface
namespace IStorageContract {
    // Get order by order ID
    func get_order(order_id : felt) -> (order : Order) {
    }
    // Set order by order ID
    func set_order(order_id : felt, new_order : Order) {
    }
    // Get head of order queue by limit ID
    func get_head(limit_id : felt) -> (id : felt) {
    }
    // Set head of order queue by limit ID
    func set_head(limit_id : felt, new_id : felt) {
    }
    // Get length of order queue by limit ID
    func get_length(limit_id : felt) -> (len : felt) {
    }
    // Set length of order queue by limit ID
    func set_length(limit_id : felt, new_len : felt) {
    }
    // Get current order ID
    func get_curr_order_id() -> (id : felt) {
    }
    // Set current order ID
    func set_curr_order_id(new_id : felt) {
    }
    // Get limit by limit ID
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
}

//
// Storage vars
//

@storage_var
func l2_storage_contract_address() -> (addr : felt) {
}

namespace Orders {

    //
    // Functions
    //

    // Initialiser function
    // @dev Called by GatewayContract on deployment
    func initialise{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        _l2_storage_contract_address : felt
    ) {
        l2_storage_contract_address.write(_l2_storage_contract_address);
        return ();
    }

    // Get address of storage contract
    // @return storage_addr : address of storage contract
    func get_storage_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (storage_addr : felt) {
        let (storage_addr) = l2_storage_contract_address.read();
        return (storage_addr=storage_addr);
    }

    // Insert new order to the end of the list.
    // @param is_bid : 1 if buy order, 0 if sell order
    // @param price : limit price
    // @param amount : amount of order
    // @param datetime : datetime of order entry
    // @param owner : owner of order
    // @param limit_id : ID of limit price corresponding to order
    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        is_bid : felt, price : felt, amount : felt, datetime : felt, owner : felt, limit_id : felt
    ) -> (new_order : Order) {
        alloc_locals;

        let (storage_addr) = get_storage_address();
        let (id) = IStorageContract.get_curr_order_id(storage_addr);
        tempvar new_order: Order* = new Order(
            order_id=id, next_id=0, is_bid=is_bid, price=price, amount=amount, filled=0, datetime=datetime, owner=owner, limit_id=limit_id
        );
        IStorageContract.set_order(storage_addr, id, [new_order]);
        IStorageContract.set_curr_order_id(storage_addr, id + 1);

        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        IStorageContract.set_length(storage_addr, limit_id, length + 1);
        if (length == 0) {
            IStorageContract.set_head(storage_addr, limit_id, new_order.order_id);
            handle_revoked_refs();
            return (new_order=[new_order]);
        } else {
            let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
            let (head) = IStorageContract.get_order(storage_addr, head_id);
            let (old_tail) = locate_item_from_head(0, length - 1, head);
            tempvar old_tail_updated: Order* = new Order(
                order_id=old_tail.order_id, next_id=new_order.order_id, is_bid=old_tail.is_bid, price=old_tail.price, amount=old_tail.amount, 
                filled=old_tail.filled, datetime=old_tail.datetime, owner=old_tail.owner, limit_id=old_tail.limit_id
            );
            IStorageContract.set_order(storage_addr, old_tail.order_id, [old_tail_updated]);
            tempvar new_tail: Order* = new Order(
                order_id=new_order.order_id, next_id=0, is_bid=new_order.is_bid, price=new_order.price, amount=new_order.amount, 
                filled=new_order.filled, datetime=new_order.datetime, owner=new_order.owner, limit_id=new_order.limit_id
            );
            IStorageContract.set_order(storage_addr, new_order.order_id, [new_tail]);
            handle_revoked_refs();

            return (new_order=[new_tail]);
        }
    }

    // Remove order from head of list
    // @param limit_id : limit ID of order list being amended
    // @return del : deleted order
    func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
        alloc_locals;

        let (storage_addr) = get_storage_address();
        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        let empty_order : Order* = gen_empty_order();
        if (length == 0) {
            return (del=[empty_order]);
        }

        let (old_head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (old_head) = IStorageContract.get_order(storage_addr, old_head_id);

        if (length - 1 == 0) {
            IStorageContract.set_head(storage_addr, limit_id, 0);
            handle_revoked_refs();
        } else {
            IStorageContract.set_head(storage_addr, limit_id, old_head.next_id);
            let (new_head) = IStorageContract.get_order(storage_addr, old_head.next_id);
            tempvar new_head_updated: Order* = new Order(
                order_id=new_head.order_id, next_id=new_head.next_id, is_bid=new_head.is_bid, price=new_head.price, 
                amount=new_head.amount, filled=new_head.filled, datetime=new_head.datetime, owner=new_head.owner, 
                limit_id=new_head.limit_id
            );
            IStorageContract.set_order(storage_addr, new_head.order_id, [new_head_updated]);
            IStorageContract.set_head(storage_addr, limit_id, new_head.order_id);
            handle_revoked_refs();
        }

        IStorageContract.set_length(storage_addr, limit_id, length - 1);

        // Diagnostics
        // print_del_order(old_head, limit_id, length);

        return (del=old_head);
    } 

    // Remove order from the end of the list.
    // @param limit_id : limit ID of order list being amended
    // @return del : order deleted from list (or empty order if list is empty)
    func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
        alloc_locals;
        
        let (storage_addr) = get_storage_address();
        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        let empty_order : Order* = gen_empty_order();
        if (length == 0) {
            return (del=[empty_order]);
        }

        let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (head) = IStorageContract.get_order(storage_addr, head_id);
        let (old_tail) = locate_item_from_head(0, length - 1, head);

        if (length - 1 == 0) {
            IStorageContract.set_head(storage_addr, limit_id, 0);
            handle_revoked_refs();
        } else {
            let (limit) = IStorageContract.get_limit(storage_addr, old_tail.limit_id);
            let (prev_id) = locate_previous_item(head, [empty_order], old_tail.order_id);
            let (new_tail) = IStorageContract.get_order(storage_addr, prev_id);
            tempvar new_tail_updated: Order* = new Order(
                order_id=new_tail.order_id, next_id=0, is_bid=new_tail.is_bid, price=new_tail.price, amount=new_tail.amount, 
                filled=new_tail.filled, datetime=new_tail.datetime, owner=new_tail.owner, limit_id=new_tail.limit_id
            );
            IStorageContract.set_order(storage_addr, new_tail.order_id, [new_tail_updated]);
            handle_revoked_refs();
        }

        IStorageContract.set_length(storage_addr, limit_id, length - 1);

        return (del=old_tail);
    }

    // Update filled amount of order.
    // @param id : order ID
    // @param filled : updated filled amount of order
    func set_filled{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        order_id : felt, filled : felt
    ) {
        let (storage_addr) = get_storage_address();
        let (order) = IStorageContract.get_order(storage_addr, order_id);
        let is_valid = is_le(filled, order.amount);
        let is_incremental = is_le(order.filled, filled - 1);
        let is_positive = is_le(1, filled);
        if (is_valid + is_incremental + is_positive == 3) {
            tempvar new_order : Order* = new Order(
                order_id=order.order_id, next_id=order.next_id, is_bid=order.is_bid, price=order.price, amount=order.amount,
                filled=filled, datetime=order.datetime, owner=order.owner, limit_id=order.limit_id
            );
            IStorageContract.set_order(storage_addr, order.order_id, [new_order]);
            handle_revoked_refs();
            return ();
        } else {
            with_attr error_message("Fill amount invalid") {
                assert 1 = 0;
            } 
            handle_revoked_refs();
            return ();
        }    
    }

    // Remove order by ID.
    // @param order_id : ID of order being amended
    // @return del : deleted order (or empty order if order does not exist)
    func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (del : Order) {
        alloc_locals;
        
        let (storage_addr) = get_storage_address();
        let (removed) = IStorageContract.get_order(storage_addr, order_id);
        let empty_order : Order* = gen_empty_order();
        let is_valid = is_le(1, order_id); 
        if (is_valid == 0) {
            return (del=[empty_order]);
        }
        
        if (removed.next_id == 0) {
            let (del) = pop(removed.limit_id);
            return (del=del);
        }

        let (head_id) = IStorageContract.get_head(storage_addr, removed.limit_id);
        if (head_id == order_id) {
            let (del) = shift(removed.limit_id);
            return (del=del);
        }

        let (head) = IStorageContract.get_order(storage_addr, head_id);
        let (prev_id) = locate_previous_item(head, [empty_order], order_id);
        let (removed_prev) = IStorageContract.get_order(storage_addr, prev_id);
        tempvar updated_removed_prev: Order* = new Order(
            order_id=removed_prev.order_id, next_id=removed.next_id, is_bid=removed_prev.is_bid, price=removed_prev.price, amount=removed_prev.amount, 
            filled=removed_prev.filled, datetime=removed_prev.datetime, owner=removed_prev.owner, limit_id=removed_prev.limit_id
        ); 
        IStorageContract.set_order(storage_addr, removed_prev.order_id, [updated_removed_prev]);

        let (removed_next) = IStorageContract.get_order(storage_addr, removed.next_id);
        tempvar updated_removed_next: Order* = new Order(
            order_id=removed_next.order_id, next_id=removed_next.next_id, is_bid=removed_next.is_bid, price=removed_next.price, amount=removed_next.amount,
            filled=removed_next.filled, datetime=removed_next.datetime, owner=removed_next.owner, limit_id=removed_next.limit_id
        ); 
        IStorageContract.set_order(storage_addr, removed_next.order_id, [updated_removed_next]);

        let (length) = IStorageContract.get_length(storage_addr, removed.limit_id);
        IStorageContract.set_length(storage_addr, removed.limit_id, length - 1);

        return (del=removed);
    }

    // Get order by index.
    // func get{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt, idx : felt) -> (order : Order) {
    //     alloc_locals;
        
    //     let (storage_addr) = get_storage_address();
    //     let empty_order : Order* = gen_empty_order();
    //     let (in_range) = validate_idx(limit_id, idx);
    //     if (in_range == 0) {
    //         return (order=[empty_order]);
    //     }
    //     let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
    //     let (head) = IStorageContract.get_order(storage_addr, head_id);
    //     let (order) = locate_item_from_head(i=0, idx=idx, curr=head);
    //     return (order=order);
    // }

    // Utility function to locate previous item in linked list.
    // @dev If item is not found, returns 0
    // @param curr : order in current iteration of the list
    // @param prev : previous order in current iteration of the list
    // @param order_id : target order ID
    // @return prev_id : ID of previous order in list
    func locate_previous_item{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        curr : Order, prev : Order, order_id : felt
    ) -> (prev_id : felt) {
        if (curr.order_id == order_id) {
            return (prev_id=prev.order_id);
        }
        if (curr.next_id == 0) {
            return (prev_id=0);
        }
        let (storage_addr) = get_storage_address();
        let (next) = IStorageContract.get_order(storage_addr, curr.next_id);
        return locate_previous_item(next, curr, order_id);
    }

    // Utility function to iterate through list to find item from head element.
    // @param i : current iteration
    // @param idx : list position to be found
    // @param curr : order in current iteration of the list
    func locate_item_from_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        i : felt, idx : felt, curr : Order
    ) -> (order : Order) {
        if (i == idx) {
            return (order=curr);
        }
        let (storage_addr) = get_storage_address();
        let (next) = IStorageContract.get_order(storage_addr, curr.next_id);
        return locate_item_from_head(i + 1, idx, next);
    }

    // Utility function to check idx is not out of bounds.
    // @param idx : index to check
    // @return in_range : 1 if idx in range, 0 otherwise
    func validate_idx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        limit_id : felt, idx : felt
    ) -> (in_range : felt) {
        alloc_locals;
        
        let (storage_addr) = get_storage_address();
        let (length) = IStorageContract.get_length(storage_addr, limit_id);
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

    // Utility function to generate an empty order.
    func gen_empty_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () -> (empty_order : Order*) {
        tempvar empty_order: Order* = new Order(
            order_id=0, next_id=0, is_bid=0, price=0, amount=0, filled=0, datetime=0, owner=0, limit_id=0
        );
        return (empty_order=empty_order);
    }
}
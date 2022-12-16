%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from src.dex.structs import Order
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
    // Get tail of order queue by limit ID
    func get_tail(limit_id : felt) -> (id : felt) {
    }
    // Set head of order queue by limit ID
    func set_tail(limit_id : felt, new_id : felt) {
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
}

//
// Storage vars
//

// Stores orders in doubly linked lists.
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
        _l2_storage_contract_address
    ) {
        l2_storage_contract_address.write(_l2_storage_contract_address);
        return ();
    }

    // Set addresses of external contracts
    // @dev Can only be called by contract owner
    // @return l2_storage_contract_address : deployed contract address of L2StorageContract
    func get_storage_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    ) -> (storage_addr : felt) {
        let (storage_addr) = l2_storage_contract_address.read();
        return (storage_addr=storage_addr);
    }

    // Getter for head ID and tail ID.
    func get_head_and_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        limit_id : felt
    ) -> (head_id : felt, tail_id : felt) {
        let (storage_addr) = l2_storage_contract_address.read();
        let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (tail_id) = IStorageContract.get_tail(storage_addr, limit_id);
        return (head_id=head_id, tail_id=tail_id);
    }

    // Getter for list length.
    func get_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (len : felt) {
        let (storage_addr) = l2_storage_contract_address.read();
        let (len) = IStorageContract.get_length(storage_addr, limit_id);
        return (len=len);
    }

    // Getter for particular order.
    // @dev To be distinguished from get(), which retrieves order at particular position of a list. 
    // @param id : order ID
    // @return order : returned order
    func get_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (id : felt) -> (order : Order) {
        let (storage_addr) = l2_storage_contract_address.read();
        let (order) = IStorageContract.get_order(storage_addr, id);
        return (order=order);
    }

    // Insert new order to the list.
    // @param is_buy : 1 if buy order, 0 if sell order
    // @param price : limit price
    // @param amount : amount of order
    // @param dt : datetime of order entry
    // @param owner : owner of order
    // @param limit_id : ID of limit price corresponding to order
    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt
    ) -> (new_order : Order) {
        alloc_locals;

        let (storage_addr) = l2_storage_contract_address.read();
        let (id) = IStorageContract.get_curr_order_id(storage_addr);
        tempvar new_order: Order* = new Order(
            id=id, next_id=0, prev_id=0, is_buy=is_buy, price=price, amount=amount, filled=0, dt=dt, owner=owner, limit_id=limit_id
        );
        IStorageContract.set_order(storage_addr, id, [new_order]);
        IStorageContract.set_curr_order_id(storage_addr, id + 1);

        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        IStorageContract.set_length(storage_addr, limit_id, length + 1);
        if (length == 0) {
            IStorageContract.set_head(storage_addr, limit_id, new_order.id);
            IStorageContract.set_tail(storage_addr, limit_id, new_order.id);
            handle_revoked_refs();

            // Diagnostics
            // %{ print("Pushed order") %}
            // let (head_id) = IStorageContract.get_headstorage_addr, limit_id);
            // print_order_list(head_id, length + 1, 1);

            return (new_order=[new_order]);
        } else {
            let (tail_id) = IStorageContract.get_tail(storage_addr, limit_id);
            let (tail) = IStorageContract.get_order(storage_addr, tail_id);
            tempvar new_tail: Order* = new Order(
                id=tail.id, next_id=new_order.id, prev_id=tail.prev_id, is_buy=tail.is_buy, 
                price=tail.price, amount=tail.amount, filled=tail.filled, dt=tail.dt, owner=tail.owner, limit_id=tail.limit_id
            );
            IStorageContract.set_order(storage_addr, tail_id, [new_tail]);
            tempvar new_order_updated: Order* = new Order(
                id=new_order.id, next_id=0, prev_id=tail_id, is_buy=new_order.is_buy, 
                price=new_order.price, amount=new_order.amount, filled=new_order.filled, dt=new_order.dt, 
                owner=new_order.owner, limit_id=new_order.limit_id
            );
            IStorageContract.set_order(storage_addr, new_order.id, [new_order_updated]);
            IStorageContract.set_tail(storage_addr, limit_id, new_order.id);
            handle_revoked_refs();

            // Diagnostics
            // %{ print("Pushed order") %}
            // let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
            // print_order_list(head_id, length + 1, 1);

            return (new_order=[new_order_updated]);
        }
    }

    // Remove order from the end of the list.
    // @param limit_id : limit ID of order list being amended
    // @return del : order deleted from list (or empty order if list is empty)
    func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
        alloc_locals;
        
        let (storage_addr) = l2_storage_contract_address.read();
        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        let empty_order : Order* = gen_empty_order();
        if (length == 0) {
            return (del=[empty_order]);
        }

        let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (old_tail_id) = IStorageContract.get_tail(storage_addr, limit_id);
        let (old_tail) = IStorageContract.get_order(storage_addr, old_tail_id);

        if (length - 1 == 0) {
            IStorageContract.set_order(storage_addr, head_id, [empty_order]);
            IStorageContract.set_order(storage_addr, old_tail_id, [empty_order]);
            IStorageContract.set_head(storage_addr, limit_id, 0);
            IStorageContract.set_tail(storage_addr, limit_id, 0);
            handle_revoked_refs();
        } else {
            IStorageContract.set_tail(storage_addr, limit_id, old_tail.prev_id);
            let (new_tail) = IStorageContract.get_order(storage_addr, old_tail.prev_id);
            tempvar new_tail_updated: Order* = new Order(
                id=new_tail.id, next_id=0, prev_id=new_tail.prev_id, is_buy=new_tail.is_buy, price=new_tail.price,  
                amount=new_tail.amount, filled=new_tail.filled, dt=new_tail.dt, owner=new_tail.owner, 
                limit_id=new_tail.limit_id
            );
            IStorageContract.set_order(storage_addr, new_tail.id, [new_tail_updated]);
            handle_revoked_refs();
        }

        IStorageContract.set_length(storage_addr, limit_id, length - 1);

        // Diagnostics
        // %{ print("Deleted: ") %}
        // print_order(old_tail);
        // print_order_list(head_id, length - 1, 1);

        return (del=old_tail);
    }

    // Remove order from head of list
    // @param limit_id : limit ID of order list being amended
    // @return del : deleted order
    func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (del : Order) {
        alloc_locals;

        let (storage_addr) = l2_storage_contract_address.read();
        let (length) = IStorageContract.get_length(storage_addr, limit_id);
        let empty_order : Order* = gen_empty_order();
        if (length == 0) {
            return (del=[empty_order]);
        }

        let (old_head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (old_head) = IStorageContract.get_order(storage_addr, old_head_id);

        if (length - 1 == 0) {
            IStorageContract.set_head(storage_addr, limit_id, 0);
            IStorageContract.set_tail(storage_addr, limit_id, 0);
            handle_revoked_refs();
        } else {
            IStorageContract.set_head(storage_addr, limit_id, old_head.next_id);
            let (new_head) = IStorageContract.get_order(storage_addr, old_head.next_id);
            tempvar new_head_updated: Order* = new Order(
                id=new_head.id, next_id=new_head.next_id, prev_id=0, is_buy=new_head.is_buy, price=new_head.price, 
                amount=new_head.amount, filled=new_head.filled, dt=new_head.dt, owner=new_head.owner, 
                limit_id=new_head.limit_id
            );
            IStorageContract.set_order(storage_addr, new_head.id, [new_head_updated]);
            handle_revoked_refs();
        }

        IStorageContract.set_length(storage_addr, limit_id, length - 1);

        // Diagnostics
        // print_del_order(old_head, limit_id, length);

        return (del=old_head);
    } 

    // Retrieve order at particular position in the list.
    // @param limit_id : limit ID of order list being amended
    // @param idx : order to retrieve
    // @return order : retrieved order
    func get{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt, idx : felt) -> (order : Order) {
        alloc_locals;
        
        let (storage_addr) = l2_storage_contract_address.read();
        let empty_order : Order* = gen_empty_order();
        let (in_range) = validate_idx(limit_id, idx);
        if (in_range == 0) {
            return (order=[empty_order]);
        }

        let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
        let (head) = IStorageContract.get_order(storage_addr, head_id);
        let (tail_id) = IStorageContract.get_tail(storage_addr, limit_id);
        let (tail) = IStorageContract.get_order(storage_addr, tail_id);

        let (length) = IStorageContract.get_length(storage_addr, limit_id);
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
        let (storage_addr) = l2_storage_contract_address.read();
        let (next) = IStorageContract.get_order(storage_addr, curr.next_id);
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
        let (storage_addr) = l2_storage_contract_address.read();
        let (prev) = IStorageContract.get_order(storage_addr, curr.prev_id);
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
    //      let (storage_addr) = l2_storage_contract_address.read();
    //     let (order) = IStorageContract.get_order(storage_addr, idx);
    //     tempvar new_order : Order* = new Order(
    //         id=order.id, next_id=order.next_id, prev_id=order.prev_id, is_buy=is_buy, price=price, 
    //         amount=amount, filled=filled, dt=dt, owner=owner, limit_id=limit_id
    //     );
    //     IStorageContract.set_order(storage_addr, order.id, [new_order]);

    //     // Diagnostics
        // %{ print("Set order") %}
        // let (head_id) = IStorageContract.get_head(storage_addr, limit_id);
        // let (length) = IStorageContract.get_length(storage_addr, limit_id);
        // print_order_list(head_id, length, 1);

    //     return (success=1);
    // }

    // Update filled amount of order.
    // @param id : order ID
    // @param filled : updated filled amount of order
    // @return success : 1 if update was successful, 0 otherwise
    func set_filled{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        id : felt, filled : felt
    ) -> (success : felt) {
        let (storage_addr) = l2_storage_contract_address.read();
        let (order) = IStorageContract.get_order(storage_addr, id);
        let is_valid = is_le(filled, order.amount);
        let is_incremental = is_le(order.filled, filled - 1);
        let is_positive = is_le(1, filled);
        if (is_valid + is_incremental + is_positive == 3) {
            tempvar new_order : Order* = new Order(
                id=order.id, next_id=order.next_id, prev_id=order.prev_id, is_buy=order.is_buy, price=order.price, 
                amount=order.amount, filled=filled, dt=order.dt, owner=order.owner, limit_id=order.limit_id
            );
            IStorageContract.set_order(storage_addr, order.id, [new_order]);
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
    func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (success : felt) {
        alloc_locals;
        
        let (storage_addr) = l2_storage_contract_address.read();
        let (removed) = IStorageContract.get_order(storage_addr, order_id);
        let empty_order : Order* = gen_empty_order();
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

        let (removed_prev) = IStorageContract.get_order(storage_addr, removed.prev_id);
        tempvar updated_removed_prev: Order* = new Order(
            id=removed_prev.id, next_id=removed.next_id, prev_id=removed_prev.prev_id, is_buy=removed_prev.is_buy, 
            price=removed_prev.price, amount=removed_prev.amount, filled=removed_prev.filled, dt=removed_prev.dt, 
            owner=removed_prev.owner, limit_id=removed_prev.limit_id
        ); 
        IStorageContract.set_order(storage_addr, removed.prev_id, [updated_removed_prev]);

        let (removed_next) = IStorageContract.get_order(storage_addr, removed.next_id);
        tempvar updated_removed_next: Order* = new Order(
            id=removed_next.id, next_id=removed_next.next_id, prev_id=removed.prev_id, is_buy=removed_next.is_buy, 
            price=removed_next.price, amount=removed_next.amount, filled=removed_next.filled, dt=removed_next.dt, 
            owner=removed_next.owner, limit_id=removed_next.limit_id
        ); 
        IStorageContract.set_order(storage_addr, removed_next.id, [updated_removed_next]);

        let (length) = IStorageContract.get_length(storage_addr, removed.limit_id);
        IStorageContract.set_length(storage_addr, removed.limit_id, length - 1);

        // Diagnostics
        // %{ print("Removed order") %}
        // let (head_id) = IStorageContract.get_head(storage_addr, removed.limit_id);
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
        
        let (storage_addr) = l2_storage_contract_address.read();
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
            id=0, next_id=0, prev_id=0, is_buy=0, price=0, amount=0, filled=0, dt=0, owner=0, limit_id=0
        );
        return (empty_order=empty_order);
    }
}
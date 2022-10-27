%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from src.tree.structs import Limit
// from src.tree.utils import print_limit, print_limit_tree

// Stores details of limit prices as mapping.
@storage_var
func limits(id : felt) -> (limit : Limit) {
}

// Stores roots of binary search trees.
@storage_var
func roots(tree_id : felt) -> (id : felt) {
}

// Stores latest limit id.
@storage_var
func curr_limit_id() -> (id : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    curr_limit_id.write(1);
    return ();
}

// Getter for limit price
@external
func get_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit_id : felt) -> (limit : Limit) {
    let (limit) = limits.read(limit_id);
    return (limit=limit);
}

// Getter for lowest limit price in the tree
// @param tree_id : ID of limit tree to be searched
// @return min : node representation of lowest limit price in the tree
@external
func get_min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (tree_id : felt) -> (min : Limit) {
    alloc_locals;
    let empty_limit : Limit* = gen_empty_limit();
    let (root_id) = roots.read(tree_id);
    if (root_id == 0) {
        return (min=[empty_limit]);
    }
    let (root) = limits.read(root_id);
    let (min, _) = find_min(root, [empty_limit]);
    return (min=min);
}

// Getter for highest limit price in the tree
// @param tree_id : ID of limit tree to be searched
// @return max : node representation of highest limit price in the tree
@external
func get_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (tree_id : felt) -> (max : Limit) {
    alloc_locals;
    let (root_id) = roots.read(tree_id);
    let empty_limit: Limit* = gen_empty_limit();
    if (root_id == 0) {
        return (max=[empty_limit]);
    }
    let (root) = limits.read(root_id);
    let (max) = find_max(curr=root);
    return (max=max);
}

// Insert new limit price into BST.
// @param price : new limit price to be inserted
// @param tree_id : ID of tree currently being traversed
// @param tree_id : ID of current market
// @return success : 1 if insertion was successful, 0 otherwise
@external
func insert{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt, market_id : felt) -> (new_limit : Limit
) {
    alloc_locals;

    let (id) = curr_limit_id.read();
    tempvar new_limit: Limit* = new Limit(
        id=id, left_id=0, right_id=0, price=price, total_vol=0, length=0, head_id=0, tail_id=0, tree_id=tree_id, market_id=market_id
    );
    limits.write(id, [new_limit]);
    curr_limit_id.write(id + 1);
    
    let (root_id) = roots.read(tree_id);
    if (root_id == 0) {
        roots.write(tree_id, new_limit.id);

        // Diagnostics
        // let (new_root) = limits.read(new_limit.id);
        // print_limit_tree(new_root, 1);

        return (new_limit=[new_limit]);
    }
    let (root) = limits.read(root_id);
    let (inserted) = insert_helper(price, root, new_limit.id, tree_id, market_id);

    // Diagnostics
    // let (new_root) = limits.read(root_id);
    // print_limit_tree(new_root, 1);

    return (new_limit=inserted);
}

// Recursively finds correct position for new limit price in BST and inserts it. 
// @param price : new price to be inserted
// @param curr : current node in traversal of the BST
// @param new_limit_id : id of new node to be inserted into the BST
// @param tree_id : ID of tree currently being traversed
// @param market_id : ID of current market
// @return success : 1 if insertion was successful, 0 otherwise
func insert_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, curr : Limit, new_limit_id : felt, tree_id : felt, market_id : felt) -> (new_limit : Limit
) {
    alloc_locals;
    let (root_id) = roots.read(tree_id);
    let (root) = limits.read(root_id);

    let greater_than = is_le(curr.price, price - 1);
    let less_than = is_le(price, curr.price - 1);

    if (greater_than == 1) {
        if (curr.right_id == 0) {
            tempvar new_curr: Limit* = new Limit(
                id=curr.id, left_id=curr.left_id, right_id=new_limit_id, price=curr.price, total_vol=curr.total_vol, 
                length=curr.length, head_id=curr.head_id, tail_id=curr.tail_id, tree_id=tree_id, market_id=curr.market_id
            );
            limits.write(curr.id, [new_curr]);
            handle_revoked_refs();
            return (new_limit=[new_curr]);
        } else {
            let (curr_right) = limits.read(curr.right_id);
            handle_revoked_refs();
            return insert_helper(price, curr_right, new_limit_id, tree_id, market_id);
        }
    } else {
        handle_revoked_refs(); 
    }
    
    if (less_than == 1) {
        if (curr.left_id == 0) {
            tempvar new_curr: Limit* = new Limit(
                id=curr.id, left_id=new_limit_id, right_id=curr.right_id, price=curr.price, total_vol=curr.total_vol, 
                length=curr.length, head_id=curr.head_id, tail_id=curr.tail_id, tree_id=tree_id, market_id=curr.market_id
            );
            limits.write(curr.id, [new_curr]);
            handle_revoked_refs();
            return (new_limit=[new_curr]);
        } else {
            let (curr_left) = limits.read(curr.left_id);
            handle_revoked_refs();
            return insert_helper(price, curr_left, new_limit_id, tree_id, market_id);
        }
    } else {
        handle_revoked_refs(); 
    }

    let empty_limit: Limit* = gen_empty_limit();
    return (new_limit=[empty_limit]);
}

// Find a limit price in binary search tree.
// @param price : limit price to be found
// @param tree_id : ID of tree currently being traversed
// @return limit : retrieved limit price (or empty limit if not found)
// @return parent : parent of retrieved limit price (or empty limit if not found)
@view
func find{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt) -> (limit : Limit, parent : Limit
) {
    alloc_locals;
    let (root_id) = roots.read(tree_id);
    let empty_limit: Limit* = gen_empty_limit();
    if (root_id == 0) {
        return (limit=[empty_limit], parent=[empty_limit]);
    }
    let (root) = limits.read(root_id);
    return find_helper(tree_id=tree_id, price=price, curr=root, parent=[empty_limit]);
}

// Recursively traverses BST to find limit price.
// @param tree_id : ID of tree currently being traversed
// @param price : limit price to be found
// @param curr : current node in traversal of the BST
// @param parent : parent of current node in traversal of the BST
// @return limit : retrieved limit price (or empty limit if not found)
// @return parent : parent of retrieved limit price (or empty limit if not found)
func find_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt, price : felt, curr : Limit, parent : Limit) -> (limit : Limit, parent : Limit
) {
    alloc_locals;

    if (curr.id == 0) {
        let empty_limit: Limit* = gen_empty_limit();
        handle_revoked_refs();
        return (limit=[empty_limit], parent=[empty_limit]);
    } else {
        handle_revoked_refs();
    }    

    let greater_than = is_le(curr.price, price - 1);
    if (greater_than == 1) {
        let (curr_right) = limits.read(curr.right_id);
        handle_revoked_refs();
        return find_helper(tree_id, price, curr_right, curr);
    } else {
        handle_revoked_refs();
    }

    let less_than = is_le(price, curr.price - 1);
    if (less_than == 1) {
        let (curr_left) = limits.read(curr.left_id);
        handle_revoked_refs();
        return find_helper(tree_id, price, curr_left, curr);
    } else {
        handle_revoked_refs();
    }

    return (limit=curr, parent=parent);
}

// Deletes limit price from BST
// @param price : limit price to be deleted
// @param tree_id : ID of tree currently being traversed
// @param market_id : ID of current market
// @return del : node representation of deleted limit price
@external
func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    price : felt, tree_id : felt, market_id : felt) -> (del : Limit
) {
    alloc_locals;

    let empty_limit: Limit* = gen_empty_limit();
    let (root_id) = roots.read(tree_id);
    if (root_id == 0) {
        handle_revoked_refs();
        return (del=[empty_limit]);
    } else {
        handle_revoked_refs();
    }

    let (limit, parent) = find(price, tree_id);
    if (limit.id == 0) {
        return (del=[empty_limit]);
    }

    if (limit.left_id == 0) {
        if (limit.right_id == 0) {
            update_parent(tree_id=tree_id, parent=parent, limit=limit, new_id=0);
            handle_revoked_refs();
        } else {
            update_parent(tree_id=tree_id, parent=parent, limit=limit, new_id=limit.right_id);
            handle_revoked_refs();
        }
    } else {
        if (limit.right_id == 0) {
            update_parent(tree_id=tree_id, parent=parent, limit=limit, new_id=limit.left_id);
            handle_revoked_refs();
        } else {
            let (right) = limits.read(limit.right_id);
            let (successor, successor_parent) = find_min(right, limit);

            update_parent(tree_id=tree_id, parent=parent, limit=limit, new_id=successor.id);
            if (limit.left_id == successor.id) {                
                update_pointers(successor, 0, limit.right_id);
            } else {
                if (limit.right_id == successor.id) {
                    update_pointers(successor, limit.left_id, 0);                    
                } else {
                    update_pointers(successor, limit.left_id, limit.right_id);
                }   
            }
            update_parent(tree_id=tree_id, parent=successor_parent, limit=successor, new_id=0);
        }
    }

    // Diagnostics
    // let (root_id) = roots.read(tree_id);
    // let (new_root) = limits.read(root_id);
    // print_limit_tree(new_root, 1);

    return (del=limit);
}

// Helper function to update left or right child of parent.
// @param tree_id : ID of tree currently being traversed
// @param parent : parent node to update
// @param limit : current node to be replaced
// @param new_id : id of the new node that parent should point to
func update_parent{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt, parent : Limit, limit : Limit, new_id : felt
) {
    alloc_locals;

    if (parent.id == 0) {
        roots.write(tree_id, new_id);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }

    if (parent.left_id == limit.id) {
        update_pointers(parent, new_id, parent.right_id);
    } else {
        update_pointers(parent, parent.left_id, new_id);
    }

    return ();
}

// Helper function to update left and right pointer of a node.
// @param node : current node to update
// @param left_id : id of new left child
// @param right_id : id of new right child
func update_pointers{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    node : Limit, left_id : felt, right_id : felt
) {
    tempvar new_node: Limit* = new Limit(
        id=node.id, left_id=left_id, right_id=right_id, price=node.price, total_vol=node.total_vol, 
        length=node.length, head_id=node.head_id, tail_id=node.tail_id, tree_id=node.tree_id, market_id=node.market_id
    );
    limits.write(node.id, [new_node]);
    handle_revoked_refs();
    return ();
}

// Helper function to find the lowest limit price within a tree
// @param root : root of tree to be searched
// @param parent : parent node of root
// @return min : node representation of lowest limit price
// @return parent : parent node of lowest limit price
func find_min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    curr : Limit, parent : Limit) -> (min : Limit, parent : Limit
) {
    if (curr.left_id == 0) {
        return (min=curr, parent=parent);
    }
    let (left) = limits.read(curr.left_id);
    return find_min(curr=left, parent=curr);
}

// Helper function to find the highest limit price within a tree
// @param root : root of tree to be searched
// @return min : node representation of highest limit price
func find_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (curr : Limit) -> (max : Limit) {
    if (curr.right_id == 0) {
        return (max=curr);
    }
    let (right) = limits.read(curr.right_id);
    return find_max(curr=right);
}

// Setter function to update details of limit price
// @param limit : ID of limit price to update
// @param new_vol : new volume
// @return success : 1 if successfully inserted, 0 otherwise
@external
func update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, total_vol : felt, length : felt, head_id : felt, tail_id : felt) -> (success : felt
) {
    if (limit_id == 0) {
        return (success=0);
    }
    let (limit) = limits.read(limit_id);
    tempvar new_limit: Limit* = new Limit(
        id=limit.id, left_id=limit.left_id, right_id=limit.right_id, price=limit.price, total_vol=total_vol, 
        length=length, head_id=head_id, tail_id=tail_id, tree_id=limit.tree_id, market_id=limit.market_id
    );
    limits.write(limit_id, [new_limit]);
    return (success=1);
}

func gen_empty_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () -> (empty_limit : Limit*) {
    tempvar empty_limit: Limit* = new Limit(
        id=0, left_id=0, right_id=0, price=0, total_vol=0, length=0, head_id=0, tail_id=0, tree_id=0, market_id=0
    );
    return (empty_limit=empty_limit);
}

// Utility function to handle revoked implicit references.
func handle_revoked_refs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
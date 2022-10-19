%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le

// Data structure representing a limit price.
struct Limit {
    id : felt,
    left_id : felt,
    right_id : felt,
    price : felt,
    total_vol : felt,
    order_len : felt,
    order_head : felt, 
    order_tail : felt,
    tree_id : felt,
}

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
func curr_id() -> (id : felt) {
}

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} () {
    curr_id.write(1);
    return ();
}

// Insert new limit price into BST.
// @param price : new limit price to be inserted
// @return success : 1 if insertion was successful, 0 otherwise
func insert{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (price : felt, tree_id : felt) -> (success : felt) {
    alloc_locals;

    let (id) = curr_id.read();
    tempvar new_limit: Limit* = new Limit(
        id=id, left_id=0, right_id=0, price=price, total_vol=0, order_len=0, order_head=0, order_tail=0, tree_id=tree_id
    );
    limits.write(id, [new_limit]);
    curr_id.write(id + 1);
    
    let (root_id) = roots.read(tree_id);
    if (root_id == 0) {
        roots.write(tree_id, new_limit.id);

        // Diagnostics
        let (new_root) = limits.read(new_limit.id);
        print_dfs_in_order(new_root, 1);

        return (success=1);
    }
    let (root) = limits.read(root_id);
    let (success) = insert_helper(tree_id, price, root, new_limit.id);

    // Diagnostics
    let (new_root) = limits.read(root_id);
    print_dfs_in_order(new_root, 1);

    return (success=success);
}

// Recursively finds correct position for new limit price in BST and inserts it. 
// @param tree_id : ID of tree currently being traversed
// @param price : new price to be inserted
// @param curr : current node in traversal of the BST
// @param new_limit : id of new node to be inserted into the BST
// @return success : 1 if insertion was successful, 0 otherwise
func insert_helper{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (tree_id : felt, price : felt, curr : Limit, new_limit_id : felt) -> (success : felt) {
    alloc_locals;
    let (root_id) = roots.read(tree_id);
    let (root) = limits.read(root_id);

    let greater_than = is_le(curr.price, price - 1);
    let less_than = is_le(price, curr.price - 1);

    if (greater_than == 1) {
        if (curr.right_id == 0) {
            tempvar new_curr: Limit* = new Limit(
                id=curr.id, left_id=curr.left_id, right_id=new_limit_id, price=curr.price, total_vol=curr.total_vol, 
                order_len=curr.order_len, order_head=curr.order_head, order_tail=curr.order_tail, tree_id=tree_id
            );
            limits.write(curr.id, [new_curr]);
            handle_revoked_refs();
            return (success=1);
        } else {
            let (curr_right) = limits.read(curr.right_id);
            handle_revoked_refs();
            return insert_helper(tree_id, price, curr_right, new_limit_id);
        }
    } else {
        handle_revoked_refs(); 
    }
    
    if (less_than == 1) {
        if (curr.left_id == 0) {
            tempvar new_curr: Limit* = new Limit(
                id=curr.id, left_id=new_limit_id, right_id=curr.right_id, price=curr.price, total_vol=curr.total_vol, 
                order_len=curr.order_len, order_head=curr.order_head, order_tail=curr.order_tail, tree_id=tree_id
            );
            limits.write(curr.id, [new_curr]);
            handle_revoked_refs();
            return (success=1);
        } else {
            let (curr_left) = limits.read(curr.left_id);
            handle_revoked_refs();
            return insert_helper(tree_id, price, curr_left, new_limit_id);
        }
    } else {
        handle_revoked_refs(); 
    }

    return (success=0);
}

// Find a limit price in binary search tree.
// @param price : limit price to be found
// @param tree_id : ID of tree currently being traversed
// @return limit : retrieved limit price (or empty limit if not found)
// @return parent : parent of retrieved limit price (or empty limit if not found)
func find{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (price : felt, tree_id : felt) -> (limit : Limit, parent : Limit) {    
    let (root_id) = roots.read(tree_id);
    let (root) = limits.read(root_id);
    tempvar empty_limit: Limit* = new Limit(
        id=0, left_id=0, right_id=0, price=0, total_vol=0, order_len=0, order_head=0, order_tail=0, tree_id=0
    );
    if (root_id == 0) {
        return (limit=[empty_limit], parent=[empty_limit]);
    }
    return find_helper(tree_id=tree_id, price=price, curr=root, parent=[empty_limit]);
}

// Recursively traverses BST to find limit price.
// @param tree_id : ID of tree currently being traversed
// @param price : limit price to be found
// @param curr : current node in traversal of the BST
// @param parent : parent of current node in traversal of the BST
// @return limit : retrieved limit price (or empty limit if not found)
// @return parent : parent of retrieved limit price (or empty limit if not found)
func find_helper{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (tree_id : felt, price : felt, curr : Limit, parent : Limit) -> (limit : Limit, parent : Limit) {
    alloc_locals;

    if (curr.id == 0) {
        tempvar empty_limit: Limit* = new Limit(
            id=0, left_id=0, right_id=0, price=0, total_vol=0, order_len=0, order_head=0, order_tail=0, tree_id=0
        );
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
// @param tree_id : ID of tree currently being traversed
// @param price : limit price to be deleted
// @return del : node representation of deleted limit price
func delete{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (price : felt, tree_id : felt) -> (del : Limit) {
    alloc_locals;

    tempvar empty_limit: Limit* = new Limit(
        id=0, left_id=0, right_id=0, price=0, total_vol=0, order_len=0, order_head=0, order_tail=0, tree_id=0
    );

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
    let (root_id) = roots.read(tree_id);
    let (new_root) = limits.read(root_id);
    print_dfs_in_order(new_root, 1);

    return (del=limit);
}

// Helper function to update left or right child of parent.
// @param parent : parent node to update
// @param node : current node to be replaced
// @param new_id : id of the new node that parent should point to
func update_parent{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (tree_id : felt, parent : Limit, limit : Limit, new_id : felt) {
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
func update_pointers{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (node : Limit, left_id : felt, right_id : felt) {
    tempvar new_node: Limit* = new Limit(
        id=node.id, left_id=left_id, right_id=right_id, price=node.price, total_vol=node.total_vol, 
        order_len=node.order_len, order_head=node.order_head, order_tail=node.order_tail, tree_id=node.tree_id
    );
    limits.write(node.id, [new_node]);
    handle_revoked_refs();
    return ();
}

// Helper function to find the lowest limit price within a tree
// @param root : root of tree to be searched
// @return min : node representation of lowest limit price
// @return parent : parent node of lowest limit price
func find_min{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (root : Limit, parent : Limit) -> (min : Limit, parent : Limit) {
    if (root.left_id == 0) {
        return (min=root, parent=parent);
    }
    let (left) = limits.read(root.left_id);
    return find_min(left, root);
}

// Utility function to handle printing of tree nodes in left to right order.
func print_dfs_in_order{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (root : Limit, iter : felt) {
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
        print_dfs_in_order(left, 0);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
    %{ 
        print("    ", end="")
        print("id: {}, left_id: {}, right_id: {}, price: {}, total_vol: {}, order_len: {}, order_head: {}, order_tail: {}, tree_id: {}".format(ids.root.id, ids.root.left_id, ids.root.right_id, ids.root.price, ids.root.total_vol, ids.root.order_len, ids.root.order_head, ids.root.order_tail, ids.root.tree_id))
    %}
    if (right_exists == 1) {
        let (right) = limits.read(root.right_id);
        print_dfs_in_order(right, 0);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
    return ();
}

func print_limit_order{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (limit : Limit) {
    %{ 
        print("id: {}, left_id: {}, right_id: {}, price: {}, total_vol: {}, order_len: {}, order_head: {}, order_tail: {}, tree_id: {}".format(ids.limit.id, ids.limit.left_id, ids.limit.right_id, ids.limit.price, ids.limit.total_vol, ids.limit.order_len, ids.limit.order_head, ids.limit.order_tail, ids.limit.tree_id)) 
    %}
    return ();
}

// Utility function to handle revoked implicit references.
// @dev tempvars used to handle revoked implict references
func handle_revoked_refs{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
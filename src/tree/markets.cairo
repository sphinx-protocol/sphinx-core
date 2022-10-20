%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from src.tree.limits import Limit, limits, print_limit_order, print_dfs_in_order
from src.tree.orders import Order, print_list

struct Market {
    id : felt,
    bid_tree_id : felt,
    ask_tree_id : felt,
    lowest_ask : felt,
    highest_bid : felt,
    base_asset : felt,
    quote_asset : felt,
    controller : felt,
}

@contract_interface
namespace IOrdersContract {
    // Getter for head ID.
    func get_head(limit_id : felt) -> (head_id : felt) {
    }
     // Getter for tail ID.
    func get_tail(limit_id : felt) -> (tail_id : felt) {
    }
    // Getter for list length.
    func get_length(limit_id : felt) -> (len : felt) {
    }
    // Insert new order to the list.
    func push(is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt) {
    }
    // Remove order from head of list
    func shift(limit_id : felt) -> (del : Order) {
    } 
    // Retrieve order at particular position in the list.
    func get(limit_id : felt, idx : felt) -> (order : Order) {
    }
    // Update order at particular position in the list.
    func set(limit_id : felt, idx : felt, is_buy : felt, price : felt, amount : felt, filled : felt, dt : felt, owner : felt) -> 
        (success : felt) {
    }
    // Remove value at particular position in the list.
    func remove(limit_id : felt, idx : felt) -> (del : Order) {
    }
}

@contract_interface
namespace ILimitsContract {
    // Getter for limit price
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
    // Insert new limit price into BST.
    func insert(price : felt, tree_id : felt, market_id : felt) -> (new_limit : Limit) {
    }
    // Find a limit price in binary search tree.
    func find(price : felt, tree_id : felt) -> (limit : Limit, parent : Limit) {    
    }
    // Deletes limit price from BST
    func delete(price : felt, tree_id : felt) -> (del : Limit) {
    }
    // Setter function to update details of a limit price.
    func update(limit_id : felt, total_vol : felt, order_len : felt, order_head : felt, order_tail : felt ) -> (success : felt) {
    }   
}

// Stores active markets.
@storage_var
func markets(id : felt) -> (market : Market) {
}

// Stores pointers to bid and ask limit trees.
@storage_var
func trees(id : felt) -> (root_id : felt) {
}

// Stores latest market id.
@storage_var
func curr_market_id() -> (id : felt) {
}

// Stores latest tree id.
@storage_var
func curr_tree_id() -> (id : felt) {
}

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} () {
    curr_market_id.write(1);
    curr_tree_id.write(1);
    return ();
}

// Create a new market for exchanging between two assets.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param controller : felt representation of account that controls the market
func create_market{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    alloc_locals;
    
    let (market_id) = curr_market_id.read();
    let (tree_id) = curr_tree_id.read();
    let (caller) = get_caller_address();
    
    tempvar new_market: Market* = new Market(
        id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask=0, highest_bid=0, 
        base_asset=base_asset, quote_asset=quote_asset, controller=caller
    );
    markets.write(market_id, [new_market]);

    curr_market_id.write(market_id + 1);
    curr_tree_id.write(tree_id + 2);

    return (new_market=[new_market]);
}

// Submit a new bid (limit buy order) to a given market.
// @param orders_addr : deployed address of IOrdersContract [TEMPORARY - FOR TESTING ONLY]
// @param limits_addr : deployed address of ILimitsContract [TEMPORARY - FOR TESTING ONLY]
// @param market_id : ID of market
// @param price : limit price of order
// @param amount : order size in number of tokens
func create_bid{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (orders_addr : felt, limits_addr : felt, market_id : felt, price : felt, amount : felt) {
    alloc_locals;

    let (market) = markets.read(market_id);
    if (market.id == 0) {
        return ();
    }
    if (market.highest_bid == 0) {
        create_bid_helper(orders_addr, limits_addr, market, 1, price, amount, market.bid_tree_id);
        handle_revoked_refs();
    } else {
        let is_limit = is_le(price, market.highest_bid - 1);
        create_bid_helper(orders_addr, limits_addr, market, is_limit, price, amount, market.bid_tree_id);
        handle_revoked_refs();
    }    

    return ();
}

func create_bid_helper{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (orders_addr : felt, limits_addr : felt, market : Market, is_limit : felt, price : felt, amount : felt, tree_id : felt) {
    alloc_locals;

    let (caller) = get_caller_address();
    let (dt) = get_block_timestamp();

    if (is_limit == 0) {
        // buy();
        handle_revoked_refs();
        return ();
    } else {
        let (limit, _) = ILimitsContract.find(limits_addr, price, tree_id);
        if (limit.id == 0) {
            let (new_limit) = ILimitsContract.insert(limits_addr, price, tree_id, market.id);
            let success = is_le(1, new_limit.id);
            assert success = 1;
            IOrdersContract.push(orders_addr, 1, price, amount, dt, caller, new_limit.id);                
            let (new_head) = IOrdersContract.get_head(orders_addr, new_limit.id);
            let (new_tail) = IOrdersContract.get_tail(orders_addr, new_limit.id);
            let (update_success) = ILimitsContract.update(limits_addr, new_limit.id, new_limit.total_vol + amount, new_limit.order_len + 1, new_head, new_tail);
            assert update_success = 1;
            handle_revoked_refs();       
        } else {
            IOrdersContract.push(orders_addr, 1, price, amount, dt, caller, limit.id);
            let (new_head) = IOrdersContract.get_head(orders_addr, market.bid_tree_id);
            let (new_tail) = IOrdersContract.get_tail(orders_addr, market.bid_tree_id);
            let (limit) = ILimitsContract.get_limit(limits_addr, market.bid_tree_id);
            let (update_success) = ILimitsContract.update(limits_addr, limit.id, limit.total_vol + amount, limit.order_len + 1, new_head, new_tail);
            assert update_success = 1;
            handle_revoked_refs();
        }
    }    

    return ();
}

// func buy{
//     syscall_ptr: felt*,
//     pedersen_ptr: HashBuiltin*,
//     range_check_ptr,
// } (orders_addr : felt, limits_addr : felt, market_id : felt, is_buy : felt, max_price : felt, amount : felt) {
//     // Get head of order book
//     // If 

// }

func print_market{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
} (market : Market) {
    %{ 
        print("id: {}, bid_tree_id: {}, ask_tree_id: {}, lowest_ask: {}, highest_bid: {}, base_asset: {}, quote_asset: {}, controller: {}".format(ids.market.id, ids.market.bid_tree_id, ids.market.ask_tree_id, ids.market.lowest_ask, ids.market.highest_bid, ids.market.base_asset, ids.market.quote_asset, ids.market.controller)) 
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
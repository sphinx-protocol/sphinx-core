%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from src.tree.limits import Limit, limits, print_limit_order, print_dfs_in_order
from src.tree.orders import Order, print_list
from starkware.cairo.common.alloc import alloc

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
    // Getter for head ID and tail ID.
    func get_head_and_tail(limit_id : felt) -> (head_id : felt, tail_id : felt) {
    }
    // Getter for list length.
    func get_length(limit_id : felt) -> (len : felt) {
    }
    // Getter for particular order.
    func get_order(id : felt) -> (order : Order) {
    }
    // Insert new order to the list.
    func push(is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt) -> (new_order : Order) {
    }
    // Remove order from head of list
    func shift(limit_id : felt) -> (del : Order) {
    } 
    // Retrieve order at particular position in the list.
    func get(limit_id : felt, idx : felt) -> (order : Order) {
    }
    // Update order at particular position in the list.
    func set(id : felt, is_buy : felt, price : felt, amount : felt, filled : felt, dt : felt, owner : felt) -> 
        (success : felt) {
    }
    // Update filled amount of order.
    func set_filled(id : felt, filled : felt) -> (success : felt) {  
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
    // Getter for lowest limit price within tree
    func get_min(tree_id : felt) -> (min : Limit) {
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
    func delete(price : felt, tree_id : felt) -> (del : Limit) {
    }
    // Setter function to update details of a limit price.
    func update(limit_id : felt, total_vol : felt, order_len : felt, order_head : felt, order_tail : felt ) -> (success : felt) {
    }   
}

@contract_interface
namespace IUsersContract {
    // Getter for user balances
    func get_balance(user : felt, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // Setter for user balances
    func set_balance(user : felt, asset : felt, in_account : felt, new_amount : felt) {
    }
    // Transfer balance from one user to another.
    func transfer_balance(sender : felt, recipient : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer account balance to order balance.
    func transfer_to_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer order balance to account balance.
    func transfer_from_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Fill an open order.
    func fill_order(buyer : felt, seller : felt, base_asset : felt, quote_asset : felt, amount : felt, price : felt) -> (success : felt) {
    }
}

// Stores active markets.
@storage_var
func markets(id : felt) -> (market : Market) {
}

// Stores on-chain mapping of asset addresses to market id.
@storage_var
func market_ids(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
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

// Emit create market event.
@event
func log_create_market(id : felt, bid_tree_id : felt, ask_tree_id : felt, lowest_ask : felt, highest_bid : felt, base_asset : felt, quote_asset : felt, controller : felt) {
}

// Emit create new bid.
@event
func log_create_bid(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt) {
}

// Emit offer filled.
@event
func log_offer_filled(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, buyer : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, total_filled : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    curr_market_id.write(1);
    curr_tree_id.write(1);
    return ();
}

// Create a new market for exchanging between two assets.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param controller : felt representation of account that controls the market
func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} 
    (base_asset : felt, quote_asset : felt) -> (new_market : Market) 
{
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
    market_ids.write(base_asset, quote_asset, market_id + 1);

    log_create_market.emit(
        id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask=0, highest_bid=0, 
        base_asset=base_asset, quote_asset=quote_asset, controller=caller
    );

    return (new_market=[new_market]);
}

// Update inside quote of market.
func update_inside_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} 
    (market_id : felt, lowest_ask : felt, highest_bid : felt) -> (success : felt) 
{
    let (market) = markets.read(market_id);
    if (market.id == 0) {
        return (success=0);
    }
    tempvar new_market: Market* = new Market(
        id=market_id, bid_tree_id=market.bid_tree_id, ask_tree_id=market.ask_tree_id, lowest_ask=lowest_ask, 
        highest_bid=highest_bid, base_asset=market.base_asset, quote_asset=market.quote_asset, controller=market.controller
    );
    markets.write(market_id, [new_market]);
    return (success=1);
}

// Submit a new bid (limit buy order) to a given market.
// @param orders_addr : deployed address of IOrdersContract [TEMPORARY - FOR TESTING ONLY]
// @param limits_addr : deployed address of ILimitsContract [TEMPORARY - FOR TESTING ONLY]
// @param balances_addr : deployed address of IUsersContract [TEMPORARY - FOR TESTING ONLY]
// @param market_id : ID of market
// @param price : limit price of order
// @param amount : order size in number of tokens
// @return success : 1 if successfully created bid, 0 otherwise
func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} 
    (orders_addr : felt, limits_addr : felt, balances_addr : felt, market_id : felt, price : felt, amount : felt)
        ->
    (success : felt) 
{
    alloc_locals;

    let (market) = markets.read(market_id);
    if (market.id == 0) {
        return (success=0);
    }
    if (market.lowest_ask == 0) {
        handle_revoked_refs();
        let (success) = create_bid_helper(orders_addr, limits_addr, balances_addr, market, 1, price, amount, market.bid_tree_id);
        return (success=success);
    } else {
        let (lowest_ask) = IOrdersContract.get_order(orders_addr, market.lowest_ask);
        let is_limit = is_le(price, lowest_ask.price - 1);
        handle_revoked_refs();
        let (success) = create_bid_helper(orders_addr, limits_addr, balances_addr, market, is_limit, price, amount, market.bid_tree_id);
        return (success=success);
    }
}

func create_bid_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}
    (orders_addr : felt, limits_addr : felt, balances_addr : felt, market : Market, is_limit : felt, price : felt, amount : felt, tree_id : felt) 
        -> 
    (success : felt) 
{
    alloc_locals;
    let (caller) = get_caller_address();
    let (account_balance) = IUsersContract.get_balance(balances_addr, caller, market.base_asset, 1);
    let balance_sufficient = is_le(amount, account_balance);
    if (balance_sufficient == 0) {
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    if (is_limit == 0) {
        // buy();
        handle_revoked_refs();
    } else {
        let (limit, _) = ILimitsContract.find(limits_addr, price, tree_id);
        let (dt) = get_block_timestamp();
        if (limit.id == 0) {
            let (new_limit) = ILimitsContract.insert(limits_addr, price, tree_id, market.id);
            let success = is_le(1, new_limit.id);
            assert success = 1;
            
            let (new_order) = IOrdersContract.push(orders_addr, 1, price, amount, dt, caller, new_limit.id);
            let (new_head, new_tail) = IOrdersContract.get_head_and_tail(orders_addr, market.bid_tree_id);
            let (update_limit_success) = ILimitsContract.update(limits_addr, new_limit.id, amount, 1, new_head, new_tail);
            assert update_limit_success = 1;

            let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_order.id);
            assert update_market_success = 1;

            log_create_bid.emit(id=new_order.id, limit_id=new_limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, amount=amount);
            handle_revoked_refs();       
        } else {
            let (new_order) = IOrdersContract.push(orders_addr, 1, price, amount, dt, caller, limit.id);
            let (new_head, new_tail) = IOrdersContract.get_head_and_tail(orders_addr, market.bid_tree_id);
            let (update_limit_success) = ILimitsContract.update(limits_addr, limit.id, limit.total_vol + amount, limit.order_len + 1, new_head, new_tail);
            assert update_limit_success = 1;

            let (highest_bid) = IOrdersContract.get_order(orders_addr, market.highest_bid);
            let is_highest_bid = is_le(highest_bid.price, price - 1);
            if (is_highest_bid == 1) {
                let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_order.id);
                assert update_market_success = 1;
                handle_revoked_refs();
            } else {
                handle_revoked_refs();
            }
            log_create_bid.emit(id=new_order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, amount=amount);
            handle_revoked_refs();
        }
        let (update_balance_success) = IUsersContract.transfer_to_order(balances_addr, caller, market.base_asset, amount);
        assert update_balance_success = 1;
        handle_revoked_refs();
    }
    return (success=1);
}

func buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}
    (orders_addr : felt, limits_addr : felt, balances_addr : felt, market_id : felt, is_buy : felt, max_price : felt, amount : felt) 
        -> 
    (success : felt)
{
    alloc_locals;

    let (caller) = get_caller_address();
    let (market) = markets.read(market_id);
    if (market.id == 0) {
        return (success=0);
    }
    let (lowest_ask) = IOrdersContract.get_order(orders_addr, market.lowest_ask);
    let (base_amount, _) = unsigned_div_rem(amount, lowest_ask.price);
    let (account_balance) = IUsersContract.get_balance(caller, market.base_asset, 1);
    let is_sufficient = is_le(base_amount, account_balance);
    let is_positive = is_le(1, amount);

    if ((is_sufficient - 1) * (is_positive - 1) == 0) {
        handle_revoked_refs();
        return (success=0)
    } else {
        handle_revoked_refs();
    }

    let is_below_max_price = is_le(lowest_ask.price, max_price);
    let is_partial_fill = is_le(amount, lowest_ask.amount - lowest_ask.filled - 1);
    if (is_below_max_price == 1) {
        let (dt) = get_block_timestamp();
        if (is_partial_fill == 1) {
            // Partial fill of order
            IOrdersContract.set_filled(orders_addr, lowest_ask.id, amount);
            let (success) = IUsersContract.fill_order(balances_addr, caller, lowest_ask.owner, market.base_asset, market.quote_asset, amount, lowest_ask.price);
            assert success = 1;

            log_offer_filled.emit(id=lowest_ask.id, limit_id=market.ask_limit_tree, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=lowest_ask.filled + amount);
            handle_revoked_refs();
            return (success=1)
        } else {
            // Full fill of order
            IOrdersContract.set_filled(orders_addr, lowest_ask.id, lowest_ask.amount);
            IOrdersContract.shift(orders_addr, market.ask_tree_id);
            let (limit) = ILimitsContract.get_limit(market.ask_tree_id);
            let (new_head, new_tail) = IOrdersContract.get_head_and_tail(orders_addr, market.ask_tree_id);
            let (update_limit_success) = ILimitsContract.update(limit.id, limit.total_vol - lowest_ask.amount + lowest_ask.filled, limit.order_len - 1, new_head, new_tail);                
            assert update_limit_success = 1;

            if (new_head.id == 0) {
                ILimitsContract.delete(lowest_ask.price, market.ask_tree_id, market.id);
                let (next_limit) = ILimitsContract.get_min(market.ask_tree_id);
                let (next_head, _) = IOrdersContract.get_head_and_tail(orders_addr, next_limit);
                let (update_market_success) = update_inside_quote(market.id, next_head.id, market.highest_bid);
                assert update_market_success = 1;
                handle_revoked_refs();
            } else {
                let (update_market_success) = update_inside_quote(market.id, new_head.id, market.highest_bid);
                assert update_market_success = 1;
                handle_revoked_refs();
            }
            let (update_account_balance_success) = IUsersContract.fill_order(balances_addr, caller, lowest_ask.owner, market.base_asset, market.quote_asset, lowest_ask.amount, lowest_ask.price);
            assert = update_account_balance_success;

            log_offer_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=amount);
            
            handle_revoked_refs();
            buy(orders_addr, limits_addr, balances_addr, market_id, is_buy, max_price, amount - lowest_ask.amount); 
            return (success=1)
        }
    } else {
        create_bid(orders_addr, limits_addr, balances_addr, market_id, price, amount);
        return (success=1)
    }
}

func print_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (market : Market) {
    %{ 
        print("id: {}, bid_tree_id: {}, ask_tree_id: {}, lowest_ask: {}, highest_bid: {}, base_asset: {}, quote_asset: {}, controller: {}".format(ids.market.id, ids.market.bid_tree_id, ids.market.ask_tree_id, ids.market.lowest_ask, ids.market.highest_bid, ids.market.base_asset, ids.market.quote_asset, ids.market.controller)) 
    %}
    return ();
}

// Utility function to handle revoked implicit references.
// @dev tempvars used to handle revoked implict references
func handle_revoked_refs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
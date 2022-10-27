%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from src.tree.structs import Order, Limit, Market
from src.tree.events import (
    log_create_market, log_create_bid, log_create_ask, log_bid_taken, log_offer_taken, log_buy_filled, log_sell_filled, log_delete_order
)

@contract_interface
namespace IOrdersContract {
    // Getter for head ID and tail ID.
    func get_head_and_tail(limit_id : felt) -> (head_id : felt, tail_id : felt) {
    }
    // Getter for particular order.
    func get_order(id : felt) -> (order : Order) {
    }
    // Insert new order to the list.
    func push(is_buy : felt, price : felt, amount : felt, dt : felt, owner : felt, limit_id : felt) -> (new_order : Order) {
    }
    // Retrieve order at particular position in the list.
    func get(limit_id : felt, idx : felt) -> (order : Order) {
    }
    // Update filled amount of order.
    func set_filled(id : felt, filled : felt) -> (success : felt) {  
    }
    // Remove order by ID.
    func remove(order_id : felt) -> (success : felt) {
    }
}

@contract_interface
namespace ILimitsContract {
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

@contract_interface
namespace IBalancesContract {
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

// Stores IOrdersContract contract address.
@storage_var
func orders_addr() -> (addr : felt) {
}

// Stores ILimitsContract contract address.
@storage_var
func limits_addr() -> (addr : felt) {
}

// Stores IBalancesContract contract address.
@storage_var
func balances_addr() -> (addr : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    _orders_addr : felt, _limits_addr : felt, _balances_addr : felt
) {
    curr_market_id.write(1);
    curr_tree_id.write(1);
    orders_addr.write(_orders_addr);
    limits_addr.write(_limits_addr);
    balances_addr.write(_balances_addr);
    return ();
}

// Get market ID given two assets (or 0 if one doesn't exist).
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @return market_id : market iD
@view
func get_market_ids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt) -> (market_id : felt
) {
    let (market_id) = market_ids.read(base_asset, quote_asset);
    return (market_id=market_id);
}

// Get market from market ID.
// @param market_id : market ID
// @return market : retrieved market
@view
func get_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (market_id : felt
) -> (market : Market) {
    let (market) = markets.read(market_id);
    return (market=market);
}

// Create a new market for exchanging between two assets.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param controller : felt representation of account that controls the market
@external
func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt
) -> (new_market : Market) {
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
func update_inside_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, lowest_ask : felt, highest_bid : felt
) -> (success : felt) {
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
// @param market_id : ID of market
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
// @return success : 1 if successfully created bid, 0 otherwise
@external
func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, price : felt, amount : felt, post_only : felt
) -> (success : felt) {
    alloc_locals;

    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();
    let (market) = markets.read(market_id);
    let (limit, _) = ILimitsContract.find(_limits_addr, price, market.bid_tree_id);
    let (lowest_ask) = IOrdersContract.get_order(_orders_addr, market.lowest_ask);

    if (market.id == 0) {
        return (success=0);
    }

    // If ask exists and price greater than lowest ask, place market buy
    if (lowest_ask.id == 0) {
        handle_revoked_refs();
    } else {        
        let is_market_order = is_le(lowest_ask.price, price);
        handle_revoked_refs();
        if (is_market_order == 1) {
            if (post_only == 0) {
                let (buy_order_success) = buy(market.id, price, amount);
                assert buy_order_success = 1;
                handle_revoked_refs();
                return (success=1);
            } else {
                handle_revoked_refs();
                return (success=0);
            }
            
        } else {
            handle_revoked_refs();
        }
    }
    
    // Otherwise, place limit order
    if (limit.id == 0) {
        // Limit tree doesn't exist yet, insert new limit tree
        let (new_limit) = ILimitsContract.insert(_limits_addr, price, market.bid_tree_id, market.id);
        let create_limit_success = is_le(1, new_limit.id);
        assert create_limit_success = 1;
        let (create_bid_success) = create_bid_helper(market, new_limit, price, amount, post_only);
        assert create_bid_success = 1;
        handle_revoked_refs();
    } else {
        // Add order to limit tree
        let (create_bid_success) = create_bid_helper(market, limit, price, amount, post_only);
        assert create_bid_success = 1;
        handle_revoked_refs();
    }
    
    return (success=1);
}

// Helper function for creating a new bid (limit buy order).
// @param market : market to which bid is being submitted
// @param limit : limit tree to which bid is being submitted
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @return success : 1 if successfully created bid, 0 otherwise
func create_bid_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market : Market, limit : Limit, price : felt, amount : felt, post_only : felt
) -> (success : felt) {
    alloc_locals;

    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();
    
    let (caller) = get_caller_address();
    let (account_balance) = IBalancesContract.get_balance(_balances_addr, caller, market.base_asset, 1);
    let balance_sufficient = is_le(amount, account_balance);
    if (balance_sufficient == 0) {
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let (dt) = get_block_timestamp();
    let (new_order) = IOrdersContract.push(_orders_addr, 1, price, amount, dt, caller, limit.id);
    let (new_head, new_tail) = IOrdersContract.get_head_and_tail(_orders_addr, limit.id);
    let (update_limit_success) = ILimitsContract.update(_limits_addr, limit.id, limit.total_vol + amount, limit.length + 1, new_head, new_tail);
    assert update_limit_success = 1;

    let (highest_bid) = IOrdersContract.get_order(_orders_addr, market.highest_bid);
    let highest_bid_exists = is_le(1, highest_bid.id); 
    let is_not_highest_bid = is_le(price, highest_bid.price);
    if (is_not_highest_bid + highest_bid_exists == 2) {
        handle_revoked_refs();
    } else {
        let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_order.id);
        assert update_market_success = 1;
        handle_revoked_refs();
    }
    let (update_balance_success) = IBalancesContract.transfer_to_order(_balances_addr, caller, market.base_asset, amount);
    assert update_balance_success = 1;

    log_create_bid.emit(
        id=new_order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, 
        amount=amount, post_only=post_only
    );

    return (success=1);
}

// Submit a new ask (limit sell order) to a given market.
// @param market_id : ID of market
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
// @return success : 1 if successfully created ask, 0 otherwise
@external
func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, price : felt, amount : felt, post_only : felt
) -> (success : felt) {
    alloc_locals;

    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();
    let (market) = markets.read(market_id);
    let (limit, _) = ILimitsContract.find(_limits_addr, price, market.ask_tree_id);
    let (highest_bid) = IOrdersContract.get_order(_orders_addr, market.highest_bid);

    if (market.id == 0) {
        return (success=0);
    }

    // If bid exists and price lower than highest bid, place market sell
    if (highest_bid.id == 1) {
        let is_market_order = is_le(price, highest_bid.price);
        handle_revoked_refs();
        if (is_market_order == 1) {
            if (post_only == 0) {
                let (sell_order_success) = sell(market.id, price, amount);
                assert sell_order_success = 1;
                handle_revoked_refs();
                return (success=1);
            } else {
                handle_revoked_refs();
                return (success=0);
            }
        } else {
            handle_revoked_refs();
        }
    } else {
        handle_revoked_refs();
    }

    // Otherwise, place limit sell order
    if (limit.id == 0) {
        // Limit tree doesn't exist yet, insert new limit tree
        let (new_limit) = ILimitsContract.insert(_limits_addr, price, market.ask_tree_id, market.id);
        let create_limit_success = is_le(1, new_limit.id);
        assert create_limit_success = 1;
        let (create_ask_success) = create_ask_helper(market, new_limit, price, amount, post_only);
        assert create_ask_success = 1;
        handle_revoked_refs();
    } else {
        // Add order to limit tree
        let (create_ask_success) = create_ask_helper(market, limit, price, amount, post_only);
        assert create_ask_success = 1;
        handle_revoked_refs();
    }
    
    return (success=1);
}

// Helper function for creating a new ask (limit sell order).
// @param market : market to which bid is being submitted
// @param limit : limit tree to which bid is being submitted
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @return success : 1 if successfully created bid, 0 otherwise
func create_ask_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market : Market, limit : Limit, price : felt, amount : felt, post_only : felt
) -> (success : felt) {
    alloc_locals;
    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();

    let (caller) = get_caller_address();
    let (account_balance) = IBalancesContract.get_balance(_balances_addr, caller, market.quote_asset, 1);
    let balance_sufficient = is_le(amount, account_balance);
    if (balance_sufficient == 0) {
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let (dt) = get_block_timestamp();
    let (new_order) = IOrdersContract.push(_orders_addr, 0, price, amount, dt, caller, limit.id);
    let (new_head, new_tail) = IOrdersContract.get_head_and_tail(_orders_addr, limit.id);
    let (update_limit_success) = ILimitsContract.update(_limits_addr, limit.id, limit.total_vol + amount, limit.length + 1, new_head, new_tail);
    assert update_limit_success = 1;

    let (lowest_ask) = IOrdersContract.get_order(_orders_addr, market.lowest_ask);
    let lowest_ask_exists = is_le(1, lowest_ask.id); 
    let is_not_lowest_ask = is_le(lowest_ask.price, price);
    if (lowest_ask_exists + is_not_lowest_ask == 2) {
        handle_revoked_refs();        
    } else {
        let (update_market_success) = update_inside_quote(market.id, new_order.id, market.highest_bid);
        assert update_market_success = 1;
        handle_revoked_refs();
    }
    let (update_balance_success) = IBalancesContract.transfer_to_order(_balances_addr, caller, market.quote_asset, amount);
    assert update_balance_success = 1;

    log_create_ask.emit(
        id=new_order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, 
        amount=amount, post_only=post_only
    );

    return (success=1);
}

// Submit a new market buy order to a given market.
// @param market_id : ID of market
// @param max_price : highest price at which buyer is willing to fulfill order
// @param amount : order size in number of tokens of quote asset
// @return success : 1 if successfully created bid, 0 otherwise
@external
func buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, max_price : felt, amount : felt
) -> (success : felt) {
    alloc_locals;

    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();

    let (market) = markets.read(market_id);
    let (lowest_ask) = IOrdersContract.get_order(_orders_addr, market.lowest_ask);
    let (base_amount, _) = unsigned_div_rem(amount, lowest_ask.price);
    let (caller) = get_caller_address();
    let (account_balance) = IBalancesContract.get_balance(_balances_addr, caller, market.base_asset, 1);
    let is_sufficient = is_le(base_amount, account_balance);
    let is_positive = is_le(1, amount);
    if (is_sufficient * is_positive * market.id == 0) {
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let lowest_ask_exists = is_le(1, market.lowest_ask);
    if (lowest_ask_exists == 0) {
        let (create_bid_success) = create_bid(market_id, max_price, amount, 0);
        assert create_bid_success = 1;
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let is_below_max_price = is_le(lowest_ask.price, max_price);
    if (is_below_max_price == 0) {
        let (create_bid_success) = create_bid(market_id, max_price, amount, 0);
        assert create_bid_success = 1;
        handle_revoked_refs();
        return (success=1);
    } else {
        handle_revoked_refs();
    }
    
    let (dt) = get_block_timestamp();
    let is_partial_fill = is_le(amount, lowest_ask.amount - lowest_ask.filled - 1);
    let (limit) = ILimitsContract.get_limit(_limits_addr, lowest_ask.limit_id);
    if (is_partial_fill == 1) {
        // Partial fill of order
        IOrdersContract.set_filled(_orders_addr, lowest_ask.id, amount);
        let (transfer_balance_success_1) = IBalancesContract.transfer_from_order(_balances_addr, lowest_ask.owner, market.quote_asset, amount);
        let (base_amount, _) = unsigned_div_rem(amount, lowest_ask.price);
        let (transfer_balance_success_1) = IBalancesContract.transfer_balance(_balances_addr, caller, lowest_ask.owner, market.base_asset, base_amount);
        assert transfer_balance_success_1 = 1;
        let (transfer_balance_success_2) = IBalancesContract.transfer_balance(_balances_addr, lowest_ask.owner, caller, market.quote_asset, amount);
        assert transfer_balance_success_2 = 1;
        let (update_limit_success) = ILimitsContract.update(_limits_addr, limit.id, limit.total_vol - amount, limit.length, limit.head_id, limit.tail_id);                
        assert update_limit_success = 1;
        log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=amount);
        log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=amount);
        handle_revoked_refs();
        return (success=1);
    } else {
        // Fill entire order
        IOrdersContract.set_filled(_orders_addr, lowest_ask.id, lowest_ask.amount);
        delete(lowest_ask.id);
        let (base_amount, _) = unsigned_div_rem(lowest_ask.amount - lowest_ask.filled, lowest_ask.price);
        let (transfer_balance_success_1) = IBalancesContract.transfer_balance(_balances_addr, caller, lowest_ask.owner, market.base_asset, base_amount);
        assert transfer_balance_success_1 = 1;
        let (transfer_balance_success_2) = IBalancesContract.transfer_balance(_balances_addr, lowest_ask.owner, caller, market.quote_asset, amount);
        assert transfer_balance_success_2 = 1;

        log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=amount);
        log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=amount);

        buy(market_id, max_price, amount - lowest_ask.amount + lowest_ask.filled); 
        
        handle_revoked_refs();
        return (success=1);
    }
}

// Submit a new market sell order to a given market.
// @param market_id : ID of market
// @param min_price : lowest price at which seller is willing to fulfill order
// @param amount : order size in number of tokens of quote asset
// @return success : 1 if successfully created ask, 0 otherwise
@external
func sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, min_price : felt, amount : felt
) -> (success : felt) {
    alloc_locals;

    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();

    let (market) = markets.read(market_id);
    let (caller) = get_caller_address();
    let (account_balance) = IBalancesContract.get_balance(_balances_addr, caller, market.quote_asset, 1);
    let is_sufficient = is_le(amount, account_balance);
    let is_positive = is_le(1, amount);
    if (is_sufficient * is_positive * market.id == 0) {
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let highest_bid_exists = is_le(1, market.highest_bid);
    if (highest_bid_exists == 0) {
        let (create_ask_success) = create_ask(market_id, min_price, amount, 0);
        assert create_ask_success = 1;
        handle_revoked_refs();
        return (success=0);
    } else {
        handle_revoked_refs();
    }

    let (highest_bid) = IOrdersContract.get_order(_orders_addr, market.highest_bid)
    let is_above_min_price = is_le(min_price, highest_bid.price);
    if (is_above_min_price == 0) {
        let (create_ask_success) = create_ask(market_id, min_price, amount, 0);
        assert create_ask_success = 1;
        handle_revoked_refs();
        return (success=1);
    } else {
        handle_revoked_refs();
    }
    
    let (dt) = get_block_timestamp();
    let is_partial_fill = is_le(amount, highest_bid.amount - highest_bid.filled - 1);
    let (limit) = ILimitsContract.get_limit(_limits_addr, highest_bid.limit_id);
    if (is_partial_fill == 1) {
        // Partial fill of order
        IOrdersContract.set_filled(_orders_addr, highest_bid.id, amount);
        let (transfer_balance_success_1) = IBalancesContract.transfer_from_order(_balances_addr, highest_bid.owner, market.base_asset, amount);
        let (base_amount, _) = unsigned_div_rem(amount, highest_bid.price);
        let (transfer_balance_success_1) = IBalancesContract.transfer_balance(_balances_addr, caller, highest_bid.owner, market.quote_asset, amount);
        assert transfer_balance_success_1 = 1;
        let (transfer_balance_success_2) = IBalancesContract.transfer_balance(_balances_addr, highest_bid.owner, caller, market.base_asset, base_amount);
        assert transfer_balance_success_2 = 1;
        let (update_limit_success) = ILimitsContract.update(_limits_addr, limit.id, limit.total_vol - amount, limit.length, limit.head_id, limit.tail_id);                
        assert update_limit_success = 1;

        log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=amount, total_filled=amount);
        log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=amount, total_filled=amount);
        handle_revoked_refs();

        return (success=1);
    } else {
        // Fill entire order
        IOrdersContract.set_filled(_orders_addr, highest_bid.id, highest_bid.amount);
        delete(highest_bid.id);
        let (base_amount, _) = unsigned_div_rem(highest_bid.amount - highest_bid.filled, highest_bid.price);
        let (transfer_balance_success_1) = IBalancesContract.transfer_balance(_balances_addr, caller, highest_bid.owner, market.quote_asset, amount);
        assert transfer_balance_success_1 = 1;
        let (transfer_balance_success_2) = IBalancesContract.transfer_balance(_balances_addr, highest_bid.owner, caller, market.base_asset, base_amount);
        assert transfer_balance_success_2 = 1;

        log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=amount);
        log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=amount);

        sell(market_id, min_price, amount - highest_bid.amount + highest_bid.filled); 
        
        handle_revoked_refs();
        return (success=1);
    }
}

// Delete an order and update limits, markets and balances.
// @param order_id : ID of order
@external
func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (success : felt) {
    alloc_locals;
    
    let (_orders_addr) = orders_addr.read();
    let (_limits_addr) = limits_addr.read();
    let (_balances_addr) = balances_addr.read();

    let (caller) = get_caller_address();
    let (order) = IOrdersContract.get_order(_orders_addr, order_id);

    if (caller == order.owner) {
        handle_revoked_refs();
    } else {
        return (success=0);
    }

    let (update_orders_success) = IOrdersContract.remove(_orders_addr, order_id);
    assert update_orders_success = 1;
    let (new_head_id, new_tail_id) = IOrdersContract.get_head_and_tail(_orders_addr, order.limit_id);
    let (limit) = ILimitsContract.get_limit(_limits_addr, order.limit_id);
    let (update_limit_success) = ILimitsContract.update(_limits_addr, limit.id, limit.total_vol - order.amount + order.filled, limit.length - 1, new_head_id, new_tail_id);
    assert update_limit_success = 1;

    let (market) = markets.read(limit.market_id);

    if (order.is_buy == 1) {
        if (new_head_id == 0) {
            ILimitsContract.delete(_limits_addr, limit.price, limit.tree_id, limit.market_id);
            let (next_limit) = ILimitsContract.get_max(_limits_addr, limit.tree_id);
            if (next_limit.id == 0) {
                let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, 0);
                assert update_market_success = 1;
                handle_revoked_refs();
            } else {
                let (next_head, _) = IOrdersContract.get_head_and_tail(_orders_addr, next_limit.id);
                let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, next_head);
                assert update_market_success = 1;
                handle_revoked_refs();
            }
        } else {
            let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_head_id);
            assert update_market_success = 1;
            handle_revoked_refs();     
        }
        let (update_balance_success) = IBalancesContract.transfer_from_order(_balances_addr, caller, market.base_asset, order.amount);
        assert update_balance_success = 1;
        handle_revoked_refs();
    } else {
        if (new_head_id == 0) {
            ILimitsContract.delete(_limits_addr, limit.price, limit.tree_id, limit.market_id);
            let (next_limit) = ILimitsContract.get_max(_limits_addr, limit.tree_id);
            if (next_limit.id == 0) {
                let (update_market_success) = update_inside_quote(market.id, 0, market.highest_bid);
                assert update_market_success = 1;
                handle_revoked_refs();
            } else {
                let (next_head, _) = IOrdersContract.get_head_and_tail(_orders_addr, next_limit.id);
                let (update_market_success) = update_inside_quote(market.id, next_head, market.highest_bid);
                assert update_market_success = 1;
                handle_revoked_refs();
            }
        } else {
            let (update_market_success) = update_inside_quote(market.id, new_head_id, market.highest_bid);
            assert update_market_success = 1;
            handle_revoked_refs();    
        }
        let (update_balance_success) = IBalancesContract.transfer_from_order(_balances_addr, caller, market.quote_asset, order.amount);
        assert update_balance_success = 1;
        handle_revoked_refs();
    }

    let (dt) = get_block_timestamp();
    log_delete_order.emit(order.id, limit.id, market.id, dt, order.owner, market.base_asset, market.quote_asset, order.price, order.amount, order.filled);
    return (success=1);
}

// Utility function to handle revoked implicit references.
func handle_revoked_refs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
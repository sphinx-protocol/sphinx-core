%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp

from src.dex.orders import Orders
from src.dex.limits import Limits
from src.dex.balances import Balances
from src.dex.structs import Order, Limit, Market
from src.dex.events import (
    log_create_market, log_create_bid, log_create_ask, log_bid_taken, log_offer_taken, log_buy_filled, log_sell_filled, log_delete_order
)
from src.utils.handle_revoked_refs import handle_revoked_refs

//
// Storage vars
//

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

namespace Markets {

    //
    // Functions
    //

    // Initialiser function
    // @dev Called by GatewayContract on deployment
    func initialise{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
        curr_market_id.write(1);
        curr_tree_id.write(1);
        return ();
    }

    // Get market ID given two assets (or 0 if one doesn't exist).
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    // @return market_id : market iD
    func get_market_ids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt) -> (market_id : felt
    ) {
        let (market_id) = market_ids.read(base_asset, quote_asset);
        if (market_id == 0) {
            // Checks for reverse order
            let (alt_market_id) = market_ids.read(quote_asset, base_asset);
            return (market_id=alt_market_id);
        } else {
            return (market_id=market_id);
        }
    }

    // Get market from market ID.
    // @param market_id : market ID
    // @return market : retrieved market
    func get_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (market_id : felt
    ) -> (market : Market) {
        let (market) = markets.read(market_id);
        return (market=market);
    }

    // Create a new market for exchanging between two assets.
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt
    ) -> (new_market : Market) {
        alloc_locals;
        
        let (existing_market_id) = get_market_ids(base_asset, quote_asset);
        let market_exists = is_le(1, existing_market_id);
        assert market_exists = 0;

        let (market_id) = curr_market_id.read();
        let (tree_id) = curr_tree_id.read();

        tempvar new_market: Market* = new Market(
            id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask=0, highest_bid=0, 
            base_asset=base_asset, quote_asset=quote_asset
        );
        markets.write(market_id, [new_market]);

        curr_market_id.write(market_id + 1);
        curr_tree_id.write(tree_id + 2);
        market_ids.write(base_asset, quote_asset, market_id);

        log_create_market.emit(
            id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask=0, highest_bid=0, 
            base_asset=base_asset, quote_asset=quote_asset
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
            highest_bid=highest_bid, base_asset=market.base_asset, quote_asset=market.quote_asset
        );
        markets.write(market_id, [new_market]);
        return (success=1);
    }

    // Submit a new bid (limit buy order) to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param price : limit price of order
    // @param amount : order size in number of tokens of quote asset
    // @param post_only : 1 if create bid in post only mode, 0 otherwise
    // @return success : 1 if successfully created bid, 0 otherwise
    func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, price : felt, amount : felt, post_only : felt
    ) -> (success : felt) {
        alloc_locals;

        let (market) = markets.read(market_id);
        let (limit, _) = Limits.find(price, market.bid_tree_id);
        let (lowest_ask) = Orders.get_order(market.lowest_ask);

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
                    let (buy_order_success) = buy(caller, market.id, price, amount);
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
            let (new_limit) = Limits.insert(price, market.bid_tree_id, market.id);
            let create_limit_success = is_le(1, new_limit.id);
            assert create_limit_success = 1;
            let (create_bid_success) = create_bid_helper(caller, market, new_limit, price, amount, post_only);
            assert create_bid_success = 1;
            handle_revoked_refs();
        } else {
            // Add order to limit tree
            let (create_bid_success) = create_bid_helper(caller, market, limit, price, amount, post_only);
            assert create_bid_success = 1;
            handle_revoked_refs();
        }
        
        return (success=1);
    }

    // Helper function for creating a new bid (limit buy order).
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market : market to which bid is being submitted
    // @param limit : limit tree to which bid is being submitted
    // @param price : limit price of order
    // @param amount : order size in number of tokens of quote asset
    // @return success : 1 if successfully created bid, 0 otherwise
    func create_bid_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market : Market, limit : Limit, price : felt, amount : felt, post_only : felt
    ) -> (success : felt) {
        alloc_locals;

        let (account_balance) = Balances.get_balance(caller, market.base_asset, 1);
        let balance_sufficient = is_le(amount, account_balance);
        if (balance_sufficient == 0) {
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let (dt) = get_block_timestamp();
        let (new_order) = Orders.push(1, price, amount, dt, caller, limit.id);
        let (new_head, new_tail) = Orders.get_head_and_tail(limit.id);
        let (update_limit_success) = Limits.update(limit.id, limit.total_vol + amount, limit.length + 1, new_head, new_tail);
        assert update_limit_success = 1;

        let (highest_bid) = Orders.get_order(market.highest_bid);
        let highest_bid_exists = is_le(1, highest_bid.id); 
        let is_not_highest_bid = is_le(price, highest_bid.price);
        if (is_not_highest_bid + highest_bid_exists == 2) {
            handle_revoked_refs();
        } else {
            let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_order.id);
            assert update_market_success = 1;
            handle_revoked_refs();
        }
        let (update_balance_success) = Balances.transfer_to_order(caller, market.base_asset, amount);
        assert update_balance_success = 1;

        log_create_bid.emit(
            id=new_order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, 
            amount=amount, post_only=post_only
        );

        return (success=1);
    }

    // Submit a new ask (limit sell order) to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param price : limit price of order
    // @param amount : order size in number of tokens of quote asset
    // @param post_only : 1 if create bid in post only mode, 0 otherwise
    // @return success : 1 if successfully created ask, 0 otherwise
    func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, price : felt, amount : felt, post_only : felt
    ) -> (success : felt) {
        alloc_locals;

        let (market) = markets.read(market_id);
        let (limit, _) = Limits.find(price, market.ask_tree_id);
        let (highest_bid) = Orders.get_order(market.highest_bid);

        if (market.id == 0) {
            return (success=0);
        }

        // If bid exists and price lower than highest bid, place market sell
        if (highest_bid.id == 1) {
            let is_market_order = is_le(price, highest_bid.price);
            handle_revoked_refs();
            if (is_market_order == 1) {
                if (post_only == 0) {
                    let (sell_order_success) = sell(caller, market.id, price, amount);
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
            let (new_limit) = Limits.insert(price, market.ask_tree_id, market.id);
            let create_limit_success = is_le(1, new_limit.id);
            assert create_limit_success = 1;
            let (create_ask_success) = create_ask_helper(caller, market, new_limit, price, amount, post_only);
            assert create_ask_success = 1;
            handle_revoked_refs();
        } else {
            // Add order to limit tree
            let (create_ask_success) = create_ask_helper(caller, market, limit, price, amount, post_only);
            assert create_ask_success = 1;
            handle_revoked_refs();
        }
        
        return (success=1);
    }

    // Helper function for creating a new ask (limit sell order).
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market : market to which bid is being submitted
    // @param limit : limit tree to which bid is being submitted
    // @param price : limit price of order
    // @param amount : order size in number of tokens of quote asset
    // @return success : 1 if successfully created bid, 0 otherwise
    func create_ask_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market : Market, limit : Limit, price : felt, amount : felt, post_only : felt
    ) -> (success : felt) {
        alloc_locals;

        let (account_balance) = Balances.get_balance(caller, market.quote_asset, 1);
        let balance_sufficient = is_le(amount, account_balance);
        if (balance_sufficient == 0) {
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let (dt) = get_block_timestamp();
        let (new_order) = Orders.push(0, price, amount, dt, caller, limit.id);
        let (new_head, new_tail) = Orders.get_head_and_tail(limit.id);
        let (update_limit_success) = Limits.update(limit.id, limit.total_vol + amount, limit.length + 1, new_head, new_tail);
        assert update_limit_success = 1;

        let (lowest_ask) = Orders.get_order(market.lowest_ask);
        let lowest_ask_exists = is_le(1, lowest_ask.id); 
        let is_not_lowest_ask = is_le(lowest_ask.price, price);
        if (lowest_ask_exists + is_not_lowest_ask == 2) {
            handle_revoked_refs();        
        } else {
            let (update_market_success) = update_inside_quote(market.id, new_order.id, market.highest_bid);
            assert update_market_success = 1;
            handle_revoked_refs();
        }
        let (update_balance_success) = Balances.transfer_to_order(caller, market.quote_asset, amount);
        assert update_balance_success = 1;

        log_create_ask.emit(
            id=new_order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, 
            amount=amount, post_only=post_only
        );

        return (success=1);
    }

    // Submit a new market buy order to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param max_price : highest price at which buyer is willing to fulfill order
    // @param amount : order size in number of tokens of quote asset
    // @return success : 1 if successfully created bid, 0 otherwise
    func buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, max_price : felt, amount : felt
    ) -> (success : felt) {
        alloc_locals;

        let (market) = markets.read(market_id);
        let (lowest_ask) = Orders.get_order(market.lowest_ask);
        let (base_amount, _) = unsigned_div_rem(amount, lowest_ask.price);
        let (account_balance) = Balances.get_balance(caller, market.base_asset, 1);
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
            let (create_bid_success) = create_bid(caller, market_id, max_price, amount, 0);
            assert create_bid_success = 1;
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let is_below_max_price = is_le(lowest_ask.price, max_price);
        if (is_below_max_price == 0) {
            let (create_bid_success) = create_bid(caller, market_id, max_price, amount, 0);
            assert create_bid_success = 1;
            handle_revoked_refs();
            return (success=1);
        } else {
            handle_revoked_refs();
        }
        
        let (dt) = get_block_timestamp();
        let is_partial_fill = is_le(amount, lowest_ask.amount - lowest_ask.filled - 1);
        let (limit) = Limits.get_limit(lowest_ask.limit_id);
        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(lowest_ask.id, amount);
            let (transfer_balance_success_1) = Balances.transfer_from_order(lowest_ask.owner, market.quote_asset, amount);
            let (base_amount, _) = unsigned_div_rem(amount, lowest_ask.price);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, lowest_ask.owner, market.base_asset, base_amount);
            assert transfer_balance_success_1 = 1;
            let (transfer_balance_success_2) = Balances.transfer_balance(lowest_ask.owner, caller, market.quote_asset, amount);
            assert transfer_balance_success_2 = 1;
            let (update_limit_success) = Limits.update(limit.id, limit.total_vol - amount, limit.length, limit.head_id, limit.tail_id);                
            assert update_limit_success = 1;
            log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=amount);
            log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=amount, total_filled=amount);
            handle_revoked_refs();
            return (success=1);
        } else {
            // Fill entire order
            Orders.set_filled(lowest_ask.id, lowest_ask.amount);
            delete(caller, lowest_ask.id);
            let (base_amount, _) = unsigned_div_rem(lowest_ask.amount - lowest_ask.filled, lowest_ask.price);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, lowest_ask.owner, market.base_asset, base_amount);
            assert transfer_balance_success_1 = 1;
            let (transfer_balance_success_2) = Balances.transfer_balance(lowest_ask.owner, caller, market.quote_asset, amount);
            assert transfer_balance_success_2 = 1;

            log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=amount);
            log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=amount);

            buy(caller, market_id, max_price, amount - lowest_ask.amount + lowest_ask.filled); 
            
            handle_revoked_refs();
            return (success=1);
        }
    }

    // Submit a new market sell order to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param min_price : lowest price at which seller is willing to fulfill order
    // @param amount : order size in number of tokens of quote asset
    // @return success : 1 if successfully created ask, 0 otherwise
    func sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, min_price : felt, amount : felt
    ) -> (success : felt) {
        alloc_locals;

        let (market) = markets.read(market_id);
        let (account_balance) = Balances.get_balance(caller, market.quote_asset, 1);
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
            let (create_ask_success) = create_ask(caller, market_id, min_price, amount, 0);
            assert create_ask_success = 1;
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let (highest_bid) = Orders.get_order(market.highest_bid);
        let is_above_min_price = is_le(min_price, highest_bid.price);
        if (is_above_min_price == 0) {
            let (create_ask_success) = create_ask(caller, market_id, min_price, amount, 0);
            assert create_ask_success = 1;
            handle_revoked_refs();
            return (success=1);
        } else {
            handle_revoked_refs();
        }
        
        let (dt) = get_block_timestamp();
        let is_partial_fill = is_le(amount, highest_bid.amount - highest_bid.filled - 1);
        let (limit) = Limits.get_limit(highest_bid.limit_id);
        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(highest_bid.id, amount);
            let (transfer_balance_success_1) = Balances.transfer_from_order(highest_bid.owner, market.base_asset, amount);
            let (base_amount, _) = unsigned_div_rem(amount, highest_bid.price);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, highest_bid.owner, market.quote_asset, amount);
            assert transfer_balance_success_1 = 1;
            let (transfer_balance_success_2) = Balances.transfer_balance(highest_bid.owner, caller, market.base_asset, base_amount);
            assert transfer_balance_success_2 = 1;
            let (update_limit_success) = Limits.update(limit.id, limit.total_vol - amount, limit.length, limit.head_id, limit.tail_id);                
            assert update_limit_success = 1;

            log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=amount, total_filled=amount);
            log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=amount, total_filled=amount);
            handle_revoked_refs();

            return (success=1);
        } else {
            // Fill entire order
            Orders.set_filled(highest_bid.id, highest_bid.amount);
            delete(caller, highest_bid.id);
            let (base_amount, _) = unsigned_div_rem(highest_bid.amount - highest_bid.filled, highest_bid.price);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, highest_bid.owner, market.quote_asset, amount);
            assert transfer_balance_success_1 = 1;
            let (transfer_balance_success_2) = Balances.transfer_balance(highest_bid.owner, caller, market.base_asset, base_amount);
            assert transfer_balance_success_2 = 1;

            log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=amount);
            log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=amount);

            sell(caller, market_id, min_price, amount - highest_bid.amount + highest_bid.filled); 
            
            handle_revoked_refs();
            return (success=1);
        }
    }

    // Delete an order and update limits, markets and balances.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param order_id : ID of order
    func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, order_id : felt
    ) -> (success : felt) {
        alloc_locals;

        let (order) = Orders.get_order(order_id);
        if (caller == order.owner) {
            handle_revoked_refs();
        } else {
            return (success=0);
        }

        let (update_orders_success) = Orders.remove(order_id);
        assert update_orders_success = 1;
        let (new_head_id, new_tail_id) = Orders.get_head_and_tail(order.limit_id);
        let (limit) = Limits.get_limit(order.limit_id);
        let (update_limit_success) = Limits.update(limit.id, limit.total_vol - order.amount + order.filled, limit.length - 1, new_head_id, new_tail_id);
        assert update_limit_success = 1;

        let (market) = markets.read(limit.market_id);

        if (order.is_buy == 1) {
            if (new_head_id == 0) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_max(limit.tree_id);
                if (next_limit.id == 0) {
                    let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, 0);
                    assert update_market_success = 1;
                    handle_revoked_refs();
                } else {
                    let (next_head, _) = Orders.get_head_and_tail(next_limit.id);
                    let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, next_head);
                    assert update_market_success = 1;
                    handle_revoked_refs();
                }
            } else {
                let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_head_id);
                assert update_market_success = 1;
                handle_revoked_refs();     
            }
            let (update_balance_success) = Balances.transfer_from_order(caller, market.base_asset, order.amount);
            assert update_balance_success = 1;
            handle_revoked_refs();
        } else {
            if (new_head_id == 0) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_max(limit.tree_id);
                if (next_limit.id == 0) {
                    let (update_market_success) = update_inside_quote(market.id, 0, market.highest_bid);
                    assert update_market_success = 1;
                    handle_revoked_refs();
                } else {
                    let (next_head, _) = Orders.get_head_and_tail(next_limit.id);
                    let (update_market_success) = update_inside_quote(market.id, next_head, market.highest_bid);
                    assert update_market_success = 1;
                    handle_revoked_refs();
                }
            } else {
                let (update_market_success) = update_inside_quote(market.id, new_head_id, market.highest_bid);
                assert update_market_success = 1;
                handle_revoked_refs();    
            }
            let (update_balance_success) = Balances.transfer_from_order(caller, market.quote_asset, order.amount);
            assert update_balance_success = 1;
            handle_revoked_refs();
        }

        let (dt) = get_block_timestamp();
        log_delete_order.emit(order.id, limit.id, market.id, dt, order.owner, market.base_asset, market.quote_asset, order.price, order.amount, order.filled);
        return (success=1);
    }
}
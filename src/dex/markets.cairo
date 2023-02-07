%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.pow import pow

from src.dex.orders import Orders
from src.dex.limits import Limits
from src.dex.balances import Balances
from src.dex.structs import Order, Limit, Market
from src.dex.events import (
    log_create_market, log_create_bid, log_create_ask, log_bid_taken, log_offer_taken, log_buy_filled, log_sell_filled
)
from src.utils.handle_revoked_refs import handle_revoked_refs

@contract_interface
namespace IStorageContract {
    // Get market by market ID
    func get_market(market_id : felt) -> (market : Market) {
    }
    // Set market by market ID
    func set_market(market_id : felt, new_market : Market) {
    }
    // Get market ID by base and quote asset addresses
    func get_market_id(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
    }
    // Set market ID by base and quote asset addresses
    func set_market_id(base_asset : felt, quote_asset : felt, new_market_id : felt) {
    }
    // Get current market ID
    func get_curr_market_id() -> (id : felt) {
    }
    // Set current market ID
    func set_curr_market_id(new_id : felt) {
    }
    // Get current tree ID
    func get_curr_tree_id() -> (id : felt) {
    }
    // Set current tree ID
    func set_curr_tree_id(new_id : felt) {
    }
    // Get order by order ID
    func get_order(order_id : felt) -> (order : Order) {
    }
    // Get head order by limit ID
    func get_head(limit_id : felt) -> (order_id : felt) {
    }
    // Get limit by limit ID
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
    // Get base asset decimals
    func get_base_decimals(market_id : felt) -> (decimals : felt) {
    }
    // Set base asset decimals
    func set_base_decimals(market_id : felt, decimals : felt) {
    }
    // Get quote asset decimals
    func get_quote_decimals(market_id : felt) -> (decimals : felt) {
    }
    // Set quote asset decimals
    func set_quote_decimals(market_id : felt, decimals : felt) {
    }
}

namespace Markets {

    //
    // Functions
    //

    // Get market ID given two assets (or 0 if one doesn't exist).
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    // @return market_id : market iD
    func get_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt) -> (market_id : felt
    ) {
        let (storage_addr) = Orders.get_storage_address();
        let (market_id) = IStorageContract.get_market_id(storage_addr, base_asset, quote_asset);
        if (market_id == 0) {
            // Checks for reverse order
            let (alt_market_id) = IStorageContract.get_market_id(storage_addr, quote_asset, base_asset);
            return (market_id=alt_market_id);
        } else {
            return (market_id=market_id);
        }
    }

    // Create a new market for exchanging between two assets.
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt, base_decimals : felt, quote_decimals : felt
    ) -> (new_market : Market) {
        alloc_locals;
        
        let (storage_addr) = Orders.get_storage_address();
        let (existing_market_id) = get_market_id(base_asset, quote_asset);
        let market_exists = is_le(1, existing_market_id);
        with_attr error_message("Market already exists") {
            assert market_exists = 0;
        }
        if (base_asset == quote_asset) {
            with_attr error_message("Assets cannot be the same") {
                assert 1 = 0;
            }
        }

        let (market_id) = IStorageContract.get_curr_market_id(storage_addr);
        let (tree_id) = IStorageContract.get_curr_tree_id(storage_addr);

        tempvar new_market: Market* = new Market(
            market_id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask_id=0, highest_bid_id=0, 
            base_asset=base_asset, quote_asset=quote_asset
        );
        IStorageContract.set_market(storage_addr, market_id, [new_market]);

        IStorageContract.set_curr_market_id(storage_addr, market_id + 1);
        IStorageContract.set_curr_tree_id(storage_addr, tree_id + 2);
        IStorageContract.set_market_id(storage_addr, base_asset, quote_asset, market_id);

        IStorageContract.set_base_decimals(storage_addr, market_id, base_decimals);
        IStorageContract.set_quote_decimals(storage_addr, market_id, quote_decimals);

        log_create_market.emit(
            market_id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask_id=0, highest_bid_id=0, 
            base_asset=base_asset, quote_asset=quote_asset
        );

        return (new_market=[new_market]);
    }

    // Update inside quote of market.
    // @param market_id : market ID
    // @param lowest_ask_id : ID of lowest ask of market
    // @param highest_bid_id : ID of highest bid of market
    func update_inside_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        market_id : felt, lowest_ask_id : felt, highest_bid_id : felt
    ) {
        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        if (market.market_id == 0) {
            with_attr error_message("Market does not exist") {
                assert 0 = 1;
            }
            return ();
        }
        tempvar new_market: Market* = new Market(
            market_id=market_id, bid_tree_id=market.bid_tree_id, ask_tree_id=market.ask_tree_id, lowest_ask_id=lowest_ask_id, 
            highest_bid_id=highest_bid_id, base_asset=market.base_asset, quote_asset=market.quote_asset
        );
        IStorageContract.set_market(storage_addr, market_id, [new_market]);
        return ();
    }

    // Submit a new bid (limit buy order) to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param price : limit price of order
    // @param quote_amount : order size in number of tokens of quote asset
    // @param post_only : 1 if create bid in post only mode, 0 otherwise
    func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, price : felt, quote_amount : felt, post_only : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let (limit, _) = Limits.find(price, market.bid_tree_id);
        let (lowest_ask_id) = IStorageContract.get_order(storage_addr, market.lowest_ask_id);

        if (market.market_id == 0) {
            with_attr error_message("Market does not exist") {
                assert 0 = 1;
            }
        }

        // If ask exists and price greater than lowest ask, place market buy
        if (lowest_ask_id.limit_id == 0) {
            handle_revoked_refs();
        } else {        
            let is_market_order = is_le(lowest_ask_id.price, price);
            handle_revoked_refs();
            if (is_market_order == 1) {
                if (post_only == 0) {
                    buy(caller, market.market_id, price, 0, quote_amount);
                    handle_revoked_refs();
                    return ();
                } else {
                    handle_revoked_refs();
                    with_attr error_message("Order would be filled immediately") {
                        assert 0 = 1;
                    }
                    return ();
                }
                
            } else {
                handle_revoked_refs();
            }
        }
        // Otherwise, place limit order
        if (limit.limit_id == 0) {
            // Limit tree doesn't exist yet, insert new limit tree
            let (new_limit) = Limits.insert(price, market.bid_tree_id, market.market_id);
            create_bid_helper(caller, market, new_limit, price, quote_amount, post_only);
            handle_revoked_refs();
        } else {
            // Add order to limit tree
            create_bid_helper(caller, market, limit, price, quote_amount, post_only);
            handle_revoked_refs();
        }
        return ();
    }

    // Helper function for creating a new bid (limit buy order).
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market : market to which bid is being submitted
    // @param limit : limit tree to which bid is being submitted
    // @param price : limit price of order
    // @param quote_amount : order size in number of tokens of quote asset
    func create_bid_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market : Market, limit : Limit, price : felt, quote_amount : felt, post_only : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (quote_decimals) = IStorageContract.get_quote_decimals(storage_addr, market.market_id);
        let (base_decimals) = IStorageContract.get_base_decimals(storage_addr, market.market_id);
        let (denominator) = pow(10, 18 + quote_decimals - base_decimals);
        let (base_amount, _) = unsigned_div_rem(quote_amount * price, denominator);

        let (account_balance) = Balances.get_balance(caller, market.base_asset, 1);
        let balance_sufficient = is_le(base_amount, account_balance);
        if (balance_sufficient == 0) {
            handle_revoked_refs();
            with_attr error_message("Balance insufficient") {
                assert 0 = 1;
            }
            return ();
        } else {
            handle_revoked_refs();
        }

        let (datetime) = get_block_timestamp();
        let (new_order) = Orders.push(1, price, quote_amount, datetime, caller, limit.limit_id);
        let (new_head_id) = IStorageContract.get_head(storage_addr, limit.limit_id);
        Limits.update(limit.limit_id, limit.amount + quote_amount, limit.length + 1);

        let (highest_bid_id) = IStorageContract.get_order(storage_addr, market.highest_bid_id);
        let highest_bid_id_exists = is_le(1, highest_bid_id.order_id); 
        let is_not_highest_bid_id = is_le(price, highest_bid_id.price);
        if (is_not_highest_bid_id + highest_bid_id_exists == 2) {
            handle_revoked_refs();
        } else {
            update_inside_quote(market.market_id, market.lowest_ask_id, new_order.order_id);
            handle_revoked_refs();
        }

        let (order_size_in_base, _) = unsigned_div_rem(quote_amount * price, denominator);
        Balances.transfer_to_order(caller, market.base_asset, order_size_in_base);

        log_create_bid.emit(
            order_id=new_order.order_id, limit_id=limit.limit_id, market_id=market.market_id, datetime=datetime, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, quote_amount=quote_amount, post_only=post_only
        );

        return ();
    }

    // Submit a new ask (limit sell order) to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param price : limit price of order
    // @param quote_amount : order size in number of tokens of quote asset
    // @param post_only : 1 if create bid in post only mode, 0 otherwise
    func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, price : felt, quote_amount : felt, post_only : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let (limit, _) = Limits.find(price, market.ask_tree_id);
        let (highest_bid_id) = IStorageContract.get_order(storage_addr, market.highest_bid_id);

        if (market.market_id == 0) {
            with_attr error_message("Market does not exist") {
                assert 0 = 1;
            }
            return ();
        }

        // If bid exists and price lower than highest bid, place market sell
        if (highest_bid_id.order_id == 0) {
            handle_revoked_refs();
        } else {
            handle_revoked_refs();
            let is_market_order = is_le(price, highest_bid_id.price);
            if (is_market_order == 1) {
                if (post_only == 0) {
                    sell(caller, market.market_id, price, 0, quote_amount);
                    handle_revoked_refs();
                    return ();
                } else {
                    handle_revoked_refs();
                    with_attr error_message("Order would be filled immediately") {
                        assert 0 = 1;
                    }
                    return ();
                }
            } else {
                handle_revoked_refs();
            }
        }

        // Otherwise, place limit sell order
        if (limit.limit_id == 0) {
            // Limit tree doesn't exist yet, insert new limit tree
            let (new_limit) = Limits.insert(price, market.ask_tree_id, market.market_id);
            create_ask_helper(caller, market, new_limit, price, quote_amount, post_only);
            handle_revoked_refs();
        } else {
            // Add order to limit tree
            create_ask_helper(caller, market, limit, price, quote_amount, post_only);
            handle_revoked_refs();
        }
        
        return ();
    }

    // Helper function for creating a new ask (limit sell order).
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market : market to which bid is being submitted
    // @param limit : limit tree to which bid is being submitted
    // @param price : limit price of order
    // @param quote_amount : order size in number of tokens of quote asset
    func create_ask_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market : Market, limit : Limit, price : felt, quote_amount : felt, post_only : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (account_balance) = Balances.get_balance(caller, market.quote_asset, 1);
        let balance_sufficient = is_le(quote_amount, account_balance);
        if (balance_sufficient == 0) {
            handle_revoked_refs();
            with_attr error_message("Balance insufficient") {
                assert 0 = 1;
            }
            return ();
        } else {
            handle_revoked_refs();
        }

        let (datetime) = get_block_timestamp();
        let (new_order) = Orders.push(0, price, quote_amount, datetime, caller, limit.limit_id);
        let (new_head_id) = IStorageContract.get_head(storage_addr, limit.limit_id);
        Limits.update(limit.limit_id, limit.amount + quote_amount, limit.length + 1);

        let (lowest_ask_id) = IStorageContract.get_order(storage_addr, market.lowest_ask_id);
        let lowest_ask_id_exists = is_le(1, lowest_ask_id.order_id); 
        let is_not_lowest_ask_id = is_le(lowest_ask_id.price, price);
        if (lowest_ask_id_exists + is_not_lowest_ask_id == 2) {
            handle_revoked_refs();        
        } else {
            update_inside_quote(market.market_id, new_order.order_id, market.highest_bid_id);
            handle_revoked_refs();
        }
        Balances.transfer_to_order(caller, market.quote_asset, quote_amount);

        log_create_ask.emit(
            order_id=new_order.order_id, limit_id=limit.limit_id, market_id=market.market_id, datetime=datetime, owner=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=price, 
            quote_amount=quote_amount, post_only=post_only
        );

        return ();
    }

    // Submit a new market buy order to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param max_price : highest price at which buyer is willing to fulfill order
    // @param filled : size of order already filled in previous recursive calls of buy fn (in quote asset terms)
    // @param quote_amount : order size in number of tokens of quote asset
    func buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, max_price : felt, filled : felt, quote_amount : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let lowest_ask_id_exists = is_le(1, market.lowest_ask_id);
        with_attr error_message("[Markets] buy > Lowest ask does not exist") {
            assert lowest_ask_id_exists = 1;
        }
        
        let (lowest_ask_id) = IStorageContract.get_order(storage_addr, market.lowest_ask_id);
        let (quote_decimals) = IStorageContract.get_quote_decimals(storage_addr, market.market_id);
        let (base_decimals) = IStorageContract.get_base_decimals(storage_addr, market.market_id);
        let (denominator) = pow(10, 18 + quote_decimals - base_decimals);
        let (base_amount, _) = unsigned_div_rem(quote_amount * lowest_ask_id.price, denominator);
        let (account_balance) = Balances.get_balance(caller, market.base_asset, 1);
        
        let is_sufficient = is_le(base_amount, account_balance);
        let is_positive = is_le(1, quote_amount);
        if (is_sufficient * is_positive * market.market_id == 0) {
            handle_revoked_refs();
            with_attr error_message("Balance insufficient, amount negative or market does not exist") {
                assert 0 = 1;
            }
            return ();
        } else {
            handle_revoked_refs();
        }

        let is_below_max_price = is_le(lowest_ask_id.price, max_price);
        if (is_below_max_price == 0) {
            create_bid(caller, market_id, max_price, quote_amount, 0);
            handle_revoked_refs();
            return ();
        } else {
            handle_revoked_refs();
        }
        
        let (datetime) = get_block_timestamp();
        let is_partial_fill = is_le(quote_amount, lowest_ask_id.amount - lowest_ask_id.filled - 1);
        let (limit) = IStorageContract.get_limit(storage_addr, lowest_ask_id.limit_id);

        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(.order_id, lowest_ask_id.filled + quote_amount);
            Balances.transfer_from_order(lowest_ask_id.owner, market.quote_asset, quote_amount);
            Balances.transfer_balance(caller, lowest_ask_id.owner, market.base_asset, base_amount);
            Balances.transfer_balance(lowest_ask_id.owner, caller, market.quote_asset, quote_amount);
            Limits.update(limit.limit_id, limit.amount - quote_amount, limit.length);                
            
            log_offer_taken.emit(lowest_ask_id.order_id, limit.limit_id, market.market_id, datetime, lowest_ask_id.owner, caller, market.base_asset, market.quote_asset, lowest_ask_id.price, quote_amount, lowest_ask_id.filled+quote_amount);
            log_buy_filled.emit(lowest_ask_id.order_id, limit.limit_id, market.market_id, datetime, caller, lowest_ask_id.owner, market.base_asset, market.quote_asset, lowest_ask_id.price, quote_amount, filled+quote_amount);
            handle_revoked_refs();
            return ();
        } else {
            // Fill entire order
            delete(lowest_ask_id.order_id);
            let (price_units) = pow(10, 18);
            let (updated_base_amount, _) = unsigned_div_rem((lowest_ask_id.amount - lowest_ask_id.filled) * lowest_ask_id.price, price_units);
            Balances.transfer_balance(caller, lowest_ask_id.owner, market.base_asset, updated_base_amount);
            Balances.transfer_balance(lowest_ask_id.owner, caller, market.quote_asset, lowest_ask_id.amount - lowest_ask_id.filled);
            Orders.set_filled(lowest_ask_id.order_id, lowest_ask_id.amount);

            log_offer_taken.emit(lowest_ask_id.order_id, limit.limit_id, market.market_id, datetime, lowest_ask_id.owner, caller, market.base_asset, market.quote_asset, lowest_ask_id.price, lowest_ask_id.amount, lowest_ask_id.amount);
            log_buy_filled.emit(lowest_ask_id.order_id, limit.limit_id, market.market_id, datetime, caller, lowest_ask_id.owner, market.base_asset, market.quote_asset, lowest_ask_id.price, lowest_ask_id.amount-lowest_ask_id.filled, filled+lowest_ask_id.amount-lowest_ask_id.filled);

            if (quote_amount - lowest_ask_id.amount + lowest_ask_id.filled == 0) {
                handle_revoked_refs();
            } else {
                handle_revoked_refs();
                buy(caller, market_id, max_price, filled + lowest_ask_id.amount - lowest_ask_id.filled, quote_amount - lowest_ask_id.amount + lowest_ask_id.filled);
            }

            handle_revoked_refs();
            return ();
        }
    }

    // Submit a new market sell order to a given market.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param market_id : ID of market
    // @param min_price : lowest price at which seller is willing to fulfill order
    // @param filled : size of order already filled in previous recursive calls of buy fn (in quote asset terms)
    // @param quote_amount : order size in number of tokens of quote asset
    func sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        caller : felt, market_id : felt, min_price : felt, filled : felt, quote_amount : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let highest_bid_id_exists = is_le(1, market.highest_bid_id);
        with_attr error_message("[Markets] sell > Highest bid does not exist") {
            assert highest_bid_id_exists = 1;
        }

        let (highest_bid_id) = IStorageContract.get_order(storage_addr, market.highest_bid_id);
        let (quote_decimals) = IStorageContract.get_quote_decimals(storage_addr, market.market_id);
        let (base_decimals) = IStorageContract.get_base_decimals(storage_addr, market.market_id);
        let (denominator) = pow(10, 18 + quote_decimals - base_decimals);
        let (base_amount, _) = unsigned_div_rem(quote_amount * highest_bid_id.price, denominator);
        let (account_balance) = Balances.get_balance(caller, market.quote_asset, 1);

        let is_sufficient = is_le(quote_amount, account_balance);
        let is_positive = is_le(1, quote_amount);
        if (is_sufficient * is_positive * market.market_id == 0) {
            handle_revoked_refs();
            with_attr error_message("Balance insufficient, amount negative or market does not exist") {
                assert 0 = 1;
            }
            return ();
        } else {
            handle_revoked_refs();
        }

        let is_above_min_price = is_le(min_price, highest_bid_id.price);
        if (is_above_min_price == 0) {
            create_ask(caller, market_id, min_price, quote_amount, 0);
            handle_revoked_refs();
            return ();
        } else {
            handle_revoked_refs();
        }
        
        let (datetime) = get_block_timestamp();
        let is_partial_fill = is_le(quote_amount, highest_bid_id.amount - highest_bid_id.filled - 1);
        let (limit) = IStorageContract.get_limit(storage_addr, highest_bid_id.limit_id);
        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(highest_bid_id.order_id, highest_bid_id.filled + quote_amount);
            Balances.transfer_from_order(highest_bid_id.owner, market.base_asset, base_amount);
            Balances.transfer_balance(caller, highest_bid_id.owner, market.quote_asset, quote_amount);
            Balances.transfer_balance(highest_bid_id.owner, caller, market.base_asset, base_amount);
            Limits.update(limit.limit_id, limit.amount - quote_amount, limit.length);                

            log_bid_taken.emit(highest_bid_id.order_id, limit.limit_id, market.market_id, datetime, highest_bid_id.owner, caller, market.base_asset, market.quote_asset, highest_bid_id.price, highest_bid_id.amount, highest_bid_id.filled+quote_amount);
            log_sell_filled.emit(highest_bid_id.order_id, limit.limit_id, market.market_id, datetime, caller, highest_bid_id.owner, market.base_asset, market.quote_asset, highest_bid_id.price, quote_amount, filled+quote_amount);
            handle_revoked_refs();

            return ();
        } else {
            // Fill entire order
            delete(highest_bid_id.order_id);
            Balances.transfer_balance(caller, highest_bid_id.owner, market.quote_asset, highest_bid_id.amount - highest_bid_id.filled);
            let (price_units) = pow(10, 18);
            let (updated_base_amount, _) = unsigned_div_rem((highest_bid_id.amount - highest_bid_id.filled) * highest_bid_id.price, price_units);
            Balances.transfer_balance(highest_bid_id.owner, caller, market.base_asset, updated_base_amount);
            Orders.set_filled(highest_bid_id.order_id, highest_bid_id.amount);

            log_bid_taken.emit(highest_bid_id.order_id, limit.limit_id, market.market_id, datetime, highest_bid_id.owner, caller, market.base_asset, market.quote_asset, highest_bid_id.price, highest_bid_id.amount, highest_bid_id.amount);
            log_sell_filled.emit(highest_bid_id.order_id, limit.limit_id, market.market_id, datetime, caller, highest_bid_id.owner, market.base_asset, market.quote_asset, highest_bid_id.price, highest_bid_id.amount-highest_bid_id.filled, filled+highest_bid_id.amount-highest_bid_id.filled);
            
            if (quote_amount - highest_bid_id.amount + highest_bid_id.filled == 0) {
                handle_revoked_refs();
            } else {
                handle_revoked_refs();
                sell(caller, market_id, min_price, filled + highest_bid_id.amount - highest_bid_id.filled, quote_amount - highest_bid_id.amount + highest_bid_id.filled); 
            }

            handle_revoked_refs();
            return ();
        }
    }

    // Delete an order and update limits, markets and balances.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param order_id : ID of order
    // @return order details returned for event emitted in GatewayContract
    func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) -> (
        order_id : felt, limit_id : felt, market_id : felt, datetime : felt, owner : felt, 
        base_asset : felt, quote_asset : felt, price : felt, quote_amount : felt, filled : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (order) = IStorageContract.get_order(storage_addr, order_id);
        Orders.remove(order_id);
        let (limit) = IStorageContract.get_limit(storage_addr, order.limit_id);
        let (market) = IStorageContract.get_market(storage_addr, limit.market_id);
        let (new_head_id) = IStorageContract.get_head(storage_addr, order.limit_id);

        let (quote_decimals) = IStorageContract.get_quote_decimals(storage_addr, market.market_id);
        let (base_decimals) = IStorageContract.get_base_decimals(storage_addr, market.market_id);
        let (denominator) = pow(10, 18 + quote_decimals - base_decimals);

        if (order.is_bid == 1) {
            if (limit.length == 1) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_max(limit.tree_id);
                if (next_limit.limit_id == 0) {
                    update_inside_quote(market.market_id, market.lowest_ask_id, 0);
                    handle_revoked_refs();
                } else {
                    let (next_head_id) = IStorageContract.get_head(storage_addr, next_limit.limit_id);
                    update_inside_quote(market.market_id, market.lowest_ask_id, next_head_id);
                    handle_revoked_refs();
                }
            } else {
                Limits.update(limit.limit_id, limit.amount - order.amount + order.filled, limit.length - 1);
                update_inside_quote(market.market_id, market.lowest_ask_id, new_head_id);
                handle_revoked_refs();     
            }
            let (order_base_balance, _) = unsigned_div_rem((order.amount - order.filled) * order.price, denominator);
            Balances.transfer_from_order(order.owner, market.base_asset, order_base_balance);
            handle_revoked_refs();
        } else {
            if (limit.length == 1) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_min(limit.tree_id);
                if (next_limit.limit_id == 0) {
                    update_inside_quote(market.market_id, 0, market.highest_bid_id);
                    handle_revoked_refs();
                } else {
                    let (next_head_id) = IStorageContract.get_head(storage_addr, next_limit.limit_id);
                    update_inside_quote(market.market_id, next_head_id, market.highest_bid_id);
                    handle_revoked_refs();
                }
            } else {
                Limits.update(limit.limit_id, limit.amount - order.amount + order.filled, limit.length - 1);
                update_inside_quote(market.market_id, new_head_id, market.highest_bid_id);
                handle_revoked_refs();    
            }
            Balances.transfer_from_order(order.owner, market.quote_asset, order.amount - order.filled);
            handle_revoked_refs();
        }

        let (datetime) = get_block_timestamp();
        return (order_id=order.order_id, limit_id=limit.limit_id, market_id=market.market_id, datetime=datetime, owner=order.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=order.price, quote_amount=order.amount, filled=order.filled);
    }

    // Fetches quote for fulfilling market order based on current order book.
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    // @param is_bid : 1 for market buy order, 0 for market sell order
    // @param amount : size of order in terms of quote asset
    // @return price : quote price
    // @return base_amount : order amount in terms of base asset
    // @return quote_amount : order amount in terms of quote asset
    func fetch_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt, is_bid : felt, amount : felt
    ) -> (price : felt, base_amount : felt, quote_amount : felt) {
        alloc_locals;

        let (market_id) = get_market_id(base_asset, quote_asset);
        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);

        if (is_bid == 1) {
            let (prices, amounts, length) = Limits.view_limit_tree(market.ask_tree_id);
            let (rev_prices : felt*) = alloc();
            let (rev_amounts : felt*) = alloc();
            reverse_array{new_array=rev_prices}(array=prices, idx=length, length=length);
            reverse_array{new_array=rev_amounts}(array=amounts, idx=length, length=length);
            let (price, base_amount, quote_amount) = fetch_quote_helper(length, rev_prices, rev_amounts, 0, 0, amount, market_id);
            return (price=price, base_amount=base_amount, quote_amount=quote_amount);
        } else {
            let (prices, amounts, length) = Limits.view_limit_tree(market.bid_tree_id);
            let (price, base_amount, quote_amount) = fetch_quote_helper(length, prices, amounts, 0, 0, amount, market_id);
            return (price=price, base_amount=base_amount, quote_amount=quote_amount);
        }
    }

    // Helper function for fetching quote.
    // @param idx : index denoting current iteration of function
    // @param prices : array of order prices
    // @param amounts : array of order amounts
    // @param total_quote : cumulative amount filled in terms of quote asset
    // @param total_base : cumulative amount filled in terms of base asset
    // @param amount_rem : remaining unfilled order in terms of quote asset
    // @param market_id : market ID
    // @return price : quote price
    // @return base_amount : order amount in terms of base asset
    // @return quote_amount : order amount in terms of quote asset
    func fetch_quote_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        idx : felt, prices : felt*, amounts : felt*, total_quote : felt, total_base : felt, amount_rem : felt, market_id : felt
    ) -> (price : felt, base_amount : felt, quote_amount : felt) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (quote_decimals) = IStorageContract.get_quote_decimals(storage_addr, market_id);
        let (base_decimals) = IStorageContract.get_base_decimals(storage_addr, market_id);
        let (units) = pow(10, 18 - base_decimals + quote_decimals);

        if ((idx - 0) * (amount_rem - 0) == 0) {
            if ((total_quote - 0) * (total_base - 0) == 0) {
                handle_revoked_refs();
                return (price=0, base_amount=0, quote_amount=0);
            } else {
                handle_revoked_refs();
                let (units) = pow(10, 18 - base_decimals + quote_decimals);
                let (price, _) = unsigned_div_rem(total_base * units, total_quote);
                return (price=price, base_amount=total_base, quote_amount=total_quote);
            }
        } else {
            handle_revoked_refs();
        }

        let price = prices[idx - 1];
        let amount = amounts[idx - 1];
        let is_partial_order = is_le(amount_rem, amount - 1);

        if (is_partial_order == 1) {
            handle_revoked_refs();
            let (new_base, _) = unsigned_div_rem(price * amount_rem, units);
            return fetch_quote_helper(idx - 1, prices, amounts, total_quote + amount_rem, total_base + new_base, 0, market_id);
        } else {
            handle_revoked_refs();
            let (new_base, _) = unsigned_div_rem(price * amount, units);
            return fetch_quote_helper(idx - 1, prices, amounts, total_quote + amount, total_base + new_base, amount_rem - amount, market_id);
        }
    }

    // Helper function to reverse array.
    // @param (implict arg) new_array : pointer to new array
    // @param array : original array
    // @param idx : index denoting current run of function
    // @param length : length of array
    func reverse_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, new_array : felt*} (
        array : felt*, idx : felt, length : felt
    ) {
        if (idx == 0) {
            return ();
        }
        assert new_array[idx - 1] = array[length - idx];
        reverse_array(array, idx - 1, length);
        return ();
    }
}
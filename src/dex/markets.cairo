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
    // Get root node of tree based on tree ID
    func get_tree(tree_id : felt) -> (root_id : felt) {
    }
    // Set root node of tree based on tree ID
    func set_tree(tree_id : felt, new_root_id : felt) {
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
}


namespace Markets {

    //
    // Functions
    //

    // Get market ID given two assets (or 0 if one doesn't exist).
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    // @return market_id : market iD
    func get_market_ids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
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

    // Get market from market ID.
    // @param market_id : market ID
    // @return market : retrieved market
    func get_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (market_id : felt
    ) -> (market : Market) {
        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        return (market=market);
    }

    // Create a new market for exchanging between two assets.
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt
    ) -> (new_market : Market) {
        alloc_locals;
        
        let (storage_addr) = Orders.get_storage_address();
        let (existing_market_id) = get_market_ids(base_asset, quote_asset);
        let market_exists = is_le(1, existing_market_id);
        assert market_exists = 0;

        let (market_id) = IStorageContract.get_curr_market_id(storage_addr, );
        let (tree_id) = IStorageContract.get_curr_tree_id(storage_addr, );

        tempvar new_market: Market* = new Market(
            id=market_id, bid_tree_id=tree_id, ask_tree_id=tree_id+1, lowest_ask=0, highest_bid=0, 
            base_asset=base_asset, quote_asset=quote_asset
        );
        IStorageContract.set_market(storage_addr, market_id, [new_market]);

        IStorageContract.set_curr_market_id(storage_addr, market_id + 1);
        IStorageContract.set_curr_tree_id(storage_addr, tree_id + 2);
        IStorageContract.set_market_id(storage_addr, base_asset, quote_asset, market_id);

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
        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        if (market.id == 0) {
            return (success=0);
        }
        tempvar new_market: Market* = new Market(
            id=market_id, bid_tree_id=market.bid_tree_id, ask_tree_id=market.ask_tree_id, lowest_ask=lowest_ask, 
            highest_bid=highest_bid, base_asset=market.base_asset, quote_asset=market.quote_asset
        );
        IStorageContract.set_market(storage_addr, market_id, [new_market]);
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

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
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

        let (storage_addr) = Orders.get_storage_address();
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
        let (order_size, _) = unsigned_div_rem(amount * price, 1000000000000000000);
        let (update_balance_success) = Balances.transfer_to_order(caller, market.base_asset, order_size);
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

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let (limit, _) = Limits.find(price, market.ask_tree_id);
        let (highest_bid) = Orders.get_order(market.highest_bid);

        if (market.id == 0) {
            return (success=0);
        }

        // If bid exists and price lower than highest bid, place market sell
        if (highest_bid.id == 0) {
            handle_revoked_refs();
        } else {
            handle_revoked_refs();
            let is_market_order = is_le(price, highest_bid.price);
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

        let (storage_addr) = Orders.get_storage_address();
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

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let (lowest_ask) = Orders.get_order(market.lowest_ask);
        let (_, base_amount, quote_amount) = fetch_quote(market.base_asset, market.quote_asset, 1, amount);
        let (account_balance) = Balances.get_balance(caller, market.base_asset, 1);
        let is_sufficient = is_le(base_amount, account_balance);
        // %{ print("caller: {}, base_amount: {}, account_balance: {}".format(ids.caller, ids.base_amount, ids.account_balance)) %}
        let is_positive = is_le(1, quote_amount);
        // %{ print("is_sufficient: {}, is_positive: {}, market.id: {}".format(ids.is_sufficient, ids.is_positive, ids.market.id)) %}
        if (is_sufficient * is_positive * market.id == 0) {
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let lowest_ask_exists = is_le(1, market.lowest_ask);
        // %{ print("lowest_ask_exists: {}".format(ids.lowest_ask_exists)) %}
        if (lowest_ask_exists == 0) {
            let (create_bid_success) = create_bid(caller, market_id, max_price, quote_amount, 0);
            // %{ print("create_bid_success: {}".format(ids.create_bid_success)) %}
            with_attr error_message("[Markets] buy > Create bid unsuccessful") {
                assert create_bid_success = 1;
            }
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let is_below_max_price = is_le(lowest_ask.price, max_price);
        // %{ print("is_below_max_price: {}".format(ids.is_below_max_price)) %}
        if (is_below_max_price == 0) {
            let (create_bid_success) = create_bid(caller, market_id, max_price, quote_amount, 0);
            // %{ print("create_bid_success: {}".format(ids.create_bid_success)) %}
            with_attr error_message("[Markets] buy > Create bid unsuccessful") {
                assert create_bid_success = 1;
            }
            handle_revoked_refs();
            return (success=1);
        } else {
            handle_revoked_refs();
        }
        
        let (dt) = get_block_timestamp();
        let is_partial_fill = is_le(quote_amount, lowest_ask.amount - lowest_ask.filled - 1);
        let (limit) = Limits.get_limit(lowest_ask.limit_id);
        // %{ print("is_partial_fill: {}".format(ids.is_partial_fill)) %}
        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(lowest_ask.id, quote_amount);
            let (transfer_balance_success_1) = Balances.transfer_from_order(lowest_ask.owner, market.quote_asset, quote_amount);
            let (updated_base_amount, _) = unsigned_div_rem(quote_amount * lowest_ask.price, 1000000000000000000);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, lowest_ask.owner, market.base_asset, updated_base_amount);
            // %{ print("transfer_balance_success_1: {}".format(ids.transfer_balance_success_1)) %}
            with_attr error_message("[Markets] buy > Transfer balance 1 unsuccessful") {
                assert transfer_balance_success_1 = 1;
            }
            let (transfer_balance_success_2) = Balances.transfer_balance(lowest_ask.owner, caller, market.quote_asset, quote_amount);
            // %{ print("transfer_balance_success_2: {}".format(ids.transfer_balance_success_2)) %}
            with_attr error_message("[Markets] buy > Transfer balance 2 unsuccessful") {
                assert transfer_balance_success_2 = 1;
            }
            let (update_limit_success) = Limits.update(limit.id, limit.total_vol - quote_amount, limit.length, limit.head_id, limit.tail_id);                
            // %{ print("update_limit_success: {}".format(ids.update_limit_success)) %}
            with_attr error_message("[Markets] buy > Update limit unsuccessful") {
                assert update_limit_success = 1;
            }
            log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=quote_amount, total_filled=quote_amount);
            log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=quote_amount, total_filled=quote_amount);
            handle_revoked_refs();
            return (success=1);
        } else {
            // Fill entire order
            Orders.set_filled(lowest_ask.id, lowest_ask.amount);
            delete(caller, lowest_ask.id);
            let (updated_base_amount, _) = unsigned_div_rem((lowest_ask.amount - lowest_ask.filled) * lowest_ask.price, 1000000000000000000);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, lowest_ask.owner, market.base_asset, updated_base_amount);
            // %{ print("transfer_balance_success_1: {}".format(ids.transfer_balance_success_1)) %}
            with_attr error_message("[Markets] buy > Transfer balance 1 unsuccessful") {
                assert transfer_balance_success_1 = 1;
            }
            let (transfer_balance_success_2) = Balances.transfer_balance(lowest_ask.owner, caller, market.quote_asset, quote_amount);
            // %{ print("transfer_balance_success_2: {}".format(ids.transfer_balance_success_2)) %}
            with_attr error_message("[Markets] buy > Transfer balance 2 unsuccessful") {
                assert transfer_balance_success_2 = 1;
            }

            log_offer_taken.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=lowest_ask.owner, buyer=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=quote_amount);
            log_buy_filled.emit(id=lowest_ask.id, limit_id=limit.id, market_id=market.id, dt=dt, buyer=caller, seller=lowest_ask.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=lowest_ask.price, amount=lowest_ask.amount - lowest_ask.filled, total_filled=quote_amount);

            buy(caller, market_id, max_price, quote_amount - lowest_ask.amount + lowest_ask.filled); 
            
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

        let (storage_addr) = Orders.get_storage_address();
        let (market) = IStorageContract.get_market(storage_addr, market_id);
        let (_, base_amount, quote_amount) = fetch_quote(market.base_asset, market.quote_asset, 0, amount);
        let (account_balance) = Balances.get_balance(caller, market.quote_asset, 1);
        let is_sufficient = is_le(quote_amount, account_balance);
        let is_positive = is_le(1, quote_amount);
        if (is_sufficient * is_positive * market.id == 0) {
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let highest_bid_exists = is_le(1, market.highest_bid);
        if (highest_bid_exists == 0) {
            let (create_ask_success) = create_ask(caller, market_id, min_price, quote_amount, 0);
            with_attr error_message("[Markets] sell > Create ask unsuccessful") {
                assert create_ask_success = 1;
            }
            handle_revoked_refs();
            return (success=0);
        } else {
            handle_revoked_refs();
        }

        let (highest_bid) = Orders.get_order(market.highest_bid);
        let is_above_min_price = is_le(min_price, highest_bid.price);
        if (is_above_min_price == 0) {
            let (create_ask_success) = create_ask(caller, market_id, min_price, quote_amount, 0);
            with_attr error_message("[Markets] sell > Create ask unsuccessful") {
                assert create_ask_success = 1;
            }
            handle_revoked_refs();
            return (success=1);
        } else {
            handle_revoked_refs();
        }
        
        let (dt) = get_block_timestamp();
        let is_partial_fill = is_le(quote_amount, highest_bid.amount - highest_bid.filled - 1);
        let (limit) = Limits.get_limit(highest_bid.limit_id);
        if (is_partial_fill == 1) {
            // Partial fill of order
            Orders.set_filled(highest_bid.id, quote_amount);
            let (transfer_balance_success_1) = Balances.transfer_from_order(highest_bid.owner, market.base_asset, quote_amount);
            with_attr error_message("[Markets] sell > Transfer balance 1 unsuccessful") {
                assert transfer_balance_success_1 = 1;
            }
            let (transfer_balance_success_2) = Balances.transfer_balance(caller, highest_bid.owner, market.quote_asset, quote_amount);
            with_attr error_message("[Markets] sell > Transfer balance 2 unsuccessful") {
                assert transfer_balance_success_2 = 1;
            }
            let (transfer_balance_success_3) = Balances.transfer_balance(highest_bid.owner, caller, market.base_asset, base_amount);
            with_attr error_message("[Markets] sell > Transfer balance 3 unsuccessful") {
                assert transfer_balance_success_3 = 1;
            }
            let (update_limit_success) = Limits.update(limit.id, limit.total_vol - quote_amount, limit.length, limit.head_id, limit.tail_id);                
            with_attr error_message("[Markets] sell > Update limit unsuccessful") {
                assert update_limit_success = 1;
            }

            log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=quote_amount, total_filled=quote_amount);
            log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=quote_amount, total_filled=quote_amount);
            handle_revoked_refs();

            return (success=1);
        } else {
            // Fill entire order
            Orders.set_filled(highest_bid.id, highest_bid.amount);
            delete(caller, highest_bid.id);
            let (base_amount, _) = unsigned_div_rem((highest_bid.amount - highest_bid.filled) * highest_bid.price, 1000000000000000000);
            let (transfer_balance_success_1) = Balances.transfer_balance(caller, highest_bid.owner, market.quote_asset, quote_amount);
            with_attr error_message("[Markets] sell > Transfer balance 1 unsuccessful") {
                assert transfer_balance_success_1 = 1;
            }
            let (transfer_balance_success_2) = Balances.transfer_balance(highest_bid.owner, caller, market.base_asset, base_amount);
            with_attr error_message("[Markets] sell > Transfer balance 2 unsuccessful") {
                assert transfer_balance_success_2 = 1;
            }
            log_bid_taken.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=highest_bid.owner, seller=caller, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=quote_amount);
            log_sell_filled.emit(id=highest_bid.id, limit_id=limit.id, market_id=market.id, dt=dt, seller=caller, buyer=highest_bid.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=highest_bid.price, amount=highest_bid.amount-highest_bid.filled, total_filled=quote_amount);

            sell(caller, market_id, min_price, quote_amount - highest_bid.amount + highest_bid.filled); 
            
            handle_revoked_refs();
            return (success=1);
        }
    }

    // Delete an order and update limits, markets and balances.
    // @param caller : caller of contract method, passed in from GatewayContract
    // @param order_id : ID of order
    func delete{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (caller : felt, order_id : felt) -> (
        order_id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, 
        base_asset : felt, quote_asset : felt, price : felt, amount : felt, filled : felt
    ) {
        alloc_locals;

        let (storage_addr) = Orders.get_storage_address();
        let (order) = Orders.get_order(order_id);
        let (update_orders_success) = Orders.remove(order_id);
        // %{ print("update_orders_success: {}".format(ids.update_orders_success)) %}
        with_attr error_message("[Markets] delete > Update orders unsuccessful") {
            assert update_orders_success = 1;
        }
        let (new_head_id, new_tail_id) = Orders.get_head_and_tail(order.limit_id);
        let (limit) = Limits.get_limit(order.limit_id);
        let (update_limit_success) = Limits.update(limit.id, limit.total_vol - order.amount + order.filled, limit.length - 1, new_head_id, new_tail_id);
        // %{ print("update_limit_success: {}".format(ids.update_limit_success)) %}
        with_attr error_message("[Markets] delete > Update limits unsuccessful") {
            assert update_limit_success = 1;
        }

        let (market) = IStorageContract.get_market(storage_addr, limit.market_id);

        // %{ print("order.is_buy: {}".format(ids.order.is_buy)) %}
        if (order.is_buy == 1) {
            // %{ print("new_head_id: {}".format(ids.new_head_id)) %}
            if (new_head_id == 0) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_max(limit.tree_id);
                // %{ print("next_limit.id: {}".format(ids.next_limit.id)) %}
                if (next_limit.id == 0) {
                    let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, 0);
                    // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                    with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                        assert update_market_success = 1;
                    }
                    handle_revoked_refs();
                } else {
                    let (next_head, _) = Orders.get_head_and_tail(next_limit.id);
                    let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, next_head);
                    // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                    with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                        assert update_market_success = 1;
                    }
                    handle_revoked_refs();
                }
            } else {
                let (update_market_success) = update_inside_quote(market.id, market.lowest_ask, new_head_id);
                // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                    assert update_market_success = 1;
                }
                handle_revoked_refs();     
            }
            let (update_balance_success) = Balances.transfer_from_order(order.owner, market.base_asset, order.amount);
            // %{ print("update_balance_success: {}".format(ids.update_balance_success)) %}
            with_attr error_message("[Markets] delete > Update balance unsuccessful") {
                assert update_balance_success = 1;
            }
            handle_revoked_refs();
        } else {
            // %{ print("new_head_id: {}".format(ids.new_head_id)) %}
            if (new_head_id == 0) {
                Limits.delete(limit.price, limit.tree_id, limit.market_id);
                let (next_limit) = Limits.get_max(limit.tree_id);
                // %{ print("next_limit.id: {}".format(ids.next_limit.id)) %}
                if (next_limit.id == 0) {
                    let (update_market_success) = update_inside_quote(market.id, 0, market.highest_bid);
                    // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                    with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                        assert update_market_success = 1;
                    }
                    handle_revoked_refs();
                } else {
                    let (next_head, _) = Orders.get_head_and_tail(next_limit.id);
                    let (update_market_success) = update_inside_quote(market.id, next_head, market.highest_bid);
                    // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                    with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                        assert update_market_success = 1;
                    }
                    handle_revoked_refs();
                }
            } else {
                let (update_market_success) = update_inside_quote(market.id, new_head_id, market.highest_bid);
                // %{ print("update_market_success: {}".format(ids.update_market_success)) %}
                with_attr error_message("[Markets] delete > Update markets unsuccessful") {
                    assert update_market_success = 1;
                }
                handle_revoked_refs();    
            }
            let (update_balance_success) = Balances.transfer_from_order(order.owner, market.quote_asset, order.amount);
            // %{ print("update_balance_success: {}".format(ids.update_balance_success)) %}
            with_attr error_message("[Markets] delete > Update balance unsuccessful") {
                assert update_balance_success = 1;
            }
            handle_revoked_refs();
        }

        let (dt) = get_block_timestamp();
        return (order_id=order.id, limit_id=limit.id, market_id=market.id, dt=dt, owner=order.owner, base_asset=market.base_asset, quote_asset=market.quote_asset, price=order.price, amount=order.amount, filled=order.filled);
    }

    // Fetches quote for fulfilling market order based on current order book.
    // @param base_asset : felt representation of ERC20 base asset contract address
    // @param quote_asset : felt representation of ERC20 quote asset contract address
    // @param is_buy : 1 for market buy order, 0 for market sell order
    // @param amount : size of order in terms of quote asset
    // @return price : quote price
    // @return base_amount : order amount in terms of base asset
    // @return quote_amount : order amount in terms of quote asset
    @view
    func fetch_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        base_asset : felt, quote_asset : felt, is_buy : felt, amount : felt
    ) -> (price : felt, base_amount : felt, quote_amount : felt) {
        alloc_locals;

        let (market_id) = get_market_ids(base_asset, quote_asset);
        let (market) = get_market(market_id);

        if (is_buy == 1) {
            let (prices, amounts, length) = Limits.view_limit_tree(market.ask_tree_id);
            let (rev_prices : felt*) = alloc();
            let (rev_amounts : felt*) = alloc();
            reverse_array{new_array=rev_prices}(array=prices, idx=length, length=length);
            reverse_array{new_array=rev_amounts}(array=amounts, idx=length, length=length);
            let (price, base_amount, quote_amount) = fetch_quote_helper(length, rev_prices, rev_amounts, 0, 0, amount);
            return (price=price, base_amount=base_amount, quote_amount=quote_amount);
        } else {
            let (prices, amounts, length) = Limits.view_limit_tree(market.bid_tree_id);
            let (price, base_amount, quote_amount) = fetch_quote_helper(length, prices, amounts, 0, 0, amount);
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
    // @return price : quote price
    // @return base_amount : order amount in terms of base asset
    // @return quote_amount : order amount in terms of quote asset
    func fetch_quote_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
        idx : felt, prices : felt*, amounts : felt*, total_quote : felt, total_base : felt, amount_rem : felt
    ) -> (price : felt, base_amount : felt, quote_amount : felt) {
        alloc_locals;

        if ((idx - 0) * (amount_rem - 0) == 0) {
            if ((total_quote - 0) * (total_base - 0) == 0) {
                handle_revoked_refs();
                return (price=0, base_amount=0, quote_amount=0);
            } else {
                handle_revoked_refs();
                let (price, _) = unsigned_div_rem(total_base * 1000000000000000000, total_quote);
                // %{ print("price: {}, base_amount: {}, quote_amount: {}".format(ids.price, ids.total_base, ids.total_quote)) %}
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
            let (new_base, _) = unsigned_div_rem(price * amount_rem, 1000000000000000000);
            return fetch_quote_helper(idx - 1, prices, amounts, total_quote + amount_rem, total_base + new_base, 0);
        } else {
            handle_revoked_refs();
            let (new_base, _) = unsigned_div_rem(price * amount, 1000000000000000000);
            return fetch_quote_helper(idx - 1, prices, amounts, total_quote + amount, total_base + new_base, amount_rem - amount);
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
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from lib.math_utils import MathUtils
from starkware.cairo.common.uint256 import Uint256

from src.dex.balances import Balances
from src.dex.markets import Markets
from src.dex.limits import Limits
from src.dex.orders import Orders
from src.dex.structs import Order, Limit, Market

const MAX_FELT = 340282366920938463463374607431768211456; 

@contract_interface
namespace IMarketsContract {
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    }
    // Get market IDs from base and quote asset addresses.
    func get_market_id(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(caller : felt, market_id : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(caller : felt, market_id : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new market buy to a given market.
    func buy(caller : felt, market_id : felt, max_price : felt, filled : felt, quote_amount : felt) {
    }
    // Submit a new market sell to a given market.
    func sell(caller : felt, market_id : felt, min_price : felt, filled : felt, quote_amount : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func cancel_order(order_id : felt) {
    }
}

@contract_interface
namespace IStorageContract {
    // Set external contract address
    func set_gateway_address(_l2_gateway_contract_address : felt) {
    }
    // Get order by order ID
    func get_order(order_id : felt) -> (order : Order) {
    }
    // Get limit by limit ID
    func get_limit(limit_id : felt) -> (limit : Limit) {
    }
    // Get root limit node by tree ID
    func get_root(tree_id : felt) -> (limit_id : felt) {
    }
    // Get market by market ID
    func get_market(market_id : felt) -> (market : Market) {
    }
    // Set user account balance
    func set_account_balance(user : felt, asset : felt, new_amount : felt) {
    }
}


@contract_interface
namespace IERC20 {
    // Approve spender
    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }
    // Account balance
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
    // Transfer amount to recipient
    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }
    // Transfer amount from sender to recipient
    func transferFrom(sender : felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }
}

@external
func test_markets{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;
    
    // Set addresses
    const owner = 11111111;
    const buyer = 123456789;
    const seller = 666666666;
    const base_asset = 123213123123;
    const quote_asset = 788978978998;
    const gateway_addr = 789789789;

    // Deploy contracts
    local storage_addr : felt;
    local markets_addr : felt;
    %{ ids.storage_addr = deploy_contract("./src/dex/storage.cairo", [ids.owner]).contract_address %}
    %{ ids.markets_addr = deploy_contract("./src/dex/test/markets.cairo", [ids.storage_addr]).contract_address %}

    // Invoke functions
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.storage_addr) %}
    IStorageContract.set_gateway_address(storage_addr, gateway_addr);
    %{ stop_prank_callable() %}

    // 'Fund' user balances
    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.storage_addr) %}
    IStorageContract.set_account_balance(storage_addr, buyer, base_asset, 10000 * 1000000000000000000);
    IStorageContract.set_account_balance(storage_addr, seller, quote_asset, 10000 * 1000000000000000000);
    %{ stop_prank_callable() %}

    // Tests
    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.storage_addr) %}

    // Test 1 : Should create new market
    let (new_market) = IMarketsContract.create_market(markets_addr, base_asset, quote_asset);
    assert new_market.market_id = 1;
    assert new_market.bid_tree_id = 1;
    assert new_market.ask_tree_id = 2;
    assert new_market.base_asset = base_asset;

    // Test 2 : Should fail to create existing market
    // TODO: uncomment and replace with Protostar cheatcode for expect failure)
    // IMarketsContract.create_market(markets_addr, quote_asset, base_asset);

    // Test 3 : Should fail to create market with same base and quote asset
    // TODO: uncomment and replace with Protostar cheatcode for expect failure)
    // IMarketsContract.create_market(markets_addr, base_asset, base_asset);

    // Test 4 : Should fetch market IDs
    IMarketsContract.create_market(markets_addr, 712317239, 41823823);
    let (market_id) = IMarketsContract.get_market_id(markets_addr, base_asset, quote_asset);
    let (market_id_reverse) = IMarketsContract.get_market_id(markets_addr, quote_asset, base_asset);
    assert market_id = 1;
    assert market_id_reverse = 1;

    // Test 5 : Should create bids
    IMarketsContract.create_bid(markets_addr, buyer, market_id, 800 * 1000000000000000000, 1000 * 1000000000000000, 1);
    IMarketsContract.create_bid(markets_addr, buyer, market_id, 700 * 1000000000000000000, 500 * 1000000000000000, 1);
    IMarketsContract.create_bid(markets_addr, buyer, market_id, 900 * 1000000000000000000, 200 * 1000000000000000, 1);
    IMarketsContract.create_bid(markets_addr, buyer, market_id, 700 * 1000000000000000000, 50 * 1000000000000000, 1);
    let (market) = IStorageContract.get_market(storage_addr, market_id);
    let (bid_tree_root_id) = IStorageContract.get_root(storage_addr, market.bid_tree_id);
    let (bid_tree_root) = IStorageContract.get_limit(storage_addr, bid_tree_root_id);
    assert bid_tree_root.price = 800 * 1000000000000000000;
    assert bid_tree_root.left_id = 2;
    assert bid_tree_root.length = 1;
    let (left_child) = IStorageContract.get_limit(storage_addr, bid_tree_root.left_id);
    assert left_child.length = 2;
    let (order) = IStorageContract.get_order(storage_addr, 2);
    assert order.order_id = 2;
    assert order.price = 700 * 1000000000000000000;
    assert order.limit_id = 2;

    // Test 6 : Should create asks
    IMarketsContract.create_ask(markets_addr, seller, market_id, 1100 * 1000000000000000000, 200 * 1000000000000000, 1);
    IMarketsContract.create_ask(markets_addr, seller, market_id, 1000 * 1000000000000000000, 500 * 1000000000000000, 1);
    IMarketsContract.create_ask(markets_addr, seller, market_id, 1250 * 1000000000000000000, 1000 * 1000000000000000, 1);
    IMarketsContract.create_ask(markets_addr, seller, market_id, 1000 * 1000000000000000000, 50 * 1000000000000000, 1);
    let (ask_tree_root_id) = IStorageContract.get_root(storage_addr, market.ask_tree_id);
    let (ask_tree_root) = IStorageContract.get_limit(storage_addr, ask_tree_root_id);
    assert ask_tree_root.price = 1100 * 1000000000000000000;
    assert ask_tree_root.left_id = 5;
    let (right_child) = IStorageContract.get_limit(storage_addr, ask_tree_root.right_id);
    assert right_child.length = 1;
    let (order_2) = IStorageContract.get_order(storage_addr, 8);
    assert order_2.price = 1000 * 1000000000000000000;
    assert order_2.limit_id = 5;

    // Test 7 : Bid above min ask price with post only mode should fail
    // TODO: uncomment and replace with Protostar cheatcode for expect failure)
    // IMarketsContract.create_bid(markets_addr, buyer, market_id, 1200 * 1000000000000000000, 1000 * 1000000000000000, 1);

    // Test 8 : Bid above min ask price with post only mode disabled should fill a buy
    IMarketsContract.create_bid(markets_addr, buyer, market_id, 1200 * 1000000000000000000, 500 * 1000000000000000, 0);
    let (filled) = IStorageContract.get_order(storage_addr, 6);
    assert filled.filled = 500 * 1000000000000000;
    let (next) = IStorageContract.get_order(storage_addr, 8);
    assert next.filled = 0;
    
    // Test 9 : Ask below max bid price with post only mode should fail
    // TODO: uncomment and replace with Protostar cheatcode for expect failure)
    // IMarketsContract.create_ask(markets_addr, seller, market_id, 850 * 1000000000000000000, 100 * 1000000000000000, 1);

    // Test 10 : Ask below max bid price with post only mode disabled should fill a sell
    IMarketsContract.create_ask(markets_addr, seller, market_id, 850 * 1000000000000000000, 100 * 1000000000000000, 0);
    let (filled_2) = IStorageContract.get_order(storage_addr, 3);
    assert filled_2.filled = 100 * 1000000000000000;

    // Test 11 : Buy should fill successfully over single order
    let (test) = IStorageContract.get_order(storage_addr, 8);
    IMarketsContract.buy(markets_addr, buyer, market_id, MAX_FELT, 0, 50 * 1000000000000000);
    let (filled_3) = IStorageContract.get_order(storage_addr, 8);
    assert filled_3.filled = 50 * 1000000000000000;
    
    // Test 12 : Buy should fill successfully over multiple orders, including partial fills
    IMarketsContract.buy(markets_addr, buyer, market_id, MAX_FELT, 0, 300 * 1000000000000000);
    let (filled_4) = IStorageContract.get_order(storage_addr, 5);
    let (filled_5) = IStorageContract.get_order(storage_addr, 7);
    assert filled_4.filled = 200 * 1000000000000000;
    assert filled_5.filled = 100 * 1000000000000000;

    // Test 13 : Sells should fill successfully over single order
    IMarketsContract.sell(markets_addr, seller, market_id, 0, 0, 100 * 1000000000000000);
    let (filled_6) = IStorageContract.get_order(storage_addr, 3);
    assert filled_6.filled = 200 * 1000000000000000;

    // Test 14 : Sells should fill successfully over multiple orders, including partial fills
    IMarketsContract.sell(markets_addr, seller, market_id, 0, 0, 1500 * 1000000000000000);
    let (filled_7) = IStorageContract.get_order(storage_addr, 1);
    let (filled_8) = IStorageContract.get_order(storage_addr, 2);
    assert filled_7.filled = 1000 * 1000000000000000;
    assert filled_8.filled = 500 * 1000000000000000;

    // Test 15 : Buy at below lowest ask should create a bid
    // Test 16 : Selling at above highest bid should create an ask
    // Test 17 : Should be able to cancel order

    // Test emit events

    %{ stop_prank_callable() %}

    return ();
}

// Utility function for printing order.
func print_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order : Order) {
    %{
        print("    ", end="")
        print("order_id: {}, next_id: {}, is_buy: {}, price: {}, amount: {}, filled: {}, datetime: {}, owner: {}, limit_id: {}".format(ids.order.order_id, ids.order.next_id, ids.order.is_buy, ids.order.price, ids.order.amount, ids.order.filled, ids.order.datetime, ids.order.owner, ids.order.limit_id))
    %}
    return ();
}

// Utility function to handle printing info about a limit price.
func print_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (limit : Limit) {
    %{ 
        print("limit_id: {}, left_id: {}, right_id: {}, price: {}, total_vol: {}, length: {}, tree_id: {}".format(ids.limit.limit_id, ids.limit.left_id, ids.limit.right_id, ids.limit.price, ids.limit.total_vol, ids.limit.length, ids.limit.tree_id, ids.limit.market_id)) 
    %}
    return ();
}


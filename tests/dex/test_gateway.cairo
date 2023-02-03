%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from src.dex.structs import Market
from lib.math_utils import MathUtils

@contract_interface
namespace IGatewayContract {
    // Set MarketsContract address
    func set_addresses(_l2_eth_remote_core_addr : felt, _l2_eth_remote_eip_712_addr : felt) {
    }
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt, base_decimals : felt, quote_decimals : felt) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Submit a new market buy to a given market.
    func market_buy(base_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Submit a new market sell to a given market.
    func market_sell(base_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func cancel_order(order_id : felt) {
    }
    // Deposit ERC20 token to exchange
    func deposit(asset : felt, amount : felt) {
    }
    // Withdraw exchange balance as ERC20 token
    func withdraw(asset : felt, amount : felt) {
    }
    // Relay cross-chain request to submit a new bid (limit buy order) to a given market.
    func remote_create_bid(user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Relay cross-chain request to submit a new ask (limit sell order) to a given market.
    func remote_create_ask(user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
    }
    // Relay cross-chain request to submit a new market buy to a given market.
    func remote_market_buy(user : felt, base_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Relay cross-chain request to submit a new market sell to a given market.
    func remote_market_sell(user : felt, ase_asset : felt, quote_asset : felt, amount : felt) {
    }
    // Relay cross-chain request to cancel an order and update limits, markets and balances.
    func remote_cancel_order(user : felt, order_id : felt) {
    }
    // Relay remote deposit from other chain.
    func remote_deposit(user : felt, asset : felt, amount : felt) {
    }
    // Relay remote withdraw request from other chain.
    func remote_withdraw(user : felt, chain_id : felt, asset : felt, amount : felt) {
    }
    // Getter for user balances
    func get_balance(user : felt, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // View bid or ask order book for a particular market
    func view_order_book(base_asset : felt, quote_asset : felt, is_bid : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) {
    }
    // View bid or ask order book for a particular market
    func view_order_book_orders(base_asset : felt, quote_asset : felt, is_bid : felt) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*, owners_len: felt, owners: felt*, ids_len: felt, ids: felt*) {
    }
    // Fetches quote for market order based on current order book.
    func fetch_quote(base_asset : felt, quote_asset : felt, is_buy : felt, amount : felt) -> (price : felt, base_amount : felt, quote_amount : felt) {
    }
}

@contract_interface
namespace IStorageContract {
    // Set gateway contract address
    func set_gateway_address(_l2_gateway_contract_address : felt) {
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

// 
// Tests
// 

@external
func test_gateway{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;
    
    // Set contract addresses
    const owner = 31678259801237;
    const buyer = 123456789;
    const seller = 666666666;

    // Set params
    const base_decimals = 6;
    const quote_decimals = 18;

    // Deploy contracts
    local l2_eth_remote_core_addr : felt;
    local l2_eth_remote_eip_712_addr : felt;
    local base_asset : felt;
    local quote_asset : felt;
    local gateway_addr : felt;
    local storage_addr : felt;
    %{ ids.l2_eth_remote_core_addr = deploy_contract("./src/crosschain/l2_eth_remote_core.cairo", [ids.owner]).contract_address %}
    %{ ids.l2_eth_remote_eip_712_addr = deploy_contract("./src/crosschain/l2_eth_remote_eip_712.cairo", [ids.owner]).contract_address %}
    %{ ids.base_asset = deploy_contract("./src/ERC20/ERC20.cairo", [1, 1, ids.base_decimals, 1000000 * 1000000, 0, ids.buyer]).contract_address %}
    %{ ids.quote_asset = deploy_contract("./src/ERC20/ERC20.cairo", [2, 2, ids.quote_decimals, 1000000 * 1000000000000000000, 0, ids.seller]).contract_address %}
    %{ ids.storage_addr = deploy_contract("./src/dex/storage.cairo", [ids.owner]).contract_address %}
    %{ ids.gateway_addr = deploy_contract("./src/dex/gateway.cairo", [ids.owner, ids.storage_addr]).contract_address %}

    // Set gateway contract address in IStorageContract
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.storage_addr) %}
    IStorageContract.set_gateway_address(storage_addr, gateway_addr);
    %{ stop_prank_callable() %}

    // Set contract addresses and create new market
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.set_addresses(gateway_addr, l2_eth_remote_core_addr, l2_eth_remote_eip_712_addr);
    IGatewayContract.create_market(gateway_addr, base_asset, quote_asset, base_decimals, quote_decimals);
    %{ stop_prank_callable() %}

    // Fund user balances (deposit)
    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.base_asset) %}
    let (base_amount_u256) = MathUtils.felt_to_uint256(10000 * 1000000);
    IERC20.approve(base_asset, gateway_addr, base_amount_u256);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.quote_asset) %}
    let (quote_amount_u256) = MathUtils.felt_to_uint256(10000 * 1000000000000000000);
    IERC20.approve(quote_asset, gateway_addr, quote_amount_u256);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.deposit(gateway_addr, base_asset, 10000 * 1000000);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.deposit(gateway_addr, quote_asset, 10000 * 1000000000000000000);
    %{ stop_prank_callable() %}

    // Place bids as buyer
    // %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.gateway_addr) %}
    // IGatewayContract.create_ask(gateway_addr, base_asset, quote_asset, 1250 * 1000000000000000000, 1000 * 1000000000000000, 1);
    // IGatewayContract.create_ask(gateway_addr, base_asset, quote_asset, 1200 * 1000000000000000000, 500 * 1000000000000000, 1);
    // %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1100 * 1000000000000000, 500 * 1000000000000000, 1);
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1000 * 1000000000000000, 250 * 1000000000000000, 1);
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1230 * 1000000000000000, 750 * 1000000000000000, 1);
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1200 * 1000000000000000, 900 * 1000000000000000, 1);
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1100 * 1000000000000000, 220 * 1000000000000000, 1);
    %{ stop_prank_callable() %}

    let (buyer_base_account_balance) = IGatewayContract.get_balance(gateway_addr, buyer, base_asset, 1);
    let (buyer_base_locked_balance) = IGatewayContract.get_balance(gateway_addr, buyer, base_asset, 0);
    let (buyer_quote_account_balance) = IGatewayContract.get_balance(gateway_addr, buyer, quote_asset, 1);
    let (buyer_quote_locked_balance) = IGatewayContract.get_balance(gateway_addr, buyer, quote_asset, 0);

    let (seller_base_account_balance) = IGatewayContract.get_balance(gateway_addr, seller, base_asset, 1);
    let (seller_base_locked_balance) = IGatewayContract.get_balance(gateway_addr, seller, base_asset, 0);
    let (seller_quote_account_balance) = IGatewayContract.get_balance(gateway_addr, seller, quote_asset, 1);
    let (seller_quote_locked_balance) = IGatewayContract.get_balance(gateway_addr, seller, quote_asset, 0);

    %{ print("buyer_base_account_balance: {}, buyer_base_locked_balance: {}, buyer_quote_account_balance: {}, buyer_quote_locked_balance: {}".format(ids.buyer_base_account_balance, ids.buyer_base_locked_balance, ids.buyer_quote_account_balance, ids.buyer_quote_locked_balance)) %}
    %{ print("seller_base_account_balance: {}, seller_base_locked_balance: {}, seller_quote_account_balance: {}, seller_quote_locked_balance: {}".format(ids.seller_base_account_balance, ids.seller_base_locked_balance, ids.seller_quote_account_balance, ids.seller_quote_locked_balance)) %}

    // let (bob_prices_len, bob_prices, bob_amounts_len, bob_amounts) = IGatewayContract.view_order_book(gateway_addr, base_asset, quote_asset, 1);
    // %{ "Bid order book" %}
    // %{ print("Prices:") %}
    // print_list(bob_prices, bob_prices_len);
    // %{ print("Amounts:") %}
    // print_list(bob_amounts, bob_amounts_len);

    // let (aob_prices_len, aob_prices, aob_amounts_len, aob_amounts) = IGatewayContract.view_order_book(gateway_addr, base_asset, quote_asset, 0);
    // %{ "Ask order book" %}
    // %{ print("Prices:") %}
    // print_list(aob_prices, aob_prices_len);
    // %{ print("Amounts:") %}
    // print_list(aob_amounts, aob_amounts_len);

    let (bob_prices_len, bob_prices, bob_amounts_len, bob_amounts, bob_owners_len, bob_owners, bob_ids_len, bob_ids) = IGatewayContract.view_order_book_orders(gateway_addr, base_asset, quote_asset, 1);
    %{ "Bid order book" %}
    %{ print("Prices:") %}
    print_list(bob_prices, bob_prices_len);
    %{ print("Amounts:") %}
    print_list(bob_amounts, bob_amounts_len);
    %{ print("Owners:") %}
    print_list(bob_owners, bob_owners_len);
    %{ print("IDs:") %}
    print_list(bob_ids, bob_ids_len);

    let (aob_prices_len, aob_prices, aob_amounts_len, aob_amounts, aob_owners_len, aob_owners, aob_ids_len, aob_ids) = IGatewayContract.view_order_book_orders(gateway_addr, base_asset, quote_asset, 0);
    %{ "Ask order book" %}
    %{ print("Prices:") %}
    print_list(aob_prices, aob_prices_len);
    %{ print("Amounts:") %}
    print_list(aob_amounts, aob_amounts_len);
    %{ print("Owners:") %}
    print_list(aob_owners, aob_owners_len);
    %{ print("IDs:") %}
    print_list(aob_ids, aob_ids_len);

    return ();
}

func print_list{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} (array : felt*, idx : felt) {
    alloc_locals;

    if (idx == 0) {
        return ();
    }
    let value = array[idx - 1];
    %{ print("[{}]: {}".format(ids.idx - 1, ids.value)) %}
    print_list(array, idx - 1);
    
    return ();
}
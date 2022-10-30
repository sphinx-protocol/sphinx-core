%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Market

@contract_interface
namespace IOrdersContract {
    // Set MarketsContract address.
    func set_markets_addr(_markets_addr : felt) {
    }
}

@contract_interface
namespace ILimitsContract {
    // Set MarketsContract address.
    func set_markets_addr(_markets_addr : felt) {
    }
}

@contract_interface
namespace IBalancesContract {
    // Set MarketsContract and GatewayContract address.
    func set_addresses(_markets_addr : felt, _gateway_addr : felt) {
    }
     // Getter for user balances
    func get_balance(user : felt, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // Setter for user balances
    func set_balance(user : felt, asset : felt, in_account : felt, new_amount : felt) {
    }
}

@contract_interface
namespace IMarketsContract {
    // Set address.
    func set_addresses(_orders_addr : felt, _limits_addr : felt, _balances_addr : felt, _gateway_addr : felt) {
    }
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    }
}

@contract_interface
namespace IGatewayContract {
    // Set MarketsContract address
    func set_addresses(_balances_addr: felt, _markets_addr: felt, _l2_eth_remote_core_addr : felt, _l2_eth_remote_eip_712_addr : felt) {
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
}

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
    const base_asset = 123213123123;
    const quote_asset = 788978978998;

    // Deploy contracts
    local orders_addr: felt;
    local limits_addr: felt;
    local balances_addr: felt;
    local markets_addr: felt;
    local gateway_addr: felt;
    local l2_eth_remote_core_addr: felt;
    local l2_eth_remote_eip_712_addr: felt;
    %{ ids.orders_addr = deploy_contract("./src/dex/orders.cairo", [ids.owner]).contract_address %}
    %{ ids.limits_addr = deploy_contract("./src/dex/limits.cairo", [ids.owner]).contract_address %}
    %{ ids.balances_addr = deploy_contract("./src/dex/balances.cairo", [ids.owner]).contract_address %}
    %{ ids.gateway_addr = deploy_contract("./src/gateway.cairo", [ids.owner]).contract_address %}
    %{ ids.markets_addr = deploy_contract("./src/dex/markets.cairo", [ids.owner]).contract_address %}
    %{ ids.l2_eth_remote_core_addr = deploy_contract("./src/crosschain/l2_eth_remote_core.cairo", [ids.owner]).contract_address %}
    %{ ids.l2_eth_remote_eip_712_addr = deploy_contract("./src/crosschain/l2_eth_remote_eip_712.cairo", [ids.owner]).contract_address %}

    // %{ print("orders_addr: {}, limits_addr: {}, balances_addr: {}, gateway_addr: {}, markets_addr: {}".format(ids.orders_addr, ids.limits_addr, ids.balances_addr, ids.gateway_addr, ids.markets_addr)) %}

    // Set contract addresses within deployed contracts
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.orders_addr) %}
    IOrdersContract.set_markets_addr(orders_addr, markets_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.limits_addr) %}
    ILimitsContract.set_markets_addr(limits_addr, markets_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.balances_addr) %}
    IBalancesContract.set_addresses(balances_addr, markets_addr, gateway_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.markets_addr) %}
    IMarketsContract.set_addresses(markets_addr, orders_addr, limits_addr, balances_addr, gateway_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.set_addresses(gateway_addr, balances_addr, markets_addr, l2_eth_remote_core_addr, l2_eth_remote_eip_712_addr);
    %{ stop_prank_callable() %}
    
    // Create new market
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.markets_addr) %}
    let (new_market) = IMarketsContract.create_market(markets_addr, base_asset, quote_asset);
    %{ stop_prank_callable() %}

    // Fund user balances (fake deposit)
    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.balances_addr) %}
    IBalancesContract.set_balance(balances_addr, buyer, base_asset, 1, 5000);
    IBalancesContract.set_balance(balances_addr, seller, quote_asset, 1, 5000);
    %{ stop_prank_callable() %}

    // Place bids as buyer
    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1, 1000, 1);
    %{ stop_warp = warp(200) %}
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1, 1000, 1);
    %{ stop_warp = warp(220) %}
    IGatewayContract.create_bid(gateway_addr, base_asset, quote_asset, 1, 200, 1);
    %{ stop_warp = warp(321) %}
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.create_ask(gateway_addr, base_asset, quote_asset, 1, 500, 0);
    %{ stop_warp = warp(335) %}
    IGatewayContract.create_ask(gateway_addr, base_asset, quote_asset, 1, 300, 0);
    %{ stop_warp = warp(350) %}
    IGatewayContract.create_ask(gateway_addr, base_asset, quote_asset, 1, 300, 0);
    %{ stop_warp %}
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.buyer, target_contract_address=ids.gateway_addr) %}
    let (buyer_base_account_balance) = IBalancesContract.get_balance(balances_addr, buyer, base_asset, 1);
    let (buyer_base_locked_balance) = IBalancesContract.get_balance(balances_addr, buyer, base_asset, 0);
    let (buyer_quote_account_balance) = IBalancesContract.get_balance(balances_addr, buyer, quote_asset, 1);
    let (buyer_quote_locked_balance) = IBalancesContract.get_balance(balances_addr, buyer, quote_asset, 0);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.seller, target_contract_address=ids.gateway_addr) %}
    let (seller_base_account_balance) = IBalancesContract.get_balance(balances_addr, seller, base_asset, 1);
    let (seller_base_locked_balance) = IBalancesContract.get_balance(balances_addr, seller, base_asset, 0);
    let (seller_quote_account_balance) = IBalancesContract.get_balance(balances_addr, seller, quote_asset, 1);
    let (seller_quote_locked_balance) = IBalancesContract.get_balance(balances_addr, seller, quote_asset, 0);
    %{ stop_prank_callable() %}

    %{ print("[test_markets.cairo] buyer_base_account_balance: {}, buyer_base_locked_balance: {}, buyer_quote_account_balance: {}, buyer_quote_locked_balance: {}".format(ids.buyer_base_account_balance, ids.buyer_base_locked_balance, ids.buyer_quote_account_balance, ids.buyer_quote_locked_balance)) %}
    %{ print("[test_markets.cairo] seller_base_account_balance: {}, seller_base_locked_balance: {}, seller_quote_account_balance: {}, seller_quote_locked_balance: {}".format(ids.seller_base_account_balance, ids.seller_base_locked_balance, ids.seller_quote_account_balance, ids.seller_quote_locked_balance)) %}

    return ();
}
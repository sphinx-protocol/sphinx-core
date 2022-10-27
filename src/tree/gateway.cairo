%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.uint256 import Uint256
from lib.math_utils import MathUtils
from starkware.starknet.common.syscalls import get_caller_address
from src.tree.structs import Market
from src.tree.events import log_create_bid

const MAX_FELT = 7237005577332262320683916064616567226037794236132864326206141556383157321729; // 2^252 + 17 x 2^192 + 1

@contract_interface
namespace IMarketsContract {
    // Get market ID given two assets (or 0 if one doesn't exist).
    func get_market_ids(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
    }
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new market buy order to a given market.
    func buy(market_id : felt, max_price : felt, amount : felt) -> (success : felt) {
    }
    // Submit a new market sell order to a given market.
    func sell(market_id : felt, min_price : felt, amount : felt) -> (success : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func delete(order_id : felt) -> (success : felt) {
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
}

@contract_interface
namespace IERC20 {
    // Transfer amount to recipient
    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }
    // Get balance of account
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
}

// Stores IBalancesContract contract address.
@storage_var
func balances_addr() -> (addr : felt) {
}

// Stores IMarketsContract contract address.
@storage_var
func markets_addr() -> (addr : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    _balances_addr : felt, _markets_addr : felt
) {
    balances_addr.write(_balances_addr);
    markets_addr.write(_markets_addr);
    return ();
}

// Submit a new bid (limit buy order) to a given market.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
@external
func create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(base_asset, quote_asset);
    let (success) = IMarketsContract.create_bid(_markets_addr, market_id, price, amount, post_only);
    assert success = 1;
    return ();
}

// Submit a new ask (limit sell order) to a given market.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
@external
func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(base_asset, quote_asset);
    let (success) = IMarketsContract.create_ask(_markets_addr, market_id, price, amount, post_only);
    assert success = 1;
    return ();
}

// Submit a new market buy to a given market.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param amount : order size in number of tokens of quote asset
@external
func market_buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, amount : felt
) {
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(base_asset, quote_asset);
    let (success) = IMarketsContract.buy(_markets_addr, market_id, MAX_FELT, amount);
    assert success = 1;
    return ();
}

// Submit a new market sell to a given market.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param amount : order size in number of tokens of quote asset
@external
func market_sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, amount : felt
) {
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(base_asset, quote_asset);
    let (success) = IMarketsContract.sell(_markets_addr, market_id, 0, amount);
    assert success = 1;
    return ();
}

// Delete an order and update limits, markets and balances.
// @param order_id : ID of order
@external
func cancel_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) {
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(base_asset, quote_asset);
    let (success) = IMarketsContract.delete(_markets_addr, order_id);
    assert success = 1;
    return ();
}

// Deposit ERC20 token to exchange
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    let (caller) = get_caller_address();
    let (user_wallet_balance) = IERC20.balanceOf(asset, caller);
    let is_sufficient = is_le(amount, user_wallet_balance); 
    assert is_sufficient = 1;

    let (contract_address) = get_contract_address();
    let (amount_u256 : Uint256) = MathUtils.felt_to_uint256(amount);
    let (success) = IERC20.transferFrom(asset, caller, contract_address, amount_u256);
    assert success = 1;

    let (_balances_addr) = balances_addr.read();
    let (user_dex_balance) = IBalancesContract.get_balance(_balances_addr, caller, asset, 1);
    IBalancesContract.set_balance(_balances_addr, caller, asset, 1, user_dex_balance + amount);

    return ();
}

// Withdraw exchange balance as ERC20 token
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    let (_balances_addr) = balances_addr.read();
    let (caller) = get_caller_address();
    let (user_dex_balance) = IBalancesContract.get_balance(_balances_addr, caller, asset, 1);
    let is_sufficient = is_le(amount, user_dex_balance); 
    assert is_sufficient = 1;
    
    let (contract_address) = get_contract_address();
    IBalancesContract.set_balance(_balances_addr, caller, asset, 1, user_dex_balance - amount);
    let (amount_u256 : Uint256) = MathUtils.felt_to_uint256(amount);
    let (success) = IERC20.transferFrom(asset, contract_address, caller, amount_u256);
    assert success = 1;

    return ();
}
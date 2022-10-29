%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.uint256 import Uint256
from lib.math_utils import MathUtils
from starkware.starknet.common.syscalls import get_caller_address
from lib.openzeppelin.access.ownable.library import Ownable
from src.dex.structs import Market, User
from src.dex.events import log_create_bid

const MAX_FELT = 7237005577332262320683916064616567226037794236132864326206141556383157321729; // 2^252 + 17 x 2^192 + 1
const ETH_GOERLI_CHAIN_ID = 1;
const STARKNET_GOERLI_CHAIN_ID = 2;

@contract_interface
namespace IL2EthRemoteCoreContract {
    // Handle request from L1 EthRemoteCore contract to withdraw assets from DEX.
    func confirm_remote_withdraw(user_address: felt, token_address: felt, amount: felt) {
    }
}


@contract_interface
namespace IMarketsContract {
    // Get market ID given two assets (or 0 if one doesn't exist).
    func get_market_ids(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(caller : User, market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(caller : User, market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new market buy order to a given market.
    func buy(caller : User, market_id : felt, max_price : felt, amount : felt) -> (success : felt) {
    }
    // Submit a new market sell order to a given market.
    func sell(caller : User, market_id : felt, min_price : felt, amount : felt) -> (success : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func delete(caller : User, order_id : felt) -> (success : felt) {
    }
}

@contract_interface
namespace IBalancesContract {
    // Getter for user balances
    func get_balance(user : User, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // Setter for user balances
    func set_balance(user : User, asset : felt, in_account : felt, new_amount : felt) {
    }
}

@contract_interface
namespace IERC20 {
    // Transfer amount from sender to recipient
    func transferFrom(sender : felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }
    // Get balance of account
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
}

// Stores IBalancesContract contract address.
@storage_var
func balances_addr() -> (addr : felt) {
}
// Stores contract address of contract owner.
@storage_var
func owner_addr() -> (id : felt) {
}
// Stores IMarketsContract contract address.
@storage_var
func markets_addr() -> (addr : felt) {
}
// Stores L2EthRemoteCore contract address.
@storage_var
func l2_eth_remote_core_addr() -> (addr : felt) {
}
// 1 if markets_addr has been set, 0 otherwise
@storage_var
func is_markets_addr_set() -> (bool : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    owner : felt, _balances_addr : felt, _l2_eth_remote_core_addr : felt
) {
    Ownable.initializer(owner);
    balances_addr.write(_balances_addr);
    l2_eth_remote_core_addr.write(_l2_eth_remote_core_addr);
    return ();
}

// Set MarketsContract address.
// @dev Can only be called by contract owner and is write once.
@external
func set_markets_addr{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (_markets_addr : felt) {
    Ownable.assert_only_owner();
    let (is_set) = is_markets_addr_set.read();
    if (is_set == 0) {
        markets_addr.write(_markets_addr);
        is_markets_addr_set.write(1);
        handle_revoked_refs();
    } else {
        handle_revoked_refs();
    }
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
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(_markets_addr, base_asset, quote_asset);
    let (success) = IMarketsContract.create_bid(_markets_addr, caller, market_id, price, amount, post_only);
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
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(_markets_addr, base_asset, quote_asset);
    let (success) = IMarketsContract.create_ask(_markets_addr, caller, market_id, price, amount, post_only);
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
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(_markets_addr, base_asset, quote_asset);
    let (success) = IMarketsContract.buy(_markets_addr, caller, market_id, MAX_FELT, amount);
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
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (market_id) = IMarketsContract.get_market_ids(_markets_addr, base_asset, quote_asset);
    let (success) = IMarketsContract.sell(_markets_addr, caller, market_id, 0, amount);
    assert success = 1;
    return ();
}

// Delete an order and update limits, markets and balances.
// @param order_id : ID of order
@external
func cancel_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) {
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (success) = IMarketsContract.delete(_markets_addr, caller, order_id);
    assert success = 1;
    return ();
}

// Deposit ERC20 token to exchange.
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    let (caller) = get_caller_address();
    let (user_wallet_balance_u256) = IERC20.balanceOf(asset, caller);
    let user_wallet_balance : felt = user_wallet_balance_u256.low + user_wallet_balance_u256.high * 2 ** 128;
    let is_sufficient = is_le(amount, user_wallet_balance); 
    assert is_sufficient = 1;

    let (contract_address) = get_contract_address();
    let (amount_u256 : Uint256) = MathUtils.felt_to_uint256(amount);
    let (success) = IERC20.transferFrom(asset, caller, contract_address, amount_u256);
    assert success = 1;

    deposit_helper(caller, STARKNET_GOERLI_CHAIN_ID, asset, amount);
    return ();
}

// Relay remote deposit from other chain.
// @dev Only callable by L2EthRemoteCore contract
// @param user : felt representation of depositor's EOA
// @param chain_id : ID of chain where funds originated
// @param asset : asset address
// @param amount : amount to deposit
@external
func remote_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, chain_id : felt, asset : felt, amount : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_core_addr) = l2_eth_remote_core_addr.read();
    assert caller = _l2_eth_remote_core_addr;
    deposit_helper(user, chain_id, asset, amount);
    return ();
}

// Helper function to trigger deposit
func deposit_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, chain_id : felt, asset : felt, amount : felt
) {
    let (_balances_addr) = balances_addr.read();
    tempvar caller : User* = new User(addr=user, chain_id=chain_id);
    let (user_dex_balance) = IBalancesContract.get_balance(_balances_addr, [caller], asset, 1);
    IBalancesContract.set_balance(_balances_addr, [caller], asset, 1, user_dex_balance + amount);
    return ();
}

// Withdraw exchange balance as ERC20 token.
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    let (_balances_addr) = balances_addr.read();
    let (caller) = get_caller_address();
    withdraw_helper(caller, STARKNET_GOERLI_CHAIN_ID, asset, amount, caller);
    return ();
}

// Relay remote withdraw from other chain.
// @dev Only callable by L2EthRemoteCore contract
// @param user : felt representation of depositor's EOA
// @param chain_id : ID of chain where funds originated
// @param asset : asset address
// @param amount : amount to deposit
@external
func remote_withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, chain_id : felt, asset : felt, amount : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_core_addr) = l2_eth_remote_core_addr.read();
    assert caller = _l2_eth_remote_core_addr;
    if (chain_id == ETH_GOERLI_CHAIN_ID) {
        withdraw_helper(user, chain_id, asset, amount, _l2_eth_remote_core_addr);
        IL2EthRemoteCoreContract.confirm_remote_withdraw(_l2_eth_remote_core_addr, user, asset, amount);
    } else {
        with_attr error_message("Chain ID not valid") {
            assert 1 = 0;
        }
    }
    return ();
}

// Helper function to trigger withdrawal
func withdraw_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, chain_id : felt, asset : felt, amount : felt, recipient : felt
) {
    tempvar caller : User* = new User(addr=user, chain_id=chain_id);
    let (user_dex_balance) = IBalancesContract.get_balance(_balances_addr, [caller], asset, 1);
    let is_sufficient = is_le(amount, user_dex_balance); 
    assert is_sufficient = 1;
    
    IBalancesContract.set_balance(_balances_addr, [caller], asset, 1, user_dex_balance - amount);
    let (contract_address) = get_contract_address();
    let (amount_u256 : Uint256) = MathUtils.felt_to_uint256(amount);
    let (success) = IERC20.transferFrom(asset, contract_address, recipient, amount_u256);
    assert success = 1;
    return ();
}

// Utility function to handle revoked implicit references.
func handle_revoked_refs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    return ();
}
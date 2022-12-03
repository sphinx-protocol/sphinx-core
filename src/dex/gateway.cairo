%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import get_caller_address

from src.dex.orders import Orders
from src.dex.limits import Limits
from src.dex.balances import Balances
from src.dex.markets import Markets
from src.dex.structs import Market
from src.dex.events import log_create_bid
from src.utils.handle_revoked_refs import handle_revoked_refs
from lib.math_utils import MathUtils
from lib.openzeppelin.access.ownable.library import Ownable

//
// Constants
//

const MAX_FELT = 7237005577332262320683916064616567226037794236132864326206141556383157321729; // 2^252 + 17 x 2^192 + 1
const ETH_GOERLI_CHAIN_ID = 1;
const STARKNET_GOERLI_CHAIN_ID = 2;

//
// External contract interfaces
//

@contract_interface
namespace IL2EthRemoteCoreContract {
    // Handle request from L1 EthRemoteCore contract to withdraw assets from DEX.
    func remote_withdraw(user_address: felt, token_address: felt, amount: felt, chain_id : felt) {
    }
}

@contract_interface
namespace IERC20 {
    // Approve spender
    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }
    // Transfer amount to recipient
    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }
    // Transfer amount from sender to recipient
    func transferFrom(sender : felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }
    // Get balance of account
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
}

//
// Storage vars
//

// Stores L2EthRemoteCore contract address.
@storage_var
func l2_eth_remote_core_addr() -> (addr : felt) {
}
// 1 if L2EthRemoteCore contract address has been set, 0 otherwise
@storage_var
func is_eth_remote_core_set() -> (bool : felt) {
}
// Stores L2EthRemoteEIP712 contract address.
@storage_var
func l2_eth_remote_eip_712_addr() -> (addr : felt) {
}
// 1 if L2EthRemoteEIP712 has been set, 0 otherwise
@storage_var
func is_eth_remote_eip_712_set() -> (bool : felt) {
}

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    owner : felt
) {
    Ownable.initializer(owner);
    Orders.initialise();
    Limits.initialise();
    Markets.initialise();
    return ();
}

//
// Functions
//

// Set addresses of external contracts
// @dev Can only be called by contract owner
// @param _l2_eth_remote_core_addr : deployed contract address of L2EthRemoteCore
// @param _l2_eth_remote_eip_712_addr : deployed contract address of L2EthRemoteEIP712
@external
func set_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    _l2_eth_remote_core_addr : felt, 
    _l2_eth_remote_eip_712_addr : felt
) {
    Ownable.assert_only_owner();
    let (_is_eth_remote_core_set) = is_eth_remote_core_set.read();
    let (_is_eth_remote_eip_712_set) = is_eth_remote_eip_712_set.read();
    // with_attr error_message("[Gateway] set_addresses > Addresses have already been set") {
    //     assert _is_eth_remote_core_set + _is_eth_remote_eip_712_set = 0;
    // }
    l2_eth_remote_core_addr.write(_l2_eth_remote_core_addr);
    l2_eth_remote_eip_712_addr.write(_l2_eth_remote_eip_712_addr);
    is_eth_remote_core_set.write(1);
    is_eth_remote_eip_712_set.write(1);
    return ();
}

// Create a new market for exchanging between two assets.
// @dev Can only be called by contract owner
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
@external
func create_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt
) {
    Ownable.assert_only_owner();
    Markets.create_market(base_asset, quote_asset);
    return ();
}

// View bid or ask order book for a particular market
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param is_bid : 1 to view bid order book, 0 to view ask order book
// @return prices_len : length of array of limit prices
// @return prices : array of limit prices
// @return amounts_len : length of array of volumes
// @return amounts : array of volumes at each limit price
@view
func view_order_book{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, is_bid : felt
) -> (prices_len : felt, prices : felt*, amounts_len : felt, amounts : felt*) {
    alloc_locals;

    let (market_id) = Markets.get_market_ids(base_asset, quote_asset);
    let (market) = Markets.get_market(market_id);

    if (is_bid == 1) {
        let (prices, amounts, length) = Limits.view_limit_tree(market.bid_tree_id);
        return (prices_len=length, prices=prices, amounts_len=length, amounts=amounts);
    } else {
        let (prices, amounts, length) = Limits.view_limit_tree(market.ask_tree_id);
        return (prices_len=length, prices=prices, amounts_len=length, amounts=amounts);
    }
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
    create_bid_helper(caller, base_asset, quote_asset, price, amount, post_only);
    return ();
}

// Relay cross-chain request to submit a new bid (limit buy order) to a given market.
// @dev Can only be called by L2EthRemoteCore contract
// @param user : felt representation of user EOA
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
@external
func remote_create_bid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_create_bid > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    create_bid_helper(user, base_asset, quote_asset, price, amount, post_only);
    return ();
}

// Helper function to create bid.
func create_bid_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (market_id) = Markets.get_market_ids(base_asset, quote_asset);
    let (success) = Markets.create_bid(user, market_id, price, amount, post_only);
    with_attr error_message("[Gateway] create_bid_helper > Create bid unsuccessful") {
        assert success = 1;
    }
    return ();
}

// Submit a new ask (limit sell order) to a given market.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create ask in post only mode, 0 otherwise
@external
func create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (caller) = get_caller_address();
    create_ask_helper(caller, base_asset, quote_asset, price, amount, post_only);
    return ();
}

// Relay cross-chain request to submit a new ask (limit sell order) to a given market.
// @dev Can only be called by L2EthRemoteCore contract
// @param user : felt representation of user EOA
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param price : limit price of order
// @param amount : order size in number of tokens of quote asset
// @param post_only : 1 if create bid in post only mode, 0 otherwise
@external
func remote_create_ask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_create_ask > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    create_ask_helper(user, base_asset, quote_asset, price, amount, post_only);
    return ();
}

// Helper function to create ask.
func create_ask_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt
) {
    let (market_id) = Markets.get_market_ids(base_asset, quote_asset);
    let (success) = Markets.create_ask(user, market_id, price, amount, post_only);
    with_attr error_message("[Gateway] create_ask_helper > Create ask unsuccessful") {
        assert success = 1;
    }
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
    market_buy_helper(caller, base_asset, quote_asset, amount);
    return ();
}

// Relay cross-chain request to submit a new market buy to a given market.
// @param user : felt representation of user EOA
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param amount : order size in number of tokens of quote asset
@external
func remote_market_buy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, amount : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_market_buy > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    market_buy_helper(user, base_asset, quote_asset, amount);
    return ();
}

// Helper function to create market buy order.
func market_buy_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, amount : felt
) {
    let (market_id) = Markets.get_market_ids(base_asset, quote_asset);
    let (success) = Markets.buy(user, market_id, MAX_FELT, amount);
    with_attr error_message("[Gateway] market_buy_helper > Market buy unsuccessful") {
        assert success = 1;
    }
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
    market_sell_helper(caller, base_asset, quote_asset, amount);
    return ();
}

// Relay cross-chain request to submit a new market sell to a given market.
// @param user : felt representation of user EOA
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param amount : order size in number of tokens of quote asset
@external
func remote_market_sell{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, amount : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_market_sell > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    market_sell_helper(user, base_asset, quote_asset, amount);
    return ();
}

// Helper function to create market sell order.
func market_sell_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, base_asset : felt, quote_asset : felt, amount : felt
) {
    let (market_id) = Markets.get_market_ids(base_asset, quote_asset);
    let (success) = Markets.sell(user, market_id, 0, amount);
    with_attr error_message("[Gateway] market_sell_helper > Market sell unsuccessful") {
        assert success = 1;
    }
    return ();
}

// Delete an order and update limits, markets and balances.
// @param order_id : ID of order
@external
func cancel_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (order_id : felt) {
    let (caller) = get_caller_address();
    let (success) = Markets.delete(caller, order_id);
    with_attr error_message("[Gateway] cancel_order > Cancel order unsuccessful") {
        assert success = 1;
    }
    return ();
}

// Relay cross-chain request to cancel an order and update limits, markets and balances.
// @param user : felt representation of user EOA
// @param order_id : ID of order
@external
func remote_cancel_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, order_id : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_cancel_order > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    let (success) = Markets.delete(user, order_id);
    with_attr error_message("[Gateway] remote_cancel_order > Remote cancel order unsuccessful") {
        assert success = 1;
    }
    return ();
}

// Deposit ERC20 token to exchange.
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    let (caller) = get_caller_address();
    let (user_wallet_balance_u256) = IERC20.balanceOf(asset, caller);
    let (amount_u256) = MathUtils.felt_to_uint256(amount);
    let (is_sufficient) = uint256_le(amount_u256, user_wallet_balance_u256); 
    with_attr error_message("[Gateway] deposit > Deposit unsuccessful, depositing {amount_u256} but only {user_wallet_balance_u256} available") {
        assert is_sufficient = 1;
    }
    
    let (contract_address) = get_contract_address();
    let (success) = IERC20.transferFrom(asset, caller, contract_address, amount_u256);
    with_attr error_message("[Gateway] deposit > Transfer from {caller} to {contract_address} unsuccessful") {
        assert success = 1;
    }

    deposit_helper(caller, asset, amount);
    return ();
}

// Relay remote deposit from other chain.
// @dev Only callable by L2EthRemoteCore contract
// @param user : felt representation of depositor's EOA
// @param asset : asset address
// @param amount : amount to deposit
@external
func remote_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, amount : felt
) {
    let (caller) = get_caller_address();
    let (_l2_eth_remote_core_addr) = l2_eth_remote_core_addr.read();
    with_attr error_message("[Gateway] remote_deposit > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_core_addr;
    }
    deposit_helper(user, asset, amount);
    return ();
}

// Helper function to trigger deposit
func deposit_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, asset : felt, amount : felt
) {
    let (user_dex_balance) = Balances.get_balance(user, asset, 1);
    Balances.set_balance(user, asset, 1, user_dex_balance + amount);
    return ();
}

// Withdraw exchange balance as ERC20 token.
// @param asset : felt representation of ERC20 asset contract address
// @param amount : amount to deposit
@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset : felt, amount : felt) {
    alloc_locals;
    let (caller) = get_caller_address();
    withdraw_helper(caller, asset, amount);
    let (contract_address) = get_contract_address();
    let (amount_u256 : Uint256) = MathUtils.felt_to_uint256(amount);
    let (success) = IERC20.transferFrom(asset, contract_address, caller, amount_u256);
    with_attr error_message("[Gateway] withdraw > Transfer from {contract_address} to {caller} unsuccessful") {
        assert success = 1;
    }
    return ();
}

// Relay remote withdraw request from other chain.
// @dev Only callable by L2EthRemoteCore contract
// @param user : felt representation of depositor's EOA
// @param chain_id : ID of chain where funds originated
// @param asset : asset address
// @param amount : amount to deposit
@external
func remote_withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, chain_id : felt, asset : felt, amount : felt
) {
    alloc_locals;
    let (caller) = get_caller_address();
    let (_l2_eth_remote_eip_712_addr) = l2_eth_remote_eip_712_addr.read();
    with_attr error_message("[Gateway] remote_withdraw > Caller must be L2EthRemoteEIP712, got caller {caller}") {
        assert caller = _l2_eth_remote_eip_712_addr;
    }
    let (_l2_eth_remote_core_addr) = l2_eth_remote_core_addr.read();
    if (chain_id == ETH_GOERLI_CHAIN_ID) {
        withdraw_helper(user, asset, amount);
        IL2EthRemoteCoreContract.remote_withdraw(_l2_eth_remote_core_addr, user, chain_id, asset, amount);
        handle_revoked_refs();
    } else {
        with_attr error_message("[Gateway] remote_withdraw > Chain ID not valid") {
            assert 1 = 0;
        }
        handle_revoked_refs();
    }
    return ();
}

// Helper function to trigger withdrawal.
func withdraw_helper{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user : felt, asset : felt, amount : felt
) {
    let (user_dex_balance) = Balances.get_balance(user, asset, 1);
    let is_sufficient = is_le(amount, user_dex_balance); 
    
    with_attr error_message("[Gateway] withdraw_helper > Withdrawal unsuccessful, requesting {amount} but only {user_dex_balance} available") {
        assert is_sufficient = 1;
    }
    Balances.set_balance(user, asset, 1, user_dex_balance - amount);
    return ();
}

// Getter for user balances.
// @param user : felt representation of user's EOA
// @param asset : felt representation of ERC20 token contract address
// @param in_account : 1 for account balances, 0 for order balances
// @return amount : token balance
@view
func get_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, in_account : felt
) -> (amount : felt) {
    alloc_locals;
    let (amount) = Balances.get_balance(user, asset, in_account);
    return (amount=amount);
}

// Fetches quote for market order based on current order book.
// @param base_asset : felt representation of ERC20 base asset contract address
// @param quote_asset : felt representation of ERC20 quote asset contract address
// @param is_buy : 1 for market buy order, 0 for market sell order
// @param amount : size of order in terms of quote asset
// @return price : quote price
@view
func fetch_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, is_buy : felt, amount : felt
) -> (price : felt) {
    let (price) = Markets.fetch_quote(base_asset, quote_asset, is_buy, amount);
    return (price=price);
}
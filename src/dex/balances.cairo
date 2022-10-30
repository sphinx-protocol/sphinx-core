%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address
from lib.openzeppelin.access.ownable.library import Ownable
from src.utils.handle_revoked_refs import handle_revoked_refs

// Stores user balances.
@storage_var
func account_balances(user : felt, asset : felt) -> (amount : felt) {
}
// Stores user balances locked in open orders.
@storage_var
func order_balances(user : felt, asset : felt) -> (amount : felt) {
}
// Stores contract address of MarketsContract.
@storage_var
func markets_addr() -> (id : felt) {
}
// 1 if markets_addr has been set, 0 otherwise
@storage_var
func is_markets_addr_set() -> (bool : felt) {
}
// Stores contract address of GatewayContract.
@storage_var
func gateway_addr() -> (id : felt) {
}
// 1 if gateway_addr has been set, 0 otherwise
@storage_var
func is_gateway_addr_set() -> (bool : felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (owner : felt) {
    Ownable.initializer(owner);
    return ();
}

// Set MarketsContract and GatewayContract address.
// @dev Can only be called by contract owner and is write once.
@external
func set_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    _markets_addr : felt, _gateway_addr : felt
) {
    Ownable.assert_only_owner();
    let (_is_markets_addr_set) = is_markets_addr_set.read();
    let (_is_gateway_addr_set) = is_gateway_addr_set.read();
    assert _is_markets_addr_set + _is_gateway_addr_set = 0;
    markets_addr.write(_markets_addr);
    gateway_addr.write(_gateway_addr);
    is_markets_addr_set.write(1);
    is_gateway_addr_set.write(1);
    return ();
}

// Getter for user balances
// @param user : User EOA
// @param asset : felt representation of ERC20 token contract address
// @param in_account : 1 for account balances, 0 for order balances
// @return amount : token balance
@view
func get_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, in_account : felt
) -> (amount : felt) {
    check_permissions();
    if (in_account == 1) {
        let (amount) = account_balances.read(user, asset);
        return (amount=amount);
    } else {
        let (amount) = order_balances.read(user, asset);
        return (amount=amount);
    }
}

// Setter for user balances
// @param user : User EOA
// @param asset : felt representation of ERC20 token contract address
// @param in_account : 1 for account balances, 0 for order balances
// @param amount : new token balance
@external
func set_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, in_account : felt, new_amount : felt
) {
    check_permissions();
    if (in_account == 1) {
        account_balances.write(user, asset, new_amount);
        return ();
    } else {
        order_balances.write(user, asset, new_amount);
        return ();
    }
}

// Transfer balance from one user to another. 
// @param sender : sender EOA
// @param recipient : recipient EOA
// @param asset : felt representation of ERC20 token contract address
// @param amount : token balance
// @return success : 1 if successful, 0 otherwise
@external
func transfer_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    sender : felt, recipient : felt, asset : felt, amount : felt
) -> (success : felt) {
    alloc_locals;
    check_permissions();
    let (sender_balance) = get_balance(sender, asset, 1);
    let is_sufficient = is_le(amount, sender_balance);
    let is_positive = is_le(1, amount);
    if (is_sufficient + is_positive == 2) {
        let (recipient_balance) = get_balance(recipient, asset, 1);
        set_balance(sender, asset, 1, sender_balance - amount);
        set_balance(recipient, asset, 1, recipient_balance + amount);
        return (success=1);
    } else {
        return (success=0);
    }
}

// Transfer account balance to order balance.
// @param user : User EOA
// @param asset : felt representation of ERC20 token contract address
// @param amount : balance to transfer to open order
// @return success : 1 if successful, 0 otherwise
@external
func transfer_to_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, amount : felt
) -> (success : felt) {
    alloc_locals;
    check_permissions();
    let (balance) = get_balance(user, asset, 1);
    let is_sufficient = is_le(amount, balance);
    let is_positive = is_le(1, amount);
    if (is_sufficient + is_positive == 2) {
        let (locked_balance) = get_balance(user, asset, 0);
        set_balance(user, asset, 1, balance - amount);
        set_balance(user, asset, 0, locked_balance + amount);
        let (user_account_balance) = get_balance(user, asset, 1);
        let (user_locked_balance) = get_balance(user, asset, 0);        
        return (success=1);
    } else {
        return (success=0);
    }   
}

// Transfer order balance to account balance.
// @param user : User EOA
// @param asset : felt representation of ERC20 token contract address
// @param amount : balance to transfer from open order to account balance
// @return success : 1 if successful, 0 otherwise
@external
func transfer_from_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, amount : felt
) -> (success : felt) {
    alloc_locals;
    check_permissions();
    let (locked_balance) = get_balance(user, asset, 0);
    let is_sufficient = is_le(amount, locked_balance);
    let is_positive = is_le(1, amount);
    if (is_sufficient + is_positive == 2) {
        let (balance) = get_balance(user, asset, 1);
        set_balance(user, asset, 0, locked_balance - amount);
        set_balance(user, asset, 1, balance + amount);
        let (user_account_balance) = get_balance(user, asset, 1);
        let (user_locked_balance) = get_balance(user, asset, 0);
        return (success=1);
    } else {
        return (success=0);
    }   
}

// Utility function to check that caller is either contract owner, markets contract, or gateway contract.
@view
func check_permissions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    alloc_locals;
    let (caller) = get_caller_address();
    let (_markets_addr) = markets_addr.read();
    let (_gateway_addr) = gateway_addr.read();
    if (caller == _markets_addr) {
        return ();
    }
    if (caller == _gateway_addr) {
        return ();
    }
    with_attr error_message("Caller does not have permission to call this function.") {
        assert 1 = 0;
    }
    return ();
}
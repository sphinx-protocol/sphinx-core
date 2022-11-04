%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_lt_felt, assert_le
from starkware.starknet.common.messages import send_message_to_l1
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s_bigend
from lib.openzeppelin.access.ownable.library import Ownable
from lib.math_utils import MathUtils

// 
// External contract interfaces
//

@contract_interface
namespace IGatewayContract {
    // Relay remote deposit from other chain
    func remote_deposit(user : felt, asset : felt, amount : felt) {
    }
    // Relay remote withdraw from other chain.
    func remote_withdraw(user : felt, chain_id : felt, asset : felt, amount : felt) {
    }
}

// 
// Storage vars
//

// Contract address for L1 EthRemoteCore
@storage_var
func l1_eth_remote_address() -> (res : felt) {
}
// 1 if contract address for L1 EthRemoteCore has been set, 0 otherwise
@storage_var
func is_l1_eth_remote_addr_set() -> (bool : felt) {
}
// Contract address for GatewayContract
@storage_var
func gateway_addr() -> (res : felt) {
}
// 1 if contract address for GatewayContract has been set, 0 otherwise
@storage_var
func is_gateway_addr_set() -> (bool : felt) {
}
// Nonce
// @storage_var
// func nonce() -> (nonce : felt) {
// }
// Nullifiers
@storage_var
func nullifiers(nullifier : Uint256) -> (exist : felt) {
}

// 
// Events (for Apibara)
//

// Log remote deposit 
@event
func log_remote_deposit(user_address : felt, token_address: felt, amount: felt, chain_id : felt) {
}
// Log remote withdraw
@event
func log_remote_withdraw(user_address : felt, token_address: felt, amount: felt, chain_id : felt) {
}

// 
// Constructor
//

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (owner: felt) {
    Ownable.initializer(owner);
    return ();
}

// 
// Functions
//

@external
func set_addresses{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    _l1_eth_remote_address: felt, _gateway_addr : felt
) {
    Ownable.assert_only_owner();
    let (is_remote_set) = is_l1_eth_remote_addr_set.read();
    let (is_gateway_set) = is_gateway_addr_set.read();
    assert is_remote_set + is_gateway_set = 0;
    l1_eth_remote_address.write(_l1_eth_remote_address);
    gateway_addr.write(_gateway_addr);
    is_l1_eth_remote_addr_set.write(1);
    is_gateway_addr_set.write(1);
    return ();
}

// @view
// func view_nonce{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} () -> (current_nonce: felt) {
//     let (current_nonce) = nonce.read();
//     return (current_nonce=current_nonce);
// }

// Handle request from L1 EthRemoteCore contract to deposit assets to DEX.
// @l1_handler
@external
func remote_deposit{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
} (
    from_address: felt, user_address: felt, token_address: felt, amount: felt, chain_id : felt
) -> (success : felt) {
    alloc_locals;

    // Make sure the message was sent by the intended L1 contract.
    let (_l1_eth_remote_address) = l1_eth_remote_address.read();
    assert from_address = _l1_eth_remote_address;

    let (user_address_u256) = MathUtils.felt_to_uint256(user_address);
    let (token_address_u256) = MathUtils.felt_to_uint256(token_address);
    let (amount_u256) = MathUtils.felt_to_uint256(amount);
    // let (nonce_u256) = MathUtils.felt_to_uint256(nonce);
    let (chain_id_u256) = MathUtils.felt_to_uint256(chain_id);

    let (payload_data : Uint256*) = alloc();
    assert payload_data[0] = user_address_u256;
    assert payload_data[1] = token_address_u256;
    assert payload_data[2] = amount_u256;
    // assert payload_data[3] = nonce_u256;
    assert payload_data[3] = chain_id_u256;

    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;

    let (nullifier) = _get_keccak_hash{keccak_ptr=keccak_ptr}(4, payload_data);
    let (exist) = nullifiers.read(nullifier);

    // Prevent double deposit
    if (exist == 1) {
        return (success=0);
    }
    nullifiers.write(nullifier, 1);
    
    let (_gateway_addr) = gateway_addr.read();
    IGatewayContract.remote_deposit(_gateway_addr, user_address, token_address, amount); 
    log_remote_deposit.emit(user_address, token_address, amount, chain_id);

    return (success=1);
}

// Send confirmation to L1 EthRemoteCore contract to release assets to users.
@external
func remote_withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    user_address: felt, chain_id : felt, token_address: felt, amount: felt
) {
    let (caller) = get_caller_address();
    let (_gateway_addr) = gateway_addr.read();
    assert caller = _gateway_addr;

    // let (current_nonce) = nonce.read();

    let (message_payload : felt*) = alloc();
    assert message_payload[0] = user_address;
    assert message_payload[1] = token_address;
    assert message_payload[2] = amount;
    // assert message_payload[3] = current_nonce;
    assert message_payload[3] = chain_id;

    // nonce.write(current_nonce + 1);

    let (_l1_eth_remote_address) = l1_eth_remote_address.read();
    send_message_to_l1(
        to_address=_l1_eth_remote_address,
        payload_size=4,
        payload=message_payload,
    );

    log_remote_withdraw.emit(user_address, token_address, amount, chain_id);

    return ();
}

func _get_keccak_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
    uint256_words_len: felt, uint256_words: Uint256*
) -> (hash: Uint256) {
        let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words);
        return (hash,);
}
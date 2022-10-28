%lang starknet

from starkware.cairo.common.cairo_builtins import (HashBuiltin, BitwiseBuiltin)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_lt_felt, assert_le
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s_bigend

from contracts.starknet.lib.math_utils import MathUtils

@contract_interface
namespace IGatewayContract {
    // Deposit ERC20 token to exchange
    func deposit(asset : felt, amount : felt) {
    }
    // Withdraw exchange balance as ERC20 token
    func withdraw(asset : felt, amount : felt) {
    }
}

@event
func log_notify_L1_contract(user_address : felt, token_address: felt, amount: felt, nonce: felt){
}

@storage_var
func L1_gateway_address() -> (res : felt){
}

@storage_var
func nonce() -> (nonce : felt){
}

@storage_var
func nullifiers(nullifier : Uint256) -> (exist : felt){
}

@view
func view_nonce{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}() -> (currentNonce: felt){
    let (currentNonce) = counter.read();
    return (currentNonce=currentNonce);
}


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _L1_gateway_address: felt
){
    L1_gateway_address.write(_L1_gateway_address);
    return ();
}

@external
func notify_L1_remote_contract{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(user_address: felt, token_address: felt, amount: felt){
    let (gateway_addr) = L1_gateway_address.read();

    // TODO: check that user has enough tokens in mapping
    // reduce amount from mapping 
    // transfer back 1000 USDC from DEX to lender

    let (currentNonce) = nonce.read();

    let (message_payload : felt*) = alloc();
    assert message_payload[0] = user_address;
    assert message_payload[1] = token_address;
    assert message_payload[2] = amount;
    assert message_payload[3] = currentNonce;

    nonce.write(currentNonce + 1);

    send_message_to_l1(
        to_address=gateway_addr,
        payload_size=4,
        payload=message_payload,
    );

    log_notify_L1_contract.emit(user_address, token_address, amount, currentNonce);

    return ();
}

@l1_handler
func receive_from_l1{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}(from_address: felt, user_address: felt, token_address: felt, amount: felt, nonce: felt) {
    alloc_locals;

    // Make sure the message was sent by the intended L1 contract.
    let (gateway_addr) = L1_gateway_address.read();
    assert from_address = gateway_addr;

    let (user_address_u256) = MathUtils.felt_to_uint256(user_address);
    let (token_address_u256) = MathUtils.felt_to_uint256(token_address);
    let (amount_u256) = MathUtils.felt_to_uint256(amount);
    let (nonce_u256) = MathUtils.felt_to_uint256(nonce);

    let (payload_data : Uint256*) = alloc();
    assert payload_data[0] = user_address_u256;
    assert payload_data[1] = token_address_u256;
    assert payload_data[2] = amount_u256;
    assert payload_data[3] = nonce_u256;

    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;

    let (nullifier) = _get_keccak_hash{keccak_ptr=keccak_ptr}(4, payload_data);
    let (exist) = nullifiers.read(nullifier);

    // prevent double deposit
    if (exist == 1) {
        return ();
    }

    nullifiers.write(nullifier, 1);

    // TODO: fund tokens to account
    // Transfer 1000 USDC from lender to user account
    // credit 1000 USDC inside mapping
    return ();
}

func _get_keccak_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
    uint256_words_len: felt, uint256_words: Uint256*
) -> (hash: Uint256) {
    let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words);
    return (hash,);
}
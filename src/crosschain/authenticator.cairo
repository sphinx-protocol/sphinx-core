// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)

from src.lib.eip712 import EIP712
from src.lib.execute import execute
from src.lib.math_utils import MathUtils

//
// @title Ethereum Signature Authenticator
// @author SnapshotLabs
// @notice Contract to allow authentication of Snapshot X users via an Ethereum signature
//

// @dev Authentication of an action (vote or propose) via an Ethereum signature
// @param amount is the amount of tokens
// @param strategy is the action requested. 0 is for place an order. 1 is to cancel an order and 2 is to perform a withdrawal
// @param r Signature parameter
// @param s Signature parameter
// @param v Signature parameter
// @param salt Signature salt
// @param target Address of the space contract
// @param function_selector Function selector of the action
// @param calldata Calldata array required for the action
@external
func authenticate{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    price: felt,
    amount: felt,
    strategy: felt,
    r: Uint256,
    s: Uint256,
    v: felt,
    salt: Uint256,
    market: felt,
    calldata_len: felt,
    calldata: felt*,
) -> () {
    // verify the signature
    EIP712.verify_signed_message(price, amount, strategy, r, s, v, salt, market, calldata_len, calldata);

    if (strategy == 0) {
    // TODO: 
    }

    if (strategy == 1) {
    // TODO: 
    }

    if (strategy == 2) {
    // TODO: 
    }

    return ();
}
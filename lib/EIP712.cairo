// SPDX-License-Identifier: MIT
// @title EIP712 Library
// @author Stark X - Remi
// @reference: The code was inspired from the Snapshot X EIP 712 implementation. Source: https://github.com/snapshot-labs/sx-core/blob/05e0b1be3000d91d263fe85069f1bf571d4a5767/contracts/starknet/lib/eip712.cairo
// @notice A library for verifying Ethereum EIP712 signatures on typed data
// @dev Refer to the official EIP for more information: https://eips.ethereum.org/EIPS/eip-712

%lang starknet

from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_uint256s_bigend,
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)

from contracts.starknet.lib.math_utils import MathUtils
from contracts.starknet.lib.array_utils import ArrayUtils

const ETHEREUM_PREFIX = 0x1901;

// Domain Separator: (Goerli chain id)
// name: 'stark-x',
// version: '1'
// chainId: '5'
const DOMAIN_HASH_HIGH = 0x86de7eea74b928333a5f774079924393;
const DOMAIN_HASH_LOW = 0x01c2ce4f5a9b9bef74e2e79f59ff98f0;

// keccak256("Order(bytes32 authenticator,bytes32 market,address author,address token,uint256 amount,uint256 price,uint256 strategy,uint256 salt)")
// d4eeb39eaeef500fca5d670228cd9e51e7509352df8ac73b20f027951362af4c
const ORDER_TYPE_HASH_HIGH = 0xd4eeb39eaeef500fca5d670228cd9e51;
const ORDER_TYPE_HASH_LOW = 0xe7509352df8ac73b20f027951362af4c;

// @dev Signature salts store
@storage_var
func EIP712_salts(eth_address: felt, salt: Uint256) -> (already_used: felt) {
}

namespace EIP712 {
    // @dev Asserts that a signature to cast a vote is valid
    // @param r Signature parameter
    // @param s Signature parameter
    // @param v Signature parameter
    // @param salt Signature salt
    // @param target Address of the space contract where the user is casting a vote
    // @param calldata Vote calldata
    func verify_signed_message{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
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
    ) {
        alloc_locals;

        MathUtils.assert_valid_uint256(r);
        MathUtils.assert_valid_uint256(s);
        MathUtils.assert_valid_uint256(salt);

        let voter_address = calldata[0];
        let token_address = calldata[1];
        // let amount = calldata[2];

        let (authenticator_address) = get_contract_address();
        let (auth_address_u256) = MathUtils.felt_to_uint256(authenticator_address);

        // Ensure voter has not already used this salt in a previous action
        let (already_used) = EIP712_salts.read(voter_address, salt);
        with_attr error_message("EIP712: Salt already used") {
            assert already_used = 0;
        }

        let (market_u256) = MathUtils.felt_to_uint256(market);
        let (amount_u256) = MathUtils.felt_to_uint256(amount);
        let (price_u256) = MathUtils.felt_to_uint256(price);
        let (strategy_u256) = MathUtils.felt_to_uint256(strategy);

        let (voter_address_u256) = MathUtils.felt_to_uint256(voter_address);
        let (token_address_u256) = MathUtils.felt_to_uint256(token_address);

        // Now construct the data hash (hashStruct)
        let (data: Uint256*) = alloc();
        assert data[0] = Uint256(ORDER_TYPE_HASH_LOW, ORDER_TYPE_HASH_HIGH);
        assert data[1] = auth_address_u256;
        assert data[2] = market_u256;
        assert data[3] = voter_address_u256;
        assert data[4] = token_address_u256;
        assert data[5] = amount_u256;
        assert data[6] = price_u256;
        assert data[7] = strategy_u256;
        assert data[8] = salt;

        let (local keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;

        let (hash_struct) = _get_keccak_hash{keccak_ptr=keccak_ptr}(9, data);

        // Prepare the encoded data
        let (prepared_encoded: Uint256*) = alloc();
        assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH);
        assert prepared_encoded[1] = hash_struct;

        // Prepend the ethereum prefix
        let (encoded_data: Uint256*) = alloc();
        _prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded);

        // Now go from Uint256s to Uint64s (required in order to call `keccak`)
        let (signable_bytes) = alloc();
        let signable_bytes_start = signable_bytes;
        keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1);

        // Compute the hash
        let (hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
            inputs=signable_bytes_start, n_bytes=2 * 32 + 2
        );

        // `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
        // We substract `27` because `v` = `{0, 1} + 27`
        verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(hash, r, s, v - 27, voter_address);

        // Verify that all the previous keccaks are correct
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        // Write the salt to prevent replay attack
        EIP712_salts.write(voter_address, salt, 1);
        return ();
    }

    // Adds a 2 bytes (16 bits) `prefix` to a 16 bytes (128 bits) `value`.
    func _add_prefix128{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(value: felt, prefix: felt) -> (
        result: felt, carry: felt
    ) {
        // Shift the prefix by 128 bits
        let shifted_prefix = prefix * 2 ** 128;
        // `with_prefix` is now 18 bytes long
        let with_prefix = shifted_prefix + value;
        // Create 2 bytes mask
        let overflow_mask = 2 ** 16 - 1;
        // Extract the last two bytes of `with_prefix`
        let (carry) = bitwise_and(with_prefix, overflow_mask);
        // Compute the new number, right shift by 16
        let result = (with_prefix - carry) / 2 ** 16;
        return (result, carry);
    }

    // Concatenates a 2 bytes long `prefix` and `input` to `output`.
    // `input_len` is the number of `Uint256` in `input`.
    func _prepend_prefix_2bytes{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
        prefix: felt, output: Uint256*, input_len: felt, input: Uint256*
    ) {
        if (input_len == 0) {
            // Done, simlpy store the prefix in the `.high` part of the last Uint256, and
            // make sure we left shift it by 28 (32 - 4)
            assert output[0] = Uint256(0, prefix * 16 ** 28);
            return ();
        } else {
            let num = input[0];

            let (w1, high_carry) = _add_prefix128(num.high, prefix);
            let (w0, low_carry) = _add_prefix128(num.low, high_carry);

            let res = Uint256(w0, w1);
            assert output[0] = res;

            // Recurse, using the `low_carry` as `prefix`
            _prepend_prefix_2bytes(low_carry, &output[1], input_len - 1, &input[1]);
            return ();
        }
    }

    // Computes the `keccak256` hash from an array of `Uint256`. Does NOT call `finalize_keccak`,
    // so the caller needs to make she calls `finalize_keccak` on the `keccak_ptr` once she's done
    // with it.
    func _get_keccak_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
        uint256_words_len: felt, uint256_words: Uint256*
    ) -> (hash: Uint256) {
        let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words);

        return (hash,);
    }
}
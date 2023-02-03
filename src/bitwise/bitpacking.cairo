%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem, uint256_and

from src.dex.structs import Order


const FULL_SLOT = 2 ** 128;
const HALF_SLOT = 2 ** 64;

//
// Functions
//

// Packs Order into two Uint256 structs.
// @params Order fields
// @return order_slab0 : slab containing first half of bitpacked Order struct
// @return order_slab1 : slab containing second half of bitpacked Order struct
@external
func pack_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    order : Order
) -> (order_slab0 : Uint256, order_slab1 : Uint256) {
    alloc_locals;
    
    check_size_valid(order.order_id, 64);
    check_size_valid(order.next_id, 64);
    check_size_valid(order.price, 64);
    check_size_valid(order.amount, 64);
    check_size_valid(order.filled, 64);
    check_size_valid(order.owner_id, 64);
    check_size_valid(order.limit_id, 64);
    check_size_valid(order.is_buy, 1);

    local slab0_high = order.order_id * HALF_SLOT + order.next_id;
    local slab0_low = order.price * HALF_SLOT + order.amount;
    local slab1_high = order.filled * HALF_SLOT + order.owner_id;
    local slab1_low = order.limit_id * HALF_SLOT + order.is_buy;

    local slab0 : Uint256 = Uint256(slab0_low, slab0_high);
    local slab1 : Uint256 = Uint256(slab1_low, slab1_high);

    return (order_slab0=slab0, order_slab1=slab1);
}

// Checks size of order params against max sizes.
// @params value : order param
// @params bits : maximum size of value in bits
func check_size_valid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(value : felt, bits : felt) {
    let (size) = pow(2, bits);
    let is_valid = is_le(value, size);
    with_attr error_message("Value too large given size limit") {
        assert is_valid = 1;
    }
    return ();
}


// // Unpacks order slabs into order struct.
// // @params Order fields
// // @return order_slab0 : slab containing first half of bitpacked Order struct
// // @return order_slab1 : slab containing second half of bitpacked Order struct
// @external
// func unpack_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
//     order_slab0 : Uint256, order_slab1 : Uint256
// ) -> (order : Order) {
//     alloc_locals;
    

// }

// Retrieves data from slab given a position and length in bots.
// @params slab : Uint256 struct containing packed data
// @params pos : position of first bit in slab
// @params len : length of data in bits
@external
func unpack_slab_in_range{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    slab : Uint256, pos : felt, len : felt) -> (val : felt
) {
    alloc_locals;
    
    let is_pos_valid = is_le(pos, 256);
    let is_len_valid = is_le(len, 256);
    let is_pos_len_valid = is_le(pos + len - 1, 256);
    with_attr error_message("Position or length out of range") {
        assert is_pos_valid + is_len_valid + is_pos_len_valid = 3;
    }

    let is_lower_half = is_le(128, pos); 
    let crosses_halfway = is_le(128, pos + len - 2); 
    if (is_lower_half == 1) {
        let (mask) = pow(2, 256 - pos + 1);
        let (masked) = uint256_and(slab, Uint256(mask - 1, 0));
        let (div) = pow(2, 256 - pos - len + 1);
        let (val, _) = unsigned_div_rem(masked.low, div);
        return (val=val);
    } else {
        let (mask_high) = pow(2, 128 - pos + 1);
        let mask_low = 2 ** 128 - 1;
        let (masked) = uint256_and(slab, Uint256(mask_low - 1, mask_high - 1));
        if (crosses_halfway == 1) {
            let (mult_high) = pow(2, pos + len - 128 - 1);
            let (div_low) = pow(2, 256 - pos - len + 1);
            let (low, _) = unsigned_div_rem(masked.low, div_low);
            return (val = low + masked.high * mult_high);
        } else {
            let (div) = pow(2, 128 - pos - len + 1);
            let (val, _) = unsigned_div_rem(masked.high, div);
            return (val=val);
        }
    }
}

// Retrieves order_id from order_slab0.
// @params order_slab0 : slab containing first half of packed Order struct
// @return order_id : order ID
@external
func retrieve_order_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    order_slab0 : Uint256) -> (order_id : felt
) {
    alloc_locals;
    let (order_id) = unpack_slab_in_range(order_slab0, 1, 64);
    return (order_id=order_id);
}

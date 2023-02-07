%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem, uint256_and

from src.dex.structs import Order, Limit, Market, Asset, PackedOrder, PackedLimit, PackedMarket, PackedAsset

//
// Constants
//

const ORDER_ID_SIZE = 40;
const LIMIT_ID_SIZE = 40;
const TREE_ID_SIZE = 40;
const MARKET_ID_SIZE = 20;
const OWNER_ID_SIZE = 40;
const ASSET_ID_SIZE = 20;

const PRICE_SIZE = 88;
const AMOUNT_SIZE = 88;
const SYMBOL_SIZE = 40;
const LENGTH_SIZE = 16;
const DECIMALS_SIZE = 6;
const IS_BID_SIZE = 1;

//
// Functions
//

// Packs Order struct into slabs.
// @param order : Order struct
// @return PackedOrder : Order struct bitpacked into 128-bit slabs
@external
func pack_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    order : Order) -> (packed_order : PackedOrder
) {
    alloc_locals;
    
    check_size_valid(order.order_id, ORDER_ID_SIZE);
    check_size_valid(order.is_bid, IS_BID_SIZE);
    check_size_valid(order.next_id, ORDER_ID_SIZE);
    check_size_valid(order.limit_id, LIMIT_ID_SIZE);
    check_size_valid(order.amount, AMOUNT_SIZE);
    check_size_valid(order.owner_id, OWNER_ID_SIZE);

    let (order_id_exp) = pow(2, IS_BID_SIZE + ORDER_ID_SIZE + LIMIT_ID_SIZE);
    let (is_bid_exp) = pow(2, ORDER_ID_SIZE + LIMIT_ID_SIZE);
    let (limit_id_exp) = pow(2, LIMIT_ID_SIZE);
    let (amount_exp) = pow(2, OWNER_ID_SIZE);

    local slab0 = order.order_id * order_id_exp + order.is_bid * is_bid_exp + order.next_id * limit_id_exp + order.limit_id;
    local slab1 = order.amount * amount_exp + order.owner_id;
    local packed_order : PackedOrder = PackedOrder(slab0, slab1);

    return (packed_order=packed_order);
}

// Unpacks PackedOrder into Order struct.
// @params packed_order : packed order
// @return order : unpacked Order
@external
func unpack_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    packed_order : PackedOrder) -> (order : Order
) {
    alloc_locals;

    const stuffing0 = 128 - ORDER_ID_SIZE - IS_BID_SIZE - ORDER_ID_SIZE - LIMIT_ID_SIZE;
    const stuffing1 = 128 - AMOUNT_SIZE - OWNER_ID_SIZE;

    let (order_id) = unpack_slab_in_range(packed_order.slab0, 1, ORDER_ID_SIZE, stuffing0);
    let (is_bid) = unpack_slab_in_range(packed_order.slab0, 1 + ORDER_ID_SIZE, IS_BID_SIZE, stuffing0);
    let (next_id) = unpack_slab_in_range(packed_order.slab0, 1 + ORDER_ID_SIZE + IS_BID_SIZE, ORDER_ID_SIZE, stuffing0);
    let (limit_id) = unpack_slab_in_range(packed_order.slab0, 1 + ORDER_ID_SIZE + IS_BID_SIZE + ORDER_ID_SIZE, LIMIT_ID_SIZE, stuffing0);
    let (amount) = unpack_slab_in_range(packed_order.slab1, 1, AMOUNT_SIZE, stuffing1);
    let (owner_id) = unpack_slab_in_range(packed_order.slab1, 1 + AMOUNT_SIZE, OWNER_ID_SIZE, stuffing1);

    local order : Order = Order(order_id, next_id, is_bid, amount, owner_id, limit_id);
    return (order=order);
}

// Packs Limit struct into slabs.
// @param limit : Limit struct
// @return PackedLimit : Limit struct bitpacked into 128-bit slabs
@external
func pack_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    limit : Limit) -> (packed_limit : PackedLimit
) {
    alloc_locals;
    
    check_size_valid(limit.limit_id, LIMIT_ID_SIZE);
    check_size_valid(limit.price, PRICE_SIZE);
    check_size_valid(limit.left_id, LIMIT_ID_SIZE);
    check_size_valid(limit.amount, AMOUNT_SIZE);
    check_size_valid(limit.right_id, LIMIT_ID_SIZE);
    check_size_valid(limit.filled, AMOUNT_SIZE);
    check_size_valid(limit.length, LENGTH_SIZE);
    check_size_valid(limit.is_bid, IS_BID_SIZE);
    check_size_valid(limit.head_id, ORDER_ID_SIZE);
    check_size_valid(limit.tree_id, TREE_ID_SIZE);
    check_size_valid(limit.market_id, MARKET_ID_SIZE);

    let (limit_id_exp) = pow(2, PRICE_SIZE);
    let (limit_left_id_exp) = pow(2, AMOUNT_SIZE);
    let (limit_right_id_exp) = pow(2, AMOUNT_SIZE);
    let (limit_length_exp) = pow(2, IS_BID_SIZE + ORDER_ID_SIZE + TREE_ID_SIZE + MARKET_ID_SIZE);
    let (limit_is_bid_exp) = pow(2, ORDER_ID_SIZE + TREE_ID_SIZE + MARKET_ID_SIZE);
    let (limit_head_id_exp) = pow(2, TREE_ID_SIZE + MARKET_ID_SIZE);
    let (limit_tree_id_exp) = pow(2, MARKET_ID_SIZE);

    local slab0 = limit.limit_id * limit_id_exp + limit.price;
    local slab1 = limit.left_id * limit_left_id_exp + limit.amount;
    local slab2 = limit.right_id * limit_right_id_exp + limit.filled;
    local slab3 = limit.length * limit_length_exp + limit.is_bid * limit_is_bid_exp + limit.head_id * limit_head_id_exp + limit.tree_id * limit_tree_id_exp + limit.market_id;

    local packed_limit : PackedLimit = PackedLimit(slab0, slab1, slab2, slab3);
    return (packed_limit=packed_limit);
}

// Unpacks PackedLimit into Limit struct.
// @params packed_limit : packed limit
// @return limit : unpacked Limit
@external
func unpack_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    packed_limit : PackedLimit) -> (limit : Limit
) {
    alloc_locals;

    const stuffing0 = 128 - LIMIT_ID_SIZE - PRICE_SIZE;
    const stuffing1 = 128 - LIMIT_ID_SIZE - AMOUNT_SIZE;
    const stuffing2 = 128 - LIMIT_ID_SIZE - AMOUNT_SIZE;
    const stuffing3 = 128 - LENGTH_SIZE - IS_BID_SIZE - ORDER_ID_SIZE - TREE_ID_SIZE - MARKET_ID_SIZE;

    let (limit_id) = unpack_slab_in_range(packed_limit.slab0, 1, LIMIT_ID_SIZE, stuffing0);
    let (price) = unpack_slab_in_range(packed_limit.slab0, 1 + LIMIT_ID_SIZE, PRICE_SIZE, stuffing0);
    let (left_id) = unpack_slab_in_range(packed_limit.slab1, 1, LIMIT_ID_SIZE, stuffing1);
    let (amount) = unpack_slab_in_range(packed_limit.slab1, 1 + LIMIT_ID_SIZE, AMOUNT_SIZE, stuffing1);
    let (right_id) = unpack_slab_in_range(packed_limit.slab2, 1, LIMIT_ID_SIZE, stuffing2);
    let (filled) = unpack_slab_in_range(packed_limit.slab2, 1 + LIMIT_ID_SIZE, AMOUNT_SIZE, stuffing2);
    let (length) = unpack_slab_in_range(packed_limit.slab3, 1, LENGTH_SIZE, stuffing3);
    let (is_bid) = unpack_slab_in_range(packed_limit.slab3, 1 + LENGTH_SIZE, IS_BID_SIZE, stuffing3);
    let (head_id) = unpack_slab_in_range(packed_limit.slab3, 1 + LENGTH_SIZE + IS_BID_SIZE, ORDER_ID_SIZE, stuffing3);
    let (tree_id) = unpack_slab_in_range(packed_limit.slab3, 1 + LENGTH_SIZE + IS_BID_SIZE + ORDER_ID_SIZE, TREE_ID_SIZE, stuffing3);
    let (market_id) = unpack_slab_in_range(packed_limit.slab3, 1 + LENGTH_SIZE + IS_BID_SIZE + ORDER_ID_SIZE + TREE_ID_SIZE, MARKET_ID_SIZE, stuffing3);

    local limit : Limit = Limit(limit_id, left_id, right_id, price, amount, filled, length, is_bid, head_id, tree_id, market_id);
    return (limit=limit);
}

// Packs Market struct into slabs.
// @param market : Market struct
// @return PackedMarket : Market struct bitpacked into 128-bit slabs
@external
func pack_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    market : Market) -> (packed_market : PackedMarket
) {
    alloc_locals;
    
    check_size_valid(market.market_id, MARKET_ID_SIZE);
    check_size_valid(market.bid_tree_id, TREE_ID_SIZE);
    check_size_valid(market.ask_tree_id, TREE_ID_SIZE);
    check_size_valid(market.lowest_ask_id, ORDER_ID_SIZE);
    check_size_valid(market.highest_bid_id, ORDER_ID_SIZE);
    check_size_valid(market.base_asset_id, ASSET_ID_SIZE);
    check_size_valid(market.quote_asset_id, ASSET_ID_SIZE);

    let (market_id_exp) = pow(2, TREE_ID_SIZE + TREE_ID_SIZE);
    let (bid_tree_id_exp) = pow(2, TREE_ID_SIZE);
    let (lowest_ask_id_exp) = pow(2, ORDER_ID_SIZE + ASSET_ID_SIZE + ASSET_ID_SIZE);
    let (highest_bid_id_exp) = pow(2, ASSET_ID_SIZE + ASSET_ID_SIZE);
    let (base_asset_id_exp) = pow(2, ASSET_ID_SIZE);

    local slab0 = market.market_id * market_id_exp + market.bid_tree_id * bid_tree_id_exp + market.ask_tree_id;
    local slab1 = market.lowest_ask_id * lowest_ask_id_exp + market.highest_bid_id * highest_bid_id_exp + market.base_asset_id * base_asset_id_exp + market.quote_asset_id;

    local packed_market : PackedMarket = PackedMarket(slab0, slab1);
    return (packed_market=packed_market);
}

// Unpacks PackedMarket into Market struct.
// @params packed_market : packed market
// @return market : unpacked Market
@external
func unpack_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    packed_market : PackedMarket) -> (market : Market
) {
    alloc_locals;

    const stuffing0 = 128 - MARKET_ID_SIZE - TREE_ID_SIZE - TREE_ID_SIZE;
    const stuffing1 = 128 - 2 * ORDER_ID_SIZE - 2 * ASSET_ID_SIZE;

    let (market_id) = unpack_slab_in_range(packed_market.slab0, 1, MARKET_ID_SIZE, stuffing0);
    let (bid_tree_id) = unpack_slab_in_range(packed_market.slab0, 1 + MARKET_ID_SIZE, TREE_ID_SIZE, stuffing0);
    let (ask_tree_id) = unpack_slab_in_range(packed_market.slab0, 1 + MARKET_ID_SIZE + TREE_ID_SIZE, TREE_ID_SIZE, stuffing0);
    let (lowest_ask_id) = unpack_slab_in_range(packed_market.slab1, 1, ORDER_ID_SIZE, stuffing1);
    let (highest_bid_id) = unpack_slab_in_range(packed_market.slab1, 1 + ORDER_ID_SIZE, ORDER_ID_SIZE, stuffing1);
    let (base_asset_id) = unpack_slab_in_range(packed_market.slab1, 1 + ORDER_ID_SIZE + ORDER_ID_SIZE, ASSET_ID_SIZE, stuffing1);
    let (quote_asset_id) = unpack_slab_in_range(packed_market.slab1, 1 + 2 * ORDER_ID_SIZE + ASSET_ID_SIZE, ASSET_ID_SIZE, stuffing1);

    local market : Market = Market(market_id, bid_tree_id, ask_tree_id, lowest_ask_id, highest_bid_id, base_asset_id, quote_asset_id);
    return (market=market);
}

// Packs Asset struct into slabs.
// @param asset : Asset struct
// @return PackedAsset : Asset struct bitpacked into 128-bit slabs
@external
func pack_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    asset : Asset) -> (packed_asset : PackedAsset
) {
    alloc_locals;
    
    check_size_valid(asset.asset_id, ASSET_ID_SIZE);
    check_size_valid(asset.symbol, SYMBOL_SIZE);
    check_size_valid(asset.decimals, DECIMALS_SIZE);

    let (asset_id_exp) = pow(2, SYMBOL_SIZE + DECIMALS_SIZE);
    let (symbol_exp) = pow(2, DECIMALS_SIZE);

    local slab0 = asset.asset_id * asset_id_exp + asset.symbol * symbol_exp + asset.decimals;
    local slab1 = asset.address;

    local packed_asset : PackedAsset = PackedAsset(slab0, slab1);
    return (packed_asset=packed_asset);
}

// Unpacks PackedAsset into Asset struct.
// @params packed_asset : packed asset
// @return asset : unpacked Asset
@external
func unpack_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    packed_asset : PackedAsset) -> (asset : Asset
) {
    alloc_locals;

    const stuffing = 128 - ASSET_ID_SIZE - SYMBOL_SIZE - DECIMALS_SIZE;
    let (asset_id) = unpack_slab_in_range(packed_asset.slab0, 1, ASSET_ID_SIZE, stuffing);
    let (symbol) = unpack_slab_in_range(packed_asset.slab0, 1 + ASSET_ID_SIZE, SYMBOL_SIZE, stuffing);
    let (decimals) = unpack_slab_in_range(packed_asset.slab0, 1 + ASSET_ID_SIZE + SYMBOL_SIZE, DECIMALS_SIZE, stuffing);

    local asset : Asset = Asset(asset_id, symbol, decimals, packed_asset.slab1);
    return (asset=asset);
}

// Retrieves value from slab.
// @params slab : felt struct containing packed data
// @params pos : position of first bit in slab
// @params len : length of data in bits
// @params stuffing : number of empty bits at end of slab
// @return val : unpacked value
@external
func unpack_slab_in_range{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    slab : felt, pos : felt, len : felt, stuffing : felt) -> (val : felt
) {
    alloc_locals;
    
    let is_pos_valid = is_le(pos, 128 - stuffing);
    let is_len_valid = is_le(len, 128 - stuffing);
    let is_pos_len_valid = is_le(pos + len - 1, 128 - stuffing);
    with_attr error_message("Position or length out of range") {
        assert is_pos_valid + is_len_valid + is_pos_len_valid = 3;
    }

    let (mask) = pow(2, 128 - stuffing - pos + 1); 
    let (masked) = bitwise_and(slab, mask - 1);
    let (div) = pow(2, 128 - stuffing - pos - len + 1); 
    let (val, _) = unsigned_div_rem(masked, div);
    return (val=val);
}

// Updates value in slab.
// @params slab : felt struct containing packed data
// @params pos : position of first bit in slab
// @params len : length of data in bits
// @params new_val : new value
// @params stuffing : number of empty bits at end of slab
// @return new_slab : updated slab
@external
func update_slab_in_range{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    slab : felt, pos : felt, len : felt, stuffing : felt, new_val : felt) -> (new_slab : felt
) {
    alloc_locals;

    let is_pos_valid = is_le(pos, 128 - stuffing);
    let is_len_valid = is_le(len, 128 - stuffing);
    let is_pos_len_valid = is_le(pos + len - 1, 128 - stuffing);
    with_attr error_message("Position or length out of range") {
        assert is_pos_valid + is_len_valid + is_pos_len_valid = 3;
    }

    let (mask_full) = pow(2, 128 - stuffing); 
    let (mask_start) = pow(2, 128 - stuffing - pos + 1); 
    let (mask_end) = pow(2, 128 - stuffing - pos - len + 1); 
    let mask = (mask_full - 1) - (mask_start - 1) + (mask_end - 1);
    let (masked) = bitwise_and(slab, mask);
    let (denominator) = pow(2, 128 - stuffing - pos - len + 1);
    return (new_slab=masked + new_val * denominator);
}


// Utility function to check size of order params against max sizes.
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
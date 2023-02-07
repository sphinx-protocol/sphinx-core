%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from src.dex.structs import Order, Limit, Market, Asset, PackedOrder, PackedLimit, PackedMarket, PackedAsset
from src.dex.bitpacking import (
    pack_order, 
    unpack_order, 
    pack_limit, 
    unpack_limit, 
    pack_market, 
    unpack_market, 
    pack_asset, 
    unpack_asset, 
    unpack_slab_in_range, 
    update_slab_in_range
)

@external
func test_bitpacking{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;

    // Test 1: pack and unpack order
    local order : Order = Order(
        order_id=9874,
        next_id=9876,
        is_bid=1,
        amount=50000000000000,
        owner_id=235,
        limit_id=777,
    );

    let (packed_order) = pack_order(order=order);
    let (updated_slab0) = update_slab_in_range(packed_order.slab0, 1, 40, 7, 2468);
    local updated_packed_order : PackedOrder = PackedOrder(updated_slab0, packed_order.slab1);
    let (retrieved_order) = unpack_order(updated_packed_order);
    assert retrieved_order.order_id = 2468;
    assert retrieved_order.next_id = order.next_id;
    assert retrieved_order.is_bid = order.is_bid;
    assert retrieved_order.amount = order.amount;
    assert retrieved_order.owner_id = order.owner_id;
    assert retrieved_order.limit_id = order.limit_id;

    // Test 2: pack and unpack limit
    local limit : Limit = Limit(
        limit_id=9874,
        left_id=9872,
        right_id=9880,
        price=125,
        amount=5000,
        filled=1000,
        length=3,
        is_bid=1,
        head_id=236,
        tree_id=7749,
        market_id=5,
    );

    let (packed_limit) = pack_limit(limit=limit);
    let (updated_slab0) = update_slab_in_range(packed_limit.slab0, 41, 88, 0, 130);
    local updated_packed_limit : PackedLimit = PackedLimit(updated_slab0, packed_limit.slab1, packed_limit.slab2, packed_limit.slab3);
    let (retrieved_limit) = unpack_limit(updated_packed_limit);
    
    assert retrieved_limit.limit_id = limit.limit_id;
    assert retrieved_limit.left_id = limit.left_id;
    assert retrieved_limit.right_id = limit.right_id;
    assert retrieved_limit.price = 130;
    assert retrieved_limit.amount = limit.amount;
    assert retrieved_limit.filled = limit.filled;
    assert retrieved_limit.length = limit.length;
    assert retrieved_limit.is_bid = limit.is_bid;
    assert retrieved_limit.head_id = limit.head_id;
    assert retrieved_limit.tree_id = limit.tree_id;
    assert retrieved_limit.market_id = limit.market_id;

    // Test 3: pack and unpack market
    local market : Market = Market(
        market_id=20,
        bid_tree_id=3,
        ask_tree_id=4,
        lowest_ask_id=97,
        highest_bid_id=98,
        base_asset_id=123,
        quote_asset_id=456,
    );

    let (packed_market) = pack_market(market=market);
    let (updated_slab1) = update_slab_in_range(packed_market.slab1, 81, 20, 8, 99);
    local updated_packed_market : PackedMarket = PackedMarket(packed_market.slab0, updated_slab1);
    let (retrieved_market) = unpack_market(updated_packed_market);
    assert retrieved_market.market_id = market.market_id;
    assert retrieved_market.bid_tree_id = market.bid_tree_id;
    assert retrieved_market.ask_tree_id = market.ask_tree_id;
    assert retrieved_market.lowest_ask_id = market.lowest_ask_id;
    assert retrieved_market.highest_bid_id = market.highest_bid_id;
    assert retrieved_market.base_asset_id = 99;
    assert retrieved_market.quote_asset_id = market.quote_asset_id;

    // Test 4: pack and unpack asset
    local asset : Asset = Asset(
        asset_id=20,
        symbol=4543560,
        decimals=18,
        address=365887423642376842384324872344348,
    );

    let (packed_asset) = pack_asset(asset=asset);
    let (updated_slab0) = update_slab_in_range(packed_asset.slab0, 61, 6, 62, 6);
    local updated_packed_asset : PackedAsset = PackedAsset(updated_slab0, packed_asset.slab1);
    let (retrieved_asset) = unpack_asset(updated_packed_asset);
    assert retrieved_asset.asset_id = asset.asset_id;
    assert retrieved_asset.symbol = asset.symbol;
    assert retrieved_asset.decimals = 6;
    assert retrieved_asset.address = asset.address;

    return ();
}
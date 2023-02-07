%lang starknet

// Data structure representing an order.
struct Order {
    order_id : felt,
    next_id : felt,
    is_bid : felt, // 1 = bid, 0 = ask
    amount : felt,
    owner_id : felt,
    limit_id : felt,
}

// Data structure representing a limit price.
struct Limit {
    limit_id : felt,
    left_id : felt,
    right_id : felt,
    price : felt,
    amount : felt,
    filled : felt,
    length : felt,
    is_bid : felt,
    head_id : felt,
    tree_id : felt,
    market_id : felt,
}

// Data structure representing a market.
struct Market {
    market_id : felt,
    bid_tree_id : felt,
    ask_tree_id : felt,
    lowest_ask_id : felt,
    highest_bid_id : felt,
    base_asset_id : felt,
    quote_asset_id : felt,
}

// Data structure representing an asset.
struct Asset {
    asset_id : felt,
    symbol : felt,
    decimals : felt,
    address : felt,
}

// Bitpacked Order struct.
// -----------------------------
// slab   |  variable  |  bit(s)
// -----------------------------
// slab0  |  order_id  |      40
//        |  is_bid    |       1
//        |  next_id   |      40
//        |  limit_id  |      40
// -----------------------------
// slab1  |  amount    |      88
//        |  user_id   |      40
// -----------------------------
struct PackedOrder {
    slab0 : felt,
    slab1 : felt,
}

// Bitpacked Limit struct.
// ------------------------------
// slab   |  variable   |  bit(s)
// ------------------------------
// slab0  |  limit_id   |      40
//        |  price      |      88
// ------------------------------
// slab1  |  left_id    |      40
//        |  amount     |      88
// ------------------------------
// slab2  |  right_id   |      40
//        |  filled     |      88
// ------------------------------
// slab3  |  length     |      16
//        |  is_bid     |       1
//        |  head_id    |      40
//        |  tail_id    |      40
//        |  market_id  |      20
// ------------------------------
struct PackedLimit {
    slab0 : felt,
    slab1 : felt,
    slab2 : felt,
    slab3 : felt,
}   

// Bitpacked Market struct.
// ----------------------------------
// slab   |  variable       |  bit(s)
// ----------------------------------
// slab0  |  market_id      |      20
//        |  bid_tree_id    |      40
//        |  ask_tree_id    |      40
// ----------------------------------
// slab1  |  lowest_ask_id     |      40
//        |  highest_bid_id    |      40
//        |  base_asset_id  |      20
//        |  highest_bid_id    |      20
// ----------------------------------
struct PackedMarket {
    slab0 : felt,
    slab1 : felt,
}

// Bitpacked Asset struct.
// -------------------------------
// slab   |  variable    |  bit(s)
// -------------------------------
// slab0  |  asset_id    |      20
//        |  decimals    |       6
//        |  symbol      |      40
// -------------------------------
// slab1  |  address     |     252
// -------------------------------
struct PackedAsset {
    slab0 : felt,
    slab1 : felt,
}

// Bitpacked UserAsset struct (used as key in Balances hashmap).
// -------------------------------
// slab   |  variable    |  bit(s)
// -------------------------------
// slab0  |  user_id     |      40
//        |  asset_id    |      40
// -------------------------------
struct PackedUserAsset {
    slab0 : felt,
}

// Bitpacked Balances struct.
// ------------------------------------
// slab   |  variable         |  bit(s)
// ------------------------------------
// slab0  |  account_balance  |      40
//        |  order_balance    |      40
// ------------------------------------
struct PackedBalances {
    slab0 : felt,
}
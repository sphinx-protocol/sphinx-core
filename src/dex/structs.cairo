%lang starknet

// Data structure representing a user
struct User {
    addr : felt,
    chain_id : felt,
}

// Data structure representing an order.
struct Order {
    id : felt,
    next_id : felt,
    prev_id : felt,
    is_buy : felt, // 1 = buy, 0 = sell
    price : felt,
    amount : felt,
    filled : felt,
    dt : felt,
    owner : User,
    limit_id : felt,
}

// Data structure representing a limit price.
struct Limit {
    id : felt,
    left_id : felt,
    right_id : felt,
    price : felt,
    total_vol : felt,
    length : felt,
    head_id : felt, 
    tail_id : felt,
    tree_id : felt,
    market_id : felt,
}

// Data structure representing a market.
struct Market {
    id : felt,
    bid_tree_id : felt,
    ask_tree_id : felt,
    lowest_ask : felt,
    highest_bid : felt,
    base_asset : felt,
    quote_asset : felt,
    controller : felt,
}
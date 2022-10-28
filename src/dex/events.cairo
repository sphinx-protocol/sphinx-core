%lang starknet

// Emit create market event.
@event
func log_create_market(id : felt, bid_tree_id : felt, ask_tree_id : felt, lowest_ask : felt, highest_bid : felt, base_asset : felt, quote_asset : felt, controller : felt) {
}

// Emit create new bid.
@event
func log_create_bid(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
}

// Emit create new ask.
@event
func log_create_ask(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, post_only : felt) {
}

// Emit bid taken by buy order.
@event
func log_bid_taken(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, seller : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, total_filled : felt) {
}

// Emit offer taken by buy order.
@event
func log_offer_taken(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, buyer : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, total_filled : felt) {
}

// Emit buy order filled.
@event
func log_buy_filled(id : felt, limit_id : felt, market_id : felt, dt : felt, buyer : felt, seller : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, total_filled : felt) {
}

// Emit sell order filled.
@event
func log_sell_filled(id : felt, limit_id : felt, market_id : felt, dt : felt, seller : felt, buyer : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, total_filled : felt) {
}

// Emit delete order.
@event
func log_delete_order(id : felt, limit_id : felt, market_id : felt, dt : felt, owner : felt, base_asset : felt, quote_asset : felt, price : felt, amount : felt, filled : felt) {
}
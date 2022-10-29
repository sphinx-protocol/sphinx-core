%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.dex.structs import Market

@contract_interface
namespace IBalancesContract {
    // Getter for user balances
    func get_balance(user : felt, asset : felt, in_account : felt) -> (amount : felt) {
    }
    // Setter for user balances
    func set_balance(user : felt, asset : felt, in_account : felt, new_amount : felt) {
    }
    // Transfer balance from one user to another.
    func transfer_balance(sender : felt, recipient : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer account balance to order balance.
    func transfer_to_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
    // Transfer order balance to account balance.
    func transfer_from_order(user : felt, asset : felt, amount : felt) -> (success : felt) {
    }
}

@contract_interface
namespace IMarketsContract {
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) -> (new_market : Market) {
    }
    // Submit a new bid (limit buy order) to a given market.
    func create_bid(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Submit a new ask (limit sell order) to a given market.
    func create_ask(market_id : felt, price : felt, amount : felt, post_only : felt) -> (success : felt) {
    }
    // Delete an order and update limits, markets and balances.
    func delete(order_id : felt) {
    }
}

@external
func test_markets{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    // Migrated to test_gateway.cairo

    return ();
}
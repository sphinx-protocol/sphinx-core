%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from lib.openzeppelin.access.ownable.library import Ownable

from src.dex.structs import Order, Limit, Market, PackedOrder, PackedLimit, PackedMarket
from src.dex.bitpacking import pack_order, unpack_order, pack_limit, unpack_limit, pack_market, unpack_market, unpack_slab_in_range, update_slab_in_range
from src.utils.handle_revoked_refs import handle_revoked_refs

//
// Storage vars
//

// Contract address for L2GatewayContract
@storage_var
func l2_gateway_contract_address() -> (addr : felt) {
}
// Contract owner
@storage_var
func owner() -> (addr : felt) {
}

// Stores packed orders composed as singly linked lists.
@storage_var
func orders(order_id : felt) -> (packed_order : PackedOrder) {

// Stores latest order id.
@storage_var
func curr_order_id() -> (order_id : felt) {
}

// Stores packed limit prices composed as binary search trees.
@storage_var
func limits(limit_id : felt) -> (packed_limit : PackedLimit) {
}
// Stores latest limit id.
@storage_var
func curr_limit_id() -> (id : felt) {
}

// Stores roots of binary search trees.
@storage_var
func roots(tree_id : felt) -> (limit_id : felt) {
}
// Stores latest tree id.
@storage_var
func curr_tree_id() -> (tree_id : felt) {
}

// Stores packed market struct.
@storage_var
func markets(market_id : felt) -> (packed_market : PackedMarket) {
}
// Stores latest market id.
@storage_var
func curr_market_id() -> (market_id : felt) {
}
// Stores on-chain mapping of asset addresses to market id.
@storage_var
func market_ids(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
}

// Stores user balances available in account and locked in open orders.
@storage_var
func balances(user_asset : felt) -> (packed_balances : felt) {
}

// Stores packed asset struct.
@storage_var
func assets(asset_id : felt) -> (packed_asset : PackedAsset) {
}


//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    _owner : felt
) {
    Ownable.initializer(_owner);
    owner.write(_owner);
    curr_order_id.write(1);
    curr_limit_id.write(1);
    curr_market_id.write(1);
    curr_tree_id.write(1);
    return ();
}

//
// Functions
//

// Get external contract address
// @return l2_gateway_contract_address : deployed contract address of L2GatewayContract
@view
func get_gateway_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
) -> (gateway_addr : felt) {
    let (gateway_addr) = l2_gateway_contract_address.read();
    return (gateway_addr=gateway_addr);
}

// Set external contract address
// @dev Can only be called by contract owner
// @param _l2_gateway_contract_address : deployed contract address of L2GatewayContract
@external
func set_gateway_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    _l2_gateway_contract_address : felt, 
) {
    Ownable.assert_only_owner();
    l2_gateway_contract_address.write(_l2_gateway_contract_address);
    return ();
}

// Modifier to assert only callable by L2GatewayContract
func assert_only_gateway{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    let (caller) = get_caller_address();
    let (gateway_addr) = l2_gateway_contract_address.read();
    with_attr error_message("[Storage] assert_only_gateway > Only callable by GatewayContract") {
        assert caller = gateway_addr;
    }
    return ();
}

// Getters and setters for storage vars

@view
func get_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    order_id : felt) -> (order : Order
) {
    let (packed_order) = orders.read(order_id);
    let (order) = unpack_order(packed_order);
    return (order=order);
}

@external
func set_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    order_id : felt, new_order : Order
) {
    assert_only_gateway();
    let (new_packed_order) = pack_order(new_order);
    orders.write(order_id, new_packed_order);
    return ();
}

@view
func get_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (order_id : felt
) {
    let (packed_limit) = limits.read(limit_id);
    let (head_order_id) = unpack_slab_in_range(packed_limit.slab3, 18, 40, 11);
    return (order_id=head_order_id);
}

@external
func set_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_order_id : felt
) {
    assert_only_gateway();
    let (packed_limit) = limits.read(limit_id);
    let (updated_slab3) = update_slab_in_range(packed_limit.slab3, 18, 40, 11, new_order_id);
    local updated_limit : PackedLimit = PackedLimit(packed_limit.slab0, packed_limit.slab1, packed_limit.slab2, updated_slab3);
    limits.write(limit_id, updated_limit);
    return ();
}

@view
func get_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (order_id : felt
) {
    let (packed_limit) = limits.read(limit_id);
    let (tail_order_id) = unpack_slab_in_range(packed_limit.slab3, 58, 40, 11);
    return (order_id=tail_order_id);
}

@external
func set_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_order_id : felt
) {
    assert_only_gateway();
    let (packed_limit) = limits.read(limit_id);
    let (updated_slab3) = update_slab_in_range(packed_limit.slab3, 58, 40, 11, new_order_id);
    local updated_limit : PackedLimit = PackedLimit(packed_limit.slab0, packed_limit.slab1, packed_limit.slab2, updated_slab3);
    limits.write(limit_id, updated_limit);
    return ();
}

@view
func get_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (len : felt
) {
    let (packed_limit) = limits.read(limit_id);
    let (len) = unpack_slab_in_range(packed_limit.slab3, 1, 16, 11);
    return (len=len);
}

@external
func set_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_len : felt
) {
    assert_only_gateway();
    let (packed_limit) = limits.read(limit_id);
    let (updated_slab3) = update_slab_in_range(packed_limit.slab3, 1, 16, 11, new_len);
    local updated_limit : PackedLimit = PackedLimit(packed_limit.slab0, packed_limit.slab1, packed_limit.slab2, updated_slab3);
    limits.write(limit_id, updated_limit);
    return ();
}

@view
func get_curr_order_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (order_id : felt) {
    let (order_id) = curr_order_id.read();
    return (order_id=order_id);
}

@external
func set_curr_order_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_order_id : felt
) {
    assert_only_gateway();
    curr_order_id.write(new_order_id);
    return ();
}

@view
func get_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (limit : Limit
) {
    let (packed_limit) = limits.read(limit_id);
    let (limit) = unpack_limit(packed_limit);
    return (limit=limit);
}

@external
func set_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_limit : Limit
) {
    assert_only_gateway();
    let (new_packed_limit) = pack_limit(new_limit);
    limits.write(limit_id, new_packed_limit);
    return ();
}

@view
func get_root{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt) -> (limit_id : felt
) {
    let (limit_id) = roots.read(tree_id);
    return (limit_id=limit_id);
}

@external
func set_root{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt, new_limit_id : felt
) {
    assert_only_gateway();
    roots.write(tree_id, new_limit_id);
    return ();
}

@view
func get_curr_limit_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (limit_id : felt) {
    let (limit_id) = curr_limit_id.read();
    return (limit_id=limit_id);
}

@external
func set_curr_limit_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_limit_id : felt
) {
    assert_only_gateway();
    curr_limit_id.write(new_limit_id);
    return ();
}

@view
func get_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt) -> (market : Market
) {
    let (packed_market) = markets.read(market_id);
    let (market) = unpack_market(packed_market);
    return (market=market);
}

@external
func set_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, new_market : Market
) {
    assert_only_gateway();
    let (new_packed_market) = pack_market(new_market);
    markets.write(market_id, new_packed_market);
    return ();
}

@view
func get_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt) -> (market_id : felt
) {
    let (market_id) = market_ids.read(base_asset, quote_asset);
    return (market_id=market_id);
}

@external
func set_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt, new_market_id : felt
) {
    assert_only_gateway();
    market_ids.write(base_asset, quote_asset, new_market_id);
    return ();
}

@view
func get_curr_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (market_id : felt) {
    let (market_id) = curr_market_id.read();
    return (market_id=market_id);
}

@external
func set_curr_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_market_id : felt
) {
    assert_only_gateway();
    curr_market_id.write(new_market_id);
    return ();
}

@view
func get_curr_tree_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (tree_id : felt) {
    let (tree_id) = curr_tree_id.read();
    return (tree_id=tree_id);
}

@external
func set_curr_tree_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_tree_id : felt
) {
    assert_only_gateway();
    curr_tree_id.write(new_tree_id);
    return ();
}

@view
func get_base_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt) -> (decimals : felt
) {
    let (decimals) = base_decimals.read(market_id);
    return (decimals=decimals);
}

@external
func set_base_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, decimals : felt
) {
    assert_only_gateway();
    base_decimals.write(market_id, decimals);
    return ();
}

@view
func get_quote_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt) -> (decimals : felt
) {
    let (decimals) = quote_decimals.read(market_id);
    return (decimals=decimals);
}

@external
func set_quote_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, decimals : felt
) {
    assert_only_gateway();
    quote_decimals.write(market_id, decimals);
    return ();
}

@view
func get_account_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt
) -> (amount : felt) {
    let (amount) = account_balances.read(user, asset);
    return (amount=amount);
}

@external
func set_account_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, new_amount : felt
) {
    assert_only_gateway();
    account_balances.write(user, asset, new_amount);
    return ();
}

@view
func get_order_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt
) -> (amount : felt) {
    let (amount) = order_balances.read(user, asset);
    return (amount=amount);
}

@external
func set_order_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt, new_amount : felt
) {
    assert_only_gateway();
    order_balances.write(user, asset, new_amount);
    return ();
}
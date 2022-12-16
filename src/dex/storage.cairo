%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from lib.openzeppelin.access.ownable.library import Ownable
from src.dex.structs import Order, Limit, Market
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

// Stores orders in doubly linked lists.
@storage_var
func orders(id : felt) -> (order : Order) {
}
// Stores heads of doubly linked lists.
@storage_var
func heads(limit_id : felt) -> (id : felt) {
}
// Stores tails of doubly linked lists.
@storage_var
func tails(limit_id : felt) -> (id : felt) {
}
// Stores lengths of doubly linked lists.
@storage_var
func lengths(limit_id : felt) -> (len : felt) {
}
// Stores latest order id.
@storage_var
func curr_order_id() -> (id : felt) {
}

// Stores details of limit prices as mapping.
@storage_var
func limits(id : felt) -> (limit : Limit) {
}
// Stores roots of binary search trees.
@storage_var
func roots(tree_id : felt) -> (id : felt) {
}
// Stores latest limit id.
@storage_var
func curr_limit_id() -> (id : felt) {
}

// Stores active markets.
@storage_var
func markets(id : felt) -> (market : Market) {
}
// Stores on-chain mapping of asset addresses to market id.
@storage_var
func market_ids(base_asset : felt, quote_asset : felt) -> (market_id : felt) {
}
// Stores pointers to bid and ask limit trees.
@storage_var
func trees(id : felt) -> (root_id : felt) {
}
// Stores latest market id.
@storage_var
func curr_market_id() -> (id : felt) {
}
// Stores latest tree id.
@storage_var
func curr_tree_id() -> (id : felt) {
}

// Stores user balances.
@storage_var
func account_balances(user : felt, asset : felt) -> (amount : felt) {
}
// Stores user balances locked in open orders.
@storage_var
func order_balances(user : felt, asset : felt) -> (amount : felt) {
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

// Modifier to assert only callable by L2GatewayContract or contract owner
func assert_gateway_or_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} () {
    let (caller) = get_caller_address();
    let (gateway_addr) = l2_gateway_contract_address.read();
    let (owner_addr) = owner.read();
    if ((caller - gateway_addr) * (caller - owner_addr) == 0) {
        handle_revoked_refs();
        return ();
    } else {
        handle_revoked_refs();
        with_attr error_message("[Storage] assert_gateway_or_owner > Only callable by GatewayContract or owner") {
            assert 1 = 0;
        }
        return ();
    }
}

// Getters and setters for storage vars

@view
func get_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    order_id : felt) -> (order : Order
) {
    assert_gateway_or_owner();
    let (order) = orders.read(order_id);
    return (order=order);
}

@external
func set_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    order_id : felt, new_order : Order
) {
    assert_only_gateway();
    orders.write(order_id, new_order);
    return ();
}

@view
func get_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (id : felt
) {
    assert_gateway_or_owner();
    let (id) = heads.read(limit_id);
    return (id=id);
}

@external
func set_head{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_id : felt
) {
    assert_only_gateway();
    heads.write(limit_id, new_id);
    return ();
}

@view
func get_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (id : felt
) {
    assert_gateway_or_owner();
    let (id) = tails.read(limit_id);
    return (id=id);
}

@external
func set_tail{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_id : felt
) {
    assert_only_gateway();
    tails.write(limit_id, new_id);
    return ();
}

@view
func get_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (len : felt
) {
    assert_gateway_or_owner();
    let (len) = lengths.read(limit_id);
    return (len=len);
}

@external
func set_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_len : felt
) {
    assert_only_gateway();
    lengths.write(limit_id, new_len);
    return ();
}

@view
func get_curr_order_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (id : felt) {
    assert_gateway_or_owner();
    let (id) = curr_order_id.read();
    return (id=id);
}

@external
func set_curr_order_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_id : felt
) {
    assert_only_gateway();
    curr_order_id.write(new_id);
    return ();
}

@view
func get_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt) -> (limit : Limit
) {
    assert_gateway_or_owner();
    let (limit) = limits.read(limit_id);
    return (limit=limit);
}

@external
func set_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    limit_id : felt, new_limit : Limit
) {
    assert_only_gateway();
    limits.write(limit_id, new_limit);
    return ();
}

@view
func get_root{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt) -> (id : felt
) {
    assert_gateway_or_owner();
    let (id) = roots.read(tree_id);
    return (id=id);
}

@external
func set_root{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt, new_id : felt
) {
    assert_only_gateway();
    roots.write(tree_id, new_id);
    return ();
}

@view
func get_curr_limit_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (id : felt) {
    assert_gateway_or_owner();
    let (id) = curr_limit_id.read();
    return (id=id);
}

@external
func set_curr_limit_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    new_id : felt
) {
    assert_only_gateway();
    curr_limit_id.write(new_id);
    return ();
}

@view
func get_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt) -> (market : Market
) {
    assert_gateway_or_owner();
    let (market) = markets.read(market_id);
    return (market=market);
}

@external
func set_market{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    market_id : felt, new_market : Market
) {
    assert_only_gateway();
    markets.write(market_id, new_market);
    return ();
}

@view
func get_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    base_asset : felt, quote_asset : felt) -> (market_id : felt
) {
    assert_gateway_or_owner();
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
func get_tree{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    tree_id : felt) -> (root_id : felt
) {
    assert_gateway_or_owner();
    let (root_id) = trees.read(tree_id);
    return (root_id=root_id);
}

@external
func set_tree{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    root_id : felt, new_root_id : felt
) {
    assert_only_gateway();
    trees.write(root_id, new_root_id);
    return ();
}

@view
func get_curr_market_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
) -> (market_id : felt) {
    assert_gateway_or_owner();
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
    assert_gateway_or_owner();
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
func get_account_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    user : felt, asset : felt
) -> (amount : felt) {
    assert_gateway_or_owner();
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
    assert_gateway_or_owner();
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
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IBalancesContract {
    // Set MarketsContract and GatewayContract address.
    func set_addresses(_markets_addr : felt, _gateway_addr : felt) {
    }
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

@external
func test_balances{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;

    const owner_addr = 456456456;
    const markets_addr = 7878787878;
    const gateway_addr = 101010010;

    local balances_addr: felt;
    %{ ids.balances_addr = deploy_contract("./src/dex/balances.cairo", [ids.owner_addr]).contract_address %}

    %{ stop_prank_callable = start_prank(ids.owner_addr, target_contract_address=ids.balances_addr) %}
    IBalancesContract.set_addresses(balances_addr, markets_addr, gateway_addr);
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.markets_addr, target_contract_address=ids.balances_addr) %}
    IBalancesContract.set_balance(balances_addr, 123456, 1, 1, 1000);
    let (amount) = IBalancesContract.get_balance(balances_addr, 123456, 1, 1);
    assert amount = 1000;
    let (success) = IBalancesContract.transfer_balance(balances_addr, 123456, 456789, 1, 500);
    assert success = 1;
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.balances_addr) %}
    IBalancesContract.transfer_to_order(balances_addr, 123456, 1, 250);
    let (locked) = IBalancesContract.get_balance(balances_addr, 123456, 1, 0);
    assert locked = 250;
    IBalancesContract.transfer_from_order(balances_addr, 123456, 1, 250);

    let (amount_sender) = IBalancesContract.get_balance(balances_addr, 123456, 1, 1);
    let (amount_recipient) = IBalancesContract.get_balance(balances_addr, 456789, 1, 1);
    assert amount_sender = 500;
    assert amount_recipient = 500;
    %{ stop_prank_callable() %}

    return ();
}
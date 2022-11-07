%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// 
// Contract interfaces
// 

@contract_interface
namespace IL2EthRemoteCoreContract {
    // Set external contract addresses on deployment
    func set_addresses(_L1_eth_remote_address: felt, _gateway_addr : felt) {
    }
    // Handle request from L1 EthRemoteCore contract to deposit assets to DEX.
    func remote_deposit(from_address: felt, user_address: felt, token_address: felt, amount: felt, chain_id : felt) -> (success : felt) {
    }
    // Send confirmation to L1 EthRemoteCore contract to release assets to users.
    func remote_withdraw(user_address: felt, chain_id : felt, token_address: felt, amount: felt) {
    }
}

@contract_interface
namespace IGatewayContract {
    // Set MarketsContract address
    func set_addresses(_l2_eth_remote_core_addr : felt, _l2_eth_remote_eip_712_addr : felt) {
    }
}

// 
// Tests
// 

@external
func test_l2_eth_remote_core{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
} () {
    alloc_locals;
    
    // Set contract addresses
    const owner = 31678259801237;
    const l1_eth_remote_addr = 171283020332139;
    const buyer = 1234566778;
    const base_asset = 6666666;
    const l2_eth_remote_eip_712_addr = 1923812391231;

    // Deploy contracts
    local l2_eth_remote_core_addr : felt;
    local gateway_addr : felt;
    %{ ids.l2_eth_remote_core_addr = deploy_contract("./src/crosschain/l2_eth_remote_core.cairo", [ids.owner]).contract_address %}
    %{ ids.gateway_addr = deploy_contract("./src/dex/gateway.cairo", [ids.owner]).contract_address %}

    // Set contract addresses and create new market
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.set_addresses(l2_eth_remote_core_addr, l1_eth_remote_addr, gateway_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.set_addresses(gateway_addr, l2_eth_remote_core_addr, l2_eth_remote_eip_712_addr);
    %{ stop_prank_callable() %}

    // Remote deposit
    %{ stop_prank_callable = start_prank(ids.l1_eth_remote_addr, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.remote_deposit(l2_eth_remote_core_addr, l1_eth_remote_addr, buyer, base_asset, 5000, 1);
    %{ stop_prank_callable() %}

    // Check double deposit fails
    %{ stop_prank_callable = start_prank(ids.l1_eth_remote_addr, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.remote_deposit(l2_eth_remote_core_addr, l1_eth_remote_addr, buyer, base_asset, 5000, 1);
    %{ stop_prank_callable() %}

    // Remote withdraw
    %{ stop_prank_callable = start_prank(ids.gateway_addr, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.remote_withdraw(l2_eth_remote_core_addr, buyer, 1, base_asset, 5000);
    %{ stop_prank_callable() %}

    return ();
}

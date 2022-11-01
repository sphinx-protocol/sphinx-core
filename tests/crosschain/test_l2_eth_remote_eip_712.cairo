%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

// 
// Contract interfaces
// 

@contract_interface
namespace IL2EthRemoteEIP712Contract {
    // Set external contract addresses on deployment
    func set_gateway_addr(_gateway_addr : felt) {
    }
    // Contract to authenticate EIP-712 signature from Ethereum for remote access to the DEX.
    func authenticate(
        price: felt,
        amount: felt,
        strategy: felt,
        chainId: felt,
        orderId: felt,
        r: Uint256,
        s: Uint256,
        v: felt,
        salt: Uint256,
        base_asset: felt,
        calldata_len: felt,
        calldata: felt*,
    ) -> () {
    }
}

@contract_interface
namespace IGatewayContract {
    // Set MarketsContract address
    func set_addresses(_l2_eth_remote_core_addr : felt, _l2_eth_remote_eip_712_addr : felt) {
    }
    // Create a new market for exchanging between two assets.
    func create_market(base_asset : felt, quote_asset : felt) {
    }
}

@contract_interface
namespace IL2EthRemoteCoreContract {
    // Set external contract addresses on deployment
    func set_addresses(_L1_eth_remote_address: felt, _gateway_addr : felt) {
    }
    // Handle request from L1 EthRemoteCore contract to deposit assets to DEX.
    func remote_deposit(from_address: felt, user_address: felt, token_address: felt, amount: felt, nonce: felt, chain_id : felt) -> (success : felt) {
    }
}

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
    const user = 1234566778;
    const base_asset = 6666666;
    const quote_asset = 9999999;

    // Deploy contracts
    local l2_eth_remote_eip_712_addr : felt;
    local l2_eth_remote_core_addr : felt;
    local gateway_addr : felt;
    %{ ids.l2_eth_remote_eip_712_addr = deploy_contract("./src/crosschain/l2_eth_remote_eip_712.cairo", [ids.owner]).contract_address %}
    %{ ids.l2_eth_remote_core_addr = deploy_contract("./src/crosschain/l2_eth_remote_core.cairo", [ids.owner]).contract_address %}
    %{ ids.gateway_addr = deploy_contract("./src/dex/gateway.cairo", [ids.owner]).contract_address %}

    // Set contract addresses and create new market
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.l2_eth_remote_eip_712_addr) %}
    IL2EthRemoteEIP712Contract.set_gateway_addr(l2_eth_remote_eip_712_addr, gateway_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.set_addresses(l2_eth_remote_core_addr, l1_eth_remote_addr, gateway_addr);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.owner, target_contract_address=ids.gateway_addr) %}
    IGatewayContract.set_addresses(gateway_addr, l2_eth_remote_core_addr, l2_eth_remote_eip_712_addr);
    IGatewayContract.create_market(gateway_addr, base_asset, quote_asset);
    %{ stop_prank_callable() %}

    // Deposit funds
    %{ stop_prank_callable = start_prank(ids.l1_eth_remote_addr, target_contract_address=ids.l2_eth_remote_core_addr) %}
    IL2EthRemoteCoreContract.remote_deposit(
        l2_eth_remote_core_addr, l1_eth_remote_addr, user, base_asset, 5000, 1, 1
    );
    IL2EthRemoteCoreContract.remote_deposit(
        l2_eth_remote_core_addr, l1_eth_remote_addr, user, quote_asset, 5000, 1, 1
    );
    %{ stop_prank_callable() %}

    // Remote limit buy (post-only mode)
    let empty_u256 : Uint256 = Uint256(low=0, high=0);
    let (calldata : felt*) = alloc();
    assert calldata[0] = user;
    assert calldata[1] = quote_asset;
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 0, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote limit buy (no post-only mode)
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 1, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote limit sell (post-only mode)
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 101, 1000, 2, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote limit buy (no post-only mode)
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 3, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote market buy
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 4, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote market sell
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 5, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote cancel order
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 6, 1, 1, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    // Remote withdraw
    IL2EthRemoteEIP712Contract.authenticate(
        l2_eth_remote_eip_712_addr, 100, 1000, 7, 1, 0, empty_u256, empty_u256, 0, empty_u256, base_asset, 2, calldata
    );

    return ();
}

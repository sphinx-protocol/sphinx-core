export STARKNET_NETWORK=alpha-goerli2
export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount

starknet new_account

# Account address: 0x073c76885b035632c9b6c4cdf3b4aaf4f02eb376ff067ba5f787402a8e4f78e1
# Public key: 0x0238526cb2968849c2ee68341b577401e30121680c7c56f6df8297eb60ad3f39

# TODO: Send some ETH to account address (wait for tx to be accepted)

starknet deploy_account

starknet declare --contract build/gateway.json
starknet declare --contract build/storage.json

# Storage Contract class hash: 0x71b704ea7ceaa479b77c6d87a4b9fd6c84513d6130032d3bac03749ecc9fe2a
# Gateway Contract class hash: 0x798cba82d984fed80b5c906c8cc9ea1fc658b4225303ea614cfc3b2c7b9045b
# L2EthRemoteCore contract class hash: 0x5bfac950a390abd457bd28347e072b5876dd967950fda4c23d161ccb4466815
# L2EthRemoteEIP712 contract class hash: 0x54b505dd2f4b45b2d7cb15c8b8b62cdbf260dfa0998da5eead09213da7f7ce4

# Deploy contract by interacting with UDC: 0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf
# Link: https://testnet-2.starkscan.co/contract/0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf#write-contract
# Salt can be found in local directory ~/.starknet_accounts/starknet_open_zeppelin_accounts.json
# Unique should be set to 0 (false)

# Storage Contract:
    # classHash: 0x71b704ea7ceaa479b77c6d87a4b9fd6c84513d6130032d3bac03749ecc9fe2a
    # salt: 3376295954017000507947353736214164423281795327929321415795619423985908585326
    # unique: 0
    # calldata_len: 1
    # calldata: 3112176067681992360311991245839735412592422540530926815428076220147821108624

    # Deployed contract address: 0x050b81a68a60f485d91eb4e5f3ad1bfa813d4c0451ff7a31581225ae5b77ee7d

# Gateway Contract:
    # classHash: 0x798cba82d984fed80b5c906c8cc9ea1fc658b4225303ea614cfc3b2c7b9045b
    # salt: 3376295954017000507947353736214164423281795327929321415795619423985908585326
    # unique: 0
    # calldata_len: 2
    # calldata: 3112176067681992360311991245839735412592422540530926815428076220147821108624, 2281894375831758191924518410165984933230241576817723760171721568148786769533

    # Deployed contract address: 0x024a2811e0a5192ef00b89c2488541b3223d25eb483e5cedd612fd16a495f549

# L2EthRemoteCore Contract:
    # classHash: 0x5bfac950a390abd457bd28347e072b5876dd967950fda4c23d161ccb4466815
    # salt: 3376295954017000507947353736214164423281795327929321415795619423985908585326
    # unique: 0
    # calldata_len: 2
    # calldata: 3112176067681992360311991245839735412592422540530926815428076220147821108624, 2281894375831758191924518410165984933230241576817723760171721568148786769533

    # Deployed contract address: 0x0737eadb23a024a505d4757ebf5b2cad8af9a63918adb54ffb2b5c1c5306b8b6

# Gateway L2EthRemoteEIP712:
    # classHash: 0x54b505dd2f4b45b2d7cb15c8b8b62cdbf260dfa0998da5eead09213da7f7ce4
    # salt: 3376295954017000507947353736214164423281795327929321415795619423985908585326
    # unique: 0
    # calldata_len: 2
    # calldata: 3112176067681992360311991245839735412592422540530926815428076220147821108624, 2281894375831758191924518410165984933230241576817723760171721568148786769533

    # Deployed contract address: 0x068bafd43e50ad4be282d7baab623962bd61acc7a706b612e873fb8d62ff752a

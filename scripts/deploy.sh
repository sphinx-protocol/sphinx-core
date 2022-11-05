starknet deploy --no_wallet --contract ./build/gateway.json --network alpha-goerli --feeder_gateway_url  https://alpha4-2.starknet.io --inputs 2093101717867572091314490980361936991870830399016763450328630046935729101720 --gateway_url https://alpha4-2.starknet.io/gateway

starknet deploy --no_wallet --contract ./build/l2EthRemoteCore.json --network alpha-goerli --feeder_gateway_url  https://alpha4-2.starknet.io --inputs 2093101717867572091314490980361936991870830399016763450328630046935729101720 --gateway_url https://alpha4-2.starknet.io/gateway

starknet deploy --no_wallet --contract ./build/l2EthRemoteEIP712.json --network alpha-goerli --feeder_gateway_url  https://alpha4-2.starknet.io --inputs 2093101717867572091314490980361936991870830399016763450328630046935729101720 --gateway_url https://alpha4-2.starknet.io/gateway

# Name: Fake Ethereum (5576121254568188188599781782893)
# Symbol: ETH (4543560)
# Decimals: 18
# Initial Supply: 1,000,000,000 ([low: 1000000000000000000000000, high: 0])
# Recipient: 0x04A0a751A8c71A37A58eB8Ad1859A8bf76353717BEAB31E176de5CcC7C54Db98 (2093101717867572091314490980361936991870830399016763450328630046935729101720)
starknet deploy --no_wallet --contract ./build/ERC20.json --network alpha-goerli --feeder_gateway_url  https://alpha4-2.starknet.io --inputs 5576121254568188188599781782893 4543560 18 1000000000000000000000000 0 2093101717867572091314490980361936991870830399016763450328630046935729101720 --gateway_url https://alpha4-2.starknet.io/gateway

# Name: Fake USDC (1298291900793400542275)
# Symbol: ETH (1431520323)
# Decimals: 18
# Initial Supply: 1,000,000,000 ([low: 1000000000000000000000000, high: 0])
# Recipient: 0x04A0a751A8c71A37A58eB8Ad1859A8bf76353717BEAB31E176de5CcC7C54Db98 (2093101717867572091314490980361936991870830399016763450328630046935729101720)
starknet deploy --no_wallet --contract ./build/ERC20.json --network alpha-goerli --feeder_gateway_url  https://alpha4-2.starknet.io --inputs 1298291900793400542275 1431520323 18 1000000000000000000000000 0 2093101717867572091314490980361936991870830399016763450328630046935729101720 --gateway_url https://alpha4-2.starknet.io/gateway
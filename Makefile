-include .env

export FOUNDRY_TEST=test/integrations
export FOUNDRY_ETH_RPC_URL=https://${INTEGRATION_TEST_NETWORK}.g.alchemy.com/v2/${ALCHEMY_KEY}
export FOUNDRY_FORK_BLOCK_NUMBER=15000000
export DAPP_REMAPPINGS=@config/=config/$(INTEGRATION_TEST_NETWORK)

test-integration: node_modules lib
	@echo Run integration tests on ${INTEGRATION_TEST_NETWORK}
	@forge test -vvv --ffi -c test/integrations 

.PHONY: config
config:
	forge config

node_modules:
	@yarn

#!/bin/bash

# Fund L1 OP addresses.
    # batcher = '0xD3F2c5AFb2D76f5579F326b0cD7DA5F5a4126c35'
    # challenger = '0xf08f610d1956CAAAb34f18e9e0A122E389496529'
    # l1ProxyAdminOwner = '0x8943545177806ED17B9F23F0a21ee5948eCaa776'
    # l2ProxyAdminOwner = '0x8943545177806ED17B9F23F0a21ee5948eCaa776'
    # proposer = '0xb0994E702b603df7191cd68E6544f99126135e34'
    # systemConfigOwner = '0x8943545177806ED17B9F23F0a21ee5948eCaa776'
    # unsafeBlockSigner = '0xbb900Cf56918A2639dAA90c3f7DC5DCD2f5B9935'
addresses=(
    "0xD3F2c5AFb2D76f5579F326b0cD7DA5F5a4126c35"
    "0xf08f610d1956CAAAb34f18e9e0A122E389496529"
    "0x8943545177806ED17B9F23F0a21ee5948eCaa776"
    "0xb0994E702b603df7191cd68E6544f99126135e34"
    "0xbb900Cf56918A2639dAA90c3f7DC5DCD2f5B9935"
)

private_key=$(cast wallet private-key --mnemonic "{{.l1_preallocated_mnemonic}}")

for address in "${addresses[@]}"; do
    cast send \
        --private-key "$private_key" \
        --rpc-url "{{.l1_rpc_url}}" \
        --value "{{.l2_funding_amount}}" \
        "$address"
done

# Create New Rollup Step
cd /opt/zkevm-contracts || exit

# Extract the rollup manager address from the JSON file. .zkevm_rollup_manager_address is not available at the time of importing this script.
# So a manual extraction of polygonRollupManagerAddress is done here.
# Even with multiple op stack deployments, the rollup manager address can be retrieved from combined-001.json because it must be constant.
rollup_manager_addr="$(jq -r '.polygonRollupManagerAddress' /opt/zkevm/combined-001.json)"

# Replace the placeholder with the extracted address
sed -i "s|\"rollupManagerAddress\": \".*\"|\"rollupManagerAddress\":\"$rollup_manager_addr\"|" /opt/contract-deploy/create_new_rollup.json

# Replace the placeholder with the extracted address
sed -i "s|\"polygonRollupManagerAddress\": \".*\"|\"polygonRollupManagerAddress\":\"$rollup_manager_addr\"|" /opt/contract-deploy/add_rollup_type.json

# This will require genesis.json and create_new_rollup.json to be correctly filled. We are using a pre-defined template for these.
# The script and example files exist under https://github.com/0xPolygonHermez/zkevm-contracts/tree/v9.0.0-rc.5-pp/tools/createNewRollup
# The templates being used here - create_new_rollup.json and genesis.json were directly referenced from the above source.

# rollupTypeID="{{ .zkevm_rollup_id }}"
# if [[ "$rollupTypeID" -eq 1 ]]; then
#     cp /opt/contract-deploy/add_rollup_type.json /opt/zkevm-contracts/tools/addRollupType/add_rollup_type.json
#     cp /opt/contract-deploy/sovereign-genesis.json /opt/zkevm-contracts/tools/addRollupType/genesis.json

#     npx hardhat run ./tools/addRollupType/addRollupType.ts --network localhost 2>&1 | tee 05_add_rollup_type.out
# else
#     echo "rollupTypeID is not equal to 1. Skipping the commands."
# fi

rollupTypeID="{{ .zkevm_rollup_id }}"
if [[ "$rollupTypeID" -eq 1 ]]; then
    echo "rollupID is 1. Running 4_createRollup.ts script"
    cp /opt/contract-deploy/create_new_rollup.json /opt/zkevm-contracts/deployment/v2/create_rollup_parameters.json
    npx hardhat run deployment/v2/4_createRollup.ts --network localhost 2>&1 | tee 05_create_sovereign_rollup.out
else
    cp /opt/contract-deploy/create_new_rollup.json /opt/zkevm-contracts/tools/createNewRollup/create_new_rollup.json
    cp /opt/contract-deploy/sovereign-genesis.json /opt/zkevm-contracts/tools/createNewRollup/genesis.json
    npx hardhat run ./tools/createNewRollup/createNewRollup.ts --network localhost 2>&1 | tee 06_create_sovereign_rollup.out
fi

# cp /opt/contract-deploy/create_new_rollup.json /opt/zkevm-contracts/tools/createNewRollup/create_new_rollup.json
# cp /opt/contract-deploy/sovereign-genesis.json /opt/zkevm-contracts/tools/createNewRollup/genesis.json

# npx hardhat run ./tools/createNewRollup/createNewRollup.ts --network localhost 2>&1 | tee 06_create_sovereign_rollup.out

# cp /opt/contract-deploy/create_new_rollup.json /opt/zkevm-contracts/deployment/v2/create_rollup_parameters.json
# npx hardhat run deployment/v2/4_createRollup.ts --network localhost 2>&1 | tee 05_create_sovereign_rollup.out

# Save Rollup Information to a file.
cast call --json --rpc-url  "{{.l1_rpc_url}}" "$rollup_manager_addr" 'rollupIDToRollupData(uint32)(address,uint64,address,uint64,bytes32,uint64,uint64,uint64,uint64,uint64,uint64,uint8)' "{{.zkevm_rollup_id}}" | jq '{"sovereignRollupContract": .[0], "sovereignChainID": .[1], "verifier": .[2], "forkID": .[3], "lastLocalExitRoot": .[4], "lastBatchSequenced": .[5], "lastVerifiedBatch": .[6], "_legacyLastPendingState": .[7], "_legacyLastPendingStateConsolidated": .[8], "lastVerifiedBatchBeforeUpgrade": .[9], "rollupTypeID": .[10], "rollupVerifierType": .[11]}' > /opt/zkevm-contracts/sovereign-rollup-out.json

# These are some accounts that we want to fund for operations for running claims.
bridge_admin_addr="{{.zkevm_l2_sovereignadmin_address}}"
bridge_admin_private_key="{{.zkevm_l2_sovereignadmin_private_key}}"
aggoracle_addr="{{.zkevm_l2_aggoracle_address}}"
# aggoracle_private_key="{{.zkevm_l2_aggoracle_private_key}}"
claimtx_addr="{{.zkevm_l2_claimtx_address}}"
# claimtx_private_key="{{.zkevm_l2_claimtx_private_key}}"

rpc_url="{{.op_el_rpc_url}}"
# This is the default prefunded account for the OP Network
private_key=$(cast wallet private-key --mnemonic 'test test test test test test test test test test test junk')

cast send --value "{{.l2_funding_amount}}"  --rpc-url $rpc_url --private-key "$private_key" $bridge_admin_addr
cast send --value "{{.l2_funding_amount}}"  --rpc-url $rpc_url --private-key "$private_key" $aggoracle_addr
cast send --value "{{.l2_funding_amount}}" --rpc-url $rpc_url --private-key "$private_key" $claimtx_addr

# Contract Deployment Step
cd /opt/zkevm-contracts || exit

echo "[profile.default]
src = 'contracts'
out = 'out'
libs = ['node_modules']" > foundry.toml

echo "Building contracts with forge build"
forge build contracts/v2/sovereignChains/BridgeL2SovereignChain.sol contracts/v2/sovereignChains/GlobalExitRootManagerL2SovereignChain.sol
bridge_impl_nonce=$(cast nonce --rpc-url $rpc_url $bridge_admin_addr)
bridge_impl_addr=$(cast compute-address --nonce "$bridge_impl_nonce" $bridge_admin_addr | sed 's/.*: //')
ger_impl_addr=$(cast compute-address --nonce $((bridge_impl_nonce+1)) $bridge_admin_addr | sed 's/.*: //')
ger_proxy_addr=$(cast compute-address --nonce $((bridge_impl_nonce+2)) $bridge_admin_addr | sed 's/.*: //')
bridge_proxy_addr=$(cast compute-address --nonce $((bridge_impl_nonce+3)) $bridge_admin_addr | sed 's/.*: //')

# This is one way to prefund the bridge. It can also be done with a deposit to some unclaimable network. This step is important and needs to be discussed
cast send --value "{{.l2_funding_amount}}" --rpc-url $rpc_url --private-key "$private_key" "$bridge_proxy_addr"
forge create --broadcast --rpc-url $rpc_url --private-key $bridge_admin_private_key BridgeL2SovereignChain
forge create --broadcast --rpc-url $rpc_url --private-key $bridge_admin_private_key GlobalExitRootManagerL2SovereignChain --constructor-args "$bridge_proxy_addr"
calldata=$(cast calldata 'initialize(address _globalExitRootUpdater, address _globalExitRootRemover)' $aggoracle_addr $aggoracle_addr)
forge create --broadcast --rpc-url $rpc_url --private-key $bridge_admin_private_key TransparentUpgradeableProxy --constructor-args "$ger_impl_addr" $bridge_admin_addr "$calldata"

initNetworkID="{{.zkevm_rollup_id}}"
initGasTokenAddress=$(cast az)
initGasTokenNetwork=0
initGlobalExitRootManager=$ger_proxy_addr
initPolygonRollupManager=$(cast az)
initGasTokenMetadata=0x
initBridgeManager=$bridge_admin_addr
initSovereignWETHAddress=$(cast az)
initSovereignWETHAddressIsNotMintable=false

calldata=$(cast calldata 'function initialize(uint32 _networkID, address _gasTokenAddress, uint32 _gasTokenNetwork, address _globalExitRootManager, address _polygonRollupManager, bytes _gasTokenMetadata, address _bridgeManager, address _sovereignWETHAddress, bool _sovereignWETHAddressIsNotMintable)' $initNetworkID "$initGasTokenAddress" $initGasTokenNetwork "$initGlobalExitRootManager" "$initPolygonRollupManager" $initGasTokenMetadata $initBridgeManager "$initSovereignWETHAddress" $initSovereignWETHAddressIsNotMintable)
forge create --broadcast --rpc-url $rpc_url --private-key $bridge_admin_private_key TransparentUpgradeableProxy --constructor-args "$bridge_impl_addr" $bridge_admin_addr "$calldata"

jq --arg bridge_impl_addr "$bridge_impl_addr" '. += {"bridge_impl_addr": $bridge_impl_addr}' /opt/zkevm-contracts/sovereign-rollup-out.json > /opt/zkevm-contracts/sovereign-rollup-out.json.temp && mv /opt/zkevm-contracts/sovereign-rollup-out.json.temp /opt/zkevm-contracts/sovereign-rollup-out.json
jq --arg ger_impl_addr "$ger_impl_addr" '. += {"ger_impl_addr": $ger_impl_addr}' /opt/zkevm-contracts/sovereign-rollup-out.json > /opt/zkevm-contracts/sovereign-rollup-out.json.temp && mv /opt/zkevm-contracts/sovereign-rollup-out.json.temp /opt/zkevm-contracts/sovereign-rollup-out.json
jq --arg ger_proxy_addr "$ger_proxy_addr" '. += {"ger_proxy_addr": $ger_proxy_addr}' /opt/zkevm-contracts/sovereign-rollup-out.json > /opt/zkevm-contracts/sovereign-rollup-out.json.temp && mv /opt/zkevm-contracts/sovereign-rollup-out.json.temp /opt/zkevm-contracts/sovereign-rollup-out.json
jq --arg bridge_proxy_addr "$bridge_proxy_addr" '. += {"bridge_proxy_addr": $bridge_proxy_addr}' /opt/zkevm-contracts/sovereign-rollup-out.json > /opt/zkevm-contracts/sovereign-rollup-out.json.temp && mv /opt/zkevm-contracts/sovereign-rollup-out.json.temp /opt/zkevm-contracts/sovereign-rollup-out.json
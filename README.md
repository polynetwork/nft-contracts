## Current effective version

Current version being used in testnet is `./contracts/core`

## Generate abi files instruction

Download go-ethereum, choose the preferred version and build the executable abigen file.

```
abigen --sol ./contracts_nftlockproxy/NFTLockProxy.sol --pkg nft_lock_proxy_abi > ./go_abi/nft_lock_proxy_abi/nft_lock_proxy_abi.go

abigen --sol ./contracts_nftlockproxy/erc721_template/CrossChainNFTMapping.sol --pkg nft_mapping_abi > ./go_abi/nft_mapping_abi/nft_mapping_abi.go

abigen --sol ./contracts_nftlockproxy/PolyNFTWrap.sol --pkg nft_wrap_abi > ./go_abi/nft_wrap_abi/nft_wrap_abi.go
```

## Truffle test instruction

#### install pkg
```
npm install --save-dev @openzeppelin/test-helpers

```



[truffle documentation](https://learnblockchain.cn/docs/truffle/getting-started/interacting-with-your-contracts.html)

[web3.js api reference](https://web3.tryblockchain.org/Web3.js-api-refrence.html)

#### compile
```
truffle compile
```

#### deploy
```
truffle migrate
```

#### test

Before run a full round of test or `test/EthCrossChainManagerv3.0Test.js` file, make sure you commit the following code within ```verifyAndExecuteTx()``` method in both [EthCrossChainManager.sol](./contracts/core/CrossChainManager/logic/EthCrossChainManager.sol) and [new EthCrossChainManager.sol](./contracts/core/CrossChainManager/logic/EthCrossChainManager_new_template.sol).
```
//TODO: check this part to make sure we commit the next line when doing local net UT test
require(_executeCrossChainTx(toContract, toMerkleValue.makeTxParam.method, toMerkleValue.makeTxParam.args, toMerkleValue.makeTxParam.fromContract, toMerkleValue.fromChainID), "Execute CrossChain Tx failed!");
```

To run a full test under `test` folder, use 
```
truffle test
```
To run a specific test js file under `test` folder, use
```
truffle test ./test/ZeroCopySinkTest.js
```



## In truffle console / truffle development mode

#### Get contract instance in truffle console:
1. <code>let instance = await MetaCoin.deployed()</code>
2. Or suppose contract address ： <code>0x133739AB03b9be2b885cC11e3B9292FDFf45440E</code>, 
    we can use <code>let instance = await Contract.at("0x133739AB03b9be2b885cC11e3B9292FDFf45440E")</code> to obtain the instance.

#### Call contract function (pre-invoke/ pre-execute)
```
instance.name() / await instance.name()

(await instance.totalSupply()).toNumber()
```
Or we can also use
```
await instance..name.call()
```

#### send Transaction: (invoke / execute)
<code>let result = await instance.transfer(accounts[1], 100)</code>

the returned structure is the following:
```
result = {
    "tx": .., 
    "receipt": ..,
    "logs": []
}

```

<code> await instance.approve(accounts[2], 100)</code>

<code> (await instance.allowance(accounts[0], accounts[2])).toNumber()</code>

<code> let result1 = await instance.transferFrom(accounts[0], accounts[2], 1, {from:accounts[2]})
</code> ({from: ***} to indicate the msg.sender of this transaction)

#### about ether

Note: in truffle console, <code>accounts</code> by default means <code>eth.web3.accounts</code>

query balance : <code>web3.eth.getBalance(accounts[0])</code>

send ether: <code>web3.eth.sendTransaction({from: accounts[0], to: accounts[1], value: web3.utils.toWei('1', "ether")})</code>



## NFT Contracts

## Generate abi files instruction

Download go-ethereum, choose the preferred version and build the executable abigen file. <br>
Suggest solc version:
```
Version: 0.6.12+commit.27d51765.Darwin.appleclang
```

```
abigen --sol ./contracts/PolyNFTLockProxy.sol --pkg nft_lock_proxy_abi > ./go_abi/nft_lock_proxy_abi/nft_lock_proxy_abi.go

abigen --sol ./contracts/PolyNFTWrapper.sol --pkg nft_wrap_abi > ./go_abi/nft_wrap_abi/nft_wrap_abi.go

abigen --sol ./contracts/erc721_template/CrossChainNFTMapping.sol --pkg nft_mapping_abi > ./go_abi/nft_mapping_abi/nft_mapping_abi.go
```

## NFT Cross chain

* PolyNFTLockProxy contract

this contract used to lock original asset. and will be deployed to both of the original and destination side chain. and proxy contract record the relationship of sidechain id and NFT contract address in maps, to ensure the destination is correct while cross chain.

so, when we transfer NFT asset named `CryptoKitte` from ethereum to bsc chain.the original `CryptoKitte` will be locked in in this proxy contract, and mint a new `CryptoKittes` with the same metadata in the mirror contract which located in bsc chain. and the original `CryptoKitte` will be locked in the proxy contract which located in bsc chain.

when we tranfer back `CryptoKitte` from bsc to ethereum. the mirror `CryptoKitte` will be unlocked from proxy contract which located in bsc chain, and the original `CryptoKitte` will be unlocked to the destination user from proxy contract which located in ethereum chain.

* CrossChainNFTMapping contract

in standard erc721 `_mint` is an internal function. so we wrapper this function as an external function to ensure that cross chain success. the contract located in dir of ./contracts/erc721_template. 

* PolyNFTWrapper contract.

this contract wrap the handling fee processing function and the `safeTransferFrom` interface in the erc721 standard into an interface called lock. and this contract should be deployed in both of source side chain and destination side chain.

## How to deploy

deploy NFT contract with erc721_template in both source side chain and destination side chain, and bind this two contracts in source proxy contract and destination proxy contract.

and the abi and bin code located in diretion of ./go_abi/nft_mapping_abi.
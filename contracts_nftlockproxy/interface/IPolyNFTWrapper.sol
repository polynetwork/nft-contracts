// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IPolyNFTWrapper {
    function feeCollector() external view returns (address);
    function lockProxy() external view returns (address);
    function paused() external view returns (bool);
    function chainId() external view returns (uint);
    function owner() external view returns (address);

    function lock(
        address fromAsset,
        uint64 toChainId, 
        address toAddress,
        uint256 tokenId,
        address feeToken,
        uint256 fee,
        uint id
    ) external payable;

    function speedUp(
        address feeToken, 
        bytes calldata txHash,
        uint256 fee
    ) external payable;

    function setFeeCollector(address collector) external;
    function setLockProxy(address _lockProxy) external;
    function extractFee(address token) external;
    function pause() external;
    function unpause() external;

    event PolyWrapperLock(address indexed fromAsset, address indexed sender, uint64 toChainId, bytes toAddress, uint net, uint fee, uint id);
    event PolyWrapperSpeedUp(address indexed fromAsset, bytes indexed txHash, address indexed sender, uint efee);
}
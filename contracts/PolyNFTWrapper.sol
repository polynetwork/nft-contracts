// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

import "./libs/ownership/Ownable.sol";
import "./libs/token/ERC20/SafeERC20.sol";
import "./libs/math/SafeMath.sol";
import "./libs/lifecycle/Pausable.sol";
import "./libs/common/ZeroCopySink.sol";
import "./libs/common/ZeroCopySource.sol";
import "./libs/token/ERC721/IERC721.sol";
import "./libs/token/ERC721/IERC721Enumerable.sol";
import "./libs/token/ERC721/IERC721Metadata.sol";
import "./libs/utils/ReentrancyGuard.sol";
import "./interface/IPolyNFTLockProxy.sol";

contract PolyNFTWrapper is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint public chainId;
    address public feeCollector;
    address public lockProxy;
    
    struct CallArgs {
        bytes toAddress;
        uint64 toChainId;
    }

    event PolyWrapperLock(address indexed fromAsset, address indexed sender, uint64 toChainId, address toAddress, uint256 tokenId, address feeToken, uint256 fee, uint id);
    event PolyWrapperSpeedUp(address indexed feeToken, bytes indexed txHash, address indexed sender, uint256 efee);

    constructor(address _owner, uint _chainId) public {
        require(_chainId != 0, "!legal");
        transferOwnership(_owner);
        chainId = _chainId;
    }
    
    function setFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "emtpy address");
        feeCollector = collector;
    }

    function setLockProxy(address _lockProxy) external onlyOwner {
        require(_lockProxy != address(0));
        lockProxy = _lockProxy;
        require(IPolyNFTLockProxy(lockProxy).managerProxyContract() != address(0), "not lock proxy");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function extractFee(address token) external {
        require(msg.sender == feeCollector, "!feeCollector");
        if (token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IERC20(token).safeTransfer(feeCollector, IERC20(token).balanceOf(address(this)));
        }
    }

    function getAndCheckTokenUrl(address asset, address user, uint tokenId) public view returns (bool, string memory) {
        string memory url = "";
        address owner = IERC721(asset).ownerOf(tokenId);
        if (user != owner || user == address(0)) {
            return (false, url);
        }

        url = IERC721Metadata(asset).tokenURI(tokenId);
        return (true, url);
    }

    // getTokensByIndex index start from 0
    function getOwnerTokensByIndex(address asset, address owner, uint start, uint length) public view returns (bool, bytes memory) {
        bytes memory buff;
        if (length == 0 || length > 10) {
            return (false, buff);
        }

        uint total = IERC721(asset).balanceOf(owner);
        if (total == 0 || start >= total) {
            return (false, buff);
        }        
        uint end = _calcEndIndex(start, length, total);

        IERC721Metadata meta = IERC721Metadata(asset);
        IERC721Enumerable enu = IERC721Enumerable(asset);
        for (uint index = start; index <= end; index++) {
            uint tokenId = enu.tokenOfOwnerByIndex(owner, index);
            string memory url = meta.tokenURI(tokenId);
            buff = _serializeProfile(buff, tokenId, url);
        }
        return (true, buff);
    }

    // getTokensByIndex index start from 0
    function getTokensByIds(address asset, bytes calldata args) public view returns (bool, bytes memory) {
        uint off = 0;
        uint tokenId = 0;
        uint length = 0;
        bytes memory buff;

        (length, off) = ZeroCopySource.NextUint256(args, off);
        if (length == 0 || length > 10) {
            return (false, buff);
        }

        IERC721Metadata meta = IERC721Metadata(asset);
        for (uint index = 0; index < length; index++) {
            (tokenId, off) = ZeroCopySource.NextUint256(args, off);
            string memory url = meta.tokenURI(tokenId);
            buff = _serializeProfile(buff, tokenId, url);
        }
        return (true, buff);
    }

    function getUnCrossChainTokensByIndex(address asset, uint start, uint length) public view returns (bool, bytes memory) {
        bytes memory buff;
        if (length == 0 || length > 10) {
            return (false, buff);
        }

        IERC721Metadata meta = IERC721Metadata(asset);
        IERC721Enumerable enu = IERC721Enumerable(asset);
        IERC721 erc = IERC721(asset);
        
        uint256 total = enu.totalSupply();
        if (total == 0 || start >= total) {
            return (false, buff);
        }

        uint end = _calcEndIndex(start, length, total);
        while(start <= end && end < total) {
            uint tokenId = enu.tokenByIndex(start);
            start = start + 1;
            address owner = erc.ownerOf(tokenId);
            if (owner == lockProxy) {
                end = end + 1;
                continue;
            }
            string memory url = meta.tokenURI(tokenId);
            buff = _serializeProfile(buff, tokenId, url);
        }
        return (true, buff);
    }

    function lock(address fromAsset, uint64 toChainId, address toAddress, uint256 tokenId, address feeToken, uint256 fee, uint id) external payable nonReentrant whenNotPaused {    
        require(toChainId != chainId && toChainId != 0, "!toChainId");

        _pull(feeToken, fee);
        _push(fromAsset, toChainId, toAddress, tokenId);
        emit PolyWrapperLock(fromAsset, msg.sender, toChainId, toAddress, tokenId, feeToken, fee, id);
    }

    function speedUp(address feeToken, bytes memory txHash, uint256 fee) external payable nonReentrant whenNotPaused {
        _pull(feeToken, fee);
        emit PolyWrapperSpeedUp(feeToken, txHash, msg.sender, fee);
    }

    function _pull(address feeToken, uint256 fee) internal {
        if (feeToken == address(0)) {
            require(msg.value == fee, "insufficient ether");
        } else {
            IERC20(feeToken).safeTransferFrom(msg.sender, address(this), fee);
        }
    }

    function _push(address fromAsset, uint64 toChainId, address toAddress, uint256 tokenId) internal {
        CallArgs memory callArgs = CallArgs({
            toAddress: abi.encodePacked(toAddress),
            toChainId: toChainId
        });
        bytes memory callData = _serializeCallArgs(callArgs);
        IERC721(fromAsset).safeTransferFrom(msg.sender, lockProxy, tokenId, callData);
    }

    function _serializeCallArgs(CallArgs memory args) internal pure returns (bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            ZeroCopySink.WriteVarBytes(args.toAddress),
            ZeroCopySink.WriteUint64(args.toChainId)
            );
        return buff;
    }

    function _serializeProfile(bytes memory buff, uint tokenId, string memory url) internal pure returns (bytes memory) {
        buff = abi.encodePacked(
            buff,
            ZeroCopySink.WriteUint256(tokenId),
            ZeroCopySink.WriteVarBytes(bytes(url))
        );
        return buff;
    }

    function _calcEndIndex(uint start, uint length, uint total) internal pure returns (uint) {
        uint end = start + length - 1;
        if (end >= total) {
            end = total - 1;
        }
        return end;
    }
}
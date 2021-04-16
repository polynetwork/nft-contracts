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

    function getAndCheckTokenUrl(address asset, address user, uint tokenId) public view returns (string memory) {
        address owner = IERC721(asset).ownerOf(tokenId);
        require(address(user) == address(owner), "user is not token's owner");

        string memory url = IERC721Metadata(asset).tokenURI(tokenId);
        return url;
    }

    // getTokensByIndex index start from 0
    function getTokensByIds(address asset, bytes calldata args) public view returns (bytes memory) {
        uint off = 0;
        uint tokenId = 0;
        uint length = 0;
        bytes memory buff;

        (length, off) = ZeroCopySource.NextUint256(args, off);
        require(length > 0 && length <= 10, "length out of range");

        IERC721Metadata meta = IERC721Metadata(asset);
        for (uint index = 0; index < length; index++) {
            (tokenId, off) = ZeroCopySource.NextUint256(args, off);
            string memory url = meta.tokenURI(tokenId);
            buff = abi.encodePacked(
                buff,
                ZeroCopySink.WriteUint256(tokenId),
                ZeroCopySink.WriteVarBytes(bytes(url))
            );
        }
        
        return buff;
    }

    // getTokensByIndex index start from 0
    function getTokensByIndex(address asset, address owner, uint start, uint length) public view returns (bytes memory) {
        require(length > 0 && length <= 10, "length out of range");

        uint total = IERC721(asset).balanceOf(owner);
        require(total > 0, "total balance is zero");

        uint end = start + length - 1;
        if (end >= total) {
            end = total - 1;
        }
        
        bytes memory buff;
        IERC721Metadata meta = IERC721Metadata(asset);
        IERC721Enumerable enu = IERC721Enumerable(asset);
        for (uint index = start; index <= end; index++) {
            uint tokenId = enu.tokenOfOwnerByIndex(owner, index);
            string memory url = meta.tokenURI(tokenId);
            buff = abi.encodePacked(
                buff,
                ZeroCopySink.WriteUint256(tokenId),
                ZeroCopySink.WriteVarBytes(bytes(url))
            );
        }
        return buff;
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
}
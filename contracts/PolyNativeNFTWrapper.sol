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

contract PolyNativeNFTWrapper is Ownable, Pausable, ReentrancyGuard {
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

    // todo: 收费
    function _pull(address feeToken, uint256 fee) internal {
        // (succeed, returnData) = _toContract.call(abi.encodePacked(bytes4(keccak256(abi.encodePacked("lock", "(uint64,bytes,uint256)"))), abi.encode(toChainId, toAddress, amount)));
        // require(succeed, "");
    }

    function _push(address fromAsset, uint64 toChainId, address toAddress, uint256 tokenId) internal {
        CallArgs memory callArgs = CallArgs({
            toAddress: abi.encodePacked(toAddress),
            toChainId: toChainId
        });
        bytes memory callData = _serializeCallArgs(callArgs);

        bool succeed;
        bytes memory returnData;
        address _callContract = address(fromAsset);
        (succeed, returnData) = _callContract.call(abi.encodePacked(bytes4(keccak256(abi.encodePacked("safeTransferFrom", "(address,address,uint256,bytes)"))), abi.encode(msg.sender, lockProxy, tokenId, callData)));
        require(succeed, "native transfer failed");
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
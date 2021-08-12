pragma solidity >=0.5.0;

import "./libs/ownership/Ownable.sol";
import "./libs/token/ERC20/SafeERC20.sol";
import "./libs/token/ERC20/IERC20.sol";
import "./libs/utils/ReentrancyGuard.sol";
import "./libs/math/SafeMath.sol";
import "./libs/lifecycle/Pausable.sol";

contract PolyWrapper is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint public chainId;
    address public feeCollector;
    address public lockproxy;

    constructor(address _owner, address _lockproxy, uint _chainId) public {
        require(_chainId != 0, "!legal");
        transferOwnership(_owner);
        chainId = _chainId;
        lockproxy = _lockproxy;
    }

    function setFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "emtpy address");
        feeCollector = collector;
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
    
    function lock(address fromAsset, uint64 toChainId, bytes memory toAddress, uint amount, uint fee, uint id) external payable nonReentrant whenNotPaused {
        require(toChainId != chainId && toChainId != 0, "!toChainId");
        // require(amount > fee, "amount less than fee");
        
        // _pull(fromAsset, amount);

        _push(fromAsset, toChainId, toAddress, amount.sub(fee));

        emit PolyWrapperLock(fromAsset, msg.sender, toChainId, toAddress, amount.sub(fee), fee, id);
    }

    function speedUp(address fromAsset, bytes memory txHash, uint fee) external payable nonReentrant whenNotPaused {
        _pull(fromAsset, fee);
        emit PolyWrapperSpeedUp(fromAsset, txHash, msg.sender, fee);
    }

    function _pull(address fromAsset, uint amount) internal {
        if (fromAsset == address(0)) {
            require(msg.value == amount, "insufficient ether");
        } else {
            IERC20(fromAsset).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _push(address fromAsset, uint64 toChainId, bytes memory toAddress, uint amount) internal {
        // if (fromAsset == address(0)) {
        //     require(lockProxy.lock{value: amount}(fromAsset, toChainId, toAddress, amount), "lock ether fail");
        // } else {
        //     IERC20(fromAsset).safeApprove(address(lockProxy), amount);
        //     _nativeCallWrapLock();
        // }
        bool succeed;
        bytes memory returnData;
        // IERC20(fromAsset).safeApprove(address(lockproxy), amount);
        address _toContract = address(lockproxy);
        (succeed, returnData) = _toContract.call(abi.encodePacked(bytes4(keccak256(abi.encodePacked("lock", "(uint64,bytes,uint256)"))), abi.encode(toChainId, toAddress, amount)));
        require(succeed, "native transfer failed");
    }

    event PolyWrapperLock(address indexed fromAsset, address indexed sender, uint64 toChainId, bytes toAddress, uint net, uint fee, uint id);
    event PolyWrapperSpeedUp(address indexed fromAsset, bytes indexed txHash, address indexed sender, uint efee);
}
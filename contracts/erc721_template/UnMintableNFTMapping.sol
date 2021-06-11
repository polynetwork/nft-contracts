pragma solidity >=0.5.0;

import "../libs/token/ERC721/ERC721.sol";
import "../libs/utils/Address.sol";
import "../libs/ownership/Ownable.sol";
import "../core/cross_chain_manager/interface/IEthCrossChainManagerProxy.sol";

contract UnMintableNFTMapping is ERC721, Ownable {
    using Address for address; 

    constructor (string memory name, string memory symbol) public ERC721(name, symbol) {
    }

    address public lockProxyContract;
    
    event SetLockProxyEvent(address proxy);

    modifier onlyLockProxyContract() {
        require(_msgSender() == lockProxyContract, "msgSender is not PolyNFTLockProxy");
        _;
    }

    function setLockProxy(address _proxyAddr) onlyOwner public {
        lockProxyContract = _proxyAddr;
        emit SetLockProxyEvent(lockProxyContract);
    }

    function mintWithURI(address to, uint256 tokenId, string memory uri) onlyLockProxyContract external {
        require(!_exists(tokenId), "token id already exist");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
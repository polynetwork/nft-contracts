pragma solidity >=0.5.0;

import "../libs/token/ERC721/ERC721.sol";
import "../libs/utils/Address.sol";

contract CrossChainNFTMapping is ERC721 {
    using Address for address; 

    constructor (string memory name, string memory symbol) public ERC721(name, symbol) {
    }

    function mintWithURI(address to, uint256 tokenId, string memory uri) external {
        require(!_exists(tokenId), "token id already exist");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./IERC20.sol";

contract MS02 is ERC721A, Ownable {

    // constants
    address constant public MS01 = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    // attributes
    bool public burnToMintEnable;

    string baseTokenURI;

    modifier notContract() {
        require(msg.sender == tx.origin, "Contract not allowed");
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721A(_name, _symbol) {
        setBaseURI(_initBaseURI);
    }

    function burnToMint() external {
        require(burnToMintEnable, "Not yet started");
        require(msg.sender == address(MS01));
        _mint(msg.sender, 1);
    }

    // onlyOwner
    function setPreSaleEnable() external onlyOwner {
        burnToMintEnable = !burnToMintEnable;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // withdraw
    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "call error");
    }

    function withdrawERC20(address _token, uint _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

}
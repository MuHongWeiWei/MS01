// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./MerkleProof.sol";
import "./IMS02.sol";
import "./IERC20.sol";

    struct WhiteListData {
        uint amount;
        bool exchange;
    }

contract MS01 is ERC721A, Ownable {

    using MerkleProof for bytes32[];

    // constants
    uint constant MAX_SUPPLY = 10000;
    uint constant FREEMINT_MAX = 100;
    uint constant ACTIVITY_SEND_MAX = 1000;
    uint constant MINT_MAX = 7900;
    uint constant ACTIVITY_SEND = 10;
    IMS02 constant public MS02 = IMS02(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);

    // attributes
    uint public freemintCount;
    uint public preSaleTime;
    uint public publicSaleTime;
    uint public preSalePrice;
    uint public publicSalePrice;
    uint public whiteListExchangeAmount;

    bool public earlyBirdEnable;
    bool public preSaleEnable;
    bool public publicSaleEnable;

    bytes32 public merkleRoot;

    string baseTokenURI;

    // mapping
    mapping(address => bool) public haveFreemint;
    mapping(address => WhiteListData) public whiteListData;

    modifier notContract() {
        require(msg.sender == tx.origin, "Contract not allowed");
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721A(_name, _symbol) {
        setBaseURI(_initBaseURI);
    }

    function earlyBirdMint() external notContract {
        freemintCount++;
        require(earlyBirdEnable, "Not yet started");
        require(!haveFreemint[msg.sender], "You have been mint");
        require(freemintCount <= FREEMINT_MAX, "Maximum number of mints exceeded");

        haveFreemint[msg.sender] = true;
        _mint(msg.sender, 1);
    }

    function preMint(uint _num, bytes32[] calldata _proof) external payable {
        uint256 supply = totalSupply();
        require(preSaleEnable, "Not yet started");
        require(_num <= MINT_MAX, "You can't mint MINT_MAX");
        require(supply + _num <= MAX_SUPPLY, "Exceeds maximum supply" );
        require(msg.value >= preSalePrice * _num, "Ether sent is not correct" );
        require(whiteListVerify(_proof), "address is not on the whitelist");

        WhiteListData storage data = whiteListData[msg.sender];
        data.amount += _num;

        _mint(msg.sender, _num);

        if (data.amount >= ACTIVITY_SEND && !data.exchange) {
            whiteListExchangeAmount += ACTIVITY_SEND;
            if(whiteListExchangeAmount <= ACTIVITY_SEND_MAX) {
                data.exchange = true;
                _mint(msg.sender, ACTIVITY_SEND);
            }
        }
    }

    function publicMint(uint _num) external payable {
        uint256 supply = totalSupply();
        require(publicSaleEnable, "Not yet started");
        require(_num <= MINT_MAX, "You can't mint MINT_MAX");
        require(supply + _num <= MAX_SUPPLY, "Exceeds maximum supply" );
        require(msg.value >= publicSalePrice * _num, "Ether sent is not correct" );

        _mint(msg.sender, _num);
    }

    function burn(uint _time, uint _tokenA, uint _tokenB, bytes memory _signature, address _signer) external {
        require(_time > block.timestamp - 5 minutes, "Expired");
        require(msg.sender == ownerOf(_tokenA), "Not Yours");
        require(msg.sender == ownerOf(_tokenB), "Not Yours");

        bytes32 sign = keccak256(abi.encodePacked(_time, _tokenA, _tokenB));
        bytes32 hash = toEthSignedMessageHash(sign);
        if(recoverSigner(hash, _signature) == _signer) {
            _burn(_tokenA);
            _burn(_tokenB);
            MS02.burnToMint();
        }
    }

    // onlyOwner
    function setEarlyBirdEnable() external onlyOwner {
        earlyBirdEnable = !earlyBirdEnable;
    }

    function setPreSaleEnable() external onlyOwner {
        preSaleEnable = !preSaleEnable;
    }

    function setPublicSaleEnable() external onlyOwner {
        publicSaleEnable = !publicSaleEnable;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
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

    // metadata
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // merkle
    function whiteListVerify(bytes32[] calldata merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return merkleProof.verify(merkleRoot, leaf);
    }

    // sign
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recoverSigner(bytes32 _msgHash, bytes memory _signature) internal pure returns (address) {
        require(_signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := and(mload(add(_signature, 65)), 255)
        }

        return ecrecover(_msgHash, v, r, s);
    }

}
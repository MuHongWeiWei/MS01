// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./MerkleProof.sol";

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

    // 第一段 早鳥      Freemint  早鳥             100
    // 第二段 白單預售  0.02E     買10送10 限1000組 2000 (可累積) 白單只發2000張
    // 第三段 公售      0.03E                      7900

    // 每個地址購買上限 -- 7900

    modifier notContract() {
        require(msg.sender == tx.origin, "Contract not allowed");
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721A(_name, _symbol) {
        setBaseURI(_initBaseURI);
    }

    function earlyBirdMint() external notContract {
        require(earlyBirdEnable, "Not yet started");
        require(!haveFreemint[msg.sender], "You have been mint");
        require(freemintCount < FREEMINT_MAX, "Maximum number of mints exceeded");

        freemintCount++;
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
            require(whiteListExchangeAmount <= ACTIVITY_SEND_MAX, "activity ends");
            data.exchange = true;

            _mint(msg.sender, ACTIVITY_SEND);
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

    function burn(uint id) external {
        // 判斷兩個Token都是
        // 比對metadata相同 後端簽名確認 燒V1 生V2
        // V2 要讓 V1有權限mint
        require(msg.sender == ownerOf(id), "Not Yours");
        _burn(id);
    }

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

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function whiteListVerify(bytes32[] calldata merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return merkleProof.verify(merkleRoot, leaf);
    }

}
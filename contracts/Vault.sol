// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// safe imports
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// personal import

contract Vault is Ownable, IERC721Receiver {
    // type declarations
    using SafeERC20 for IERC20;

    // state variables
    // uint8 public commissionRate = 5; // percentage
    // mapping(address => uint256) public personnalBalance; // personal balance of the protocole
    uint256 public protocolBalance;
    mapping(address => uint256) public ownerBalance; // balance for all the owner of nfts using the protocole
    mapping(address => mapping(uint256 => address)) public nftOwner; // first key assetContract, second key tokenId
    address public rentalManager;

    // events
    event BalanceWithdrawed(
        address indexed withdrawer,
        address indexed erc20DenominationUsed,
        uint256 amount
    );


    // functions modifiers
    modifier onlyRentalManager() {
        require(msg.sender == rentalManager, "Only rentalManager is allowed to call");
        _;
    }

    // functions
    constructor() {}

    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setRentalManager(address _rentalManager) external onlyOwner {
        rentalManager = _rentalManager;
    }

    // function setCommissionRate(uint8 _newCommissionRate) external onlyOwner {
    //     commissionRate = _newCommissionRate;
    // }

    /// @dev this method is called by the rental manager to store tokens after a user rent an NFT
    function storeTokens(uint256 _fees) external payable onlyRentalManager {
        protocolBalance += _fees;
    }

    /// @dev store the NFT of the initial owner here in the Vault after a refund by a renter
    function storeNFT(address _initialOwner, address _renter, address _assetContract, uint256 _tokenId) external onlyRentalManager {
        nftOwner[_assetContract][_tokenId] = _initialOwner;
        IERC721(_assetContract).safeTransferFrom(_renter, address(this), _tokenId);
    }

    /// @dev send back the collateral to the renter
    function returnCollateral(address _renter, uint256 _collateralAmount) external onlyRentalManager {
        (bool success,) = _renter.call{value: _collateralAmount}("");
        require(success, "Failed to return collateral to renter");
    }

    function liquidateCollateral(address _originalOwner, uint256 _amount) public onlyRentalManager {
        require(_amount < address(this).balance);
        (bool success,) = _originalOwner.call{value: _amount}("");
        require(success, "refund owner during liquidation failed");
    }

    function increaseOwnerBalance(address _originalOwner, uint256 _amount) public onlyRentalManager {
        ownerBalance[_originalOwner] += _amount;
    }

    function withdrawProtocoleBalance(address _to) external onlyOwner {
        require(protocolBalance > 0, "not enough tokens");
        (bool success,) = _to.call{value: protocolBalance}("");
        require(success, "fail to retrieve protocol balance");
    }

    function retreiveNFT(address _assetContract, uint256 _tokenId) external {
        require(msg.sender == nftOwner[_assetContract][_tokenId], "Not owner of this token");
        ERC721(_assetContract).safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    /// @dev used by lender to retrieve tokens after rental was refunded.
    function withdrawBalance() external {
        uint256 balance = ownerBalance[msg.sender];
        require(balance > 0, "not enough tokens");
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "refund owner during liquidation failed");

    }

    // function withdrawProtocoleBalance(address _erc20DenominationUsed) external onlyOwner {
    //     require(personnalBalance[_erc20DenominationUsed] > 0, "Not enough found");
    //     // remove balance before transfer to prevent reentrancy
    //     uint256 amount = personnalBalance[_erc20DenominationUsed];
    //     personnalBalance[_erc20DenominationUsed] = 0;
    //     // bool success = ERC20(_erc20DenominationUsed).transfer(msg.sender, amount);
    //     // require(success, "Failed to tranfer founds");
    //     IERC20(_erc20DenominationUsed).safeTransfer(msg.sender, amount);
    //     emit BalanceWithdrawed(msg.sender, _erc20DenominationUsed, amount);
    // }

    // // Used??
    // function transferNFTFrom(address assetContract, address from, address to, uint256 tokenId) public onlyRentalManager {
    //     IERC721(assetContract).safeTransferFrom(from, to, tokenId);
    // }

    // function safeTransferCollateralFrom(address _erc20DenominationUsed, address _from, address _to, uint256 _amount) public onlyRentalManager {
    //     // Will not work for USDT cause USDT is not ERC20 compliant and return nothing - use SafeTransferLib, safeTransfer instead manually checking the return
    //     // return ERC20(_erc20DenominationUsed).transferFrom(_from, _to, _amount);
    //     IERC20(_erc20DenominationUsed).safeTransferFrom(_from, _to, _amount);
    // }

    // function safeTransferToRenter(address _renter, address _originalOwner, address _assetContract, uint256 _tokenId) external onlyRentalManager {
    //     nftOwner[_assetContract][_tokenId] = _originalOwner;
    //     IERC721(_assetContract).safeTransferFrom(_renter, address(this), _tokenId);
    // }

    // function payAndReturnCollateral(address _erc20DenominationUsed, address _to, uint256 _collateralAmount, address _ownerPaid, uint256 _paidAmount) public onlyRentalManager {
    //     ownerBalance[_ownerPaid][_erc20DenominationUsed] += _paidAmount;
    //     uint256 commission = _paidAmount * commissionRate / 100;
    //     personnalBalance[_erc20DenominationUsed] += commission;
    //     // return ERC20(_erc20DenominationUsed).transfer(_to, _collateralAmount - _paidAmount - commission);
    //     IERC20(_erc20DenominationUsed).safeTransfer(_to, _collateralAmount - _paidAmount - commission);
    //     // require(success, "Transfer of collateral failed");
    // }

    // function liquidateCollateral(address _erc20DenominationUsed, address _to, uint256 _amount) public onlyRentalManager returns (bool) {
    //     // Do we take commission on liquidation ?
    //     return ERC20(_erc20DenominationUsed).transfer(_to, _amount);
    // }

    // function retreiveNFT(address _assetContract, uint256 _tokenId) external {
    //     require(msg.sender == nftOwner[_assetContract][_tokenId], "Not owner of this token");
    //     ERC721(_assetContract).safeTransferFrom(address(this), msg.sender, _tokenId);
    // }

    // function withdrawBalance(address _erc20DenominationUsed) external {
    //     require(ownerBalance[msg.sender][_erc20DenominationUsed] > 0, "Not enough found");
    //     // remove balance before transfer to prevent reentrancy
    //     uint256 amount = ownerBalance[msg.sender][_erc20DenominationUsed];
    //     ownerBalance[msg.sender][_erc20DenominationUsed] = 0;
    //     bool success = ERC20(_erc20DenominationUsed).transfer(msg.sender, amount);
    //     require(success, "Failed to tranfer founds");
    //     emit BalanceWithdrawed(msg.sender, _erc20DenominationUsed, amount);
    // }
}
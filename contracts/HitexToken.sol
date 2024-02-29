// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract HitexToken is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    uint256 public initialSupply;
    uint256 public finalTotalSupply;
    uint256 public txFee;
    uint256 public contractFee;

    address public investWallet;
    address public admin; // owner of contract
    address public hext; // proxy contract address

    event TransferedFromContract(address to, uint256 amount);
    event ContractFeeTransfered(address to, uint256 amount);
    event txFeeTransfered(address to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("Hitex token", "HEXT");
        __Pausable_init();
        __Ownable_init();
        admin = msg.sender;
        hext = address(this);
        txFee = 3; // for 0.3% need to div by 1000
        contractFee = 5; // for 5% need to div by 100
        initialSupply = 10000000 * 10**decimals();
        finalTotalSupply = 50000000 * 10**decimals();
        _mint(address(this), initialSupply);
    }

    receive() external payable {}

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(
            ERC20Upgradeable.totalSupply() + amount <= finalTotalSupply,
            "Final supply reached!"
        );
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        require(investWallet != address(0), "set invest wallet!");
        if (from == hext) {
            uint256 investAmount = calculateContractFee(amount);
            super._transfer(address(this), to, amount);
            emit TransferedFromContract(to, amount);

            super._transfer(address(this), investWallet, investAmount);
            emit ContractFeeTransfered(to, amount);
        } else {
            uint256 sendingFee = calculateTxFee(amount);
            super._transfer(from, to, amount - sendingFee);
            emit TransferedFromContract(to, amount);

            super._transfer(from, hext, sendingFee);
            emit txFeeTransfered(hext, sendingFee);
        }
    }

    function setInvestWallet(address _a) public onlyOwner {
        require(_a != address(0), "can't be zero address!");
        investWallet = _a;
    }

    function sendFromContract(address to, uint256 amount)
        public
        onlyOwner
        whenNotPaused
    {
        require(
            isPossibleToTransfer(amount),
            "amount + fee is more that contract has"
        );
        require(investWallet != address(0), "set invest wallet!");
        require(to != address(0), "can't send to zero address!");
        _transfer(hext, to, amount);
    }

    function withdrawAllBNB(address _to) public onlyOwner whenNotPaused {
        require(_to != address(0), "can't send to zero address!");
        payable(_to).transfer(address(this).balance);
    }

    function balanceBNBOfContract() public view returns (uint256) {
        return address(this).balance;
    }

    function decimals() public view virtual override returns (uint8) {
        return 5;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function calculateTxFee(uint256 _a) private view returns (uint256) {
        return (_a * txFee) / 1000; // because of floating fee
    }

    function calculateContractFee(uint256 _a) private view returns (uint256) {
        return (_a * contractFee) / 100;
    }

    function isPossibleToTransfer(uint256 amount) private view returns (bool) {
        if (
            amount + calculateContractFee(amount) >
            ERC20Upgradeable.balanceOf(address(this))
        ) {
            return false;
        } else {
            return true;
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}

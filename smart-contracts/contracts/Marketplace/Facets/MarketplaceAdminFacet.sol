// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { MarketplaceStorage } from "../AppStorage.sol";

contract MarketplaceAdminFacet is AccessControlEnumerable {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    event UpdatedDecimals(uint256 decimals, uint256 precalculatedMultiplier);
    event UpdatedNodeFee(uint256 decimals, uint256 newPercentage);
    event UpdatedTreasuryFee(uint256 decimals, uint256 newPercentage);
    event UpdatedTreasuryAddress(address newAddress);

    function updateDecimals(uint16 newDecimals) public onlyRole(MAINTAINER) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        s.decimals = newDecimals;
        s.decimalPow = 10 ** newDecimals;
        emit UpdatedDecimals(newDecimals, s.decimalPow);
    }

    function getNodeFee() public view returns (uint16 decimals, uint256 nodeFee) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        return (s.decimals, s.nodeFee);
    }

    function updateNodeFee(uint256 newFee) public onlyRole(MAINTAINER) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        require(newFee <= 100 * s.decimalPow, "Marketplace: Invalid Fee!");
        s.nodeFee = newFee;
        emit UpdatedNodeFee(s.decimals, newFee);
    }

    function getTreasuryFee() public view returns (uint16 decimals, uint256 treasuryFee) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        return (s.decimals, s.treasuryFee);
    }

    function updateTreasuryFee(uint256 newFee) public onlyRole(MAINTAINER) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        require(newFee <= 100 * s.decimalPow, "Marketplace: Invalid Fee!");
        s.treasuryFee = newFee;
        emit UpdatedTreasuryFee(s.decimals, newFee);
    }

    function getTreasuryAddress() public view returns (address) {
        return MarketplaceStorage.layout().treasuryAddress;
    }

    function updateTreasuryAddress(address newAddress) public onlyRole(MAINTAINER) {
        MarketplaceStorage.layout().treasuryAddress = newAddress;
        emit UpdatedTreasuryAddress(newAddress);
    }

    function multiSendERC20(
        address erc20Address,
        address payable[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "MultiSend: Invalid array sizes");
        IERC20 token = IERC20(erc20Address);
        for (uint256 i = 0; i < recipients.length; i++) {
            token.transferFrom(msg.sender, recipients[i], amounts[i]);
        }
    }

    function multiSendERC20SameAmount(
        address erc20Address,
        address payable[] calldata recipients,
        uint256 amount
    ) external {
        IERC20 token = IERC20(erc20Address);
        for (uint256 i = 0; i < recipients.length; i++) {
            token.transferFrom(msg.sender, recipients[i], amount);
        }
    }
}
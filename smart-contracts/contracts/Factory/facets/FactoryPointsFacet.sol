// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { FactoryHandlerRoles } from "../AccessControlRoles.sol";
import { FactoryStorage } from "../AppStorage.sol";
import { SignedHashProtection } from "../../common/SignedHashProtection.sol";

contract FactoryPointsFacet is AccessControlEnumerable, FactoryHandlerRoles, SignedHashProtection {
    event ReceivedTokens(address userAddress, address tokenAddress, uint256 amount, uint256 totalTokensDeposited);
    event WithdrewPoints(address user, address token, uint256 amount);

    function depositTokens(uint256 amount) external {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        require(
            IERC20(store.currentERC20).allowance(msg.sender, address(this)) >= amount,
            "PointsDeposit: Not allowed to transfer tokens"
        );
        require(
            IERC20(store.currentERC20).transferFrom(msg.sender, address(this), amount),
            "PointsDeposit: Error transferring tokens"
        );

        store.totalUserPoints[msg.sender] += amount;
        store.currentUserPoints[msg.sender] += amount;

        emit ReceivedTokens(
            msg.sender,
            store.currentERC20,
            amount,
            store.currentUserPoints[msg.sender]
        );
    }

    function setWithdrawTimeLimit(uint256 timeInSeconds) public onlyRole(ADMINISTRATOR) {
        FactoryStorage.layout().transferTimeLimit = timeInSeconds;
    }

    function roundedTime() internal view returns (uint256 time) {
        time = ((block.timestamp + FactoryStorage.layout().transferTimeLimit) / 100) * 100;
    }

    function getWithdrawHash(
        address receiver,
        address token,
        uint256 amount
    ) public view returns (bytes32) {
        FactoryStorage.Layout storage facetData = FactoryStorage.layout();
        require(
            facetData.currentUserPoints[receiver] >= amount,
            "PointsWithdraw: Invalid withdraw amount"
        );
        return keccak256(
            abi.encodePacked(
                receiver,
                token,
                amount,
                facetData.currentUserPoints[receiver],
                roundedTime()
            )
        );
    }

    function withdraw(uint256 amount, bytes memory signature) public {
        FactoryStorage.Layout storage store = FactoryStorage.layout();

        bytes32 messageHash = getWithdrawHash(msg.sender, store.currentERC20, amount);
        bytes32 ethSignedMessageHash = getSignedMessageHash(messageHash);
        require(
            hasRole(
                WITHDRAW_SIGNER,
                recoverSigner(ethSignedMessageHash, signature)
            ),
            "PointsWithdraw: Invalid withdraw request"
        );
        require(
            store.currentUserPoints[msg.sender] >= amount,
            "PointsWithdraw: Insufficient points balance"
        );
        store.currentUserPoints[msg.sender] -= amount;
        IERC20(store.currentERC20).transfer(msg.sender, amount);
        emit WithdrewPoints(msg.sender, store.currentERC20, amount);
    }

    function getUserPoints(address userAddress) external view returns (uint256 balance) {
        balance = FactoryStorage.layout().currentUserPoints[userAddress];
    }

    function getTotalUserPoints(address userAddress) external view returns (uint256 balance) {
        balance = FactoryStorage.layout().totalUserPoints[userAddress];
    }
}
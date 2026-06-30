// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

library FactoryStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("rair.contracts.storage.DiamondFactory");

    struct Layout {
        address[] creators;
        mapping(address => address[]) creatorToContracts;
        mapping(address => address) contractToCreator;
        mapping(address => uint256) deploymentCostForToken;
        address currentERC20;
        mapping(address => uint256) currentUserPoints;
        mapping(address => uint256) totalUserPoints;
        uint256 transferTimeLimit;
        address facetSource;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
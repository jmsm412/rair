// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { RAIR721_Diamond } from "../../tokens/RAIR-721/RAIR-ERC721.sol";
import { FactoryStorage } from "../AppStorage.sol";

contract FactoryDeployerFacet is AccessControlEnumerable {
    event DeployedContract(
        address deployerAddress,
        uint256 deploymentIndex,
        address deploymentAddress,
        string deploymentName
    );

    function deployContract(
        string calldata contractName,
        string calldata contractSymbol
    ) external {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        uint256 cost = store.deploymentCostForToken[store.currentERC20];
        require(
            IERC20(store.currentERC20).allowance(msg.sender, address(this)) >= cost,
            "Deployer: Not allowed to transfer tokens"
        );
        require(
            IERC20(store.currentERC20).transferFrom(msg.sender, address(this), cost),
            "Deployer: Error transferring tokens"
        );

        address[] storage deploymentsFromOwner = store.creatorToContracts[msg.sender];
        store.totalUserPoints[msg.sender] += cost;
        
        if (deploymentsFromOwner.length == 0) {
            store.creators.push(msg.sender);
        }

        RAIR721_Diamond newToken = new RAIR721_Diamond(contractName, contractSymbol, msg.sender, store.facetSource);
        address tokenAddr = address(newToken);
        deploymentsFromOwner.push(tokenAddr);
        store.contractToCreator[tokenAddr] = msg.sender;

        emit DeployedContract(msg.sender, deploymentsFromOwner.length - 1, tokenAddr, contractName);
    }

    function getCreatorsCount() public view returns (uint256 count) {
        return FactoryStorage.layout().creators.length;
    }

    function getCreatorAtIndex(uint256 index) public view returns (address creator) {
        return FactoryStorage.layout().creators[index];
    }

    function getContractCountOf(address deployer) public view returns (uint256 count) {
        return FactoryStorage.layout().creatorToContracts[deployer].length;
    }

    function creatorToContractIndex(address deployer, uint256 index) public view returns (address deployedContract) {
        return FactoryStorage.layout().creatorToContracts[deployer][index];
    }

    function creatorToContractList(address deployer) public view returns (address[] memory deployedContracts) {
        return FactoryStorage.layout().creatorToContracts[deployer];
    }

    function contractToCreator(address deployedContract) public view returns (address creator) {
        creator = FactoryStorage.layout().contractToCreator[deployedContract];
    }
}
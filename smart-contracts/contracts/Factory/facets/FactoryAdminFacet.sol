// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FactoryStorage } from "../AppStorage.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { FactoryHandlerRoles } from "../AccessControlRoles.sol";

contract FactoryAdminFacet is AccessControlEnumerable, FactoryHandlerRoles {
    event ChangedToken(address contractAddress, uint256 priceToDeploy, address responsible);
    event WithdrawTokens(address recipient, address token, uint256 amount);

    function withdrawTokens(uint256 amount) public onlyRole(ADMINISTRATOR) {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        IERC20(store.currentERC20).transfer(msg.sender, amount);
        emit WithdrawTokens(msg.sender, store.currentERC20, amount);
    }

    function changeToken(address _token, uint256 _priceToDeploy) public onlyRole(ADMINISTRATOR) {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        store.currentERC20 = _token;
        store.deploymentCostForToken[_token] = _priceToDeploy;
        emit ChangedToken(_token, _priceToDeploy, msg.sender);
    }

    function getDeploymentCost() public view returns (uint256 price) {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        price = store.deploymentCostForToken[store.currentERC20];
    }

    function getCurrentToken() public view returns (address token) {
        token = FactoryStorage.layout().currentERC20;
    }

    function setFacetSource(address facetSource) public onlyRole(ADMINISTRATOR) {
        FactoryStorage.Layout storage store = FactoryStorage.layout();
        store.facetSource = facetSource;
    }

    function getFacetSource() public view returns (address facetSource) {
        facetSource = FactoryStorage.layout().facetSource;
    }
}
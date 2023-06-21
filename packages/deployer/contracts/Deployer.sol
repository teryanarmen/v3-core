// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import 'solmate/src/utils/CREATE3.sol';
import '@openzeppelin/contracts/utils/Address.sol';

import '@mimic-fi/v3-authorizer/contracts/Authorizer.sol';
import '@mimic-fi/v3-smart-vault/contracts/SmartVault.sol';
import '@mimic-fi/v3-registry/contracts/interfaces/IRegistry.sol';

contract Deployer {
    using Address for address;

    // Registry reference
    IRegistry public immutable registry;

    /**
     * @dev Emitted every time a permissions manager is deployed
     */
    event AuthorizerDeployed(string namespace, string name, address instance, address implementation);

    /**Bas
     * @dev Emitted every time a smart vault is deployed
     */
    event SmartVaultDeployed(string namespace, string name, address instance, address implementation);

    /**
     * @dev Emitted every time a task is deployed
     */
    event TaskDeployed(string namespace, string name, address instance, address implementation);

    /**
     * @dev Creates a new Deployer contract
     * @param _registry Address of the Mimic Registry to be referenced
     */
    constructor(IRegistry _registry) {
        registry = _registry;
    }

    /**
     * @dev Authorizer params
     * @param impl Address of the Authorizer implementation to be used
     * @param owners List of addresses that will be allowed to authorize and unauthorize permissions
     */
    struct AuthorizerParams {
        address impl;
        address[] owners;
    }

    /**
     * @dev Smart vault params
     * @param impl Address of the Smart Vault implementation to be used
     * @param authorized Address of the authorizer to be linked
     * @param priceOracle Optional Price Oracle to set for the Smart Vault
     * @param priceFeedParams List of price feeds to be set for the Smart Vault
     */
    struct SmartVaultParams {
        address impl;
        address authorizer;
        address priceOracle;
        SmartVault.PriceFeed[] priceFeedParams;
    }

    /**
     * @dev Task params
     * @param custom Whether the implementation is custom or not, if it is it won't be checked with Mimic's Registry
     * @param impl Address of the task implementation to be used
     * @param initializeData Call-data to initialize the new task instance
     */
    struct TaskParams {
        bool custom;
        address impl;
        bytes initializeData;
    }

    /**
     * @dev Tells the deployed address for a given input
     */
    function getAddress(address sender, string memory namespace, string memory name) external view returns (address) {
        return CREATE3.getDeployed(getSalt(sender, namespace, name));
    }

    /**
     * @dev Tells the salt for a given input
     */
    function getSalt(address sender, string memory namespace, string memory name) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, namespace, name));
    }

    /**
     * @dev Deploys a new authorizer instance
     */
    function deployAuthorizer(string memory namespace, string memory name, AuthorizerParams memory params) external {
        address instance = _deployClone(namespace, name, params.impl, true);
        Authorizer(instance).initialize(params.owners);
        emit AuthorizerDeployed(namespace, name, instance, params.impl);
    }

    /**
     * @dev Deploys a new smart vault instance
     */
    function deploySmartVault(string memory namespace, string memory name, SmartVaultParams memory params) external {
        address payable instance = payable(_deployClone(namespace, name, params.impl, true));
        SmartVault(instance).initialize(params.authorizer, params.priceOracle, params.priceFeedParams);
        emit SmartVaultDeployed(namespace, name, instance, params.impl);
    }

    /**
     * @dev Deploys a new task instance
     */
    function deployTask(string memory namespace, string memory name, TaskParams memory params) external {
        address instance = _deployClone(namespace, name, params.impl, !params.custom);
        if (params.initializeData.length > 0) instance.functionCall(params.initializeData, 'DEPLOYER_TASK_INIT_FAILED');
        emit TaskDeployed(namespace, name, instance, params.impl);
    }

    /**
     * @dev Deploys a new clone using CREATE3
     */
    function _deployClone(string memory namespace, string memory name, address implementation, bool check)
        internal
        returns (address)
    {
        if (check) {
            require(registry.isRegistered(implementation), 'DEPLOYER_IMPL_NOT_REGISTERED');
            require(!registry.isDeprecated(implementation), 'DEPLOYER_IMPL_DEPRECATED');
        }

        bytes memory bytecode = abi.encodePacked(
            hex'3d602d80600a3d3981f3363d3d373d3d3d363d73',
            implementation,
            hex'5af43d82803e903d91602b57fd5bf3'
        );

        bytes32 salt = getSalt(msg.sender, namespace, name);
        return CREATE3.deploy(salt, bytecode, 0);
    }
}

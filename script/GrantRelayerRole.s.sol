// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WorkforceDocumentRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract GrantRelayerRole is Script {
    bytes32 private constant GLOBAL_ISSUER_ROLE = keccak256("GLOBAL_ISSUER_ROLE");

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        address relayer = vm.envAddress("RELAYER_ADDRESS");

        require(contractAddress != address(0), "CONTRACT_ADDRESS required");
        require(relayer != address(0), "RELAYER_ADDRESS required");

        vm.startBroadcast(privateKey);
        WorkforceDocumentRegistry registry = WorkforceDocumentRegistry(contractAddress);
        registry.grantRole(GLOBAL_ISSUER_ROLE, relayer);
        vm.stopBroadcast();

        console2.log("Granted GLOBAL_ISSUER_ROLE to", relayer);
        console2.log("Contract", contractAddress);
        console2.log("Chain ID", block.chainid);
    }
}

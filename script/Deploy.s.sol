// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WorkforceDocumentRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract Deploy is Script {
    bytes32 private constant GLOBAL_ISSUER_ROLE = keccak256("GLOBAL_ISSUER_ROLE");

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address relayer = vm.envAddress("RELAYER_ADDRESS");
        uint48 defaultAdminDelay = uint48(vm.envOr("DEFAULT_ADMIN_DELAY", uint256(0)));

        require(relayer != address(0), "RELAYER_ADDRESS required");
        require(admin == deployer, "ADMIN_ADDRESS must match PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        WorkforceDocumentRegistry registry = new WorkforceDocumentRegistry(admin, defaultAdminDelay);
        registry.grantRole(GLOBAL_ISSUER_ROLE, relayer);
        vm.stopBroadcast();

        console2.log("WorkforceDocumentRegistry deployed at", address(registry));
        console2.log("Chain ID", block.chainid);
    }
}

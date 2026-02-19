// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WRMDocumentCertificationRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract Deploy is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address relayer = vm.envAddress("RELAYER_ADDRESS");

        require(relayer != address(0), "RELAYER_ADDRESS required");
        require(
            admin == deployer,
            "ADMIN_ADDRESS must match PRIVATE_KEY"
        );

        vm.startBroadcast(privateKey);
        WRMDocumentCertificationRegistry registry = new WRMDocumentCertificationRegistry(
            admin
        );
        registry.grantRole(registry.RELAYER_ROLE(), relayer);
        vm.stopBroadcast();

        console2.log(
            "WRMDocumentCertificationRegistry deployed at",
            address(registry)
        );
        console2.log("Chain ID", block.chainid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {WRMDocumentCertificationRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract GrantRelayerRole is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        address relayer = vm.envAddress("RELAYER_ADDRESS");

        require(contractAddress != address(0), "CONTRACT_ADDRESS required");
        require(relayer != address(0), "RELAYER_ADDRESS required");

        vm.startBroadcast(privateKey);
        WRMDocumentCertificationRegistry registry = WRMDocumentCertificationRegistry(
                contractAddress
            );
        registry.grantRole(registry.RELAYER_ROLE(), relayer);
        vm.stopBroadcast();

        console2.log("Granted RELAYER_ROLE to", relayer);
        console2.log("Contract", contractAddress);
        console2.log("Chain ID", block.chainid);
    }
}

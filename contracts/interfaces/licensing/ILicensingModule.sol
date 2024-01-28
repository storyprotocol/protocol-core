// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";

interface ILicensingModule is IParamVerifier {
    
    function licenseRegistry() external view returns (address);
    function policyToJson(Licensing.Policy memory policy) returns (string memory);

}

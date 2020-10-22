pragma solidity ^0.6.0;

import "../core/DFSRegistry.sol";

abstract contract ActionBase {
    DFSRegistry public constant registry = DFSRegistry(0x2f111D6611D3a3d559992f39e3F05aC0385dCd5D);
    DefisaverLogger public constant logger = DefisaverLogger(0x5c55B921f590a89C1Ebe84dF170E655a82b62126);

    enum ActionType { FL_ACTION, STANDARD_ACTION, CUSTOM_ACTION }

    function executeAction(uint, bytes memory, bytes32[] memory) virtual public payable returns (bytes32);
    function actionType() virtual public returns (uint8);
}

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../../interfaces/Manager.sol";
import "../../../interfaces/Vat.sol";
import "../../../interfaces/Join.sol";
import "../../../DS/DSMath.sol";
import "../ActionBase.sol";
import "../../../utils/SafeERC20.sol";


contract McdSupply is ActionBase, DSMath {
    address public constant MANAGER_ADDRESS = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address public constant VAT_ADDRESS = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant ETH_JOIN_ADDRESS = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;

    Manager public constant manager = Manager(MANAGER_ADDRESS);
    Vat public constant vat = Vat(VAT_ADDRESS);

    using SafeERC20 for ERC20;

    function executeAction(uint _actionId, bytes memory _callData, bytes32[] memory _returnValues) override public payable returns (bytes32) {
        int convertAmount = 0;

        (uint cdpId, uint amount, address joinAddr, address from) = parseParamData(_callData, _returnValues);

        pullTokens(joinAddr, from, amount);

        if (joinAddr == ETH_JOIN_ADDRESS) {
            Join(joinAddr).gem().deposit{value: amount}();
            convertAmount = toPositiveInt(amount);
        } else {
            convertAmount = toPositiveInt(convertTo18(joinAddr, amount));
        }

        Join(joinAddr).gem().approve(joinAddr, amount);
        Join(joinAddr).join(address(this), amount);

        vat.frob(
            manager.ilks(cdpId),
            manager.urns(cdpId),
            address(this),
            address(this),
            convertAmount,
            0
        );

        logger.Log(address(this), msg.sender, "McdSupply", abi.encode(cdpId, amount, joinAddr, from));

        return bytes32(convertAmount);
    }

    function actionType() override public returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    function parseParamData(
        bytes memory _data,
        bytes32[] memory _returnValues
    ) public pure returns (uint cdpId,uint amount, address joinAddr, address from) {
        uint8[] memory inputMapping;

        (cdpId, amount, joinAddr, from, inputMapping) = abi.decode(_data, (uint256,uint256,address,address,uint8[]));

        // mapping return values to new inputs
        if (inputMapping.length > 0 && _returnValues.length > 0) {
            for (uint i = 0; i < inputMapping.length; i += 2) {
                bytes32 returnValue = _returnValues[inputMapping[i + 1]];

                if (inputMapping[i] == 0) {
                    cdpId = uint(returnValue);
                } else if (inputMapping[i] == 1) {
                    amount = uint(returnValue);
                } else if (inputMapping[i] == 2) {
                    joinAddr = address(bytes20(returnValue));
                } else if (inputMapping[i] == 3) {
                    from = address(bytes20(returnValue));
                }
            }
        }
    }

    function pullTokens(address _joinAddr, address _from, uint _amount) internal {
        if (_from != address(0) && _joinAddr != ETH_JOIN_ADDRESS) {
            ERC20(address(Join(_joinAddr).gem())).safeTransferFrom(_from, address(this), _amount);
        }
    }


    /// @notice Converts a uint to int and checks if positive
    /// @param _x Number to be converted
    function toPositiveInt(uint _x) internal pure returns (int y) {
        y = int(_x);
        require(y >= 0, "int-overflow");
    }

    /// @notice Converts a number to 18 decimal percision
    /// @param _joinAddr Join address of the collateral
    /// @param _amount Number to be converted
    function convertTo18(address _joinAddr, uint256 _amount) internal view returns (uint256) {
        return mul(_amount, 10 ** (18 - Join(_joinAddr).dec()));
    }
}

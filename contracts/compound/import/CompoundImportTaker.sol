pragma solidity ^0.5.0;

import "../../flashloan/aave/ILendingPool.sol";
import "../../interfaces/CTokenInterface.sol";
import "../CompoundSaverHelper.sol";
import "../../auth/ProxyPermission.sol";
import "../../flashloan/FlashLoanLogger.sol";

contract ProxyRegistryLike {
    function proxies(address) public view returns (address);
    function build(address) public returns (address);
}

contract CompoundImportTaker is CompoundSaverHelper, ProxyPermission {

    ILendingPool public constant lendingPool = ILendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);

    address payable public constant COMPOUND_IMPORT_FLASH_LOAN = 0x0D5Ec207D7B29525Cc25963347903958C98a66d3;
    address public constant PROXY_REGISTRY_ADDRESS = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;

    // solhint-disable-next-line const-name-snakecase
    FlashLoanLogger public constant logger = FlashLoanLogger(
        0xb9303686B0EE92F92f63973EF85f3105329D345c
    );

    /// @dev User must approve COMPOUND_IMPORT_FLASH_LOAN to pull _cCollateralToken
    function importLoan(address _cCollateralToken, address _cBorrowToken) external {
        address proxy = getProxy();

        uint loanAmount = CTokenInterface(_cBorrowToken).borrowBalanceCurrent(address(this));
        bytes memory paramsData = abi.encode(_cCollateralToken, _cBorrowToken, msg.sender, proxy);

        givePermission(COMPOUND_IMPORT_FLASH_LOAN);

        lendingPool.flashLoan(COMPOUND_IMPORT_FLASH_LOAN, getUnderlyingAddr(_cBorrowToken), loanAmount, paramsData);

        removePermission(COMPOUND_IMPORT_FLASH_LOAN);

        logger.logFlashLoan("CompoundImport", loanAmount, 0, _cCollateralToken);
    }

    function getProxy() internal returns (address proxy) {
        proxy = ProxyRegistryLike(PROXY_REGISTRY_ADDRESS).proxies(msg.sender);

        if (proxy == address(0)) {
            proxy = ProxyRegistryLike(PROXY_REGISTRY_ADDRESS).build(msg.sender);
        }

    }
}
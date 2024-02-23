// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "../../../../contracts/lib/AccessPermission.sol";
import { TokenManagementModule } from "../../../../contracts/modules/external/TokenManagementModule.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { TOKEN_MANAGEMENT_MODULE_KEY } from "../../../../contracts/lib/modules/Module.sol";

// test
import { MockERC20 } from "../../mocks/token/MockERC20.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { MockERC1155 } from "../../mocks/token/MockERC1155.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TokenManagementModuleTest is BaseTest {
    using Strings for *;

    MockERC20 private tErc20 = new MockERC20();
    MockERC721 private tErc721 = new MockERC721("MockERC721");
    MockERC1155 private tErc1155 = new MockERC1155("uri");

    TokenManagementModule private tokenManagementModule;

    IIPAccount private ipAcct1;
    IIPAccount private ipAcct2;

    uint256 mintAmount20 = 100 * 10 ** tErc20.decimals();

    address randomFrontend = address(0x123);

    function setUp() public override {
        super.setUp();
        buildDeployAccessCondition(DeployAccessCondition({ accessController: true, governance: true }));
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: false, moduleRegistry: true }));
        deployConditionally();
        postDeploymentSetup();

        // Create IPAccounts (Alice is the owner)
        mockNFT.mintId(alice, 1);
        mockNFT.mintId(alice, 2);

        ipAcct1 = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1)));
        ipAcct2 = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2)));

        vm.label(address(ipAcct1), "IPAccount1");
        vm.label(address(ipAcct2), "IPAccount2");

        tokenManagementModule = new TokenManagementModule(address(accessController), address(ipAccountRegistry));

        vm.prank(u.admin);
        moduleRegistry.registerModule(TOKEN_MANAGEMENT_MODULE_KEY, address(tokenManagementModule));
    }

    modifier testERC20_mintToIpAcct1() {
        _expectBalanceERC20(address(ipAcct1), 0);
        tErc20.mint(address(ipAcct1), mintAmount20);
        _expectBalanceERC20(address(ipAcct1), mintAmount20);
        _expectBalanceERC20(address(ipAcct2), 0);
        _;
    }

    function test_TokenManagementModule_transferERC20() public testERC20_mintToIpAcct1 {
        _approveERC20(alice, ipAcct1, address(tokenManagementModule));

        vm.prank(alice);
        tokenManagementModule.transferERC20(payable(ipAcct1), address(ipAcct2), address(tErc20), mintAmount20 / 2);

        _expectBalanceERC20(address(ipAcct1), mintAmount20 / 2);
        _expectBalanceERC20(address(ipAcct2), mintAmount20 / 2);

        vm.prank(alice);
        ipAcct1.execute(
            address(tokenManagementModule),
            0,
            abi.encodeWithSelector(
                tokenManagementModule.transferERC20.selector,
                payable(ipAcct1),
                address(ipAcct2),
                address(tErc20),
                mintAmount20
            )
        );

        _expectBalanceERC20(address(ipAcct1), 0);
        _expectBalanceERC20(address(ipAcct2), mintAmount20);
    }

    function test_TokenManagementModule_transferERC20_delegatedCall() public testERC20_mintToIpAcct1 {
        // signer: tokenManagementModule
        // to: tErc20
        // func: transfer
        _approveERC20(alice, ipAcct1, address(tokenManagementModule));

        // signer: randomFrontend
        // to: tokenManagementModule
        // func: transferERC20
        vm.prank(alice);
        ipAcct1.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAcct1),
                randomFrontend,
                address(tokenManagementModule),
                tokenManagementModule.transferERC20.selector,
                AccessPermission.ALLOW
            )
        );

        vm.prank(randomFrontend);
        tokenManagementModule.transferERC20(payable(ipAcct1), address(ipAcct2), address(tErc20), mintAmount20 / 2);

        _expectBalanceERC20(address(ipAcct1), mintAmount20 / 2);
        _expectBalanceERC20(address(ipAcct2), mintAmount20 / 2);

        vm.prank(randomFrontend);
        ipAcct1.execute(
            address(tokenManagementModule),
            0,
            abi.encodeWithSelector(
                tokenManagementModule.transferERC20.selector,
                payable(ipAcct1),
                address(ipAcct2),
                address(tErc20),
                mintAmount20
            )
        );

        _expectBalanceERC20(address(ipAcct1), 0);
        _expectBalanceERC20(address(ipAcct2), mintAmount20);
    }

    function test_TokenManagementModule_transferERC20_revert_malicious_anotherERC20Transfer()
        public
        testERC20_mintToIpAcct1
    {
        address maliciousFrontend = address(0x456);

        MockERC20 anotherErc20 = new MockERC20();

        anotherErc20.mint(address(ipAcct1), 1000);
        assertEq(anotherErc20.balanceOf(address(ipAcct1)), 1000, "ERC20 balance does not match");

        // Approve TokenManagementModule to transfer tErc20 from IPAccount1
        // signer: tokenManagementModule
        // to: tErc20
        // func: transfer
        _approveERC20(alice, ipAcct1, address(tokenManagementModule));

        // Approve TokenManagementModule to transfer anotherErc20 from IPAccount1
        // signer: tokenManagementModule
        // to: anotherErc20
        // func: transfer
        vm.prank(address(ipAcct1));
        accessController.setPermission(
            address(ipAcct1),
            address(tokenManagementModule),
            address(anotherErc20),
            anotherErc20.transfer.selector,
            AccessPermission.ALLOW
        );

        // Approve a frontend contract to transfer token on behalf of a user (IPAccount1)
        // signer: maliciousFrontend
        // to: tokenManagementModule
        // func: transferERC20
        vm.prank(alice);
        ipAcct1.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAcct1),
                maliciousFrontend,
                address(tokenManagementModule),
                tokenManagementModule.transferERC20.selector,
                AccessPermission.ALLOW
            )
        );

        //
        // ======= Malicious behavior =======
        // Alice (owner of IPAccount1) only wants the frontend to transfer tErc20. However, because there's no
        // restriction on delegation, the malicious frontend can transfer anotherErc20 as well.
        // ==================================
        //

        vm.startPrank(maliciousFrontend);
        tokenManagementModule.transferERC20(payable(ipAcct1), address(0xbeef), address(tErc20), 1000);
        tokenManagementModule.transferERC20(payable(ipAcct1), address(0xbeef), address(anotherErc20), 1000);
        vm.stopPrank();

        // another token is drained
        assertEq(anotherErc20.balanceOf(address(ipAcct1)), 0, "ERC20 balance does not match");
        assertEq(anotherErc20.balanceOf(address(0xbeef)), 1000, "ERC20 balance does not match");
    }

    function test_TokenManagementModule_transferERC20_revert_moduleCaller_invalidAccess()
        public
        testERC20_mintToIpAcct1
    {
        _approveERC20(alice, ipAcct1, address(tokenManagementModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenManagementModule),
            tokenManagementModule.transferERC20.selector
        );
        tokenManagementModule.transferERC20(payable(ipAcct1), address(ipAcct2), address(tErc20), mintAmount20);

        _expectBalanceERC20(address(ipAcct1), mintAmount20);
    }

    function test_TokenManagementModule_transferERC721() public {
        uint256 tokenId = tErc721.mint(address(ipAcct1));
        _expectOwnerERC721(address(ipAcct1), tokenId);

        _approveERC721(alice, ipAcct1, address(tokenManagementModule));

        vm.prank(alice);
        tokenManagementModule.transferERC721(payable(ipAcct1), address(ipAcct2), address(tErc721), tokenId);

        _expectOwnerERC721(address(ipAcct2), tokenId);
    }

    function test_TokenManagementModule_transferERC721_revert_moduleCaller_invalidAccess() public {
        uint256 tokenId = tErc721.mint(address(ipAcct1));
        _expectOwnerERC721(address(ipAcct1), tokenId);

        _approveERC721(alice, ipAcct1, address(tokenManagementModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenManagementModule),
            tokenManagementModule.transferERC721.selector
        );
        tokenManagementModule.transferERC721(payable(ipAcct1), address(ipAcct2), address(tErc721), tokenId);

        _expectOwnerERC721(address(ipAcct1), tokenId);
    }

    function test_TokenManagementModule_transferERC1155() public {
        uint256 tokenId = 1;
        uint256 mintAmount1155 = 100;
        tErc1155.mintId(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct2), tokenId, 0);

        _approveERC1155(alice, ipAcct1, address(tokenManagementModule));

        vm.prank(alice);
        tokenManagementModule.transferERC1155(
            payable(ipAcct1),
            address(ipAcct2),
            address(tErc1155),
            tokenId,
            mintAmount1155
        );

        _expectBalanceERC1155(address(ipAcct1), tokenId, 0);
        _expectBalanceERC1155(address(ipAcct2), tokenId, mintAmount1155);
    }

    function test_TokenManagementModule_transferERC1155_revert_moduleCaller_invalidAccess() public {
        uint256 tokenId = 1;
        uint256 mintAmount1155 = 100;
        tErc1155.mintId(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct2), tokenId, 0);

        _approveERC1155(alice, ipAcct1, address(tokenManagementModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenManagementModule),
            tokenManagementModule.transferERC1155.selector
        );
        tokenManagementModule.transferERC1155(
            payable(ipAcct1),
            address(ipAcct2),
            address(tErc1155),
            tokenId,
            mintAmount1155
        );

        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct2), tokenId, 0);
    }

    //
    // Helpers
    //

    function _approveERC20(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc20),
                tErc20.transfer.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _approveERC721(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc721),
                tErc721.transferFrom.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _approveERC1155(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc1155),
                tErc1155.safeTransferFrom.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _expectBalanceERC20(address account, uint256 expected) internal {
        assertEq(tErc20.balanceOf(account), expected, "ERC20 balance does not match");
    }

    function _expectOwnerERC721(address account, uint256 tokenId) internal {
        assertEq(tErc721.ownerOf(tokenId), account, "Owner does not match");
    }

    function _expectBalanceERC1155(address account, uint256 tokenId, uint256 expected) internal {
        assertEq(tErc1155.balanceOf(account, tokenId), expected, "ERC1155 balance does not match");
    }

    function _expectInvalidAccess(address ipAccount, address signer, address to, bytes4 func) internal {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.AccessController__PermissionDenied.selector, ipAccount, signer, to, func)
        );
    }
}

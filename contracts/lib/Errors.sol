// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol contract errors.
library Errors {
    ////////////////////////////////////////////////////////////////////////////
    //                                Governance                              //
    ////////////////////////////////////////////////////////////////////////////
    error Governance__OnlyProtocolAdmin();
    error Governance__ZeroAddress();
    error Governance__ProtocolPaused();
    error Governance__InconsistentState();
    error Governance__NewStateIsTheSameWithOldState();
    error Governance__UnsupportedInterface(string interfaceName);

    ////////////////////////////////////////////////////////////////////////////
    //                                IPAccount                               //
    ////////////////////////////////////////////////////////////////////////////
    error IPAccount__InvalidSigner();
    error IPAccount__InvalidSignature();
    error IPAccount__ExpiredSignature();
    error IPAccount__InvalidCalldata();

    ////////////////////////////////////////////////////////////////////////////
    //                                   Module                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The caller is not allowed to call the provided module.
    error Module_Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                               IPAccountRegistry                        //
    ////////////////////////////////////////////////////////////////////////////
    error IPAccountRegistry_InvalidIpAccountImpl();

    ////////////////////////////////////////////////////////////////////////////
    //                               IPAssetRegistry                         //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The IP asset has already been registered.
    error IPAssetRegistry__AlreadyRegistered();

    /// @notice The IP account has already been created.
    error IPAssetRegistry__IPAccountAlreadyCreated();

    /// @notice The IP asset has not yet been registered.
    error IPAssetRegistry__NotYetRegistered();

    /// @notice The specified IP resolver is not valid.
    error IPAssetRegistry__ResolverInvalid();

    /// @notice Caller not authorized to perform the IP registry function call.
    error IPAssetRegistry__Unauthorized();

    /// @notice The deployed address of account doesn't match with IP ID.
    error IPAssetRegistry__InvalidAccount();

    /// @notice The metadata provider is not valid.
    error IPAssetRegistry__InvalidMetadataProvider();

    ////////////////////////////////////////////////////////////////////////////
    //                                 IPResolver                            ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The targeted IP does not yet have an IP account.
    error IPResolver_InvalidIP();

    /// @notice Caller not authorized to perform the IP resolver function call.
    error IPResolver_Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                          Metadata Provider                            ///
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Provided hash metadata is not valid.
    error MetadataProvider__HashInvalid();

    /// @notice The caller is not the authorized IP asset owner.
    error MetadataProvider__IPAssetOwnerInvalid();

    /// @notice Provided hash metadata is not valid.
    error MetadataProvider__NameInvalid();

    /// @notice The new metadata provider is not compatible with the old provider.
    error MetadataProvider__MetadataNotCompatible();

    /// @notice Provided registrant metadata is not valid.
    error MetadataProvider__RegistrantInvalid();

    /// @notice Provided registration date is not valid.
    error MetadataProvider__RegistrationDateInvalid();

    /// @notice Caller does not access to set metadata storage for the provider.
    error MetadataProvider__Unauthorized();

    /// @notice A metadata provider upgrade is not currently available.
    error MetadataProvider__UpgradeUnavailable();

    /// @notice The upgrade provider is not valid.
    error MetadataProvider__UpgradeProviderInvalid();

    /// @notice Provided metadata URI is not valid.
    error MetadataProvider__URIInvalid();

    ////////////////////////////////////////////////////////////////////////////
    //                            LicenseRegistry                             //
    ////////////////////////////////////////////////////////////////////////////

    error LicenseRegistry__CallerNotLicensingModule();
    error LicenseRegistry__ZeroLicensingModule();
    error LicensingModule__CallerNotLicenseRegistry();
    /// @notice emitted when trying to transfer a license that is not transferable (by policy)
    error LicenseRegistry__NotTransferable();

    ////////////////////////////////////////////////////////////////////////////
    //                            LicensingModule                             //
    ////////////////////////////////////////////////////////////////////////////

    error LicensingModule__PolicyAlreadySetForIpId();
    error LicensingModule__FrameworkNotFound();
    error LicensingModule__EmptyLicenseUrl();
    error LicensingModule__InvalidPolicyFramework();
    error LicensingModule__PolicyAlreadyAdded();
    error LicensingModule__ParamVerifierLengthMismatch();
    error LicensingModule__PolicyNotFound();
    error LicensingModule__NotLicensee();
    error LicensingModule__ParentIdEqualThanChild();
    error LicensingModule__LicensorDoesntHaveThisPolicy();
    error LicensingModule__MintLicenseParamFailed();
    error LicensingModule__LinkParentParamFailed();
    error LicensingModule__TransferParamFailed();
    error LicensingModule__InvalidLicensor();
    error LicensingModule__ParamVerifierAlreadySet();
    error LicensingModule__CommercialTermInNonCommercialPolicy();
    error LicensingModule__EmptyParamName();
    error LicensingModule__UnregisteredFrameworkAddingPolicy();
    error LicensingModule__UnauthorizedAccess();
    error LicensingModule__LicensorNotRegistered();
    error LicensingModule__CallerNotLicensorAndPolicyNotSet();
    error LicensingModule__DerivativesCannotAddPolicy();
    error LicensingModule__IncompatibleRoyaltyPolicyAddress();
    error LicensingModule__IncompatibleRoyaltyPolicyDerivativeRevShare();
    error LicensingModule__IncompatibleLicensorCommercialPolicy();
    error LicensingModule__IncompatibleLicensorRoyaltyDerivativeRevShare();
    error LicensingModule__DerivativeRevShareSumExceedsMaxRNFTSupply();
    error LicensingModule__MismatchBetweenCommercialRevenueShareAndMinRoyalty();
    error LicensingModule__MismatchBetweenRoyaltyPolicy();

    ////////////////////////////////////////////////////////////////////////////
    //                        LicensingModuleAware                            //
    ////////////////////////////////////////////////////////////////////////////

    error LicensingModuleAware__CallerNotLicensingModule();

    ////////////////////////////////////////////////////////////////////////////
    //                         PolicyFrameworkManager                         //
    ////////////////////////////////////////////////////////////////////////////

    error PolicyFrameworkManager__GettingPolicyWrongFramework();

    ////////////////////////////////////////////////////////////////////////////
    //                     LicensorApprovalChecker                            //
    ////////////////////////////////////////////////////////////////////////////
    error LicensorApprovalChecker__Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                            Dispute Module                              //
    ////////////////////////////////////////////////////////////////////////////

    error DisputeModule__ZeroArbitrationPolicy();
    error DisputeModule__ZeroArbitrationRelayer();
    error DisputeModule__ZeroDisputeTag();
    error DisputeModule__ZeroLinkToDisputeEvidence();
    error DisputeModule__NotWhitelistedArbitrationPolicy();
    error DisputeModule__NotWhitelistedDisputeTag();
    error DisputeModule__NotWhitelistedArbitrationRelayer();
    error DisputeModule__NotDisputeInitiator();
    error DisputeModule__NotInDisputeState();
    error DisputeModule__NotAbleToResolve();
    error DisputeModule__NotRegisteredIpId();
    error DisputeModule__UnauthorizedAccess();

    error ArbitrationPolicySP__ZeroDisputeModule();
    error ArbitrationPolicySP__ZeroPaymentToken();
    error ArbitrationPolicySP__NotDisputeModule();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Module                              //
    ////////////////////////////////////////////////////////////////////////////

    error RoyaltyModule__ZeroRoyaltyPolicy();
    error RoyaltyModule__NotWhitelistedRoyaltyPolicy();
    error RoyaltyModule__AlreadySetRoyaltyPolicy();
    error RoyaltyModule__ZeroRoyaltyToken();
    error RoyaltyModule__NotWhitelistedRoyaltyToken();
    error RoyaltyModule__NoRoyaltyPolicySet();
    error RoyaltyModule__IncompatibleRoyaltyPolicy();
    error RoyaltyModule__NotAllowedCaller();
    error RoyaltyModule__ZeroLicensingModule();

    error RoyaltyPolicyLS__ZeroRoyaltyModule();
    error RoyaltyPolicyLS__ZeroLiquidSplitFactory();
    error RoyaltyPolicyLS__ZeroLiquidSplitMain();
    error RoyaltyPolicyLS__NotRoyaltyModule();
    error RoyaltyPolicyLS__TransferFailed();
    error RoyaltyPolicyLS__InvalidMinRoyalty();
    error RoyaltyPolicyLS__InvalidRoyaltyStack();
    error RoyaltyPolicyLS__ZeroMinRoyalty();
    error RoyaltyPolicyLS__ZeroLicensingModule();

    error LSClaimer__InvalidPath();
    error LSClaimer__InvalidPathFirstPosition();
    error LSClaimer__InvalidPathLastPosition();
    error LSClaimer__AlreadyClaimed();
    error LSClaimer__ETHBalanceNotZero();
    error LSClaimer__ERC20BalanceNotZero();
    error LSClaimer__ZeroIpId();
    error LSClaimer__ZeroLicensingModule();
    error LSClaimer__ZeroRoyaltyPolicyLS();

    ////////////////////////////////////////////////////////////////////////////
    //                             ModuleRegistry                             //
    ////////////////////////////////////////////////////////////////////////////

    error ModuleRegistry__ModuleAddressZeroAddress();
    error ModuleRegistry__ModuleAddressNotContract();
    error ModuleRegistry__ModuleAlreadyRegistered();
    error ModuleRegistry__NameEmptyString();
    error ModuleRegistry__NameAlreadyRegistered();
    error ModuleRegistry__NameDoesNotMatch();
    error ModuleRegistry__ModuleNotRegistered();

    ////////////////////////////////////////////////////////////////////////////
    //                               RegistrationModule                       //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The caller is not the owner of the root IP NFT.
    error RegistrationModule__InvalidOwner();

    ////////////////////////////////////////////////////////////////////////////
    //                             AccessController                           //
    ////////////////////////////////////////////////////////////////////////////

    error AccessController__IPAccountIsZeroAddress();
    error AccessController__IPAccountIsNotValid(address ipAccount);
    error AccessController__SignerIsZeroAddress();
    error AccessController__CallerIsNotIPAccount();
    error AccessController__PermissionIsNotValid();
    error AccessController__RecipientIsNotRegisteredModule(address to);
    error AccessController__PermissionDenied(address ipAccount, address signer, address to, bytes4 func);

    ////////////////////////////////////////////////////////////////////////////
    //                             AccessControlled                           //
    ////////////////////////////////////////////////////////////////////////////
    error AccessControlled__ZeroAddress();
    error AccessControlled__NotIpAccount(address ipAccount);
    error AccessControlled__CallerIsNotIpAccount(address caller);

    ////////////////////////////////////////////////////////////////////////////
    //                             TaggingModule                              //
    ////////////////////////////////////////////////////////////////////////////

    error TaggingModule__InvalidRelationTypeName();
    error TaggingModule__RelationTypeAlreadyExists();
    error TaggingModule__SrcIpIdDoesNotHaveSrcTag();
    error TaggingModule__DstIpIdDoesNotHaveDstTag();
    error TaggingModule__RelationTypeDoesNotExist();
}

// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.19;

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

    ////////////////////////////////////////////////////////////////////////////
    //                                   Module                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The caller is not allowed to call the provided module.
    error Module_Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                               IPRecordRegistry                         //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The IP record has already been registered.
    error IPRecordRegistry_AlreadyRegistered();

    /// @notice The IP account has already been created.
    error IPRecordRegistry_IPAccountAlreadyCreated();

    /// @notice The IP record has not yet been registered.
    error IPRecordRegistry_NotYetRegistered();

    /// @notice The specified IP resolver is not valid.
    error IPRecordRegistry_ResolverInvalid();

    /// @notice Caller not authorized to perform the IP registry function call.
    error IPRecordRegistry_Unauthorized();

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

    /// @notice Caller does not access to set metadata storage for the provider.
    error MetadataProvider_Unauthorized();

    ////////////////////////////////////////////////////////////////////////////
    //                            LicenseRegistry                             //
    ////////////////////////////////////////////////////////////////////////////

    error LicenseRegistry__PolicyAlreadySetForIpId();
    error LicenseRegistry__FrameworkNotFound();
    error LicenseRegistry__EmptyLicenseUrl();
    error LicenseRegistry__ZeroPolicyFramework();
    error LicenseRegistry__PolicyAlreadyAdded();
    error LicenseRegistry__ParamVerifierLengthMismatch();
    error LicenseRegistry__PolicyNotFound();
    error LicenseRegistry__NotLicensee();
    error LicenseRegistry__ParentIdEqualThanChild();
    error LicenseRegistry__LicensorDoesntHaveThisPolicy();
    error LicenseRegistry__MintLicenseParamFailed();
    error LicenseRegistry__LinkParentParamFailed();
    error LicenseRegistry__TransferParamFailed();
    error LicenseRegistry__InvalidLicensor();
    error LicenseRegistry__ParamVerifierAlreadySet();
    error LicenseRegistry__CommercialTermInNonCommercialPolicy();
    error LicenseRegistry__EmptyParamName();
    error LicenseRegistry__UnregisteredFrameworkAddingPolicy();

    ////////////////////////////////////////////////////////////////////////////
    //                        LicenseRegistryAware                            //
    ////////////////////////////////////////////////////////////////////////////

    error LicenseRegistryAware__CallerNotLicenseRegistry();

    ////////////////////////////////////////////////////////////////////////////
    //                           PolicyFramework                              //
    ////////////////////////////////////////////////////////////////////////////

    error PolicyFramework_FrameworkNotYetRegistered();

    ////////////////////////////////////////////////////////////////////////////
    //                     LicensorApprovalManager                            //
    ////////////////////////////////////////////////////////////////////////////
    error LicensorApprovalManager__Unauthorized();

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

    error ArbitrationPolicySP__ZeroDisputeModule();
    error ArbitrationPolicySP__ZeroPaymentToken();
    error ArbitrationPolicySP__NotDisputeModule();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Module                              //
    ////////////////////////////////////////////////////////////////////////////

    error RoyaltyModule__ZeroRoyaltyPolicy();
    error RoyaltyModule__NotWhitelistedRoyaltyPolicy();
    error RoyaltyModule__AlreadySetRoyaltyPolicy();

    error RoyaltyPolicyLS__ZeroRoyaltyModule();
    error RoyaltyPolicyLS__ZeroLiquidSplitFactory();
    error RoyaltyPolicyLS__ZeroLiquidSplitMain();
    error RoyaltyPolicyLS__NotRoyaltyModule();
    error RoyaltyPolicyLS__TransferFailed();

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
    error AccessController__IPAccountIsNotValid();
    error AccessController__SignerIsZeroAddress();
    error AccessController__CallerIsNotIPAccount();
    error AccessController__PermissionIsNotValid();

    ////////////////////////////////////////////////////////////////////////////
    //                             TaggingModule                              //
    ////////////////////////////////////////////////////////////////////////////

    error TaggingModule__InvalidRelationTypeName();
    error TaggingModule__RelationTypeAlreadyExists();
    error TaggingModule__SrcIpIdDoesNotHaveSrcTag();
    error TaggingModule__DstIpIdDoesNotHaveDstTag();
    error TaggingModule__RelationTypeDoesNotExist();
}

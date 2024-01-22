import * as deployedAll from "../../out/all.json"
import {
  DisputeModule,
  DisputeModule__factory,
  IERC6551Registry,
  IERC6551Registry__factory,
  IPAccountRegistry,
  IPAccountRegistry__factory,
  IPMetadataResolver,
  IPMetadataResolver__factory,
  IPRecordRegistry,
  IPRecordRegistry__factory,
  LicenseRegistry,
  LicenseRegistry__factory,
  ModuleRegistry,
  ModuleRegistry__factory,
  RegistrationModule,
  RegistrationModule__factory,
  RoyaltyModule,
  RoyaltyModule__factory,
  TaggingModule,
  TaggingModule__factory,
} from "../../../typechain"

export interface DeployedContracts {
  // Registries
  ERC6551Registry: IERC6551Registry
  IPAccountRegistry: IPAccountRegistry
  IPRecordRegistry: IPRecordRegistry
  LicenseRegistry: LicenseRegistry
  ModuleRegistry: ModuleRegistry
  // Resolvers
  IPMetadataResolver: IPMetadataResolver
  // Modules
  DisputeModule: DisputeModule
  RoyaltyModule: RoyaltyModule
  TaggingModule: TaggingModule
  RegistrationModule: RegistrationModule
}

export function getDeployedContracts(deployerSigner: any) {
  const ERC6551_REGISTRY = "0x000000006551c19487814612e58FE06813775758" // v0.3.1 Ethereum

  return {
    // Registries
    ERC6551Registry: IERC6551Registry__factory.connect(ERC6551_REGISTRY, deployerSigner),
    IPAccountRegistry: IPAccountRegistry__factory.connect(deployedAll.contracts.IPAccountRegistry, deployerSigner),
    IPRecordRegistry: IPRecordRegistry__factory.connect(deployedAll.contracts.IPRecordRegistry, deployerSigner),
    LicenseRegistry: LicenseRegistry__factory.connect(deployedAll.contracts.LicenseRegistry, deployerSigner),
    ModuleRegistry: ModuleRegistry__factory.connect(deployedAll.contracts.ModuleRegistry, deployerSigner),
    // Resolvers
    IPMetadataResolver: IPMetadataResolver__factory.connect(deployedAll.contracts.IPMetadataResolver, deployerSigner),
    // Modules
    DisputeModule: DisputeModule__factory.connect(deployedAll.contracts.DisputeModule, deployerSigner),
    RoyaltyModule: RoyaltyModule__factory.connect(deployedAll.contracts.RoyaltyModule, deployerSigner),
    TaggingModule: TaggingModule__factory.connect(deployedAll.contracts.TaggingModule, deployerSigner),
    RegistrationModule: RegistrationModule__factory.connect(deployedAll.contracts.RegistrationModule, deployerSigner),
  }
}

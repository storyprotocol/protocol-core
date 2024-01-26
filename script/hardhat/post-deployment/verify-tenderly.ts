import { readFileSync } from "fs"
import { tenderly } from "hardhat"

import * as addr from "../../../deployments/deployment-1.json"

require("dotenv").config()

async function main() {
  const ERC6551_REGISTRY = "0x000000006551c19487814612e58FE06813775758"

  if (!process.env.TENDERLY_FORK_RPC_URL) throw new Error("TENDERLY_FORK_RPC_URL not set")
  const TENDERLY_FORK_ID = process.env.TENDERLY_FORK_RPC_URL.split("/").pop() ?? ""

  const _contracts = [
    {
      address: addr.AccessController,
      name: "AccessController",
      // libraries: {
      // 	name1: addr.AccessControlLibrary,
      // }
    },
    {
      address: addr.IPAccountImpl,
      name: "IPAccountImpl",
    },
    {
      address: addr.ModuleRegistry,
      name: "ModuleRegistry",
    },

    {
      address: addr.LicenseRegistry,
      name: "LicenseRegistry",
      arguments: ["https://example.com/{id}.json"],
    },

    {
      address: addr.IPAccountRegistry,
      name: "IPAccountRegistry",
      arguments: [ERC6551_REGISTRY, addr.AccessController, addr.IPAccountImpl],
    },

    {
      address: addr.IPRecordRegistry,
      name: "IPRecordRegistry",
      arguments: [addr.ModuleRegistry, addr.IPAccountRegistry],
    },

    {
      address: addr.IPMetadataResolver,
      name: "IPMetadataResolver",
      arguments: [addr.AccessController, addr.IPRecordRegistry, addr.IPAccountRegistry, addr.LicenseRegistry],
    },

    {
      address: addr.RegistrationModule,
      name: "RegistrationModule",
      arguments: [
        addr.AccessController,
        addr.IPRecordRegistry,
        addr.IPAccountRegistry,
        addr.LicenseRegistry,
        addr.IPMetadataResolver,
      ],
    },

    {
      address: addr.TaggingModule,
      name: "TaggingModule",
    },

    {
      address: addr.RoyaltyModule,
      name: "RoyaltyModule",
    },

    {
      address: addr.DisputeModule,
      name: "DisputeModule",
    },
  ]

  // tenderly.verify(
  //   _contracts.map((c) => ({
  //     ...c,
  //     compiler: {
  //       version: "0.8.23",
  //       settings: {
  //         optimizer: {
  //           enabled: true,
  //           runs: 20000,
  //         },
  //       },
  //     },
  //   }))
  // )

  const contracts = [
    // TenderlyContract[] (https://github.com/Tenderly/hardhat-tenderly/blob/b2a7831388f064483234d0583d7baeea599d332f/packages/tenderly-core/src/internal/core/types/Contract.ts#L16C18-L16C34)
    // {
    //   contractName: "AccessController",
    //   source: readFileSync("contracts/AccessController.sol", "utf-8").toString(),
    //   sourcePath: "AccessController.sol",
    //   networks: {
    //     [TENDERLY_FORK_ID]: {
    //       address: addr.AccessController,
    //       links: {},
    //     },
    //   },
    // },
    {
      contractName: "IPAccountImpl",
      source: readFileSync("contracts/IPAccountImpl.sol", "utf-8").toString(),
      sourcePath: "IPAccountImpl.sol",
      networks: {
        [TENDERLY_FORK_ID]: {
          address: addr.IPAccountImpl,
          links: {},
        },
      },
    },
  ]

  const request = {
    // TenderlyForkContractUploadRequest (https://github.com/Tenderly/hardhat-tenderly/blob/b2a7831388f064483234d0583d7baeea599d332f/packages/tenderly-core/src/internal/core/types/Requests.ts#L13)
    root: "",
    config: {
      // TenderlyContractConfig (https://github.com/Tenderly/hardhat-tenderly/blob/b2a7831388f064483234d0583d7baeea599d332f/packages/tenderly-core/src/internal/core/types/Contract.ts#L4)
      compiler_version: "0.8.23",
      optimizations_used: true,
      optimizations_count: 20000,
      evm_version: "default",
    },
    contracts,
  }

  tenderly.verifyForkAPI(
    request,
    process.env.TENDERLY_PROJECT_SLUG ?? "",
    process.env.TENDERLY_USERNAME ?? "",
    TENDERLY_FORK_ID
  )
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

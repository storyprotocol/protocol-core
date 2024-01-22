import hre from "hardhat"
import { DeployResult, DeployOptions } from "hardhat-deploy/dist/types"
// import { HardhatRuntimeEnvironment } from "hardhat/types"
import { verify } from "../utils/verify"

const libraries: { [key: string]: string } = {}
const deploys: { [key: string]: { address: string; args?: any[] } } = {}

const ERC6551_REGISTRY = "0x000000006551c19487814612e58FE06813775758"

const deployMain = async function () {
  // DeployFunction
  const { deployments, getNamedAccounts, network } = hre
  const { deploy: deployFn } = deployments
  const { deployer } = await getNamedAccounts()
  // const deployerSigner = await ethers.getSigner(deployer)

  const defaultDeployOpts: DeployOptions = {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  }

  const deployLibrary = async (libraryKey: string): Promise<string> => {
    console.log("/*////////////////////////////////////////////////////////////*/")
    console.log(`Deploying ${libraryKey}...`)
    const deployRes: DeployResult = await deployFn(libraryKey, { ...defaultDeployOpts })
    libraries[libraryKey] = deployRes.address
    console.log(`Deployed ${libraryKey} to: `, deployRes.address)
    return deployRes.address
  }

  const deployContract = async (contractKey: string, extraDeployOpts?: Partial<DeployOptions>): Promise<string> => {
    console.log("/*////////////////////////////////////////////////////////////*/")
    console.log(`Deploying ${contractKey}...`)
    const deployRes: DeployResult = await deployFn(contractKey, { ...defaultDeployOpts, ...extraDeployOpts })
    deploys[contractKey] = { address: deployRes.address, args: deployRes.args }
    console.log(`Deployed ${contractKey} to: `, deployRes.address)
    return deployRes.address
  }

  console.log(
    `/*////////////////////////////////////////////////////////////\n
		\n											Network: ${network.name}
		\n////////////////////////////////////////////////////////////*/`
  )

  await _deployLibaries(deployLibrary)
  await _deployContracts(deployContract)
  await _verifyAll()
}

async function _deployLibaries(deployLibrary: any) {
	// do one by one to keep nonce in order
  await deployLibrary("AccessPermission")
  await deployLibrary("Errors")
  await deployLibrary("IP")
  await deployLibrary("Licensing")
  await deployLibrary("IPAccountChecker")
  await deployLibrary("Module")
}

async function _deployContracts(deployContract: any) {
  let contractKey: string

  contractKey = "AccessController"
  const accessController = await deployContract(contractKey, {
    libraries: {
      AccessPermission: libraries.AccessPermission,
      Errors: libraries.Errors,
      IPAccountChecker: libraries.IPAccountChecker,
    },
  })

  contractKey = "IPAccountImpl"
  const implementation = await deployContract(contractKey)

  contractKey = "ModuleRegistry"
  const moduleRegistry = await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "LicenseRegistry"
  const licenseRegistry = await deployContract(contractKey, {
    args: ["https://example.com/{id}.json"],
    libraries: {
      Errors: libraries.Errors,
      Licensing: libraries.Licensing,
    },
  })

  contractKey = "IPAccountRegistry"
  const ipAccountRegistry = await deployContract(contractKey, {
    args: [ERC6551_REGISTRY, accessController, implementation],
  })

  contractKey = "IPRecordRegistry"
  const ipRecordRegistry = await deployContract(contractKey, {
    args: [moduleRegistry, ipAccountRegistry],
    libraries: {
      Errors: libraries.Errors,
      Module: libraries.Module,
    },
  })

  contractKey = "IPMetadataResolver"
  const ipMetadataResolver = await deployContract(contractKey, {
    args: [accessController, ipRecordRegistry, ipAccountRegistry, licenseRegistry],
    libraries: {
      Errors: libraries.Errors,
      IP: libraries.IP,
    },
  })

  contractKey = "RegistrationModule"
  await deployContract(contractKey, {
    args: [accessController, ipRecordRegistry, ipAccountRegistry, licenseRegistry, ipMetadataResolver],
    libraries: {
      Errors: libraries.Errors,
      IP: libraries.IP,
      Module: libraries.Module,
    },
  })

  contractKey = "TaggingModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "RoyaltyModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })

  contractKey = "DisputeModule"
  await deployContract(contractKey, {
    libraries: {
      Errors: libraries.Errors,
    },
  })
}

async function _verifyAll() {
  const proms = Promise.all(Object.keys(deploys).map((ck) => verify(deploys[ck].address, deploys[ck].args || [])))
  return proms
    .then((res) => {
      console.log("Verified all contracts!")
    })
    .catch((err) => {
      console.log("Error verifying contracts:", err)
    })
}

// export default deployMain
// deployMain.tags = ["all"]

deployMain().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

import hre from "hardhat"

import { MockAsset } from "../utils/mock-assets"

async function runMock() {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy: deployFn } = deployments
  const { deployer } = await getNamedAccounts()
  const deployerSigner = await ethers.getSigner(deployer)

  await MockAsset.deploy(deployFn, deployer, deployerSigner)
}

runMock().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

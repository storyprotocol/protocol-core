import { ethers } from "ethers"

export interface networkConfigItem {
    name?: string
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: number]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    31337: {
        name: "hardhat",
    },
    11155111: {
        name: "sepolia",
        blockConfirmations: 6,
    },
}

export const developmentChains = ["hardhat", "localhost"]

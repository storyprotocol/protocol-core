import { ethers } from "ethers"

export interface networkConfigItem {
    name?: string
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: number]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    5: {
        name: "goerli",
        blockConfirmations: 6,
    },
    31337: {
        name: "hardhat",
    },
}

export const developmentChains = ["hardhat", "localhost"]

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import dotenv from "dotenv";
dotenv.config()



const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
    },
    // goerli: {
    //   url: process.env.RPC_URL,
    //   accounts: [process.env.PRIVATE_KEY || ""],
    // },
    mumbai: {
      url: process.env.MUMBAI_RPC,
      accounts: [process.env.PRIVATE_KEY || ""],
    },

    // mainnet: {
    //   url: process.env.RPC_URL,
    //   accounts: [process.env.PRIVATE_KEY || ""],
    // },

  },
  etherscan: {
    apiKey: {

      //ethereum
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      ropsten: process.env.ETHERSCAN_API_KEY || "",
      rinkeby: process.env.ETHERSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      kovan: process.env.ETHERSCAN_API_KEY || "",
      //polygon
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || ""
    }
  }
};


export default config;

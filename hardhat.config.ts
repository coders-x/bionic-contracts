import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-foundry";
// import "@nomicfoundation/hardhat-verify"
import dotenv from "dotenv";
dotenv.config()



const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: 'paris', //mumbai doesn't support PUSH0 0.8.20>  https://stackoverflow.com/a/76332341
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      accounts: {
        count: 60,
      },
      forking: {
        url: "https://public.stackup.sh/api/v1/node/arbitrum-sepolia" || process.env.ARB_RPC as string,
        // blockNumber: 28200000
      }
    },
    sepolia: {
      chainId: 11155111,
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    polygonAmoy: {
      chainId: 80002,
      url: process.env.MUMBAI_RPC,
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    arb_sepolia: {
      chainId: 421614,
      url: process.env.ARB_RPC,
      accounts: [process.env.PRIVATE_KEY || ""],
    }

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
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      kovan: process.env.ETHERSCAN_API_KEY || "",
      //polygon
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || "",

      //arbitrum
      arb_sepolia: process.env.ARBITRUMSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "arb_sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io"
        }
      },
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        },
      }
    ]
  }
};


export default config;

const { version } = require("chai");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");


const { DEPLOYER_PRIVATE_KEY, INFURA_PROJECT_ID } = process.env;

module.exports = {
  solidity: {
    compilers:[
      {
        version: "0.6.6",
      },
      {
        version: "0.6.12"
      },
      {
        version: "0.5.16"
      },
      {
        version: "0.5.0"
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/pU5x91s0MtTMxAn9Ml7uh_lE9j4JDHvG",
        blockNumber: 12651413
      }
    }, 
    ropsten: {
      url: `https://rinkeby.infura.io/v3/82342931106644f3933b1c2a0818fada`,
      accounts: [`0xc9370a4a88586374e0bb178ba544cbe00a2308f4485a7269c5548b5837ae2c18`],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "A9VE65K2XH3AIEAZWPV36IUYF8U11G2TQX"
  }
};


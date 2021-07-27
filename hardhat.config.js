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
        url: 'https://data-seed-prebsc-2-s1.binance.org:8545/',
        accounts: {
          mnemonic:"test test test test test test test test test test test junk",
          initialIndex:0,
          path:"m/44'/60'/0'/0",
          count:20,
          accountsBalance:"10000000000000000000000"
        },
        timeout: 90000
      }
    }, 
    ropsten: {
      url: `https://rinkeby.infura.io/v3/82342931106644f3933b1c2a0818fada`,
      accounts: [`0xc9370a4a88586374e0bb178ba544cbe00a2308f4485a7269c5548b5837ae2c18`],
    },
    bnbTest: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "AY7QCHKHM76GAVVJ4X6Y5B7EHF6HZDPNV7"
  }
};


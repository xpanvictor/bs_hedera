import { ethers } from "hardhat";

export const Constants = {
  stableCoin: "0x05D032ac25d322df992303dCa074EE7392C117b9", // usdt lisk
  stableCoinName: "usdt-lisk",
  masterAddress: "0x125629FAab442e459C1015FCBa50499D0aAB8EE0",
  csToken: ethers.ZeroAddress, // For bitsave token point system
  initialBalance: ethers.parseEther("0.000000001"),
  DAIAddress: ethers.ZeroAddress, // TODO: DAI Address
  joinFee: ethers.parseEther("0.0000001"),
  savingFee: ethers.parseEther("0.0000001")
}


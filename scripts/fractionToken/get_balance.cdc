import FractionToken from "./contracts/FractionToken.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"

pub fun main(address: Address, tokenTypeId: UInt64): UInt64 {
    let vaultBalancePublicPathPrefix: String = "FractionTokenBalance"
    let vaultBalancePublicPath: PublicPath? = PublicPath(identifier: vaultBalancePublicPathPrefix.concat(tokenTypeId.toString()))

    let account = getAccount(address)
    let vaultRef = account.getCapability(vaultBalancePublicPath!)
        .borrow<&FractionToken.Vault{IFractionToken.Balance}>()
        ?? panic("Could not borrow reference to the vault balance")

    return vaultRef.balance
}

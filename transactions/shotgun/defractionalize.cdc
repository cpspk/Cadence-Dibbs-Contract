import Shotgun from "./contracts/Shotgun.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"
import FractionToken from "./contracts/FractionToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

transaction(auctionID: UInt64, starter: Address) {
    let tokenAdmin: &FractionToken.Administrator
    let fractionVault: @IFractionToken.Vault
    let tokenTypeId: UInt64

    prepare(signer: AuthAccount) {
        let auction = getAccount(starter).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow()
            ?? panic("Couldn't borrow a reference to the Auction Collection")

        let itemRef = auction.borrowShotgunItem(id: auctionID)
            ?? panic("No shotgun item with that ID")

        let itemMeta = itemRef.meta
        let balance = itemRef.fractionVault.balance
        assert(balance == Shotgun.TotalFractionBalace, message: "insufficient fractions")

        self.tokenTypeId = itemMeta.tokenID
        let vaultReceiverPublicPathPrefix = "FractionTokenReceiver"
        let vaultReceiverPublicPath = PublicPath(identifier: vaultReceiverPublicPathPrefix.concat(self.tokenTypeId.toString()))
        
        let fractionVaultCap = signer.getCapability<&FractionToken.Vault{IFractionToken.Receiver}>(vaultReceiverPublicPath!)
        assert(fractionVaultCap.borrow() != nil, message: "Missing or mis-typed Fraction receiver")
        itemRef.sendFractions(capability: fractionVaultCap)

        let vaultBalancePublicPathPrefix: String = "FractionTokenBalance"
        let vaultBalancePublicPath: PublicPath? = PublicPath(identifier: vaultBalancePublicPathPrefix.concat(self.tokenTypeId.toString()))

        let fractionBalanceRef = signer.getCapability(vaultBalancePublicPath!)
        .borrow<&FractionToken.Vault{IFractionToken.Balance}>()
        ?? panic("Could not borrow reference to the vault balance")
        assert(fractionBalanceRef.balance == Shotgun.TotalFractionBalace, message: "not enough balance")

        let vaultStoragePathPrefix = "FractionTokenVault"
        let vaultStoragePath = StoragePath(identifier: vaultStoragePathPrefix.concat(self.tokenTypeId.toString()))

        let fractionVaultRef = signer.borrow<&FractionToken.Vault>(from: vaultStoragePath!)
            ?? panic("Couldn't borrow a reference to the Fraction Vault")
        
        self.fractionVault <- fractionVaultRef.withdraw(amount: fractionBalanceRef.balance)
 
        self.tokenAdmin = signer.borrow<&FractionToken.Administrator>(from: FractionToken.AdminStoragePath)
            ?? panic("Unable to borrow receiver reference")
    }

    execute {
        let burner <- self.tokenAdmin.createNewBurner()
        burner.burnTokens(from: <- self.fractionVault)
        CardItems.removeFractionalized(self.tokenTypeId)

        destroy burner
    }
}

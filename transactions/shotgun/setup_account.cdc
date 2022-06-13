// This transaction creates an empty NFT Collection for the signer
// and publishes a capability to the collection in storage

import FungibleToken from "./contracts/FungibleToken.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"
import Shotgun from "./contracts/Shotgun.cdc"

transaction {

    prepare(account: AuthAccount) {
        // create a new sale object     
        // initializing it with the reference to the owner's Vault
        let auction <- Shotgun.createAuctionCollection()

        // store the sale resource in the account for storage
        account.save(<-auction, to: Shotgun.ShotgunStoragePath)

        // create a public capability to the sale so that others
        // can call it's methods
        account.link<&{Shotgun.AuctionPublic}>(
            Shotgun.ShotgunPublicPath,
            target: Shotgun.ShotgunStoragePath
        )

        log("Auction Collection and public capability created.")
    }
}

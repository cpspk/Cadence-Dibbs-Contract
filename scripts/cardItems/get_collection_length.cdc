import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

// This script returns the size of an account's CardItems collection.

pub fun main(address: Address): Int {
    let account = getAccount(address)

    let collectionRef = account.getCapability(CardItems.CollectionPublicPath)!
        .borrow<&{NonFungibleToken.CollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.getIDs().length
}

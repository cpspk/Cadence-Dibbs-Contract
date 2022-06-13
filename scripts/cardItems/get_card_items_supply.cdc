import CardItems from "./contracts/CardItems.cdc"

// This scripts returns the number of CardItems currently in existence.

pub fun main(): UInt64 {    
    return CardItems.totalSupply
}

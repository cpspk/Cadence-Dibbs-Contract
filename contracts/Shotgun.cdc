// Shotgun.cdc
//
// The Shotgun contract is an experimental implementation of an NFT Auction on Flow.
//
// This contract allows users to put their NFTs up for sale. Other users
// can purchase these NFTs with fungible tokens.
//
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import IFractionToken from "./IFractionToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract Shotgun {

    pub var totalAuctions: UInt64
    pub let TotalFractionBalace: UInt64
    pub let HalfFractionBalance: UInt64
    pub let AuctionDuration: UFix64
    pub let ShotgunStoragePath: StoragePath
    pub let ShotgunPublicPath: PublicPath

    pub event NewAuctionStarted(starter:Address, auctionID: UInt64, tokenID: UInt64, flowAmount: UFix64, fractionAmount: UInt64)
    pub event Purchased(auctionID: UInt64, flowAmount: UFix64)
    pub event StarterClaimed(claimer: Address, claimedAmount: UFix64)
    pub event OwnerSentAndRedeemed(fractionAmount: UInt64, flowAmount: UFix64)

    pub enum AuctionStatus: UInt8  {
        pub case FREE
        pub case ONGOING
        pub case OVER 
    }
    
    pub struct ItemMeta {

        pub let auctionID: UInt64  
        pub var starterAddr: Address
        pub var startedAt: UFix64
        pub var tokenID: UInt64
        pub var starterFlowBalance: UFix64
        pub var starterFractionBalance: UInt64
        pub(set) var restFlowBalance: UFix64
        pub(set) var status: AuctionStatus

        init(
            tokenID: UInt64,
            starterAddr: Address,
            startedAt: UFix64,
            starterFractionBalance: UInt64,
            starterFlowBalance: UFix64,
            restFlowBalance: UFix64,
            auctionStatus: AuctionStatus
        ) {
            self.auctionID = Shotgun.totalAuctions
            self.tokenID = tokenID
            self.starterAddr = starterAddr
            self.startedAt = startedAt
            self.starterFractionBalance = starterFractionBalance
            self.starterFlowBalance = starterFlowBalance
            self.restFlowBalance = restFlowBalance
            self.status = auctionStatus
        }
    }

    pub resource interface AuctionItemPublic {
        pub fun getItemMeta(): ItemMeta

        pub fun purchase(flowVault: @FungibleToken.Vault, flowVaultCap: Capability<&FlowToken.Vault{FungibleToken.Receiver}>, fractionVaultCap: Capability<&{IFractionToken.Receiver}>)
    
        pub fun claimFlow(claimer: Address, flowVaultCap: Capability<&{FungibleToken.Receiver}>)

        pub fun sendAndRedeemProportion(fractionVault: @IFractionToken.Vault, flowVaultCap: Capability<&{FungibleToken.Receiver}>)
    }

    pub resource AuctionItem: AuctionItemPublic {

        pub(set) var fractionVault: @IFractionToken.Vault
        pub let flowVault: @FungibleToken.Vault

        pub(set) var meta: ItemMeta

        init(
            fractionVault: @IFractionToken.Vault,
            flowVault: @FungibleToken.Vault,
            meta: ItemMeta
        ) {
            self.fractionVault <- fractionVault
            self.flowVault <- flowVault
            self.meta = meta
        }

        pub fun updateItemStatus(newStatus: Shotgun.AuctionStatus) {
            self.meta.status = newStatus
        }

        pub fun getPrice(_ fractionAmount: UInt64): UFix64 {
            let itemMeta = self.meta
            let starterFlows = itemMeta.starterFlowBalance
            let remainings = Shotgun.TotalFractionBalace - itemMeta.starterFractionBalance

            var px = UInt128(fractionAmount) * 100_000_000 //UFix64 precision
            var py = UInt128(remainings)
            var ratio = UFix64(px / py) / 100_000_000.0
            ratio = ratio * starterFlows

            return ratio 
        }

        pub fun isAuctionExpired(): Bool {
            let itemMeta = self.meta

            let startBlock = itemMeta.startedAt 
            let currentBlock = getCurrentBlock()
            
            if currentBlock.timestamp - startBlock > Shotgun.AuctionDuration {
                return true
            } else {
                return false
            }
        }

        pub fun getItemMeta(): ItemMeta {
            return self.meta
        }

        pub fun purchase(flowVault: @FungibleToken.Vault, flowVaultCap: Capability<&FlowToken.Vault{FungibleToken.Receiver}>, fractionVaultCap: Capability<&{IFractionToken.Receiver}>) {
            let itemMeta = self.meta
            let flowAmount = flowVault.balance
            let price = self.getPrice(itemMeta.starterFractionBalance)

            if itemMeta.status != AuctionStatus.ONGOING {
                panic("Shotgun auction is over.")
            }

            if flowAmount < price {
                panic("Insufficient Flow funds")
            } else if flowAmount > price {
                let diff = flowAmount - price
                self.sendFlows(capability: flowVaultCap, amount: diff)
            }

            if self.isAuctionExpired() {
                panic("Shotgun is already expired.")
            }

            self.sendFractions(capability: fractionVaultCap)
            self.depositFlows(vault: <-flowVault)

            self.meta = ItemMeta(
                tokenID: itemMeta.tokenID,
                starterAddr: itemMeta.starterAddr,
                startedAt: itemMeta.startedAt,
                starterFractionBalance: itemMeta.starterFractionBalance,
                starterFlowBalance: itemMeta.starterFlowBalance,
                restFlowBalance: flowAmount,
                auctionStatus: AuctionStatus.OVER
            )

            emit Purchased(auctionID: itemMeta.auctionID, flowAmount: flowAmount)
        }

        pub fun claimFlow(claimer: Address, flowVaultCap: Capability<&{FungibleToken.Receiver}>) {
            let itemMeta = self.meta

            if itemMeta.starterAddr != claimer {
                panic("only starter can redeem the locked FLOW")
            }

            if itemMeta.status != AuctionStatus.OVER {
                panic("Shotgun is not over yet")
            }

            let totalFlowBalance = itemMeta.starterFlowBalance + itemMeta.restFlowBalance
            self.sendFlows(capability: flowVaultCap, amount: totalFlowBalance)
            self.meta = ItemMeta(
                tokenID: itemMeta.tokenID,
                starterAddr: itemMeta.starterAddr,
                startedAt: itemMeta.startedAt,
                starterFractionBalance: itemMeta.starterFractionBalance,
                starterFlowBalance: itemMeta.starterFlowBalance,
                restFlowBalance: itemMeta.restFlowBalance,
                auctionStatus: AuctionStatus.FREE
            )

            emit StarterClaimed(claimer: claimer, claimedAmount: totalFlowBalance)
        }

        pub fun sendAndRedeemProportion(fractionVault: @IFractionToken.Vault, flowVaultCap: Capability<&{FungibleToken.Receiver}>) {
            if !self.isAuctionExpired() {
                panic("Shotgun is not expired yet.")
            }

            let itemMeta = self.meta
            let fractionAmount = fractionVault.balance

            let flowAmount = self.getPrice(fractionAmount)

            self.depositFractions(vault: <- fractionVault)
            self.sendFlows(capability: flowVaultCap, amount: flowAmount)

            emit OwnerSentAndRedeemed(fractionAmount: fractionAmount, flowAmount: flowAmount)
        }

        // depositFlows deposits the bidder's tokens into the AuctionItem's Vault
        pub fun depositFlows(vault: @FungibleToken.Vault) {
            self.flowVault.deposit(from: <-vault)
        }

        pub fun depositFractions(vault: @IFractionToken.Vault) {
            self.fractionVault.deposit(from: <- vault)
        }

        access(contract) fun sendFlows(capability: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            if let vaultRef = capability.borrow() {
                let flowVaultRef = &self.flowVault as &FungibleToken.Vault
                vaultRef.deposit(from: <-flowVaultRef.withdraw(amount: amount))
            } else {
                log("Shotgun: couldn't get vault ref")
            }
        }

        pub fun sendFractions(capability: Capability<&{IFractionToken.Receiver}>) {
            if let vaultRef = capability.borrow() {
                let fractionVaultRef = &self.fractionVault as &IFractionToken.Vault
                vaultRef.deposit(from: <-fractionVaultRef.withdraw(amount: fractionVaultRef.balance))
            } else {
                log("Shotgun: couldn't get receiver ref")
            }
        }

        destroy() {
            destroy self.fractionVault
            destroy self.flowVault
        }
    }

    pub resource interface AuctionPublic {
        pub fun borrowShotgunItem(id: UInt64): &Shotgun.AuctionItem?
    }

    pub resource AuctionCollection: AuctionPublic {
        pub var auctionItems: @{UInt64: AuctionItem}
        
        init() {
            self.auctionItems <- {}
        }

        pub fun borrowShotgunItem(id: UInt64): &Shotgun.AuctionItem? {
            if self.auctionItems[id] != nil {
                let ref = (&self.auctionItems[id] as auth &Shotgun.AuctionItem?)!
                return ref as! &Shotgun.AuctionItem
            } else {
                return nil
            }
        }

        pub fun startAuction(starterAddr: Address, tokenID: UInt64, starterFractionBalance: UInt64, fractionVault: @IFractionToken.Vault, starterFlowBalance: UFix64, flowVault: @FungibleToken.Vault) {
            if starterFractionBalance < Shotgun.HalfFractionBalance {
                panic("Shotgun: insufficient amount of fractions")
            }

            let meta = ItemMeta(
                tokenID: tokenID,
                starterAddr: starterAddr,
                startedAt: getCurrentBlock().timestamp,
                starterFractionBalance: starterFractionBalance,
                starterFlowBalance: starterFlowBalance,
                restFlowBalance: 0.0,
                auctionStatus: AuctionStatus.ONGOING
            )
            
            let item <- create AuctionItem(
                fractionVault: <-fractionVault,
                flowVault: <-flowVault,
                meta: meta
            )

            let id = item.meta.auctionID
            let oldItem <- self.auctionItems[id] <- item
            destroy oldItem

            Shotgun.totalAuctions = Shotgun.totalAuctions + UInt64(1)
            emit NewAuctionStarted(starter: starterAddr, auctionID: id, tokenID: tokenID, flowAmount: starterFlowBalance, fractionAmount: starterFractionBalance)
        }

        destroy() {
            destroy self.auctionItems
        }
    }

    pub fun createAuctionCollection(): @AuctionCollection {
        let auctionCollection <- create AuctionCollection()
        return <- auctionCollection
    }

    init() {
        self.totalAuctions = UInt64(0)
        self.TotalFractionBalace = UInt64(10_000_000_000_000_000)
        self.HalfFractionBalance = UInt64(5_000_000_000_000_000)
        self.AuctionDuration = UFix64(1800)
        self.ShotgunStoragePath = /storage/ShotgunAuction
        self.ShotgunPublicPath = /public/ShotgunAuction
    }   
}

pub fun main():UFix64{

    var x = UInt64(1000000000000000)
    var y = UInt64(4000000000000000)


    var px = UInt128(x)*100_000_000 //UFix64 precision
    var py = UInt128(y)

    var ratio = UFix64(px/py) / 100_000_000.0

    ratio = ratio * 30.0

    log(ratio)
    return ratio

}
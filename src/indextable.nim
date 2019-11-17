import tables, sequtils

type IndexTable*[T] = object
    items: seq[T]
    index: TableRef[T, Natural]

func len*(x: IndexTable): int = x.items.len
func getIndex*[T](x: IndexTable[T], key: T): Natural = x.index[key]
func getItem*[T](x: IndexTable[T], idx: Natural): T = x.items[idx]
func contains*[T](x: IndexTable[T], key: T): bool = key in x.index
proc add*[T](x: var IndexTable[T], d: T) =
    x.index[d] = x.len
    x.items.add d
iterator items*[T](x: IndexTable[T]): T =
    for d in x.items: yield d
iterator pairs*[T](x: IndexTable[T]): (int, T) =
    for i, d in x.items: yield (i, d)

func initIndexTable*[T](cap: Natural): IndexTable[T] =
    result.items = newSeqOfCap[T](cap)
    result.index = newTable[T, Natural](rightSize(cap))
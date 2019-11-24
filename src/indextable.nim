import tables, algorithm
import basetypes

type IndexTable*[T] {.shallow.} = object
    values: seq[T]
    index: TableRef[T, Natural]

func len*(x: IndexTable): int = x.values.len
func getIndex*[T](x: IndexTable[T], key: T): int = x.index[key]
func getItem*[T](x: IndexTable[T], idx: Natural): T = x.values[idx]
func contains*[T](x: IndexTable[T], key: T): bool = key in x.index
proc add*[T](x: var IndexTable[T], d: T) =
    x.index[d] = x.len
    x.values.add d
iterator items*[T](x: IndexTable[T]): T =
    for d in x.values: yield d
iterator pairs*[T](x: IndexTable[T]): (int, T) =
    for i, d in x.values: yield (i, d)
func allItems*[T](x: IndexTable[T]): seq[T] = x.values

func initIndexTable*[T](cap: Natural): IndexTable[T] =
    result.values = newSeqOfCap[T](cap)
    result.index = newTable[T, Natural](rightSize(cap))

func sorted*[T](x: IndexTable[T]): IndexTable[T] =
    result.values = x.values.sorted
    result.index = newTable[T, Natural](rightSize(x.len))
    for i, v in result.values:
        result.index[v] = i

type DofTable* = IndexTable[Dof]

func initDofTable*(cap: Natural) : DofTable =
    result = initIndexTable[Dof](cap)

func `[]`*(tab: DofTable, d: Dof): int = tab.getIndex(d)
func `[]`*(tab: DofTable, i: Natural): Dof = tab.getItem(i)

func difference*(a, b: DofTable): DofTable =
    result = initDofTable(a.len)
    for i, dof in a:
        if dof notin b:
            result.add dof
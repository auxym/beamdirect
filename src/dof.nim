import hashes, tables
import basetypes

const numDofsPerNode* = 4

type DofDirection* = enum tx, ty, rx, rz

type Dof* = tuple
    node: EntityId
    direction: DofDirection

type DofTable* = object
    dofs: seq[Dof]
    index: TableRef[Dof, int]

func hash*(d: Dof): Hash = !$(d.node.hash !& d.direction.hash)

func len*(x: DofTable): int = x.dofs.len
func `[]`*(x: DofTable, key: Dof): int = x.index[key]
func `[]`*(x: DofTable, key: int): Dof = x.dofs[key]
func contains*(x: DofTable, key: Dof): bool = key in x.index
proc add*(x: var DofTable, d: Dof) =
    x.index[d] = x.len
    x.dofs.add d
iterator items*(x: DofTable): Dof =
    for d in x.dofs: yield d
iterator pairs*(x: DofTable): (int, Dof) =
    for i, d in x.dofs: yield (i, d)

func initDofTable*(cap: Natural): DofTable =
    result.dofs = newSeqOfCap[Dof](cap)
    result.index = newTable[Dof, int](rightSize(cap))

func difference*(a, b: DofTable): DofTable =
    result = initDofTable(a.len)
    for i, dof in a:
        if dof notin b:
            result.add dof
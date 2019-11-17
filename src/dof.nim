import hashes, tables
import basetypes, indextable

const numDofsPerNode* = 4

type DofDirection* = enum tx, ty, rx, rz

type Dof* = tuple
    node: EntityId
    direction: DofDirection

func hash*(d: Dof): Hash = !$(d.node.hash !& d.direction.hash)

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
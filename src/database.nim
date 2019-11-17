import options, tables, sequtils, algorithm
import basetypes, dof, indextable

type Element* = object
    id*: EntityId
    nodes*: array[2, EntityId]
    mat*: EntityId
    section*: EntityId

type Node* = object
    id*: EntityId
    loc*: Vector2d

type Material* = object
    id*: EntityId
    E*: float64
    nu*: float64
    rho*: Option[float64]

type BeamSection* = object
    id*: EntityId
    Iz*: float64
    J*: float64
    A*: float64

type Spc* = object
    id*: EntityId
    node*: EntityId
    comps*: Table[DofDirection, float]

type Load* = object
    id*: EntityId
    node*: EntityId
    comps*: Table[DofDirection, float]

type InputDb* = object
    sections*: TableRef[EntityId, BeamSection]
    nodes*: TableRef[EntityId, Node]
    elements*: TableRef[EntityId, Element]
    materials*: TableRef[EntityId, Material]
    spcs*: TableRef[EntityId, Spc]
    loads*: TableRef[EntityId, Load]

func buildTable*[T](items: seq[T]): TableRef[EntityId, T] =
    result = newTable[EntityId, T](rightSize(items.len))
    for it in items:
        result.add(it.id, it)

func buildDofTable*(db: InputDb) : DofTable =
    let
        nodeTable = db.nodes
        numDofs = nodeTable.len * numDofsPerNode
        nodeIds = toSeq(nodeTable.keys).sorted

    result = initDofTable(numDofs)
    for nodeId in nodeIds:
        for dir in DofDirection:
            result.add (nodeId, dir)

    assert result.len == numDofs
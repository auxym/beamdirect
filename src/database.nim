import tables, sequtils, algorithm
import basetypes, indextable, element

type DbElement* = object
    id*: EntityId
    nodes*: array[2, EntityId]
    mat*: EntityId
    section*: EntityId

type InputDb* = object
    sections*: TableRef[EntityId, BeamSection]
    nodes*: TableRef[EntityId, Node]
    elements*: TableRef[EntityId, DbElement]
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

func getElemDenorm*(db: InputDb, id: EntityId): Element =
    let dbelm = db.elements[id]
    new(result)
    result.id = id
    result.nodes = [db.nodes[dbelm.nodes[0]], db.nodes[dbelm.nodes[1]]]
    result.mat = db.materials[dbelm.mat]
    result.section = db.sections[dbelm.section]
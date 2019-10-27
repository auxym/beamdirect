import samson
import tables, options

type Point* = tuple[x: float64, y: float64]

type EntityId* = int

type Element* = object
    id*: EntityId
    nodes*: array[2, EntityId]
    mat*: EntityId
    section*: EntityId

type Node* = object
    id*: EntityId
    loc*: Point

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

type JsonInput = object
    BeamSections: seq[BeamSection]
    Nodes: seq[Node]
    Elements: seq[Element]
    Materials: seq[Material]

type InputDb* = object
    sections*: TableRef[EntityId, BeamSection]
    nodes*: TableRef[EntityId, Node]
    elements*: TableRef[EntityId, Element]
    materials*: TableRef[EntityId, Material]

func buildTable[T](items: seq[T]): TableRef[EntityId, T] =
    result = newTable[EntityId, T](rightSize(items.len))
    for it in items:
        result.add(it.id, it)

proc readJsonInput*(fname: string): InputDb =
    let content: string = fname.readFile
    let ji = fromJson5(content, JsonInput)

    result.sections = buildTable(ji.BeamSections)
    result.nodes = buildTable(ji.Nodes)
    result.elements = buildTable(ji.Elements)
    result.materials = buildTable(ji.Materials)
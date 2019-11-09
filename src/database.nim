import options, tables, hashes

type Point* = tuple[x: float64, y: float64]

type EntityId* = int

type DofDirection* = enum tx, ty, rx, rz

type Dof* = tuple
    node: EntityId
    direction: DofDirection

type DofTable* = ref object
    dofs*: seq[Dof]
    index*: Table[Dof, int]

func hash*(d: Dof): Hash = !$(d.node.hash !& d.direction.hash)

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
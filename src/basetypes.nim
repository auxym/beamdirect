import tables, options, hashes

type Vector2d* = tuple[x: float64, y: float64]

type EntityId* = int

type DofDirection* = enum tx, ty, rx, rz

const numDofsPerNode* = 4

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

type Dof* = tuple
    node: EntityId
    direction: DofDirection

func hash*(d: Dof): Hash = !$(d.node.hash !& d.direction.hash)
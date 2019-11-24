import arraymancer
import basetypes
from math import sqrt

type Element* = ref object
    id*: EntityId
    nodes*: array[2, Node]
    mat*: Material
    section*: BeamSection

func distsq(a, b: Node): float64 =
    # Square of distance
    let
        dx = b.loc.x - a.loc.x
        dy = b.loc.y - a.loc.y
    result = dx*dx + dy*dy

func getStiffnessMatrix*(elem: Element): Tensor[float64] =
    result = zeros[float64]([8, 8])

    doAssert elem.nodes[0].loc.y == elem.nodes[1].loc.y

    let
        L2 = distsq(elem.nodes[0], elem.nodes[1])
        L = sqrt(L2)
        L3 = L2*L
        nu = elem.mat.nu
        E = elem.mat.E
        A = elem.section.A
        Iz = elem.section.Iz
        J = elem.section.J

    var kaa = zeros[float64]([4, 4])
    kaa[0, 0] = A / L
    kaa[1, 1] = 12 * Iz / L3
    kaa[2, 2] = J / (2 * (1+nu) * L)
    kaa[3, 3] = 4 * Iz / L
    kaa[1, 3] = 6 * Iz / L2
    kaa[3, 1] = 6 * Iz / L2

    var kab = -kaa.clone()
    kab[3, 3] = 2 * Iz / L
    kab[1, 3] = 6 * Iz / L2
    kab[3, 1] = -6 * Iz / L2

    var kbb = kaa.clone()
    kbb[1, 3] = -6 * Iz / L2
    kbb[3, 1] = -6 * Iz / L2

    result[0..3, 0..3] = kaa
    result[0..3, 4..7] = kab
    result[4..7, 0..3] = kab.transpose
    result[4..7, 4..7] = kbb
    result = result * E

func getDofList*(elem: Element): seq[Dof] =
    for node in elem.nodes:
        for dir in DofDirection:
            result.add((node.id, dir))
    assert result.len == 8
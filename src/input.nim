import samson
import tables, options, strutils, sequtils
import database, basetypes

type StrSpc = object
    id: EntityId
    node: EntityId
    comps: Table[string, float]

type StrLoad = object
    id: EntityId
    node: EntityId
    comps: Table[string, float]

func toSpc(s: StrSpc): Spc =
    result.id = s.id
    result.node = s.node

    result.comps = initTable[DofDirection, float](rightSize(s.comps.len))
    for dirName, val in s.comps:
        result.comps[parseEnum[DofDirection](dirName)] = val

func toLoad(s: StrLoad): Load =
    result.id = s.id
    result.node = s.node

    result.comps = initTable[DofDirection, float](rightSize(s.comps.len))
    for dirName, val in s.comps:
        result.comps[parseEnum[DofDirection](dirName)] = val

type JsonInput = object
    BeamSections: seq[BeamSection]
    Nodes: seq[Node]
    Elements: seq[DbElement]
    Materials: seq[Material]
    Spcs: Option[seq[StrSpc]]
    Loads: Option[seq[StrLoad]]

proc readJsonInput*(fname: string): InputDb =
    let content: string = fname.readFile
    let ji = fromJson5(content, JsonInput)

    result.sections = buildTable(ji.BeamSections)
    result.nodes = buildTable(ji.Nodes)
    result.elements = buildTable(ji.Elements)
    result.materials = buildTable(ji.Materials)

    if ji.Spcs.isSome:
        result.spcs = buildTable(ji.Spcs.get.map(toSpc))
    else:
        result.spcs = newTable[EntityId, Spc](2)

    if ji.Loads.isSome:
        result.loads = buildTable(ji.Loads.get.map(toLoad))
    else:
        result.loads = newTable[EntityId, Load](2)
import samson
import tables, options, strutils, sequtils
import database

type StrSpc = object
    id: EntityId
    node: EntityId
    comps: Table[string, float]

func toSpc(s: StrSpc): Spc =
    result.id = s.id
    result.node = s.node

    result.comps = initTable[DofDirection, float](rightSize(s.comps.len))
    for dirName, val in s.comps:
        result.comps[parseEnum[DofDirection](dirName)] = val

type JsonInput = object
    BeamSections: seq[BeamSection]
    Nodes: seq[Node]
    Elements: seq[Element]
    Materials: seq[Material]
    Spcs: seq[StrSpc]

proc readJsonInput*(fname: string): InputDb =
    let content: string = fname.readFile
    let ji = fromJson5(content, JsonInput)

    result.sections = buildTable(ji.BeamSections)
    result.nodes = buildTable(ji.Nodes)
    result.elements = buildTable(ji.Elements)
    result.materials = buildTable(ji.Materials)
    result.spcs = buildTable(ji.Spcs.map(toSpc))
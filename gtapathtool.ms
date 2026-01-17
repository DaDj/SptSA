try(closeRolloutFloater gtaToolFloater)catch()
gc()

-- ===============================================================================
-- 1. ATTRIBUTE DEFINITIONS
-- ===============================================================================

GTANodeAttribs = attributes "GTA Node Data"
(
    parameters main rollout:params
    (
        nodeID      type:#integer animatable:false ui:spn_nodeID default:0
        areaID      type:#integer animatable:false ui:spn_areaID default:0
        pathWidth   type:#float   animatable:false ui:spn_width default:4.0
        floodFill   type:#integer animatable:false ui:spn_flood default:1
        
        isPed       type:#boolean animatable:false ui:chk_isPed default:false
        linkCount   type:#integer animatable:false ui:spn_links default:0
        
        -- SA Flags
        isDeadEnd    type:#boolean animatable:false ui:chk_deadend default:false
        isSwitchedOff type:#boolean animatable:false ui:chk_off default:false
        isRoadBlock  type:#boolean animatable:false ui:chk_roadblock default:false
        isBoats      type:#boolean animatable:false ui:chk_boats default:false
        isEmergency  type:#boolean animatable:false ui:chk_emergency default:false
        isGrove      type:#boolean animatable:false ui:chk_grove default:false
        isHighway    type:#boolean animatable:false ui:chk_highway default:false
        isnotHighway type:#boolean animatable:false ui:chk_nothighway default:false
        
        spawnProb    type:#integer animatable:false ui:spn_spawn default:15
        specialFlag  type:#integer animatable:false ui:ddl_special default:1
        
        ivFlags      type:#integer animatable:false default:0 
    )

    rollout params "GTA Node Flags"
    (
        group "Identity"
        (
            spinner spn_areaID "Area ID:" type:#integer range:[-32768,65535,0] fieldwidth:50
            spinner spn_nodeID "Node ID:" type:#integer range:[-32768,65535,0] fieldwidth:50
            checkbox chk_isPed "Is Pedestrian Node"
        )
        group "Path Data"
        (
            spinner spn_width "Width:" type:#float range:[0,100,4]
            spinner spn_flood "Flood Fill:" type:#integer range:[0,65535,1]
            spinner spn_links "Link Count:" type:#integer range:[0,255,0] enabled:false
        )
        group "Standard Flags"
        (
            checkbox chk_deadend "Dead End / Low Traffic"
            checkbox chk_off "Switched Off"
            checkbox chk_roadblock "RoadBlock (Bit 6)"
            checkbox chk_boats "Boats (Bit 7)"
            checkbox chk_emergency "Emergency Only (Bit 8)"
            checkbox chk_grove "Grove (Bit 10)"
            checkbox chk_nothighway "Is Not Highway (Bit 12)"
            checkbox chk_highway "Is Highway (Bit 13)"
            
            spinner spn_spawn "Spawn Prob (0-15):" type:#integer range:[0,15,0]
        )
        group "Special Mode"
        (
            dropdownlist ddl_special "" items:#("0 - None", "1 - Parking Parallel", "2 - Parking Perpendicular", "3 - Valet", "4 - Nightclub", "5 - Deliveries", "6 - Valet Unload", "7 - Nightclub Unload", "8 - Drive Through", "9 - Drive Through Window", "10 - Deliveries Unload")
        )
    )
)

GTALinkAttribs = attributes "GTA Link Data"
(
    parameters main rollout:params
    (
        nodeA type:#node
        nodeB type:#node
        
        isPedLink    type:#boolean animatable:false default:false
        hasPedTL     type:#boolean animatable:false ui:chk_pedTL default:false
        isTwoWay     type:#boolean animatable:false ui:chk_2way default:true
        
        lanesLeft   type:#integer animatable:false ui:spn_left default:0
        lanesRight  type:#integer animatable:false ui:spn_right default:0
        
        trafficLight type:#integer animatable:false ui:ddl_tl default:1
        isTrain     type:#boolean animatable:false ui:chk_train default:false
    )
    
    rollout params "Link Properties"
    (
        checkbox chk_pedTL "Has Ped Traffic Light"
        checkbox chk_2way "Two-Way Connection" checked:true enabled:false
        
        group "Traffic Data"
        (
            spinner spn_left "Forward/Left Lanes:" type:#integer range:[0,7,0]
            spinner spn_right "Backward/Right Lanes:" type:#integer range:[0,7,0]
            dropdownlist ddl_tl "Traffic Light:" items:#("None", "North-South", "West-East")
            checkbox chk_train "Is Train Crossing"
        )
        group "Direction (High -> Low)"
        (
            label lbl_a "From (High):" align:#left
            label lbl_b "To    (Low):" align:#left
        )
        on params open do
        (
            if isValidNode nodeA do lbl_a.text = "From: " + nodeA.name
            if isValidNode nodeB do lbl_b.text = "To:    " + nodeB.name
        )
    )
)

-- ===============================================================================
-- 2. GLOBAL HELPERS
-- ===============================================================================

struct sLinkData ( isPed=false, lanesLeft=1, lanesRight=1, trafficLight=0, isTrain=false, forceTwoWay=true )

struct RawNodeData (
    pos, nodeID, areaID, pathWidth, isPed, floodFill,
    isDeadEnd=false, isSwitchedOff=false, isRoadBlock=false, isBoats=false, isEmergency=false, isGrove=false, isHighway=false, isNotHighway=false, spawnProb=15, specialFlag=1,
    raw_sa_flags=0, raw_iv_f1=0, raw_iv_f2=0, raw_iv_f3=0, raw_iv_f4=0, raw_iv_type=0,
    linkStartIdx, linkCount
)

struct RawLinkData ( sourceArea, sourceNode, targetArea, targetNode, isPed=false, lanesLeft=0, lanesRight=0, trafficLight=0, isTrain=false )
struct RawNaviData ( pos, flags )
struct RawLinkTarget ( area, node )
struct RawIVLink ( area, node, density, lenVal, flags ) 

fn readInt8 binStream = ( local b = readByte binStream; if b > 127 then b - 256 else b )
fn readUShort binStream = readShort binStream #unsigned
fn readIVFloat binStream div = ( local val = readShort binStream; return (val as float) / div )

fn writeShortToBin f val = (
    if val > 32767 do val = 32767
    if val < -32768 do val = -32768
    writeShort f (val as integer)
)

fn writeIntToBin f val = ( writeLong f (val as integer) )

fn gta_makeKey a n = ( (a as string) + "_" + (n as string) )
fn getGlobalID obj = ( if isProperty obj #areaID and isProperty obj #nodeID then (obj.areaID * 65536) + obj.nodeID else 0 )
fn getAreaIDFromPos pos = (
    local xOff = pos.x + 3000; local yOff = pos.y + 3000
    local xIdx = floor (xOff / 750.0); local yIdx = floor (yOff / 750.0)
    if xIdx < 0 do xIdx = 0; if xIdx > 7 do xIdx = 7
    if yIdx < 0 do yIdx = 0; if yIdx > 7 do yIdx = 7
    return (xIdx + (yIdx * 8)) as integer
)

global GLOBAL_RAW_NODES = #()
global GLOBAL_RAW_LINKS = #()
global gtaNodeMap = dotNetObject "System.Collections.Hashtable" 
global gta_path_update_callback = undefined

fn updateSplineGeometry s objA objB isPed =
(
    if not (isValidNode s) or not (isValidNode objA) or not (isValidNode objB) do return false
    if (numSplines s) < 1 do return false
    if (numKnots s 1) < 2 do return false
    local p1 = objA.pos
    local p2 = objB.pos
    local pMid = (p1 + p2) * 0.5
    if not isPed and (numKnots s 1) == 3 do ( pMid = getKnotPoint s 1 2; if isValidNode objB do pMid.z = objB.pos.z )
    setKnotPoint s 1 1 p1
    if isPed then ( if (numKnots s 1) >= 2 do setKnotPoint s 1 2 p2 ) 
    else ( if (numKnots s 1) >= 3 do ( setKnotPoint s 1 2 pMid; setKnotPoint s 1 3 p2 ) )
    if not isPed and (numSplines s) > 1 do (
        local dir = normalize (p2 - pMid)
        local arrowSize = 2.0
        local sideVec = cross dir [0,0,1]
        local pTip = pMid + (dir * (arrowSize*0.5))
        local pBase = pMid - (dir * (arrowSize*0.5))
        local pLeft = pBase + (sideVec * (arrowSize*0.5))
        local pRight = pBase - (sideVec * (arrowSize*0.5))
        if (numKnots s 2) >= 3 do ( setKnotPoint s 2 1 pLeft; setKnotPoint s 2 2 pTip; setKnotPoint s 2 3 pRight )
    )
    updateShape s
)

fn gta_update_connected_objects ev nodes = 
(
    for n in nodes do (
        local obj = GetAnimByHandle n
        if isValidNode obj do (
            local deps = refs.dependents obj
            for d in deps do (
                if isProperty d #nodeA and isProperty d #nodeB then (
                    local owners = refs.dependents d
                    for s in owners do (
                        if isValidNode s and (isKindOf s SplineShape or isKindOf s Line) do (
                            if isValidNode d.nodeA and isValidNode d.nodeB do updateSplineGeometry s d.nodeA d.nodeB d.isPedLink
                        )
                    )
                )
            )
        )
    )
)
gc(); gta_path_update_callback = NodeEventCallback mouseUp:false delay:10 all:gta_update_connected_objects

-- ===============================================================================
-- 3. IMPORT LOGIC
-- ===============================================================================

fn ParseSAFile f = 
(
    local numNodes=readLong f; local numVeh=readLong f; local numPed=readLong f; local numNavi=readLong f; local numLinks=readLong f
    local fileNodes = #()
    for i = 1 to numNodes do (
        local isPed=(i>numVeh); readLong f; readLong f; 
        local pX=(readShort f)/8.0; local pY=(readShort f)/8.0; local pZ=(readShort f)/8.0
        local heur=readShort f; local linkIdx=readUShort f; 
        local aID=readUShort f; local nID=readUShort f; local wid=(readInt8 f)/8.0; 
        local floodVal = readByte f #unsigned; local flgs=readLong f
        
        local rn = RawNodeData pos:[pX,pY,pZ] nodeID:nID areaID:aID pathWidth:wid isPed:isPed floodFill:floodVal linkStartIdx:linkIdx linkCount:(bit.and flgs 15)
        rn.isDeadEnd = bit.get flgs 5; rn.isSwitchedOff = bit.get flgs 6
        rn.isRoadBlock = bit.get flgs 7; rn.isBoats = bit.get flgs 8; rn.isEmergency = bit.get flgs 9
        rn.isGrove = bit.get flgs 11; rn.isNotHighway = bit.get flgs 13; rn.isHighway = bit.get flgs 14
        rn.spawnProb = (bit.and (bit.shift flgs -16) 15)
        local rawSpecial = (bit.and (bit.shift flgs -20) 15); if rawSpecial > 10 then rawSpecial = 0
        rn.specialFlag = rawSpecial + 1 
        rn.raw_sa_flags = flgs
        append fileNodes rn
    )
    local fileNavs = #(); for i=1 to numNavi do (
        local nX=(readShort f)/8.0; local nY=(readShort f)/8.0
        local nArea=readUShort f; local nNode=readUShort f
        readInt8 f; readInt8 f; local flgs=readLong f
        append fileNavs (RawNaviData pos:[nX,nY,0] flags:flgs)
    )
    local fileLinkTargets = #(); for i=1 to numLinks do append fileLinkTargets (RawLinkTarget area:(readUShort f) node:(readUShort f))
    fseek f 768 #seek_cur 
    local fileLinkNavIndices = #(); for i=1 to numLinks do append fileLinkNavIndices (readUShort f)
    fseek f numLinks #seek_cur 
    local filePedFlags = #(); for i=1 to numLinks do append filePedFlags (readByte f)
    
    for n in fileNodes do (
        append GLOBAL_RAW_NODES n
        local startIdx = n.linkStartIdx + 1; local count = n.linkCount
        for k = 0 to (count - 1) do (
            local idx = startIdx + k
            if idx <= fileLinkTargets.count do (
                local target = fileLinkTargets[idx]
                local rl = RawLinkData sourceArea:n.areaID sourceNode:n.nodeID targetArea:target.area targetNode:target.node isPed:n.isPed
                if not n.isPed and idx <= fileLinkNavIndices.count do (
                    local rawNavVal = fileLinkNavIndices[idx]; local navID = (bit.and rawNavVal 1023) + 1
                    if navID <= fileNavs.count do (
                        local navFlags = fileNavs[navID].flags
                        rl.lanesLeft = (bit.shift (bit.and navFlags 1792) -8)
                        rl.lanesRight = (bit.shift (bit.and navFlags 14336) -11)
                        rl.trafficLight = ((bit.shift (bit.and navFlags 196608) -16)+1)
                        if (bit.get navFlags 19) == true do rl.isTrain = true
                    )
                )
                if idx <= filePedFlags.count do ( if (bit.get filePedFlags[idx] 2)==true do rl.trafficLight = 2 )
                append GLOBAL_RAW_LINKS rl
            )
        )
    )
)

fn ParseIVFile f = 
(
    local numNodes = readLong f #unsigned; local numVehNodes = readLong f #unsigned
    local numPedNodes = readLong f #unsigned; local numLinks = readLong f #unsigned
    local fileNodes = #()
    for i = 1 to numNodes do (
        readLong f; readLong f 
        local areaID = readShort f #unsigned; local nodeID = readShort f #unsigned
        readLong f #unsigned; fseek f 2 #seek_cur; local baseLink = readShort f #unsigned 
        local pX = readIVFloat f 8.0; local pY = readIVFloat f 8.0; local pZ = readIVFloat f 64.0 
        local bWidth = readByte f; if bWidth > 127 do bWidth -= 256; local widthVal = bWidth / 8.0
        local bType = readByte f #unsigned
        local f1 = readByte f #unsigned; local f2 = readByte f #unsigned; local f3 = readByte f #unsigned; local f4 = readByte f #unsigned
        local isPed = (i > numVehNodes); local floodVal = 1
        local rn = RawNodeData pos:[pX,pY,pZ] nodeID:nodeID areaID:areaID pathWidth:widthVal isPed:isPed floodFill:floodVal linkStartIdx:baseLink
        rn.linkCount = (bit.and f3 15); if rn.linkCount > 8 do rn.linkCount = 0
        if rn.linkCount == 1 do rn.isDeadEnd = true
        if (bit.get f3 8) or (bit.get f4 3) do ( rn.isEmergency = true; rn.isSwitchedOff = true)
        if (bit.get f3 6) == true then rn.isHighway = true else rn.isNotHighway = true
		
        --if (bit.get f3 5) == true do rn.isNotHighway = true
        if bType == 1 or (bit.get f4 2) do ( rn.isBoats = true; rn.floodFill = 2 )
        rn.spawnProb = 15; rn.raw_iv_f1 = f1; rn.raw_iv_f2 = f2; rn.raw_iv_f3 = f3; rn.raw_iv_f4 = f4; rn.raw_iv_type = bType
        append fileNodes rn
    )
    local startLinkOffset = 16 + (numNodes * 32)
    if (ftell f) != startLinkOffset do fseek f startLinkOffset #seek_set
    local fileLinks = #(); for i = 1 to numLinks do append fileLinks (RawIVLink area:(readShort f #unsigned) node:(readShort f #unsigned) density:(readByte f #unsigned) lenVal:(readByte f #unsigned) flags:(readShort f #unsigned))
    for n in fileNodes do (
        append GLOBAL_RAW_NODES n
        local startIdx = n.linkStartIdx + 1; local count = n.linkCount
        for k = 0 to (count - 1) do (
            local idx = startIdx + k
            if idx <= fileLinks.count do (
                local lData = fileLinks[idx]
                local rl = RawLinkData sourceArea:n.areaID sourceNode:n.nodeID targetArea:lData.area targetNode:lData.node isPed:n.isPed
                local rawLen = lData.lenVal; local tlType = 1
                if rawLen > 127 then ( tlType = 3; rawLen -= 128 ) else if rawLen > 63 then ( tlType = 2; rawLen -= 64 )
                rl.lanesLeft = rawLen / 8; rl.lanesRight = rawLen - (rl.lanesLeft * 8); rl.trafficLight = tlType
                append GLOBAL_RAW_LINKS rl
            )
        )
    )
)

fn BuildSceneFromMemory pb = 
(
    if GLOBAL_RAW_NODES.count == 0 do return false
    undo off (
        with redraw off (
            gtaNodeMap = dotNetObject "System.Collections.Hashtable"
            local total = GLOBAL_RAW_NODES.count; local counter = 0
            format "Building % Nodes...\n" total
            for rn in GLOBAL_RAW_NODES do (
                counter += 1; if (mod counter 500) == 0 do ( if pb != undefined do pb.value = (counter as float / total * 50.0) )
                local p = Point pos:rn.pos size:0.6 centerMarker:true axisTripod:false cross:false box:true
                if rn.isPed then (p.wirecolor=white; p.box=false; p.cross=true) else (p.wirecolor=green)
                custAttributes.add p GTANodeAttribs
                p.nodeID = rn.nodeID; p.areaID = rn.areaID; p.pathWidth = rn.pathWidth; p.isPed = rn.isPed; p.floodFill = rn.floodFill
                p.linkCount = rn.linkCount; p.isDeadEnd = rn.isDeadEnd; p.isSwitchedOff = rn.isSwitchedOff
                p.isRoadBlock = rn.isRoadBlock; p.isBoats = rn.isBoats; p.isEmergency = rn.isEmergency
                p.isGrove = rn.isGrove; p.isHighway = rn.isHighway; p.isNotHighway = rn.isNotHighway
                p.spawnProb = rn.spawnProb; p.specialFlag = rn.specialFlag
                if rn.raw_sa_flags != 0 do setUserProp p "SA_RawFlags" rn.raw_sa_flags
                if rn.raw_iv_f1 != 0 do setUserProp p "IV_Flags_1" rn.raw_iv_f1; if rn.raw_iv_f2 != 0 do setUserProp p "IV_Flags_2" rn.raw_iv_f2
                if rn.raw_iv_f3 != 0 do setUserProp p "IV_Flags_3" rn.raw_iv_f3; if rn.raw_iv_f4 != 0 do setUserProp p "IV_Flags_4" rn.raw_iv_f4
                if rn.raw_iv_type != 0 do setUserProp p "IV_PathType" rn.raw_iv_type
                local key = gta_makeKey rn.areaID rn.nodeID
                if gtaNodeMap.ContainsKey key do gtaNodeMap.Remove key
                gtaNodeMap.Add key (dotNetMXSValue p)
            )
            local totalLinks = GLOBAL_RAW_LINKS.count; counter = 0
            format "Building % Links...\n" totalLinks
            local gtaLinkMap = dotNetObject "System.Collections.Hashtable"
            for rl in GLOBAL_RAW_LINKS do (
                counter += 1; if (mod counter 500) == 0 do ( if pb != undefined do pb.value = 50.0 + (counter as float / totalLinks * 50.0) )
                local keyA = gta_makeKey rl.sourceArea rl.sourceNode; local keyB = gta_makeKey rl.targetArea rl.targetNode
                if gtaNodeMap.ContainsKey keyA and gtaNodeMap.ContainsKey keyB do (
                    local wrapA = gtaNodeMap.Item[keyA]; local wrapB = gtaNodeMap.Item[keyB]
                    if wrapA != undefined and wrapB != undefined do (
                        local nA = wrapA.value; local nB = wrapB.value
                        local idA = getGlobalID nA; local idB = getGlobalID nB
                        local finalNodeA = nA; local finalNodeB = nB
                        local finalLanesLeft = rl.lanesLeft; local finalLanesRight = rl.lanesRight
                        if idA < idB then ( finalNodeA = nB; finalNodeB = nA; finalLanesLeft = rl.lanesRight; finalLanesRight = rl.lanesLeft )
                        local linkKey = (getGlobalID finalNodeA as string) + "_" + (getGlobalID finalNodeB as string)
                        if gtaLinkMap.ContainsKey linkKey then (
                            local wrapper = gtaLinkMap.Item[linkKey]; local existingSpline = wrapper.value
                            if isValidNode existingSpline do (
                                existingSpline.isTwoWay = true
                                if finalLanesLeft > existingSpline.lanesLeft do existingSpline.lanesLeft = finalLanesLeft
                                if finalLanesRight > existingSpline.lanesRight do existingSpline.lanesRight = finalLanesRight
                                updateSplineGeometry existingSpline existingSpline.nodeA existingSpline.nodeB existingSpline.isPedLink
                            )
                        ) else (
                            local s = SplineShape pos:finalNodeA.pos
                            custAttributes.add s GTALinkAttribs
                            s.nodeA = finalNodeA; s.nodeB = finalNodeB; s.isPedLink = rl.isPed
                            s.lanesLeft = finalLanesLeft; s.lanesRight = finalLanesRight; s.trafficLight = rl.trafficLight; s.isTrain = rl.isTrain
                            
                            -- [FORCE TWO WAY IMPORT]
                            s.isTwoWay = true
                            
                            addNewSpline s; addKnot s 1 #corner #line finalNodeA.pos
                            if s.isPedLink then ( addKnot s 1 #corner #line finalNodeB.pos; s.wirecolor = white ) 
                            else ( 
                                local navPos = (finalNodeA.pos + finalNodeB.pos) * 0.5; navPos.z = finalNodeB.pos.z
                                addKnot s 1 #corner #line navPos; addKnot s 1 #corner #line finalNodeB.pos; s.wirecolor = yellow 
                                addNewSpline s; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; close s 2 
                            )
                            updateSplineGeometry s finalNodeA finalNodeB s.isPedLink
                            if finalNodeA.parent != undefined do s.parent = finalNodeA.parent
                            if gtaLinkMap.ContainsKey linkKey do gtaLinkMap.Remove linkKey
                            gtaLinkMap.Add linkKey (dotNetMXSValue s)
                        )
                    )
                )
            )
        )
    )
    if pb != undefined do pb.value = 100
    format "Batch Build Complete.\n"
)

-- ===============================================================================
-- 5. EXPORT LOGIC (WRITE)
-- ===============================================================================

fn ExportGTA_SA dir pb useFLA4 =
(
    if dir == undefined do return false
    local allNodes = for o in objects where isProperty o #GTA_Node_Data collect o
    
    local badNodes = 0
    for n in allNodes do ( if n.areaID < 0 or n.areaID > 63 do badNodes += 1 )
    if badNodes > 0 do (
        local msg = "Warning: " + (badNodes as string) + " nodes have Area ID outside 0-63.\nThey will not be exported."
        format "%\n" msg
        messageBox msg
    )
    
    -- [STEP 1] GLOBAL NODE MAP (Lookup for cross-area)
    local globalNodeMapping = dotNetObject "System.Collections.Hashtable"
    struct MapData (area, idx, isPed)
    
    local areaBuckets = dotNetObject "System.Collections.Hashtable"
    for n in allNodes do (
        local a = n.areaID
        if a >= 0 and a <= 63 do (
            if not areaBuckets.ContainsKey a do areaBuckets.Add a (dotNetObject "System.Collections.ArrayList")
            (areaBuckets.Item[a]).Add (dotNetMXSValue n)
        )
    )
    
    for aID = 0 to 63 do (
        if areaBuckets.ContainsKey aID then (
            local nodeList = (areaBuckets.Item[aID]).ToArray()
            local vehNodes = #(); local pedNodes = #()
            for i = 1 to nodeList.count do ( local wrapper = nodeList[i]; local n = wrapper.value; if n.isPed then append pedNodes n else append vehNodes n )
            local exportNodes = #(); join exportNodes vehNodes; join exportNodes pedNodes
            
            for i = 1 to exportNodes.count do (
                local n = exportNodes[i]; local newIdx = i - 1; local mapKey = (getHandleByAnim n) as string
                local md = MapData area:aID idx:newIdx isPed:n.isPed
                if globalNodeMapping.ContainsKey mapKey do globalNodeMapping.Remove mapKey
                globalNodeMapping.Add mapKey (dotNetMXSValue md)
            )
        )
    )
    
    -- Loop 0-63 for Export
    for aID = 0 to 63 do (
        local exportNodes = #(); local vehNodes = #(); local pedNodes = #()
        
        if areaBuckets.ContainsKey aID then (
            local nodeList = (areaBuckets.Item[aID]).ToArray()
            for i = 1 to nodeList.count do (
                local wrapper = nodeList[i]
                local n = wrapper.value
                if n.isPed then append pedNodes n else append vehNodes n
            )
            join exportNodes vehNodes; join exportNodes pedNodes
        )
        
        local fName = dir + "\\nodes" + (aID as string) + ".dat"
        local f = fopen fName "wb"
        
        if f != undefined then (
            
            if useFLA4 then (
                writeLong f -1 -- 0xFFFFFFFF
                writeLong f 0x34414C46 -- '4ALF'
            )
            
            if exportNodes.count > 0 then (
                struct ExLink (targetArea, targetNode, length, naviIndex, pedFlags)
                struct ExNavi (targetArea, targetNode, pos, dirX, dirY, flags)
                local compiledLinks = #(); local compiledNavis = #()
                local naviLookup = dotNetObject "System.Collections.Hashtable"
                
                for i = 1 to exportNodes.count do (
                    local n = exportNodes[i]
                    local nodeLinks = #()
                    local deps = refs.dependents n
                    
                    for d in deps do (
                        if isProperty d #nodeA and isProperty d #nodeB then (
                            local splineObj = undefined; local owners = refs.dependents d; if owners.count > 0 do splineObj = owners[1]
                            if isValidNode splineObj and (isKindOf splineObj SplineShape or isKindOf splineObj Line) do (
                                local targetObj = undefined; local isIncomingTwoWay = false
                                if d.nodeA == n then targetObj = d.nodeB
                                else if d.nodeB == n and (d.isTwoWay == true) then ( targetObj = d.nodeA; isIncomingTwoWay = true )
                                
                                if isValidNode targetObj do (
                                    local tHandle = (getHandleByAnim targetObj) as string
                                    if globalNodeMapping.ContainsKey tHandle do (
                                        local tMap = (globalNodeMapping.Item[tHandle]).value
                                        local dist = distance n.pos targetObj.pos 
                                        local distInt = dist as integer
                                        if distInt < 1 do distInt = 1
                                        if distInt > 255 do distInt = 255
                                        
                                        local lnk = ExLink targetArea:tMap.area targetNode:tMap.idx length:distInt naviIndex:0 pedFlags:0
                                        
                                        if n.isPed then ( if d.hasPedTL do lnk.pedFlags = bit.set 0 2 true )
                                        else (
                                            local h1 = (getHandleByAnim n); local h2 = (getHandleByAnim targetObj)
                                            local navKey = ""
                                            if h1 < h2 then navKey = (h1 as string) + "_" + (h2 as string) else navKey = (h2 as string) + "_" + (h1 as string)
                                            
                                            if naviLookup.ContainsKey navKey then (
                                                lnk.naviIndex = naviLookup.Item[navKey]
                                            ) else (
                                                local highObj = n; local lowObj = targetObj
                                                local highMap = (globalNodeMapping.Item[(getHandleByAnim highObj) as string]).value
                                                local lowMap = tMap
                                                local isHigh = false
                                                if highMap.area > lowMap.area then isHigh = true
                                                else if highMap.area == lowMap.area and highMap.idx > lowMap.idx do isHigh = true
                                                if not isHigh do ( highObj = targetObj; lowObj = n )
                                                lowMap = (globalNodeMapping.Item[(getHandleByAnim lowObj) as string]).value
                                                
                                                local navPos = (highObj.pos + lowObj.pos) * 0.5
                                                if (numKnots splineObj 1) >= 3 do navPos = getKnotPoint splineObj 1 2 
                                                local vec = (lowObj.pos - navPos)
                                                local dirVec = [1,0,0]
                                                if (length vec) > 0.001 do dirVec = normalize vec
												
												local direc = lowObj.pos - navPos
												ang = atan2 direc.y direc.x
												ang = mod (ang + 90.0) 360.0
												if ang < 0.0f then
													ang += 360.0f
												dirVec.x = sin ang;
												dirVec.y = cos ang;
												
                                                local dX = (dirVec.x * 100.0) as integer; local dY = (dirVec.y * -100.0) as integer
                                                
                                                local nvFlags = 0
                                                local widthByte = (highObj.pathWidth * 8.0) as integer; if widthByte > 255 do widthByte = 255
                                                nvFlags = bit.or nvFlags widthByte
                                                nvFlags = bit.or nvFlags (bit.shift (bit.and d.lanesLeft 7) 11)
                                                nvFlags = bit.or nvFlags (bit.shift (bit.and d.lanesRight 7) 8)
                                                if d.trafficLight > 1 do nvFlags = bit.set nvFlags 15 false
                                                if d.trafficLight == 2 do nvFlags = bit.or nvFlags (bit.shift 1 16)
                                                if d.trafficLight == 3 do nvFlags = bit.or nvFlags (bit.shift 2 16)
                                                if d.isTrain do nvFlags = bit.set nvFlags 19 true 
                                                
                                                append compiledNavis (ExNavi targetArea:lowMap.area targetNode:lowMap.idx pos:navPos dirX:dX dirY:dY flags:nvFlags)
                                                local newIndex = 0
                                                if useFLA4 then ( newIndex = (compiledNavis.count - 1) ) 
                                                else ( newIndex = (bit.or (bit.shift aID 10) (compiledNavis.count - 1)) )
                                                lnk.naviIndex = newIndex
                                                naviLookup.Add navKey newIndex
                                            )
                                            append nodeLinks lnk
                                        )
                                    )
                                )
                            )
                        )
                    )
                    
                    -- [CRASH PREVENTION] Check for 0 Links
                    if nodeLinks.count == 0 do (
                        local msg = "CRITICAL: Node " + (n.nodeID as string) + " in Area " + (aID as string) + " has 0 LINKS!\nExport Aborted to prevent crash."
                        format "%\n" msg
                        select n
                        messageBox msg
                        fclose f
                        return false
                    )
                    append compiledLinks nodeLinks
                )
                
                if not useFLA4 and compiledNavis.count > 1024 do (
                    local msg = "ERROR: Area " + (aID as string) + " exceeds 1024 Navi Nodes (" + (compiledNavis.count as string) + ") for Standard Format!\nGame will crash. Use FLA4 or split area."
                    format "%\n" msg
                    messageBox msg title:"Export Error"
                )
                
                format "Exporting % Nodes to %\n" exportNodes.count fName
                local cntLinks = 0; for arr in compiledLinks do cntLinks += arr.count
                writeLong f exportNodes.count; writeLong f vehNodes.count; writeLong f pedNodes.count; writeLong f compiledNavis.count; writeLong f cntLinks
                
                -- SECTION 1
                for i = 1 to exportNodes.count do (
                    local n = exportNodes[i]
                    local lStart = 0; if i > 1 do ( for p = 1 to (i-1) do lStart += compiledLinks[p].count )
                    local lCount = compiledLinks[i].count
                    
                    if useFLA4 then (
                        writeLong f 0; writeLong f 0 
                        writeShort f 0; writeShort f 0; writeShort f 0 
                        writeShort f 0x7FFE #unsigned 
                        writeShort f lStart #unsigned
                        writeShort f n.areaID #unsigned
                        writeShort f (i-1) #unsigned
                        local wVal = (n.pathWidth * 8.0) as integer; if wVal > 255 do wVal = 255
                        writeByte f wVal #unsigned
                        writeByte f 0 #unsigned 
                        local flgs = (bit.and lCount 15)
                        if n.isDeadEnd do flgs = bit.set flgs 6 true; if n.isRoadBlock do flgs = bit.set flgs 7 true
                        if n.isBoats do flgs = bit.set flgs 8 true; if n.isEmergency do flgs = bit.set flgs 9 true
                        if n.isGrove do flgs = bit.set flgs 11 true; if n.isnotHighway do flgs = bit.set flgs 13 true
                        if n.isHighway do flgs = bit.set flgs 14 true
                        local sp = bit.and n.spawnProb 15; flgs = bit.or flgs (bit.shift sp 16)
                        if n.specialFlag > 1 do ( local spF = (n.specialFlag - 1); flgs = bit.or flgs (bit.shift spF 20) )
                        writeLong f flgs
                        writeIntToBin f (n.pos.x * 8.0); writeIntToBin f (n.pos.y * 8.0); writeIntToBin f (n.pos.z * 8.0)
                        writeShort f n.floodFill #unsigned; writeShort f 0 
                    ) else (
                        writeLong f 0; writeLong f 0
                        writeShortToBin f (n.pos.x * 8.0); writeShortToBin f (n.pos.y * 8.0); writeShortToBin f (n.pos.z * 8.0)
                        writeShort f 0x7FFE #unsigned; writeShort f lStart #unsigned; writeShort f n.areaID #unsigned; writeShort f (i-1) #unsigned
                        local wVal = (n.pathWidth * 8.0) as integer; if wVal > 255 do wVal = 255
                        writeByte f wVal #unsigned; writeByte f n.floodFill #unsigned
                        local flgs = (bit.and lCount 15)
                        if n.isDeadEnd do flgs = bit.set flgs 6 true; if n.isRoadBlock do flgs = bit.set flgs 7 true
                        if n.isBoats do flgs = bit.set flgs 8 true; if n.isEmergency do flgs = bit.set flgs 9 true
                        if n.isGrove do flgs = bit.set flgs 11 true; if n.isnotHighway do flgs = bit.set flgs 13 true
                        if n.isHighway do flgs = bit.set flgs 14 true
                        local sp = bit.and n.spawnProb 15; flgs = bit.or flgs (bit.shift sp 16)
                        if n.specialFlag > 1 do ( local spF = (n.specialFlag - 1); flgs = bit.or flgs (bit.shift spF 20) )
                        writeLong f flgs
                    )
                )
                
                -- SECTION 2
                for nv in compiledNavis do (
                    if useFLA4 then (
                        writeShort f 0; writeShort f 0; writeShort f nv.targetArea #unsigned; writeShort f nv.targetNode #unsigned
                        writeByte f nv.dirX #signed; writeByte f nv.dirY #signed; writeLong f nv.flags
                        writeShort f 0 
                        writeIntToBin f (nv.pos.x * 8.0); writeIntToBin f (nv.pos.y * 8.0)
                    ) else (
                        writeShortToBin f (nv.pos.x * 8.0); writeShortToBin f (nv.pos.y * 8.0)
                        writeShort f nv.targetArea #unsigned; writeShort f nv.targetNode #unsigned
                        writeByte f nv.dirX #signed; writeByte f nv.dirY #signed; writeLong f nv.flags
                    )
                )
                
                for arr in compiledLinks do ( for lnk in arr do ( writeShort f lnk.targetArea #unsigned; writeShort f lnk.targetNode #unsigned ) )
                for k = 1 to 192 do writeLong f 65535 
                
                for arr in compiledLinks do ( for lnk in arr do ( 
                    if useFLA4 then ( writeShort f lnk.naviIndex #unsigned; writeShort f aID #unsigned ) else ( writeShort f lnk.naviIndex #unsigned )
                ) )
                
                for arr in compiledLinks do ( for lnk in arr do writeByte f lnk.length #unsigned )
                if useFLA4 do ( for k = 1 to 192 do writeByte f 0 )
                
                for arr in compiledLinks do ( for lnk in arr do writeByte f lnk.pedFlags #unsigned )
                for k = 1 to 192 do writeByte f 0 
                
                if useFLA4 then ( writeLong f 0x00464F45 ) else ( for k = 1 to 48 do writeLong f 0 )
                
            ) else (
                if useFLA4 then ( writeLong f -1; writeLong f 0x34414C46 )
                writeLong f 0; writeLong f 0; writeLong f 0; writeLong f 0; writeLong f 0 
                for k = 1 to 192 do writeLong f 65535 
                for k = 1 to 192 do writeByte f 0 
                if useFLA4 do writeLong f 0x00464F45
            )
            fclose f
        )
    )
    messageBox "Batch Export Complete."
)

-- ===============================================================================
-- PARTIAL SCENE SNIPPET TOOLS (FIXED)
-- ===============================================================================

fn ExportSnippet fPath = (
    local selNodes = for o in selection where isProperty o #GTA_Node_Data collect o
    if selNodes.count == 0 do (messageBox "Select GTA Nodes to export."; return false)
    
    local f = createFile fPath
    format "GTAPART_V1\n" to:f
    format "NODES %\n" selNodes.count to:f
    
    local handleMap = dotNetObject "System.Collections.Hashtable"
    for i=1 to selNodes.count do handleMap.Add ((getHandleByAnim selNodes[i]) as string) i
    
    for n in selNodes do (
        -- [FIX] Check for undefined IV flags and default to 0
        local iv1 = getUserProp n "IV_Flags_1"; if iv1 == undefined do iv1 = 0
        local iv2 = getUserProp n "IV_Flags_2"; if iv2 == undefined do iv2 = 0
        
        format "% % % % % % % % % % % % % % % % % % %\n" n.pos.x n.pos.y n.pos.z n.pathWidth (n.isPed as integer) n.floodFill \
        (n.isDeadEnd as integer) (n.isSwitchedOff as integer) (n.isRoadBlock as integer) (n.isBoats as integer) \
        (n.isEmergency as integer) (n.isGrove as integer) (n.isHighway as integer) (n.isnotHighway as integer) \
        n.spawnProb n.specialFlag n.ivFlags iv1 iv2 to:f
    )
    
    local linksToWrite = #()
    for n in selNodes do (
        local deps = refs.dependents n
        for d in deps do (
            if isProperty d #nodeA and isProperty d #nodeB then (
                local hA = (getHandleByAnim d.nodeA) as string
                local hB = (getHandleByAnim d.nodeB) as string
                
                if (d.nodeA == n) and (handleMap.ContainsKey hB) do (
                    local idxA = handleMap.Item[hA]; local idxB = handleMap.Item[hB]
                    local linkID = (if idxA < idxB then (idxA as string + "_" + idxB as string) else (idxB as string + "_" + idxA as string))
                    local exists = false; for l in linksToWrite do ( if l[1] == linkID do exists = true )
                    
                    if not exists do (
                        append linksToWrite #(linkID, idxA, idxB, d.isPedLink, d.lanesLeft, d.lanesRight, d.trafficLight, d.isTrain)
                    )
                )
            )
        )
    )
    
    format "LINKS %\n" linksToWrite.count to:f
    for l in linksToWrite do (
        format "% % % % % % %\n" l[2] l[3] (l[4] as integer) l[5] l[6] l[7] (l[8] as integer) to:f
    )
    
    close f
    messageBox ("Exported Snippet: " + selNodes.count as string + " nodes.")
)

fn ImportSnippet fPath = (
    if not (doesFileExist fPath) do return false
    local f = openFile fPath
    local head = readLine f
    if head != "GTAPART_V1" do ( messageBox "Invalid Snippet File."; close f; return false )
    
    local nodeHead = filterString (readLine f) " "
    local numNodes = nodeHead[2] as integer
    local createdNodes = #()
    
    local fName = getFilenameFile fPath
    local dum = Dummy pos:[0,0,0] boxsize:[2,2,2] name:("Group_" + fName)
    select dum 
    
    with undo off, redraw off (
        for i=1 to numNodes do (
            local d = filterString (readLine f) " "
            local p = Point pos:[d[1] as float, d[2] as float, d[3] as float] size:0.6 centerMarker:true axisTripod:false cross:false box:true
            p.parent = dum
            
            custAttributes.add p GTANodeAttribs
            p.pathWidth = d[4] as float
            p.isPed = ((d[5] as integer) == 1)
            if p.isPed then (p.wirecolor=white; p.box=false; p.cross=true) else (p.wirecolor=green)
            
            p.floodFill = d[6] as integer
            p.isDeadEnd = (d[7] as integer) == 1; p.isSwitchedOff = (d[8] as integer) == 1
            p.isRoadBlock = (d[9] as integer) == 1; p.isBoats = (d[10] as integer) == 1
            p.isEmergency = (d[11] as integer) == 1; p.isGrove = (d[12] as integer) == 1
            p.isHighway = (d[13] as integer) == 1; p.isnotHighway = (d[14] as integer) == 1
            p.spawnProb = d[15] as integer; p.specialFlag = d[16] as integer
            p.ivFlags = d[17] as integer
            
            -- [FIX] Handle possible "undefined" text from old files
            if d[18] != "undefined" and d[18] != undefined do setUserProp p "IV_Flags_1" (d[18] as integer)
            if d[19] != "undefined" and d[19] != undefined do setUserProp p "IV_Flags_2" (d[19] as integer)
            
            p.areaID = getAreaIDFromPos p.pos
            p.nodeID = 0 
            append createdNodes p
        )
        
        local linkHead = filterString (readLine f) " "
        local numLinks = linkHead[2] as integer
        
        for i=1 to numLinks do (
            local d = filterString (readLine f) " "
            local idxA = d[1] as integer; local idxB = d[2] as integer
            
            if idxA <= createdNodes.count and idxB <= createdNodes.count do (
                local nA = createdNodes[idxA]; local nB = createdNodes[idxB]
                local s = SplineShape pos:nA.pos
                s.parent = dum 
                custAttributes.add s GTALinkAttribs
                s.nodeA = nA; s.nodeB = nB
                s.isPedLink = (d[3] as integer) == 1
                s.lanesLeft = d[4] as integer; s.lanesRight = d[5] as integer
                s.trafficLight = d[6] as integer; s.isTrain = (d[7] as integer) == 1
                s.isTwoWay = true 
                
                addNewSpline s; addKnot s 1 #corner #line nA.pos
                if s.isPedLink then ( addKnot s 1 #corner #line nB.pos; s.wirecolor = white ) 
                else ( 
                    local navPos = (nA.pos + nB.pos) * 0.5; navPos.z = nB.pos.z
                    addKnot s 1 #corner #line navPos; addKnot s 1 #corner #line nB.pos; s.wirecolor = yellow 
                    addNewSpline s; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; close s 2 
                )
                updateSplineGeometry s nA nB s.isPedLink
            )
        )
    )
    close f
    messageBox "Snippet Imported."
)

-- ===============================================================================
-- 6. MAIN ROLLOUT
-- ===============================================================================

fn createMatrixRollout =
(
    local str = "rollout rol_gtaMatrix \"Area Visibility (0-63)\" width:300 height:240 (\n"
    str += "  fn toggleArea aID state = (\n"
    str += "    local nodes = #()\n"
    str += "    for o in objects do (\n"
    str += "      if isProperty o #GTA_Node_Data and o.areaID == aID do append nodes o\n"
    str += "      if isProperty o #GTA_Link_Data and isValidNode o.nodeA do ( if o.nodeA.areaID == aID do append nodes o )\n"
    str += "    )\n"
    str += "    if state then unhide nodes else hide nodes\n"
    str += "  )\n"
    for y = 0 to 7 do (
        for x = 0 to 7 do (
            local id = (y*8)+x
            str += "  checkbutton ck_" + (id as string) + " \"" + (id as string) + "\" width:28 height:20 across:8 checked:true\n"
            str += "  on ck_" + (id as string) + " changed state do toggleArea " + (id as string) + " state\n"
        )
    )
    str += "  button btn_showAll \"Show All\" width:130 across:2\n"
    str += "  button btn_hideAll \"Hide All\" width:130\n"
    str += "  on btn_showAll pressed do ( for c in rol_gtaMatrix.controls where isKindOf c CheckButtonControl do c.checked = true; unhide (for o in objects where isProperty o #GTA_Node_Data or isProperty o #GTA_Link_Data collect o) )\n"
    str += "  on btn_hideAll pressed do ( for c in rol_gtaMatrix.controls where isKindOf c CheckButtonControl do c.checked = false; hide (for o in objects where isProperty o #GTA_Node_Data or isProperty o #GTA_Link_Data collect o) )\n"
    str += ")"
    execute str
)



rollout rol_gtaMain "Main Tools"
(
    local gtaPaintTool 
    
    group "Import"
    (
        button btn_load "Batch Import SA (One Pass)" width:280 height:30
        button btn_loadIV "Batch Import IV (One Pass)" width:280 height:30
        progressBar pb_progress "Progress" value:0 color:green height:8
    )
	
	group "Partial Scene Management" (
        button btn_exportPart "Save Selection (.gtapart)" width:280 height:30 tooltip:"Export selected nodes to a snippet file"
        button btn_importPart "Import Snippet (Merge)" width:280 height:30 tooltip:"Import a .gtapart file as a group"
    )
    
    -- Event Handlers for Partial Scene
    on btn_exportPart pressed do (
        local savePath = getSaveFileName caption:"Save Partial Path" types:"GTA Snippet|*.gtapart"
        if savePath != undefined do ExportSnippet savePath
    )
    
    on btn_importPart pressed do (
        local openPath = getOpenFileName caption:"Open Partial Path" types:"GTA Snippet|*.gtapart"
        if openPath != undefined do ImportSnippet openPath
    )
    group "Export"
    (
        radiobuttons rdo_format "Format:" labels:#("Standard SA", "Fastman92 FLA4") default:1
        button btn_export "Export Nodes" width:280 height:30
    )
group "Node Defaults & Batch Edit" (
        -- Standard Properties
        spinner spn_def_width "Width:" range:[0,100,4.0] type:#float fieldwidth:40 across:2
        spinner spn_def_flood "Flood:" range:[0,255,1] type:#integer fieldwidth:40
        
        -- SA Flags
        checkbox chk_d_dead "DeadEnd" across:3; checkbox chk_d_off "Off"; checkbox chk_d_road "RoadBlock"
        checkbox chk_d_boat "Boats" across:3; checkbox chk_d_emer "Emerg"; checkbox chk_d_grove "Grove"
        checkbox chk_d_high "Highway" across:2; checkbox chk_d_nhigh "Not Hwy"
        
        -- Values
        spinner spn_d_spawn "SpawnProb:" range:[0,15,15] type:#integer fieldwidth:30 across:2
        dropdownlist ddl_d_special "" items:#("0-None", "1-ParkPar", "2-ParkPerp", "3-Valet", "4-Club", "5-Deliv", "6-ValUn", "7-ClubUn", "8-DrThru", "9-DrWin", "10-DelUn") width:80 selection:1
        
        -- IV Flags
       -- label lbl_iv "Default IV Flags:" align:#left
       -- spinner spn_iv1 "F1:" range:[0,255,0] type:#integer fieldwidth:30 across:4
        --spinner spn_iv2 "F2:" range:[0,255,0] type:#integer fieldwidth:30
        --spinner spn_iv3 "F3:" range:[0,255,0] type:#integer fieldwidth:30
       -- spinner spn_iv4 "F4:" range:[0,255,0] type:#integer fieldwidth:30
        
        -- Management Buttons
        button btn_getFromSel "GET Settings from Selection" width:280 height:25 tooltip:"Reads properties of the first selected node into these controls."
        button btn_setToSel "SET Settings to Selection" width:280 height:25 tooltip:"Applies these settings to all selected nodes."
    )
    
    group "Link Defaults" (
        spinner spn_defLanesLeft "Left Lanes:" type:#integer range:[0,7,1] across:2
        spinner spn_defLanesRight "Right Lanes:" type:#integer range:[0,7,1]
    )
    group "Painting Tools"
    (
        checkbutton cbtn_paintVeh "Paint Vehicle" width:135 height:30 highlightColor:yellow across:2
        checkbutton cbtn_paintPed "Paint Ped" width:135 height:30 highlightColor:white
        checkbox chk_autoConnect "Auto-Connect" checked:true
    )
    group "Management"
    (
        button btn_linkSel "Link Selected Nodes" width:280
        button btn_recalc "Recalc IDs & Fix Directions" width:280 height:40
        button btn_validate "Scan for Errors (DivByZero)" width:280
    )

	-- Helper to apply UI defaults to a specific node object
    fn ApplyDefaultsToNode n = (
        if isValidNode n do (
            n.pathWidth = spn_def_width.value
            n.floodFill = spn_def_flood.value
            
            n.isDeadEnd = chk_d_dead.checked; n.isSwitchedOff = chk_d_off.checked
            n.isRoadBlock = chk_d_road.checked; n.isBoats = chk_d_boat.checked
            n.isEmergency = chk_d_emer.checked; n.isGrove = chk_d_grove.checked
            n.isHighway = chk_d_high.checked; n.isnotHighway = chk_d_nhigh.checked
            
            n.spawnProb = spn_d_spawn.value
            n.specialFlag = ddl_d_special.selection
            
            setUserProp n "IV_Flags_1" 0
            setUserProp n "IV_Flags_2" 0
            setUserProp n "IV_Flags_3" 0
            setUserProp n "IV_Flags_4" 0
        )
    )

   on btn_getFromSel pressed do (
        local obj = selection[1]
        if isValidNode obj then (
            -- CASE 1: GTA NODE
            if isProperty obj #GTA_Node_Data then (
                spn_def_width.value = obj.pathWidth
                spn_def_flood.value = obj.floodFill
                
                chk_d_dead.checked = obj.isDeadEnd; chk_d_off.checked = obj.isSwitchedOff
                chk_d_road.checked = obj.isRoadBlock; chk_d_boat.checked = obj.isBoats
                chk_d_emer.checked = obj.isEmergency; chk_d_grove.checked = obj.isGrove
                chk_d_high.checked = obj.isHighway; chk_d_nhigh.checked = obj.isnotHighway
                
                spn_d_spawn.value = obj.spawnProb
                if obj.specialFlag > 0 and obj.specialFlag <= 11 do ddl_d_special.selection = obj.specialFlag
                
              
                
                messageBox "NODE settings retrieved."
            )
            -- CASE 2: GTA LINK
            else if isProperty obj #GTA_Link_Data then (
                spn_defLanesLeft.value = obj.lanesLeft
                spn_defLanesRight.value = obj.lanesRight
                messageBox "LINK settings retrieved."
            )
            else messageBox "Select a GTA Node or Link."
        ) 
        else messageBox "Selection empty."
    )
    
    on btn_setToSel pressed do (
        local nodeCount = 0
        local linkCount = 0
        
        undo "Apply GTA Settings" on (
            for o in selection do (
                -- Apply to NODE
                if isProperty o #GTA_Node_Data do (
                    ApplyDefaultsToNode o
                    nodeCount += 1
                )
                
                -- Apply to LINK (and update visuals)
                if isProperty o #GTA_Link_Data do (
                    o.lanesLeft = spn_defLanesLeft.value
                    o.lanesRight = spn_defLanesRight.value
                    
                    -- [CRITICAL] Force visual update of the spline width
                    if isValidNode o.nodeA and isValidNode o.nodeB do (
                        updateSplineGeometry o o.nodeA o.nodeB o.isPedLink
                    )
                    linkCount += 1
                )
            )
        )
        
        -- Force viewport refresh to show new link widths
        redrawViews()
        
        messageBox ("Updated:\n" + nodeCount as string + " Nodes\n" + linkCount as string + " Links")
    )
	
	
    local lastNode = undefined
    
    fn selectFiles title filter = 
    (
        local dlg = dotNetObject "System.Windows.Forms.OpenFileDialog"
        dlg.Title = title; dlg.Multiselect = true; dlg.Filter = filter
        if (dlg.ShowDialog() == (dotNetClass "System.Windows.Forms.DialogResult").OK) then return dlg.FileNames else return undefined
    )
    
    fn createSmartLink nSource nTarget linkData = (
        if isValidNode nSource and isValidNode nTarget do (
            local idA = getGlobalID nSource; local idB = getGlobalID nTarget
            local finalNodeA = nSource; local finalNodeB = nTarget
            local finalLanesLeft = linkData.lanesLeft; local finalLanesRight = linkData.lanesRight
            
            if idA < idB then (
                finalNodeA = nTarget; finalNodeB = nSource
                finalLanesLeft = linkData.lanesRight; finalLanesRight = linkData.lanesLeft
            )
            
            local s = SplineShape pos:finalNodeA.pos
            custAttributes.add s GTALinkAttribs
            s.nodeA = finalNodeA; s.nodeB = finalNodeB; s.isPedLink = linkData.isPed
            s.lanesLeft = finalLanesLeft; s.lanesRight = finalLanesRight
            
            if linkData.forceTwoWay do s.isTwoWay = true
            
            addNewSpline s; addKnot s 1 #corner #line finalNodeA.pos
            if s.isPedLink then ( addKnot s 1 #corner #line finalNodeB.pos; s.wirecolor = white ) 
            else ( 
                local navPos = (finalNodeA.pos + finalNodeB.pos) * 0.5; navPos.z = finalNodeB.pos.z
                addKnot s 1 #corner #line navPos; addKnot s 1 #corner #line finalNodeB.pos; s.wirecolor = yellow 
                addNewSpline s; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; addKnot s 2 #corner #line [0,0,0]; close s 2 
            )
            updateSplineGeometry s finalNodeA finalNodeB s.isPedLink
            return s
        )
    )

    on btn_load pressed do ( 
        local files = selectFiles "Select SA nodes*.dat" "GTA Data|nodes*.dat"
        if files != undefined do (
            GLOBAL_RAW_NODES = #(); GLOBAL_RAW_LINKS = #(); pb_progress.value = 0
            for fName in files do ( local f = fopen fName "rb"; if f != undefined do ( try ( ParseSAFile f ) catch ( format "Error parsing %\n" fName ); fclose f ) )
            BuildSceneFromMemory pb_progress
        )
    )
    on btn_loadIV pressed do (
        local files = selectFiles "Select IV *.nod" "GTA IV Data|*.nod"
        if files != undefined do (
            GLOBAL_RAW_NODES = #(); GLOBAL_RAW_LINKS = #(); pb_progress.value = 0
            for fName in files do ( local f = fopen fName "rb"; if f != undefined do ( try ( ParseIVFile f ) catch ( format "Error parsing %\n" fName ); fclose f ) )
            BuildSceneFromMemory pb_progress
        )
    )
    on btn_export pressed do (
        local savePath = getSavePath caption:"Select Output Folder"
        if savePath != undefined do (
            local useFLA4 = (rdo_format.state == 2)
            ExportGTA_SA savePath pb_progress useFLA4
        )
    )
    
on btn_validate pressed do (
        local problemNodes = #()
        -- [FIX 1] Initialize the array properly
        local connectedNodes = #() 
        
        local links = for o in objects where isProperty o #GTA_Link_Data collect o
        
        for l in links do (
            -- [FIX 2] Now we can append because connectedNodes is an array
            if isValidNode l.nodeA do appendIfUnique connectedNodes l.nodeA
            if isValidNode l.nodeB do appendIfUnique connectedNodes l.nodeB
        )
        
        -- [FIX 3] Define allNodes locally before using it
        local allNodes = for o in objects where isProperty o #GTA_Node_Data collect o
        
        local orphans = for n in allNodes where (findItem connectedNodes n == 0) collect n
        
        if orphans.count > 0 then (
            select orphans
            messageBox ("Found " + (orphans.count as string) + " Orphan Nodes (Selected).")
        ) else (
            messageBox "No Orphan Nodes found."
        )
    )
    
    on btn_recalc pressed do (
        undo "Recalc GTA IDs" on (
            local allLinks = for o in objects where isProperty o #GTA_Link_Data collect o
            for s in allLinks do ( if not (isValidNode s.nodeA and isValidNode s.nodeB) then delete s )
            local areaCounters=#(); for i=1 to 64 do areaCounters[i]=0
            local allNodes = for o in objects where isProperty o #GTA_Node_Data collect o
            for n in allNodes do n.linkCount = 0
            local nodes=for o in objects where isProperty o #GTA_Node_Data collect o
            local links=for o in objects where isProperty o #GTA_Link_Data collect o
            for n in nodes do ( local a=getAreaIDFromPos n.pos; n.areaID=a; local idx=a+1; n.nodeID=areaCounters[idx]; areaCounters[idx]+=1 )
            for s in links do (
                if isValidNode s.nodeA and isValidNode s.nodeB do (
                    local idA = getGlobalID s.nodeA; local idB = getGlobalID s.nodeB
                    if idA < idB then (
                        local tempN = s.nodeA; s.nodeA = s.nodeB; s.nodeB = tempN
                        local tempL = s.lanesLeft; s.lanesLeft = s.lanesRight; s.lanesRight = tempL
                    )
                    updateSplineGeometry s s.nodeA s.nodeB s.isPedLink
                    s.nodeA.linkCount += 1
                    if s.isTwoWay do s.nodeB.linkCount += 1
                )
            )
            for n in allNodes do ( if n.linkCount == 1 then n.isDeadEnd = true else n.isDeadEnd = false )
        ); messageBox "Recalculated & Fixed Directions."
    )
    
    on cbtn_paintVeh changed state do ( if state then (cbtn_paintPed.checked=false; startTool gtaPaintTool) else stopTool gtaPaintTool )
    on cbtn_paintPed changed state do ( if state then (cbtn_paintVeh.checked=false; startTool gtaPaintTool) else stopTool gtaPaintTool )
    on btn_linkSel pressed do ( 
        if selection.count==2 then (
            local nA = selection[1]; local nB = selection[2]
            local ld = sLinkData isPed:nA.isPed lanesLeft:spn_defLanesLeft.value lanesRight:spn_defLanesRight.value
            createSmartLink nA nB ld
        ) else messageBox "Select 2 Nodes." 
    )
    
    tool gtaPaintTool (
        local isPedMode=false
        
        on start do (
            -- Set mode immediately on tool start
            if cbtn_paintPed.checked then isPedMode=true else isPedMode=false
        )

        on mouseMove click do (
            -- [CRITICAL FIX] This forces the Snap system to update coordinates in real-time.
            -- Without this, 'worldPoint' lags one click behind.
        )
on mousePoint click do (
            local spawnPos = worldPoint 
            local p = Point pos:spawnPos size:0.6 centerMarker:true axisTripod:false cross:false box:true
            custAttributes.add p GTANodeAttribs
            p.areaID = getAreaIDFromPos spawnPos
            
            -- [NEW] Apply the defaults from the new UI
            ApplyDefaultsToNode p
            
            if isPedMode then ( p.wirecolor = white; p.box = false; p.cross = true; p.isPed = true ) 
            else ( p.wirecolor = green )
            
            if chk_autoConnect.checked and isValidNode lastNode do (
                local ld = sLinkData isPed:isPedMode lanesLeft:spn_defLanesLeft.value lanesRight:spn_defLanesRight.value forceTwoWay:true
                createSmartLink lastNode p ld
            )
            lastNode = p; select p
            local key = gta_makeKey p.areaID p.nodeID
            if gtaNodeMap.ContainsKey key do gtaNodeMap.Remove key
            gtaNodeMap.Add key (dotNetMXSValue p)
        )
        on mouseAbort click do ( 
            cbtn_paintVeh.checked = false
            cbtn_paintPed.checked = false 
        )
    )
)

rollout rol_gtaDebug "IV Flag Debugger" height:780 (
    label lbl_info "Select Raw Flags:" align:#left
    group "Byte 1 (Flags 1)" ( checkbox b1_1 "1" across:4; checkbox b1_2 "2"; checkbox b1_3 "3"; checkbox b1_4 "4"; checkbox b1_5 "5 spcldead" across:4; checkbox b1_6 "6"; checkbox b1_7 "7 toll?"; checkbox b1_8 "8 spcldead" )
    group "Byte 2 (Flags 2)" ( checkbox b2_1 "1" across:4; checkbox b2_2 "2"; checkbox b2_3 "3"; checkbox b2_4 "4"; checkbox b2_5 "5" across:4; checkbox b2_6 "6"; checkbox b2_7 "7"; checkbox b2_8 "8 tunnel?" )
    group "Byte 3 (Flags 3)" ( checkbox b3_1 "1" across:4; checkbox b3_2 "2"; checkbox b3_3 "3 intsct"; checkbox b3_4 "4"; checkbox b3_5 "5" across:4; checkbox b3_6 "6 highspd?"; checkbox b3_7 "7 intersect"; checkbox b3_8 "8 emgrcy" )
    group "Byte 4 (Flags 4)" ( checkbox b4_1 "1 hway&boat" across:4; checkbox b4_2 "2 boat?"; checkbox b4_3 "3 emgrcy"; checkbox b4_4 "4"; checkbox b4_5 "5" across:4; checkbox b4_6 "6"; checkbox b4_7 "7"; checkbox b4_8 "8" )
    
    group "Value Selection (Byte 1)" (
        spinner spn_spawnRate "Spawnrate (1-4):" type:#integer range:[0,15,0] fieldwidth:40
        dropdownlist ddl_behavior "Behavior (5-8):" items:#("0 ", "1- Parking type1", "2 -Parking Straight?", "3 -Special alley?", "4 unused", "5 -Toll booths", "6 -special alley middle?", "7 unused", "8 -street laeve/enter trigger?", "9 - special deadRoads", "10 -fuel station", "11 unused", "12 -airport dropoff start7end", "13 -airport drop off middle", "14 unused", "15 unused")
        
        button btn_searchSpawn "Select Match: Spawnrate Only" width:280 height:25 tooltip:"Ignores behavior and other bytes"
        button btn_searchBehav "Select Match: Behavior Only" width:280 height:25 tooltip:"Ignores spawnrate and other bytes"
        button btn_searchBoth "Select Match: Both (Byte 1 Exact)" width:280 height:25
    )

    group "Sync Tools" (
        button btn_getFlags "Get Flags from Selected" width:280 height:30 tooltip:"Update checkboxes and spinners from selected node"
    )

    group "Quick Selection" ( button btn_selPed "Select All Ped Nodes" width:135 across:2; button btn_selOrphans "Select 0-Link Nodes" width:135 )
    button btn_debugSelect "Select Matching (ALL BYTES AND)" width:280 height:30
    button btn_debugColor "Highlight Red" width:135 across:2
    button btn_debugReset "Reset Colors" width:135
    
    -- Helper to set checkbox states from a bitmask
    fn setChecks mask controls = (
        for i = 1 to 8 do (
            controls[i].checked = bit.get mask i
        )
    )

    fn getMaskFromChecks checkboxes = ( local mask = 0; for i = 1 to 8 do ( if checkboxes[i].checked do mask = bit.set mask i true ); return mask )
    
    -- Function to sync UI controls to the Byte 1 checkboxes
    fn updateCheckboxesFromValues = (
        local sVal = spn_spawnRate.value
        local bVal = (ddl_behavior.selection - 1)
        -- Set Bits 1-4
        b1_1.checked = bit.get sVal 1; b1_2.checked = bit.get sVal 2; b1_3.checked = bit.get sVal 3; b1_4.checked = bit.get sVal 4
        -- Set Bits 5-8
        b1_5.checked = bit.get bVal 1; b1_6.checked = bit.get bVal 2; b1_7.checked = bit.get bVal 3; b1_8.checked = bit.get bVal 4
    )

    on ddl_behavior selected i do updateCheckboxesFromValues()
    on spn_spawnRate changed val do updateCheckboxesFromValues()

on btn_searchSpawn pressed do (
        local targetVal = spn_spawnRate.value
        local hits = #()
        for o in objects where isProperty o #GTA_Node_Data do (
            local f1 = getUserProp o "IV_Flags_1"
            if f1 == undefined do f1 = 0 -- Safety check added here
            if (bit.and f1 15) == targetVal do append hits o
        )
        select hits
    )

    on btn_searchBehav pressed do (
        local targetVal = (ddl_behavior.selection - 1)
        local hits = #()
        for o in objects where isProperty o #GTA_Node_Data do (
            local f1 = getUserProp o "IV_Flags_1"
            if f1 == undefined do f1 = 0 -- Safety check added here
            if (bit.shift (bit.and f1 240) -4) == targetVal do append hits o
        )
        select hits
    )

    on btn_searchBoth pressed do (
        local targetByte1 = spn_spawnRate.value + (bit.shift (ddl_behavior.selection - 1) 4)
        local hits = #()
        for o in objects where isProperty o #GTA_Node_Data do (
            local f1 = getUserProp o "IV_Flags_1"
            if f1 == undefined do f1 = 0 -- Safety check added here
            if f1 == targetByte1 do append hits o
        )
        select hits
    )

    on btn_getFlags pressed do (
        local n = selection[1]
        if n != undefined and isProperty n #GTA_Node_Data then (
            local f1 = getUserProp n "IV_Flags_1"; local f2 = getUserProp n "IV_Flags_2"
            local f3 = getUserProp n "IV_Flags_3"; local f4 = getUserProp n "IV_Flags_4"
            if f1 == undefined do f1 = 0; if f2 == undefined do f2 = 0
            if f3 == undefined do f3 = 0; if f4 == undefined do f4 = 0
            
            setChecks f1 #(b1_1, b1_2, b1_3, b1_4, b1_5, b1_6, b1_7, b1_8)
            setChecks f2 #(b2_1, b2_2, b2_3, b2_4, b2_5, b2_6, b2_7, b2_8)
            setChecks f3 #(b3_1, b3_2, b3_3, b3_4, b3_5, b3_6, b3_7, b3_8)
            setChecks f4 #(b4_1, b4_2, b4_3, b4_4, b4_5, b4_6, b4_7, b4_8)
            
            spn_spawnRate.value = bit.and f1 15
            ddl_behavior.selection = (bit.shift (bit.and f1 240) -4) + 1
        ) else ( messageBox "Select a GTA Node first." )
    )

    on btn_selPed pressed do ( select (for o in objects where isProperty o #GTA_Node_Data and o.isPed collect o) )
    on btn_selOrphans pressed do ( 
        local connectedNodes = #()
        local links = for o in objects where isProperty o #GTA_Link_Data collect o
        for l in links do (
            if isValidNode l.nodeA do appendIfUnique connectedNodes l.nodeA
            if isValidNode l.nodeB do appendIfUnique connectedNodes l.nodeB
        )
        select (for o in objects where isProperty o #GTA_Node_Data and (findItem connectedNodes o == 0) collect o)
    )
    
    on btn_debugSelect pressed do (
        local m1 = getMaskFromChecks #(b1_1, b1_2, b1_3, b1_4, b1_5, b1_6, b1_7, b1_8)
        local m2 = getMaskFromChecks #(b2_1, b2_2, b2_3, b2_4, b2_5, b2_6, b2_7, b2_8)
        local m3 = getMaskFromChecks #(b3_1, b3_2, b3_3, b3_4, b3_5, b3_6, b3_7, b3_8)
        local m4 = getMaskFromChecks #(b4_1, b4_2, b4_3, b4_4, b4_5, b4_6, b4_7, b4_8)
        local hits = #()
        for o in objects where isProperty o #GTA_Node_Data do (
            local f1 = getUserProp o "IV_Flags_1"; if f1 == undefined do f1 = 0
            local f2 = getUserProp o "IV_Flags_2"; if f2 == undefined do f2 = 0
            local f3 = getUserProp o "IV_Flags_3"; if f3 == undefined do f3 = 0
            local f4 = getUserProp o "IV_Flags_4"; if f4 == undefined do f4 = 0
            if ((m1 == 0) or ((bit.and f1 m1) == m1)) and ((m2 == 0) or ((bit.and f2 m2) == m2)) and \
               ((m3 == 0) or ((bit.and f3 m3) == m3)) and ((m4 == 0) or ((bit.and f4 m4) == m4)) do append hits o
        )
        select hits
    )

    on btn_debugColor pressed do (
        local m1 = getMaskFromChecks #(b1_1, b1_2, b1_3, b1_4, b1_5, b1_6, b1_7, b1_8)
        local m2 = getMaskFromChecks #(b2_1, b2_2, b2_3, b2_4, b2_5, b2_6, b2_7, b2_8)
        local m3 = getMaskFromChecks #(b3_1, b3_2, b3_3, b3_4, b3_5, b3_6, b3_7, b3_8)
        local m4 = getMaskFromChecks #(b4_1, b4_2, b4_3, b4_4, b4_5, b4_6, b4_7, b4_8)
        undo "Highlight IV Flags" on (
            for o in objects where isProperty o #GTA_Node_Data do (
                local f1 = getUserProp o "IV_Flags_1"; if f1 == undefined do f1 = 0
                local f2 = getUserProp o "IV_Flags_2"; if f2 == undefined do f2 = 0
                local f3 = getUserProp o "IV_Flags_3"; if f3 == undefined do f3 = 0
                local f4 = getUserProp o "IV_Flags_4"; if f4 == undefined do f4 = 0
                if ((m1 == 0) or ((bit.and f1 m1) == m1)) and ((m2 == 0) or ((bit.and f2 m2) == m2)) and \
                   ((m3 == 0) or ((bit.and f3 m3) == m3)) and ((m4 == 0) or ((bit.and f4 m4) == m4)) do o.wirecolor = red
            )
        ); redrawViews()
    )

    on btn_debugReset pressed do ( undo "Reset Colors" on ( for o in objects where isProperty o #GTA_Node_Data do ( if o.isPed then o.wirecolor = white else o.wirecolor = green ) ); redrawViews() )
)
gtaToolFloater = newRolloutFloater "GTA Path Tool" 300 780
addRollout rol_gtaMain gtaToolFloater
addRollout rol_gtaDebug gtaToolFloater rolledUp:true
createMatrixRollout()
addRollout rol_gtaMatrix gtaToolFloater rolledUp:true
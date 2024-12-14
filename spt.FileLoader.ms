
struct cregion ( 
    id = -1, 
    nodes = #(), 
    navis = #(), 
    vehs = 0, 
    peds = 0, 
    linkCount = 0, 
    nodeCount = 0, 
    naviCount = 0
)

struct cnode (
    --General
        pos,
        region = -1, nodeID = -1, 
        nodeLinks = #(),
        naviLinks = #(),
        obj, spl, realKnot = 0,
        type = 0, -- 1: Ped || 2: Veh
        linkID = 0,
        pathWidth = 0.0,
        widthByte = 0,
        pathID = 0, --Floodfill
        links = 0,

    --Import Related
        passed = false,
        outPassed = false,
        attachedNavi,

    --Flags
        flags = 0,
        onDeadEnd = 0,
        db_traffic = 1,
        switchedOff = 0,

        db_spawn = 1,
        roadblock = 0,
        boats = 0,
        emergency = 0,
        highway = false,
        parking = false,
        laneright = 1,  --Navi
        laneleft = 1,   --Navi
        specialFlag = 0,
        connector = 0

)

struct cnavi (
    pos,
    curRegion = -1,
    targetRegion = -1,
    targetNode = -1,
    dirx = 0, diry = 0,
    dirr = 0,
    naviID = -1,
    flags = 0,
    rightLanes = 0,
    leftLanes = 0,
    isTrafficLight = 0,
    reverse_TrafficLight = 0
)


function LoadRegion File = 
(
    local file = fopen filePath "rb"

    aregion = cregion()

	--FLA4 Check --
		a = readlong file -- 0xFFFFFFFF / -1
		b = readlong file -- "FLA4"
		if (b == 876694598) then isFla = true
		else					 isFla = false
		fseek file 0 #seek_set

        	-- Header --
		if isFla == true then (
			readlong file
			readlong file
		)
        aregion.nodeCount 	= ReadLong file
		aregion.vehs 		= ReadLong file
		aregion.peds 		= ReadLong file
		aregion.naviCount 	= ReadLong file
		aregion.linkCount 	= ReadLong file

)



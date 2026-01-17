/* Tools and utilities for Gta Sa path nodes */

-- 1. UTILS STRUCT
struct SPT_Utils_Struct
(
    bNodeLinktoPrev = true,
    bAutGenNaviNode = false,

    -- [LOGIC] RAW COORDINATES
    function GetAreaFromPos pos = 
    (
        local col = floor ((pos.x + 3000.0) / 750.0)
        local row = floor ((pos.y + 3000.0) / 750.0)
        
        -- Clamp to 0-7
        if col < 0 then col = 0 else if col > 7 then col = 7
        if row < 0 then row = 0 else if row > 7 then row = 7
        
        return (row * 8 + col) as integer
    ),

    -- [LOGIC] GAP FILLING ID GENERATOR
    function GetNextNodeID targetArea = 
    (
        local usedIDs = #()
        local allNodes = GetClassInstances GTA_VehiclePathNode
        
        for n in allNodes do
        (
            if n.AreaID == targetArea do appendIfUnique usedIDs n.NodeID
        )
        sort usedIDs
        
        local nextID = 0
        for id in usedIDs do
        (
            if id == nextID then nextID += 1 else exit
        )
        return nextID
    ),

    -- [LOGIC] MAIN UPDATE FUNCTION
    function UpdateSmartIDs obj forcePos:undefined = 
    (
        if isValidNode obj and classof obj == GTA_VehiclePathNode do
        (
            local currentPos = if forcePos != undefined then forcePos else obj.pos
            local newArea = GetAreaFromPos currentPos
            
            -- Update if Area changed OR if it's the default (0,0) on creation
            if newArea != obj.AreaID or (obj.NodeID == 0 and obj.AreaID == 0) then 
            (
                local oldArea = obj.AreaID
                local newID = GetNextNodeID newArea
                
                format ">> SMART UPDATE: Pos:% | Area % -> % | New ID: %\n" currentPos oldArea newArea newID
                
                with undo off 
                (
                    obj.AreaID = newArea
                    obj.NodeID = newID
                )
                
                -- SYNC NAVIS
                local allNodes = GetClassInstances GTA_VehiclePathNode
                for otherNode in allNodes where otherNode != obj do
                (
                    for link in otherNode.LinkList do
                    (
                        if link.Node == obj and isValidNode link.NaviNode do
                        (
                            link.NaviNode.areaID = newArea
                            link.NaviNode.nodeID = newID
                        )
                    )
                )
            )
        )
    )
)

-- Initialize Global Instance
if sptUtils == undefined do sptUtils = SPT_Utils_Struct()


-- =========================================================
-- 2. ROBUST EVENT SYSTEM (FIXED VARIABLE SCOPE)
-- =========================================================

fn SPT_AttachLogicToNode obj = 
(
    -- FIX: We must declare 'node' after the event to access the object inside the block
    when transform obj changes id:#spt_smart_logic node do 
    (
        sptUtils.UpdateSmartIDs node
    )
)

fn GlobalSPT_OnNodeAdded event handles = 
(
    for h in handles do 
    (
        local obj = GetAnimByHandle h
        if isValidNode obj and classof obj == GTA_VehiclePathNode do 
        (
            SPT_AttachLogicToNode obj
        )  
    )
)

fn SPT_InitSystem = 
(
    -- 1. Clear any existing 'when' handlers
    try(deleteAllChangeHandlers id:#spt_smart_logic)catch()
    
    -- 2. Clear and re-register the 'Added' callback
    if globalSPT_CallbackKey != undefined do (globalSPT_CallbackKey.enabled = false; globalSPT_CallbackKey = undefined)
    gc light:true
    
    global globalSPT_CallbackKey = NodeEventCallback added:GlobalSPT_OnNodeAdded
    
    -- 3. Attach handlers to ALL EXISTING nodes
    local allNodes = GetClassInstances GTA_VehiclePathNode
    for n in allNodes do 
    (
        SPT_AttachLogicToNode n
    )
    
    format ">> SPT Smart Logic System Initialized.\n"
)

SPT_InitSystem()


-- 3. UI UTILITIES
function spt_GuiUtils =
(
    rollout PatCreationUtils "PathCreation" width:150 height:400
    (
        checkbutton btnLinkToPrev "Link to Previous" checked:true width:200 height:25 align:#right tooltip:"Link Node to previous on Creation"
        checkbox chkGenNavi "Auto-Generate Navi" checked:false width:130 align:#right tooltip:"Automatically create NaviNodes when linking Vehicle Nodes"

        on btnLinkToPrev changed state do sptUtils.bNodeLinktoPrev = state
        on chkGenNavi changed state do sptUtils.bAutGenNaviNode = state
    )

    try (closeRolloutFloater sptGUIUtilsFloater) catch ()
    Pos = getMaxWindowSize()    
    PosX = Pos[1]/2 - 300
    sptGUIUtilsFloater  = newRolloutFloater  "Path Toolkit Utils" 250 500 PosX 250
    addRollout  PatCreationUtils sptGUIUtilsFloater
)
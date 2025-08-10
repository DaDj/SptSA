plugin Helper NaviNode
name:"SA Navi Node"
classID:#(0x39cd45f8, 0x454daadb)
extends:ArrowHelper  
category:"GTA Path"
replaceUI:true
(
    parameters main rollout:params
    (
              -- Area and Node IDs
        areaID type:#integer  default:0 range:[0,65535]
        nodeID type:#integer  default:0 range:[0,65535]
        
        -- Flags parameters
        pathWidth type:#integer ui:spnPathWidth default:0 range:[0,255]
        leftLanes type:#integer ui:spnLeftLanes default:0 range:[0,7]
        rightLanes type:#integer ui:spnRightLanes default:0 range:[0,7]
        trafficLightDir type:#boolean ui:chkTrafficLightDir default:false
        trafficLightBehavior type:#integer ui:ddlTrafficBehavior default:1 range:[0,3]
        trainCrossing type:#boolean ui:chkTrainCrossing default:false
    )
    
    rollout params "Navi Node Parameters"
    (
        group "Node References"
        (
            spinner spnAreaID "Area ID:" type:#integer range:[0,65535,0]
            spinner spnNodeID "Node ID:" type:#integer range:[0,65535,0]
        )
        
        group "Flags"
        (
            spinner spnPathWidth "Path Width:" type:#integer range:[0,255,0]
            spinner spnLeftLanes "Left Lanes:" type:#integer range:[0,7,0]
            spinner spnRightLanes "Right Lanes:" type:#integer range:[0,7,0]
            checkbox chkTrafficLightDir "Traffic Light Direction"
            dropdownlist ddlTrafficBehavior "Traffic Light Behavior:"  selection:1 items:#("North-South", "West-East")
            checkbox chkTrainCrossing "Train Crossing"
        )
    )
    
    tool create
    (
        on mousePoint click do
        (
            local pos = gridPoint
            nodeTM = matrix3 1
            nodeTM.translation = pos
            #nodeTM
        )
    )
)
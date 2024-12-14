/* Tools and utilities for Gta Sa path nodes */


struct SPT_Utils
(
    bNodeLinktoPrev = true,
    bAutGenNaviNode = false,

    function LongPathCreator = 
    (
        -- Create a fucntion where we can spawn and connect nodes just as I would draw a line
    )
) 

sptUtils = SPT_Utils()


function spt_GuiUtils =
(
	rollout PatCreationUtils "PathCreation" width:150 height:400
	(
	
		checkbutton btnLinkToPrev "Link to Previous" checked:true width:200 height:25 align:#right tooltip:"Link Node to previous on Creation"
		
        on btnLinkToPrev changed state do
        (
            if state then sptUtils.bNodeLinktoPrev = true else  sptUtils.bNodeLinktoPrev = false
        ) 
    )

    try (closeRolloutFloater sptGUIUtilsFloater) catch ()
	Pos = getMaxWindowSize() 	
	PosX = Pos[1]/2 - 300
	sptGUIUtilsFloater  = newRolloutFloater  "PAth Toolkit Utils" 250 500 PosX 250
    addRollout  PatCreationUtils sptGUIUtilsFloater
)
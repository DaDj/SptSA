plugin helper GTA_AreaController
name:"SA Area Controller"
classID:#(0x4da95fed, 0x719251bf)
extends:Dummy 
category:"GTA Path"
replaceUI:true
(
    local Links = #()
    local NaviLinks = #()
	local selfnode


    parameters main rollout:params
    (
        areaID      type:#integer ui:spn_areaID default:0
        radius      type:#float   ui:spn_radius default:2.0
    )

    rollout params "SA Area Parameters"
    (
        group "Identity"
        (
            spinner spn_areaID "Area ID: " range:[0,65535,0] type:#integer fieldwidth:50 enabled:false
          
        )
        
        group "Dimensions"
        (
            spinner spn_radius "Radius: " range:[0.1, 10000.0, 2.0] type:#float scale:0.1
        )
        
        on spn_radius changed val do
        (
            delegate.boxsize = [val*2, val*2, val*2]
        )
    )
    
    tool create
    (
        on mousePoint click do
        (
            nodeTM.translation = gridPoint
            #stop
        )
    )
    
    on create do delegate.boxsize = [radius*2, radius*2, radius*2]
    on load do delegate.boxsize = [radius*2, radius*2, radius*2]
)
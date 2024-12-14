struct SPT_Render
(
    iMaxConnects = 250,
    isDrawLinks = true,
    function DrawLinks = 
    (
        if isDrawLinks do 
        (
            gw.setTransform (Matrix3 1)
    
            local linkedObjs = #();
            gw.setColor #line green
			mynewlist = #()
           -- mynewlist[iMaxConnects] = 0
            VpWidth = (gw.getWinSizeX())
            VpHeight = (gw.getWinSizeY())
          
            for obj in  objects do 
            (
                if (classof obj) == GTA_PathNode and obj.isHiddenInVpt == false do 
                (
                    gw.setTransform (Matrix3 1)
                    posi = gw.TransPoint obj.pos
         
                    if posi.x < VpWidth  and  posi.x > 0 do 
                        if posi.y < VpHeight and posi.y > 0 do 
                            if mynewlist.count < iMaxConnects do  append mynewlist obj
                )      
            )
    
            for MyObj in mynewlist do
            (
               -- if (classof mynewlist[i]) != GTA_PathNode  do continue
                for LinkedObj in MyObj.LinkList do 
                (
                    if (findItem linkedObjs LinkedObj) == false and isValidNode LinkedObj do 
                    (
                        thepos  = gw.wTransPoint MyObj.pos
                        mpos = gw.wTransPoint LinkedObj.pos
                        gw.wPolyline #(thepos,mpos) true color:yellow  
                        appendIfUnique linkedObjs MyObj
                    )
                ) 
            )  
            gw.enlargeUpdateRect #whole
            gw.updateScreen()
            gw.setColor #line white
        )
    
    )
)

sptRender = SPT_Render()
unregisterredrawviewscallback sptRender.DrawLinks
registerredrawviewscallback sptRender.DrawLinks

struct SPT_Render
(
    iMaxConnects = 512,
    isDrawLinks = true,
    relevantobjs = #(),
    function GetObjects = 
    (
        relevantobjs = #()
        for obj in  objects where obj.isHiddenInVpt == false do 
        (
            append relevantobjs obj
        )
    ),

    function DeleteANode = 
    (
        Node =  callbacks.notificationParam() 
        id = findItem relevantobjs Node
        if id > 0 do 
        (
           deleteItem relevantobjs id
        )
    ),

    function AddANode = 
    (
        Node =  callbacks.notificationParam() 
        id = findItem relevantobjs Node
        if id < 1 and (classof Node) == GTA_VehiclePathNode do 
        (
           append relevantobjs Node
        )
    ),

    function DrawLinks = 
    (
        if isDrawLinks do 
        (
            gw.setTransform (Matrix3 1)
            local linkedObjs = #();
            gw.setColor #line green
			mynewlist = #()
            --VpWidth = (gw.getWinSizeX())
            --VpHeight = (gw.getWinSizeY())
            iconnects = 0;
          
            for obj in relevantobjs  do 
            (
                if iconnects < iMaxConnects do 
                (
                    gw.setTransform (Matrix3 1)
                    posi = gw.TransPoint obj.pos
                    if posi.x < (gw.getWinSizeX())  and  posi.x > 0 and posi.y < (gw.getWinSizeY()) and posi.y > 0 then 
                    (
                        iconnects = iconnects +1 
                        --append mynewlist obj
                        MyObj = obj
                        for LinkInfo in MyObj.LinkList do 
                        ( 
                            if (findItem linkedObjs LinkInfo.Node) == false and isValidNode LinkInfo.Node do 
                            (
                                thepos  = gw.wTransPoint MyObj.pos
                                mpos = gw.wTransPoint LinkInfo.Node.pos
                                  --gw.setColor #line green
                                  if LinkInfo.isRoadcross == true then 
                                     gw.wPolyline #(thepos,mpos) true rgb:#(yellow,yellow) 
                                  else if LinkInfo.isPedTrafficLight == true then 
                                     gw.wPolyline #(thepos,mpos) true rgb:#(orange ,orange ) 
                                  else 
                                     gw.wPolyline #(thepos,mpos) true rgb:#(blue,blue) 
                                
                                append linkedObjs MyObj
                            )
                        )   
                    ) 
                )      
            )
            --gw.enlargeUpdateRect #whole
            --gw.updateScreen()
            gw.setColor #line white
        )
    )
)

sptRender = SPT_Render()
callbacks.addScript #nodeCreated  sptRender.AddANode id:#mything1
callbacks.addScript #nodePreDelete sptRender.DeleteANode  id:#mything1
callbacks.addScript #nodeHide  sptRender.DeleteANode id:#mything1
callbacks.addScript #nodeUnhide sptRender.AddANode  id:#mything1
unregisterredrawviewscallback sptRender.DrawLinks
registerredrawviewscallback sptRender.DrawLinks

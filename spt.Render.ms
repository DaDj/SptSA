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
        if id < 1 and (classof Node) == GTA_PathNode do 
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
            VpWidth = (gw.getWinSizeX())
            VpHeight = (gw.getWinSizeY())
            iconnects = 0;
          
            for iObj = 1 to relevantobjs.count  do 
            (
                if iconnects < iMaxConnects do 
                (
                    obj = relevantobjs[iObj]
                    gw.setTransform (Matrix3 1)
                    posi = gw.TransPoint obj.pos
         
                    if posi.x < VpWidth  and  posi.x > 0 and posi.y < VpHeight and posi.y > 0 then 
                    (
                        iconnects = iconnects +1 
                        --append mynewlist obj
                        MyObj = obj
                        for LinkedObj in MyObj.LinkList do 
                        ( 
                            if (findItem linkedObjs LinkedObj) == false and isValidNode LinkedObj do 
                            (
                                thepos  = gw.wTransPoint MyObj.pos
                                mpos = gw.wTransPoint LinkedObj.pos
                                gw.wPolyline #(thepos,mpos) true color:yellow  
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

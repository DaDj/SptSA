--global spt_nodes_specialList = 

struct LinkInfo
(
	Node,
	NaviNode,
	isRoadcross = 0,
	isPedTrafficLight = 0
)


plugin helper GTA_VehiclePathNode
name:"SA Vehicle PathNode"
classID:#(0x4683fc7, 0x2854d855)
extends:Point 
category:"GTA Path"
replaceUI:true
(
	local LinkList = #()
	local selfnode

	fn SetLink obj = 
	(
	
		if (obj != undefined and classof obj == GTA_VehiclePathNode) then 
		(
			selfnode = (refs.dependentnodes this)[1]
			islinked = false
			for alinked in LinkList do 
			(
				if alinked.Node == obj do islinked == true
			)

			if  islinked == false do 
			(
				appendIfUnique LinkList (LinkInfo Node:obj NaviNode:undefined)
				appendIfUnique obj.LinkList (LinkInfo Node:selfnode NaviNode:undefined)
				--obj.SetLink selfnode
			)
		)
	)

	fn Delink obj = 
	(
		if (obj != undefined and classof obj == GTA_VehiclePathNode) then 
		(
			selfnode = (refs.dependentnodes this)[1]
			islinked = false
			for alinked in LinkList do 
			(
				if alinked.Node == obj do 
				(
					islinked == true
					idx = findItem LinkList alinked
					if idx do 
					(
						deleteItem LinkList idx 
						obj.Delink selfnode
					)
				)
			)
		)
	)

	parameters main rollout:params
	(
		LinkID  type:#integer default:0 
		AreaID	type:#integer default:0 ui:Area
		NodeID	type:#integer default:0 ui:Node
		PathWidth	type:#float default:0 ui:PathWidth
		FloodFill	type:#integer default:0 ui:floodfill
		DoConnecttoPrev type:#integer default:1 ui:btnLinkToPrev
	)
	rollout params "Triggerpoint Parameters"
	(
		checkbutton btnLinkToPrev "Link to Previous" checked:true width:150 height:25 align:#right tooltip:"Link Node to previous on Creation"

	
		Spinner Area "Area id: " type:#integer enabled:false fieldwidth:50 
		Spinner Node "Node id: " type:#integer enabled:false fieldwidth:50 
		Spinner floodfill "Flood Fill"  type:#integer range:[1,255, 1] fieldwidth:50 

		label nolbl ""
 
		Spinner PathWidth "Path Width"  type:#float range:[1,100, 1] fieldwidth:50 
		spinner db_spawn "Spawn Rate:"  range:[0.0, 1.0, 1] value:1.0   fieldwidth:50 tooltip:"Chance to spawn.\nZero doesn't mean no spawns, just less spawns"
		
		
		checkbox isOndeadEnd "Is DeadEnd"  checked:false enabled:false    
		checkbox isOff"Is Off" tooltip: "Only used by peds and emergency when off" checked:false
		checkbox isRoadBlock "Is RoadBlock"  checked:false
		checkbox isBoat "Is Boat"  checked:false enabled:false
		checkbox isEmergency "Is Emergency"  checked:false enabled:false
		checkbox isHighway "Is Highway"  checked:false
		dropdownlist dd_splist "Special" selection:1 align:#center enabled:true tooltip:"Special Behaviour for the Node" \
		items:#("1 - PARKING_PARALLEL", "2 - PARKING_PERPENDICULAR", "3 - VALET", "4 - NIGHTCLUB", "5 - DELIVERIES", "6 - VALET_UNLOAD", \
		"7 - NIGHTCLUB_UNLOAD", "8 - DRIVE_THROUGH", "9 - DRIVE_THROUGH_WINDOW", "10 - DELIVERIES_UNLOAD")

		button btnLink "Link to:" width:100
		button btnDelink "De Link from:" width:100

		on btnLink pressed do 
		(
			obj = pickObject count:1 rubberBand:selection[1].pos prompt:"Select a node" 
			SetLink obj
		)

		on btnDelink pressed do 
		(
			obj = pickObject count:1 rubberBand:selection[1].pos prompt:"Select a node" 
			Delink obj
		)
		

	)

	fn getSize= (return 14)


	
	tool create
	(
		on start do 
		(
			selfnode = (refs.dependentnodes this)[1]

			if DoConnecttoPrev == 1 and (objects as array).count > 1 then 
			(
				LinkList = #()
				thecount = (objects as array).count
				LastObj =	 (objects as array)[thecount-1]
				if LastObj != undefined do SetLink LastObj
			)
			else 
			(
				LinkList = #()
			)
		)

		on deleted do
		(
			for MyLink in LinkList do 
			(
				Delink MyLink.Node
			)

		)
	
		on mousePoint click do
		(
					--delegate.boxsize.x = 1
					--delegate.boxsize.y = 1
					--delegate.boxsize.z = 1
					--delegate.size = thing
	
			case click of (
				1: (
				nodeTM.translation = gridPoint
				nodeTM.pos = nodeTM.pos + 0.01
				#stop
				)
				2: (
				#stop
				)
			)	
		)

		on mouseMove click do (
			case click of (
				2: (

					thing = amax #(abs(gridDist.x), abs(gridDist.y))
					--delegate.boxsize.x = thing
				--	delegate.boxsize.y = thing
					delegate.boxsize.z = thing
					delegate.size = thing
				)
				3: (
					--delegate.height = gridDist.z
				)
			)
		)
	)
)


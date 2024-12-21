
things = #()
icount = 1
old  = undefined
for i = 1 to 100 do 
(
	for i2 = 1 to 200 do 
	(
		things[icount] = GTA_PathNode()
		things[icount].pos = [i*25,i2*25,0]
		things[icount].delegate.size = 8
		things[icount].SetLink old
		old = things[icount] 
		icount = icount +1
	)
)

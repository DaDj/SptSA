global MySPTRoot = pathConfig.removePathLeaf ( getSourceFileName()) ;

fn SPTStartupLoadALL MyRoot = 
(
    local files = #()
    files =  getfiles (MyRoot + "\\*.ms")
    files = deleteItem files  (finditem files (getSourceFileName())) -- dont laod startup ms again



	local dirs = getDirectories ( ( trimright MyRoot "\\" ) + "\\*" )
	for d in dirs do join dirs ( getDirectories ( ( trimright d "\\" ) + "\\*" ) )

	for d in dirs where not ( matchpattern d pattern:"*_old*" ) do join files ( getFiles ( ( trimright d "\\" ) + "\\*.ms" ) )



	for f in files do 
    (	
	 try 
	 (
		if getFilenameFile f != "TestPaths" do 
		(
			fileIn f
			format "loaded script '%'\n" f
		) 
	 )	
	 catch
	 (
		format "failed loading script '%'\n" f
	 )
	)
)

SPTStartupLoadALL MySPTRoot
SPTStartupLoadALL MySPTRoot
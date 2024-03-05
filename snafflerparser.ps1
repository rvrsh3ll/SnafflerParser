<#
	.Synopsis
	Snaffler output file parser
	.Description
	Split, sort and beautify the Snaffler output.
	Adds explorer++ integration for easy file and share browsing (runas /netonly support)
	.Parameter outformat
	Output options: 
	-all : write txt, csv, html and json
	-txt : write txt (default)
	-csv : write csv
	-json : write json
	-html : write html
	.Parameter in
	Input file (Fullpath or Filename)
	Defaults to snafflerout.txt
	.Parameter sort
	Field to sort output:
	- modified:File modified date (default)
	- keyword: Snaffler keyword
	- unc: File UNC Path
	- reason: Reason why Snaffler flagged the file
	.Parameter split
	Will create splitted (by severity blac, red, yellow ,green) exports
	.Parameter gridview
	Analyze the file and display in gridview
	.Parameter gridviewload
	Switch to load an existing gridview output (CSV)
	.Parameter gridin
	Input file (Full path or Filename)
	Defaults to snafflerout.txt_files_gridview.csv
	.Parameter pte
	pte (paths to explorer) exports the shares to Explorer++ as bookmarks (grouped by host)
	Explorer++ must be configured to be in Portable mode (settings saved in xml file) and that only one instance is allowed.
	.Parameter snaffel
	Run Snaffler and execute parser with default settings.
	.Example
	.\snafflerparser.ps1 
	(will try to load snafflerout.txt and output in TXT format)
	.Example
	.\snafflerparser.ps1 -in mysnaffleroutput.tvs
	(will try to load mysnaffleroutput.tvs and output in TXT format)
	.Example
	.\snafflerparser.ps1 -out csv -split
	(will store results as CSV and split the files by severity)
	.Example
	.\snafflerparser.ps1 -sort unc
	(will sort by the column unc)
	.Example
	.\snafflerparser.ps1 -gridview
	(Will  additionally show the output in PS Gridview and save the gridview for later use)
	.Example
	.\snafflerparser.ps1 -gridviewload
	(Load a existing gridview (defaults to snafflerout.txt_files_gridview.csv))
	.Example
	.\snafflerparser.ps1 -gridviewload -gridin mygridviewfile.csv
	(Load specific gridview file)
	.Example
	.\snafflerparser.ps1 -pte
	(Add Shares as Bookmarks to explorer++)

	.LINK
	https://github.com/zh54321/ADScout
#>
Param (
	[String[]]
	$in = 'snafflerout.txt',
	[ValidateSet("modified", "keyword", "reason", "unc")]
	[String[]]
	$sort = "modified",
	[ValidateSet("all", "csv", "txt", "json","html")]
	[String[]]
	$outformat = "txt",
	[switch]
	$gridview,
	[switch]
	$gridviewload,
	[switch]
	$split,
	[String[]]
	$gridin = 'snafflerout.txt_files_gridview.csv',
	[String[]]
	$exlorerpp = '.\Explorerpp.exe',
	[switch]
	$pte,
	[switch]
	$snaffel,
	[switch]
	$help
)

# Function section-----------------------------------------------------------------------------------
function gridview($action){
	if ($action -eq "load") {
		write-host "[*] Loading stored Gridview file: $($gridin)"
		if (!(Test-Path -Path $in -PathType Leaf)) {
			write-host "[-] Input file not found $($gridin) use -gridin to specify the file csv"
			exit
		}
		write-host "[*] Starting Gridview (opens in background)"
		$passthruobjec = Import-Csv -Path "$($gridin)" |  Out-GridView -Title "FullView" -PassThru

	} elseif ($action -eq "start") {
		write-host "[*] Writing Gridview output file for further use"
		$fulloutput | Export-Csv -Path "$($outputname)_files_gridview.csv" -NoTypeInformation
		write-host "[*] Starting Gridview (opens in background)"
		$passthruobjec = $fulloutput |  Out-GridView -Title "FullView" -PassThru
	}
	$countpassthruobjec = $passthruobjec | Measure-Object -Line -Property unc
	if ($countpassthruobjec.lines -ge 1) {
		if (!(Test-Path -Path $exlorerpp -PathType Leaf)) {
			write-host "[-] Explorer++ not found at $exlorerpp use -explorerpp to specify the exe file"
			exit
		} else {
			write-host "[-] Explorer++ found at $exlorerpp"
			write-host "[*] Found $($countpassthruobjec.lines) object. Trying to open them in explorer++"
			write-host "[i] Start the script in console window runas ... /netonly to access the files as different user"
			write-host "[i] Disables the 'Allow multiple instance' in Explorer++ to open multiple location in tabs "
			foreach ($path in $passthruobjec.unc) {
				$pathtoopen = (Split-Path -Path $path -Parent)
				# Danger danger Invoke-Expression
				Invoke-Expression "$exlorerpp $pathtoopen"
				Start-Sleep -Milliseconds 500
			}
		}
	} else {
		write-host "[!] No PassThru object found"
	}
	write-host "[*] Exiting..."
	exit
}

function explorerpp($objects){

	$explorerppfolder = Split-Path $exlorerpp
	if (Test-Path "$explorerppfolder\config.xml") {
		#Read XML
		$xmlfile = [XML](Get-Content "$explorerppfolder\config.xml")


		#Delete existing bookmarks
		write-host "[*] Delete existing bookmarks."
		$todelete = $xmlfile.SelectNodes("//Bookmark[@Type='1']")
		foreach($node in $todelete) {
			$node.ParentNode.RemoveChild($node)| Out-Null
			
		}
		#Delete existing bookmarks folders
		$todelete = $xmlfile.SelectNodes("//Bookmark[@Type='0']")
		foreach($node in $todelete) {
			$node.ParentNode.RemoveChild($node)| Out-Null
		}
		
		#Coutners for stats and XML Object IDs
		$counteruncstats = 0
		$counterunc = 0
		$counterhosts = 0

		#Go trough all objects to great booksmarks folder and bookmark entry
		foreach ($element in $objects.unc) {

			# Isolate Server
			$element -match '\\\\(.*?)\\' | Out-Null
			$server= $Matches[1]

			if(!($xmlfile.SelectSingleNode("//Bookmark[@ItemName='$server']"))){
				#Create folder
				$newbookmarkelement = $xmlfile.CreateElement("Bookmark")
				$locationfolder = $xmlfile.ExplorerPlusPlus.Bookmarksv2.PermanentItem | where {$_.name -eq 'BookmarksToolbar'}
				$newbookmarkelementadd = $locationfolder.AppendChild($newbookmarkelement)
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("name",$counterhosts)
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("Type","0")
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("GUID",([guid]::NewGuid().ToString()))
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("ItemName",$server)
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateCreatedLow","3561811627")
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateCreatedHigh","3561811627")
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateModifiedLow","3561811627")
				$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateModifiedHigh","3561811627")
				$counterunc = 0
				$counterhosts++
			}

			#Add new bookmarks to the folder
			$newbookmarkelement = $xmlfile.CreateElement("Bookmark")
			$location = $xmlfile.SelectSingleNode("//Bookmark[@ItemName='$server']")
			$newbookmarkelementadd = $location.AppendChild($newbookmarkelement)
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("name",$counterunc)
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("Type","1")
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("GUID",([guid]::NewGuid().ToString()))
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("ItemName",$element)
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("Location",$element)
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateCreatedLow","3561811627")
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateCreatedHigh","3561811627")
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateModifiedLow","3561811627")
			$newbookmarkattribute = $newbookmarkelementadd.SetAttribute("DateModifiedHigh","3561811627")
			$counterunc++
			$counteruncstats++
		}
		
		#Handle local folder because xml.save can't...
		if ($explorerppfolder -eq ".") {
			$xmlfile.Save("$pwd\config.xml")
		} else {
			$xmlfile.Save("$explorerppfolder\config.xml")
		}
		
		write-host "[+] Added $($counterhosts) bookmark-folders with $($counteruncstats) bookmarks"
	
	} else {
		write-host "[!] Aborting: Explorer++ config file not found at $explorerppfolder\config.xml !"
		write-host "[?] Is Explorer++ configured in portable mode (XML file should exist)?"
		exit
	}
	
}

# Function to export as CSV
function exportcsv($object ,$name){
	write-host "[*] Store: $($outputname)_files_$($name).csv"
	$object| Export-Csv -Path "$($outputname)_files_$($name).csv" -NoTypeInformation
}

# Function to export as TXT
function exporttxt($object ,$name){
	write-host "[*] Store: $($outputname)_files_$($name).txt"
	$object | Format-Table -AutoSize | Out-String -Width 10000 | Out-File -FilePath "$($outputname)_files_$($name).txt"
}

# Function to export as JSON
function exportjson($object ,$name){
	write-host "[*] Store: $($outputname)_files_$($name).json"
	$object | ConvertTo-Json -depth 100  | Out-File -FilePath "$($outputname)_files_$($name).json"
}

# Function to export as HTML
function exporthtml($object ,$name){
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>

"@
	write-host "[*] Store: $($outputname)_files_$($name).html"
	$object | ConvertTo-Html -Title "Snaffler $outputname" -Head $Header  | Out-File -FilePath "$($outputname)_files_$($name).html" -Encoding asci
}



# Script section-----------------------------------------------------------------------------------


# Check if snaffler should be executed
if ($help) {
	get-help $MyInvocation.MyCommand.Definition -full
	exit
}

if ($snaffel) {
	.\Snaffler.exe -o snafflerout.txt -s -y
}

# Check if gridviewfile should be loaded
if ($gridviewload) {
	gridview load
}

# Check snaffler input file and load it
write-host "[*] Check input file $in"
if (!(Test-Path -Path $in -PathType Leaf)) {
	write-host "[-] Input file not found $in"
	exit
} else {
	write-host "[+] Input file exists"
	$inputlines = (Get-Content $in).Length
	if ($inputlines -ge 1) {
		write-host "[+] Input file has $inputlines Lines"
		$data = Import-Csv -Delimiter "`t" -Path $in -Header user, timestamp , typ, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
		$outputname = Split-Path -Path $in -Leaf
	} else {
		write-host "[!] Input file seems to be empty"
		exit
	}

}

# Processing shares
$shares = foreach ($line in $data) {
    if($line.Typ -eq "[Share]") {
		[PsCustomObject]@{
			unc = $line.2
		}
    }
}

#Sort and perform dedup (in snaffler was runned twice)
$shares = $shares | Sort-Object -Property unc -Unique

# Check share count and write to file
$sharescount = $shares | Measure-Object -Line -Property unc
if ($sharescount.lines -ge 1) {
	write-host "[+] Shares identfied: $($sharescount.lines)"
	write-host "[*] Write share output file"
	$shares | Format-Table -AutoSize | Out-File -FilePath "$($outputname)_shares.txt"
} else {
	write-host "[!] Shares identfied: $($sharescount.lines)"
	write-host "[?] Was Snaffler executed with parameter -y ?"
}


# Processing files
write-host "[*] Processing files"
$files = foreach ($line in $data) {
    if($line.Typ -eq "[File]") {
		[PsCustomObject]@{
			severity = $line.1
			reason = $line.2
			keyword = $line.6
			modified = $line.8
			unc = $line.9
			content = $line.10
		}
    }
}

## ugly hack to default to descending sort, maybe fix
if ($sort -eq "modified") {

	$blacks = $files | where-object severity -EQ "Black" | sort-object -Property $sort -Descending
	$reds = $files | where-object severity -EQ "Red" | sort-object -Property $sort -Descending
	$yellows = $files | where-object severity -EQ "Yellow" | sort-object -Property $sort -Descending
	$greens = $files | where-object severity -EQ "Green" | sort-object -Property $sort -Descending
	$fulloutput = ForEach ($Result in "Black", "Red", "Yellow", "Green") {
		$files | Where-Object {$_.Severity -eq $Result } | sort-object -Property $sort -Descending
	}

} else {
	$blacks = $files | where-object severity -EQ "Black" | sort-object -Property $sort
	$reds = $files | where-object severity -EQ "Red" | sort-object -Property $sort
	$yellows = $files | where-object severity -EQ "Yellow" | sort-object -Property $sort
	$greens = $files | where-object severity -EQ "Green" | sort-object -Property $sort
	$fulloutput = ForEach ($Result in "Black", "Red", "Yellow", "Green") {
		$files | Where-Object {$_.Severity -eq $Result } | sort-object -Property $sort
	}
}

# Check file count for error detection and output
if ($blacks -ne $null) {$blackscount = $blacks | Measure-Object -Line -Property unc | select-object -ExpandProperty Lines} else {$blackscount = 0}
if ($reds -ne $null) {$redscount  = $reds | Measure-Object -Line -Property unc | select-object -ExpandProperty Lines} else {$redscount = 0}
if ($yellows -ne $null) {$yellowscount = $yellows | Measure-Object -Line -Property unc | select-object -ExpandProperty Lines} else {$yellowscount = 0}
if ($greens -ne $null) {$greenscount = $greens | Measure-Object -Line -Property unc | select-object -ExpandProperty Lines} else {$greenscount = 0}

$filesum = $blackscount + $redscount + $yellowscount + $greenscount
if ($filesum -ge 1) {
	write-host "[+] Files total: $filesum "
	write-host "[+] Files with severity black: $blackscount"
	write-host "[+] Files with severity red: $redscount"
	write-host "[+] Files with severity yellow: $yellowscount"
	write-host "[+] Files with severity green: $greenscount"

	#Write outputs depening on desired format
	if ($outformat -eq "all"){
		write-host "[*] Exporting full CSV + TXT + JSON"
		exporttxt $fulloutput full
		exportcsv $fulloutput full
		exportjson $fulloutput full
		exporthtml $fulloutput full
		if ($split) {
			write-host "[*] Exporting splitted CSV + TXT"
			if ($blackscount -ge 1) {exportcsv $blacks blacks}
			if ($redscount -ge 1) {exportcsv $reds reds}
			if ($yellowscount -ge 1) {exportcsv $yellows yellows}
			if ($greenscount -ge 1) {exportcsv $greens greens}
			if ($blackscount -ge 1) {exporttxt $blacks blacks}
			if ($redscount -ge 1) {exporttxt $reds reds}
			if ($yellowscount -ge 1) {exporttxt $yellows yellows}
			if ($greenscount -ge 1) {exporttxt $greens greens}
			if ($blackscount -ge 1) {exportjson $blacks blacks}
			if ($redscount -ge 1) {exportjson $reds reds}
			if ($yellowscount -ge 1) {exportjson $yellows yellows}
			if ($greenscount -ge 1) {exportjson $greens greens}
			if ($blackscount -ge 1) {exporthtml $blacks blacks}
			if ($redscount -ge 1) {exporthtml $reds reds}
			if ($yellowscount -ge 1) {exporthtml $yellows yellows}
			if ($greenscount -ge 1) {exporthtml $greens greens}
			
		}
	} elseif ($outformat -eq "txt") {
		write-host "[*] Exporting full TXT"
		exporttxt $fulloutput full

		if ($split) {
			write-host "[*] Exporting splitted TXT"
			if ($blackscount -ge 1) {exporttxt $blacks blacks}
			if ($redscount -ge 1) {exporttxt $reds reds}
			if ($yellowscount -ge 1) {exporttxt $yellows yellows}
			if ($greenscount -ge 1) {exporttxt $greens greens}
		}
	} elseif ($outformat -eq "csv") {
		write-host "[*] Exporting full CSV"
		exportcsv $fulloutput full
		if ($split) {
			write-host "[*] Exporting splitted CSV"
			if ($blackscount -ge 1) {exportcsv $blacks blacks}
			if ($redscount -ge 1) {exportcsv $reds reds}
			if ($yellowscount -ge 1) {exportcsv $yellows yellows}
			if ($greenscount -ge 1) {exportcsv $greens greens}
		}
	} elseif ($outformat -eq "json") {
		write-host "[*] Exporting full JSON"
		exportjson $fulloutput full
		if ($split) {
			write-host "[*] Exporting splitted JSON"
			if ($blackscount -ge 1) {exportjson $blacks blacks}
			if ($redscount -ge 1) {exportjson $reds reds}
			if ($yellowscount -ge 1) {exportjson $yellows yellows}
			if ($greenscount -ge 1) {exportjson $greens greens}
		}
	} elseif ($outformat -eq "html") {
		write-host "[*] Exporting full HTML"
		exporthtml $fulloutput full
		if ($split) {
			write-host "[*] Exporting splitted HTML"
			if ($blackscount -ge 1) {exporthtml $blacks blacks}
			if ($redscount -ge 1) {exporthtml $reds reds}
			if ($yellowscount -ge 1) {exporthtml $yellows yellows}
			if ($greenscount -ge 1) {exporthtml $greens greens}
		}
	}
} else {
	# Error handling if no files detected
	write-host "[!] Something is wrong. Number of files identified: $filesum"
	write-host "[?] Was Snaffler executed with parameter -y ?"
	exit
}

# Start grid view if desired
if ($gridview) {
	gridview start
}

# Check if shares should be exported as bookmarks to Explorer++
if ($pte) {
	write-host "[*] Will export $($sharescount.lines) shares to explorer."
	explorerpp($shares)
		
}
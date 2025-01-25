# Snaffler Output File Parser
Especially in large environments, the Snaffler output gets very large and time-consuming to analyze.

This script parse the Snaffler output file (TSV format required) and:
- Beautify it: Proper tables and different output formats like TXT, CSV, HTML, JSON or PS Gridview.
- The HTML output file:
    - Supports basic sorting and filtering (severity & extension)
    - Highlights the finding keyword in the file preview text
    - Contains direct links to the parent folder of the file and a download link for the file itself.
    - Contains basing information about the Snaffler job.
    - Support with the review workflow by let you mark reviewed or interesting items.
    - Can unescape the preview text to make it more readable.
- Sorts based on the severity (black, red, yellow, green) and then by date or unc.
- Can export all the shares to the Explorer++ config files as bookmarks.
- Generate a list of all shares Snaffler was able to access (might be useful for your client).

# Show Case
Parsing output file:

![Console Output](/images/parser_console.png "Console Output")

HTML output:
![HTML Output](/images/HTML_output.png "HTML Output")

TXT output:
![TXT Output](/images/TXT_output.png "TXT Output")

# Preconditions and Usage
Snaffler must be executed with the `-y` switch in order to create an output file in the TSV format.

Example:
`.\Snaffler.exe -o snafflerout.txt -s -y`

## Simple Parse
Simple parse the file my_snaffler_output.txt and write output with default sorting (severity, date modified) and default output files (TXT, CSV, HTML).
`.\snafflerparser.ps1 -in my_snaffler_output.txt`

## Output Options
The different file output options are:
- `-outformat all` Write txt, csv, html and json (default)
- `-outformat txt` Write txt
- `-outformat csv` Write csv
- `-outformat html` Write html
- `-outformat json` Write json

Those files can be splitted regarding the finding severity (black, red, yellow, green) using the `-split` switch.

Additonally a PS gridview output can be showed using ``-gridview`.

## HTML Report

### Dark Mode and Light Mode
Dark mode is no default.

Use `-lightmode` to switch back to the light mode HTML report.

### Custom Checkboxes for the Review Process
There are now 2 custom checkboxes:
- check : Mark interesting files to check later.
- done  : Mark files you have checked

By clicking on a checkbox, you can use the W, S, A, D keys or the arrow keys to navigate through the checkboxes within the columns, and press the spacebar to toggle them. This allows you to efficiently navigate and mark items in the list without using the mouse.

Use the filter buttons above to hide files you have checked, or to only display interesting files.

![custom checkboxes](/images/custom_checkboxes.gif "Custom checkboxes")

Important: to save the current markings you have to click on the 'Save HTML' which will download a copy of the file including your checkbox selection.

### Unescaping (experimental)
Snaffler escapes line breaks etc. in the preview content to display it in the command line.
SnafflerParser can unescape the preview text to make the code better readable in HTML or PS GridView.

Simply use the switch `-unescape`

Example:

![Unescape example](/images/unescape.png "Unescape example")

Note: Makes the rows larger.

## Sorting
The output will always be sorted regarding the severity than it can be sorted by:
- `-sort modified` File modified date (default)
- `-sort keyword` Snaffler keyword
- `-sort unc` File UNC Path
- `-sort rule` Snaffler rule name

## Explorer++ Integration

Explorer++ is an alternative file explorer on windows.


The great thing is that unlike the Windows Explorer it can be executed in another user's context including the `/netonly` switch. This is useful when performing a pentest from a dedicated, non-domain joined pentest notebook or VM.

Donwload Explorer++ https://github.com/derceg/explorerplusplus to the same folder and configure the portable mode:

![Configure Explorer++ in portable mode](/images/explorerpp_settings.png "Configure portable mode")

This will create an config.xml in the same folder.

Parse the Snaffler file using the `-pte` switch to export all accessible shares as bookmarks to the Explorer++ config XML: `.\snafflerParser.ps1 -in Snaffler_output.txt -pte`

Explorer++ can then be executed as the user which have access to the shares: `runas /user:domain\user /netonly Explorerpp.exe`
This allows easy access to the shares without authenticate for every share via the bookmark bar:

![Explorer++ Bookmarks](/images/explorerpp_bookmarks.png "Explorer++ Bookmarks")


## Changelog

### 2025-01-25

#### Improved
- Slightly improved performance
- Adjusted status messages

### 2025-01-21

#### New
- Custom checkboxes to support with the review process (feature request #3)
- Experimental unescape feature
- Dark mode

#### Improved
- General improvements HTML report


### 2025-01-17

#### Fixed
- Issue #2: Fixed: Spaces breaking in the open or download links
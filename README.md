# GitRelease
The Release.cmd batch script builds Visual Studio dotnet solution in multiple platforms, updates the Git repository, and creates a Github package. It performs this action from the remote desktop computer, and not server-side.

## Description
This script performs the below steps. See next sections for command line options and requirements.
- Builds the solution
  - Builds multiple platforms (Windows, Linux, MAC)
  - Sets Major version, Minor version, Build version and Revision version. (major.minor.build.revision [1.33.2022.123])
    - Sets major version with value in file release_variables.txt
    - Sets minor version with an incremented value. 
      - Gets previous minor version from file {release_variables.txt}, increments it, and saves it back to the file.
    - Sets the build version and revision version with the current date. 
      - The year is set for the build value, and julian date is set for the revision value.
	 Example: [1.6.2023.123] Where 1 is major version, 6 is 
  - Sets the identifier as the to the incremented minor version value.
    - The identifier helps when updating a program. It helps the installer to determine if the new install is newer than the current installation.
  - Sets release name by getting the value from release_variables.txt
- Compresses windows files to zip, and all others to tgz
- Updates Github Repository if steps 1 & 2 completed successfully
- Creates a new Github release using the version

## Command Line Options
- NoRepoUpdate
  - The repository is NOT updated
- NoBld
  - The projects do NOT get built, and the minor version is not incremented.
  - Uses the last build version.
- NoCompress
  - Skips compressing packaged files.
- NoGitRel
  - Does NOT create a new Github release, and does NOT upload packages
- NoIncVer
  - Does NOT increment minor version, and uses last version from previous build.
- RelNotes
  - Release notes used to create Git release package. Argument should have double quotes.
  - Can include batch variables: %ReleaseName%, %MajorVersion%, %MinorVersion%, %DotNetVer%, %ReleaseTitle%, %Identifier%, %ProgramVersion%, %ReleaseTag%, %YEAR%, %MONTH%, %DAY%
  - Example: Release.cmd RelNotes "%ReleaseName% Version %MajorVersion%.%MinorVersion% build date=%YEAR%-%MONTH%-%DAY%"
  - Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
- RelTitle
  - Release title used to create Git release package. Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
  - This option overrides the value in the release_variables.txt
  - Can include batch variables. See RelNotes.
  - Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
- TestRun
  - This option is the same as the combination of the following options:
  - This option overrides the value in the release_variables.txt
  - NoRepoUpdate & NoGitRel & NoIncVer
- TestVar
  - Only display variable values.
  - To avoid incrementing version, use this command in conjunction with NoIncVer. Example: Release.cmd TestVar NoIncVer

- Example Usage:
					Release.cmd TestRun
					Release.cmd NoRepoUpdate NoGitRel
					Release.cmd TestVar NoIncVer
					Release.cmd RelNotes "Beta Version %MinorVersion%" RelTitle MediaFileDuplicateFinderApp
					Release.cmd RelTitle "Latest of %ReleaseName% Version %MinorVersion%"
 
## Requirements
- Git installation: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
- Github CLI: https://github.com/cli/cli/releases
- dotnet and Visual Studio 2019, 2022, or higher
  - dotnet path must be in environmental %PATH%
  - If the solution has multiple projects, the project file "Base output path" settings should be set to $(SolutionDir)bin
  - This setting is normally needed because command line "-o" is no longer supported by dotnet.
- 7zip installed if 7z is not installed in path (C:\Program Files\7-Zip), change the value of variable Prg7Zip to correct path.
- Requires a file called release_variables.txt. See example file in this repository.
  - This file name can be changed by modifying variable ReleaseFileVariables.
  - The file contains release name, major version, minor version and dotnet target version.
  - It should be in the below format. See example release_variables.txt file in this repository.
  
				Enter solution release name below. Recommend using no spaces.
				MyApplicationProgramNameHere
				Enter desired major version number below. Value must be between 0-9999
				1
				Enter desired minor version number below. Value must be between 0-9999
				33
				Enter targeted dotnet version below.
				net7.0
				Enter release title which can use the following arguments:%ReleaseName%, %MajorVersion%, %MinorVersion%, %DotNetVer%, %ReleaseTitle%, %Identifier%, %ProgramVersion%, %ReleaseTag%, %YEAR%, %MONTH%, %DAY%
				%ReleaseName%
				Enter release notes which can use same arguments as release title.
				Version %MajorVersion%.%MinorVersion% build date=%YEAR%-%MONTH%-%DAY%

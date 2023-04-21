@echo off
setlocal ENABLEDELAYEDEXPANSION
:: ################################################################################################
:: Description: This script performs the below steps. See next sections for command line options and requirements.
:: 1. Builds the solution
::    A. Builds multiple platforms (Windows, Linux, MAC)
::    B. Sets Major version, Minor version, Build version and Revision version. (major.minor.build.revision [1.33.2022.123])
::       1) Sets major version with value in file release_variables.txt
::       2) Sets minor version with an incremented value. 
::          a) Gets previous minor version from file {release_variables.txt}, increments it, and saves it back to the file.
::       3) Sets the build version and revision version with the current date. 
::          a) The year is set for the build value, and julian date is set for the revision value.
::	 Example: [1.6.2023.123] Where 1 is major version, 6 is 
::    C. Sets the identifier as the to the incremented minor version value.
::       1) The identifier helps when updating a program. It helps the installer to determine if the new install is newer than the current installation.
::    D. Sets release name by getting the value from release_variables.txt
::    E. If a setup project (VdProj file) exist (%ReleaseName%_Setup\%ReleaseName%_Setup.vdproj)
::       1) Creates a copy of the VdProj file with the ProductVersion number updated to the new incremented value.
::       2) Builds the setup project
::       3) Moves and renames the MSI file so that the MSI file includes the version number and the file name is in the same format as the other compressed packages
::       4) Adds the MSI package to the list of files to be uploaded to the new Github release
:: 2. Compresses windows files to zip, and all others to tgz
:: 3. Updates Github Repository if steps 1 & 2 completed successfully
:: 4. Creates a new Github release using the version

:: ################################################################################################
:: Usage command line options
:: NoRepoUpdate
::					The repository is NOT updated
:: NoBld
::					The projects do NOT get built, and the minor version is not incremented.
::					Uses the last build version.
:: NoCompress
::					Skips compressing packaged files.
:: NoGitRel
::					Does NOT create a new Github release, and does NOT upload packages
:: NoIncVer
::					Does NOT increment minor version, and uses last version from previous build.
:: RelNotes
::					Release notes used to create Git release package. Argument should have double quotes.
::					This option overrides the value in the release_variables.txt
::					Can include batch variables: %ReleaseName%, %MajorVersion%, %MinorVersion%, %DotNetVer%, %ReleaseTitle%, %Identifier%, %ProgramVersion%, %ReleaseTag%, %YEAR%, %MONTH%, %DAY%
::					Example: GitRelease.cmd RelNotes "%ReleaseName% Version %MajorVersion%.%MinorVersion% build date=%YEAR%-%MONTH%-%DAY%"
::					Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
:: RelTitle
::					Release title used to create Git release package. Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
::					This option overrides the value in the release_variables.txt
::					Can include batch variables. See RelNotes.
::					Default is "%ReleaseName%_Ver%MajorVersion%.%MinorVersion%"
:: NoClean
::					Does NOT delete temporary files after processing
:: TestRun
::					This option is the same as the combination of the following options:
::					NoRepoUpdate & NoGitRel & NoIncVer & NoClean
:: TestVar
::					Only display variable values.
::					To avoid incrementing version, use this command in conjunction with NoIncVer. Example: GitRelease.cmd TestVar NoIncVer
::
:: Example Usage:
::					GitRelease.cmd TestRun
::					GitRelease.cmd NoRepoUpdate NoGitRel
::					GitRelease.cmd TestVar NoIncVer
::					GitRelease.cmd RelNotes "Beta Version %MinorVersion%" RelTitle MediaFileDuplicateFinderApp
::					GitRelease.cmd RelTitle "Latest of %ReleaseName% Version %MinorVersion%"
:: Requirements
:: Git installation: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
:: Github CLI: https://github.com/cli/cli/releases
:: dotnet and Visual Studio 2019, 2022, or higher
::		dotnet path must be in environmental %PATH%
::		If the solution has multiple projects, the project file "Base output path" settings should be set to $(SolutionDir)bin
::		This setting is normally needed because command line "-o" is no longer supported by dotnet.
:: 7zip installed if 7z is not installed in path (C:\Program Files\7-Zip), change the value of variable Prg7Zip to correct path.
:: Requires a file called release_variables.txt. See example file in this repository.
::		This file name can be changed by modifying variable ReleaseFileVariables.
::		The file contains release name, major version, minor version and dotnet target version.
::		It should be in the below format (excluding "::"). See example release_variables.txt file in this repository.
::				Enter solution release name below. Recommend using no spaces.
::				MyApplicationProgramNameHere
::				Enter desired major version number below. Value must be between 0-9999
::				1
::				Enter desired minor version number below. Value must be between 0-9999
::				33
::				Enter targeted dotnet version below.
::				net7.0
::				Enter release title which can use the following arguments:%ReleaseName%, %MajorVersion%, %MinorVersion%, %DotNetVer%, %ReleaseTitle%, %Identifier%, %ProgramVersion%, %ReleaseTag%, %YEAR%, %MONTH%, %DAY%
::				%ReleaseName%
::				Enter release notes which can use same arguments as release title.
::				Version %MajorVersion%.%MinorVersion% build date=%YEAR%-%MONTH%-%DAY%
:: Setup Project
::		If the solution has an installer (Setup Project), this script will built it if it has the following format:
::		Project-File:	%ReleaseName%_Setup\%ReleaseName%_Setup.vdproj
::		Project-Output:	.\%ReleaseName%_Setup\Release\%ReleaseName%_Setup.msi

:: ################################################################################################
:: Step 1: Get command line variables
set IsTrue=true
set NoRepoUpdate=
set NoBld=
set NoCompress=
set NoGitRel=
set NoIncVer=
set NoClean=
set TestVar=
set RelNotes=
set RelTitle=
for %%a in (%*) do (
	if [%%a] == [NoRepoUpdate] (set NoRepoUpdate=%IsTrue%) else (
		if [%%a] == [NoBld] (
			set NoBld=%IsTrue%
			set NoIncVer=%IsTrue%
		) else (
			if [%%a] == [NoCompress] (set NoCompress=%IsTrue%) else (
				if [%%a] == [NoGitRel] (set NoGitRel=%IsTrue%) else (
					if [%%a] == [NoIncVer] (set NoIncVer=%IsTrue%) else (
						if [%%a] == [TestVar] (set TestVar=%IsTrue%) else (
							if [%%a] == [TestRun] (
								set NoRepoUpdate=%IsTrue%
								set NoGitRel=%IsTrue%
								set NoIncVer=%IsTrue%
								set NoClean=%IsTrue%
							) else (
								if [%%a] == [NoClean] (set NoClean=%IsTrue%) else (
									if [%%a] == [RelNotes] (set RelNotes=%IsTrue%) else (
										if [%%a] == [RelTitle] (set RelTitle=%IsTrue%) else (
											if [!RelNotes!] == [%IsTrue%] (call set "RelNotes=%%a") else (
												if [!RelTitle!] == [%IsTrue%] (set RelTitle=%%a)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)
)
echo NoRepoUpdate = "%NoRepoUpdate%"
echo NoBld = "%NoBld%"
echo NoCompress = "%NoCompress%"
echo NoGitRel = "%NoGitRel%"
echo NoIncVer = "%NoIncVer%"
echo NoClean = %NoClean%
echo TestVar = "%TestVar%"
echo RelTitle = %RelTitle%
echo RelNotes = %RelNotes%

:: ################################################################################################
:: Step 2: Setup variables
set Line__Separator1=#####################################################
set Line__Separator2=*****************************************************
set Line__Separator3=-----------------------------------------------------
set Line__Separator4=.....................................................
set ReleaseFileVariables=release_variables.txt
:: Note: Change the following line, if 7z is installed in a different path.
set Prg7Zip=C:\Program Files\7-Zip\7z
set Success=%IsTrue%
:: Get and set the julian date
for /F "tokens=2-4 delims=/ " %%a in ("%date%") do (
   set /A "MM=1%%a-100, DD=1%%b-100, Ymod4=%%c%%4"
)
for /F "tokens=%MM%" %%m in ("0 31 59 90 120 151 181 212 243 273 304 334") do set /A JulianDate=DD+%%m
if %Ymod4% equ 0 if %MM% gtr 2 set /A JulianDate+=1

:: Read variables from a file
set "_var=VarName1,ReleaseName,VarName2,MajorVersion,VarName3,MinorVersion,VarName4,DotNetVer,VarName5,ReleaseTitle,VarName6,ReleaseNotes"
(for %%i in (%_var%)do set/p %%~i=)<.\%ReleaseFileVariables%
set ReleaseName=%ReleaseName: =%
set MajorVersion=%MajorVersion: =%
set MinorVersion=%MinorVersion: =%
set DotNetVer=%DotNetVer: =%

if [%ReleaseName%] == [] (
	echo %Line__Separator1%
	echo Error: Exiting early because ReleaseName is empty. ReleaseName="%ReleaseName%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
if [%DotNetVer%] == [] (
	echo %Line__Separator1%
	echo Error: Exiting early because DotNetVer is empty. DotNetVer="%DotNetVer%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
if [%MajorVersion%] == [] (
	echo %Line__Separator1%
	echo Error: Exiting early because MajorVersion is empty. MajorVersion="%MajorVersion%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
if [%MinorVersion%] == [] (
	echo %Line__Separator1%
	echo Error: Exiting early because MinorVersion is empty. MinorVersion="%MinorVersion%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
if 1%MajorVersion% NEQ +1%MajorVersion% (
	echo %Line__Separator1%
	echo Error: Exiting early because MajorVersion is NOT numeric. MajorVersion="%MajorVersion%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
if 1%MinorVersion% NEQ +1%MinorVersion% (
	echo %Line__Separator1%
	echo Error: Exiting early because MinorVersion is NOT numeric. MinorVersion="%MinorVersion%".
	echo Check if file "%~dp0%ReleaseFileVariables%" is correctly formatted.
	echo %Line__Separator1%
	EXIT /B 0
)
:: If not incrementing skip following section
if [%NoIncVer%] == [%IsTrue%] (
	echo Skipping minor version increment
	goto :SkipIncVersion
)
echo Incrementing minor version
set /A MinorVersion+=1
echo %VarName1%>.\%ReleaseFileVariables%
echo %ReleaseName% >>.\%ReleaseFileVariables%
echo %VarName2%>>.\%ReleaseFileVariables%
echo %MajorVersion% >>.\%ReleaseFileVariables%
echo %VarName3%>>.\%ReleaseFileVariables%
echo %MinorVersion% >>.\%ReleaseFileVariables%
echo %VarName4%>>.\%ReleaseFileVariables%
echo %DotNetVer% >>.\%ReleaseFileVariables%
echo %VarName5%>>.\%ReleaseFileVariables%
echo %ReleaseTitle%>>.\%ReleaseFileVariables%
echo %VarName6%>>.\%ReleaseFileVariables%
echo %ReleaseNotes%>>.\%ReleaseFileVariables%
:SkipIncVersion

echo ReleaseName = "%ReleaseName%"
echo MajorVersion = "%MajorVersion%"
echo MinorVersion = "%MinorVersion%"
echo DotNetVer = "%DotNetVer%"
echo ReleaseTitle = "%ReleaseTitle%"
echo ReleaseNotes = "%ReleaseNotes%"

set PkgBaseDir=LocalPackageRepository
set PkgDir=%PkgBaseDir%\Ver%MajorVersion%-%MinorVersion%
set FileList=
set YEAR=%DATE:~-4%
set MONTH=%DATE:~4,2%
set DAY=%DATE:~7,2%
set Identifier=%MajorVersion%.%MinorVersion%
set ProgramVersion=%MajorVersion%.%MinorVersion%.%YEAR%.%JulianDate%
if [%RelTitle%] NEQ [] (set ReleaseTitle=%RelTitle%)
if [%RelNotes%] NEQ [] (set ReleaseNotes=%RelNotes%)
for /f "delims== tokens=1,2" %%a in ('set') do ( set ReleaseTitle=!ReleaseTitle:%%%%a%%=%%b! )
for /f "delims== tokens=1,2" %%a in ('set') do ( set ReleaseNotes=!ReleaseNotes:%%%%a%%=%%b! )
set ReleaseTitle=%ReleaseTitle:"=%
set ReleaseNotes=%ReleaseNotes:"=%
set ReleaseTitle="%ReleaseTitle%"
set ReleaseNotes="%ReleaseNotes%"
set ReleaseTag="%PkgPrefix%Ver%MajorVersion%.%MinorVersion%"
set PkgPrefix=%ReleaseName%_
set PkgPostfix=_Ver%MajorVersion%.%MinorVersion%
set SetupProjectFile_VdProj=%ReleaseName%_Setup\%ReleaseName%_Setup.vdproj
set SetupProjectFile_VdProj_Temp=%SetupProjectFile_VdProj%_temp.vdproj
set ProductVersionStrToFind=ProductVersion
:: Excluding 4th number from the product version, because VdProj do not allow Revision number in the ProductVersion
set NewProductVersion=        "ProductVersion" = "%MajorVersion%.%MinorVersion%.%YEAR%"
:: Change the following if using different version of VS
set VS_Devenv="C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"


echo %Line__Separator1%
echo Program Version = %ProgramVersion% ;Release Name = "%ReleaseName%" ;Identifier = %Identifier%
echo YEAR = "%YEAR%" ;MONTH = "%MONTH%" ;DAY = "%DAY%" 
echo Release Title = %ReleaseTitle% ;Release Notes = %ReleaseNotes% 
echo %Line__Separator1%

echo Pre-compile variables set
echo %Line__Separator1%

if [%TestVar%] == [%IsTrue%] (EXIT /B 0)

if [%NoBld%] == [%IsTrue%] (
	echo Skipping build
	goto :SkipBuild
)
:: ################################################################################################
:: Step 3: Build the solution and save to compress packages
echo Building all platforms
if NOT exist %PkgBaseDir%\ (
	mkdir %PkgBaseDir%
)
if NOT exist %PkgDir%\ (
	mkdir %PkgDir%
) else (
	del /Q /F %PkgDir%\*
)
set ListOfOS=win-x64 osx-x64 linux-x64 osx-arm64
(for %%a in (%ListOfOS%) do (
	dotnet publish -c Release -v q --self-contained -r "%%a" --property:identifier=%Identifier% --property:version=%ProgramVersion%
	if %ERRORLEVEL% NEQ 0 (
		echo %Line__Separator1%
		echo Error: Performming early exist due to error %ERRORLEVEL% from dotnet on OS target "%%a".
		echo %Line__Separator1%
		EXIT /B 0
	)
	echo       %%a build success!
	echo       %Line__Separator3%
	if [%NoCompress%] == [%IsTrue%] (
		echo Skipping compressing files
	) else (
		if [%%a] == [win-x64] ( 
			echo          %Line__Separator4%
			echo          Creating %%a ZIP file
			"%Prg7Zip%" a -tzip "%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.zip" "./bin/Release/%DotNetVer%/%%a/*"
			if %ERRORLEVEL% NEQ 0 (
				echo %Line__Separator1%
				echo Error: Performming early exist due to error %ERRORLEVEL% from 7z for file "%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.zip".
				echo Check folder contents of "%~dp0bin\Release\%DotNetVer%\%%a"
				echo %Line__Separator1%
				EXIT /B 0
			)
			call set "FileList=%%FileList%%%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.zip " 
			:: Try to build an MSI file if setup project exist using the project name + Setup
			if exist %SetupProjectFile_VdProj% (
				:: Replace the product version number
				>"%SetupProjectFile_VdProj_Temp%" (
				  for /f "usebackq delims=" %%a in ("%SetupProjectFile_VdProj%") do (
					SET fn=%%~na
					SET fn=!fn:~9,14!
					if [!fn!] == [%ProductVersionStrToFind%] (echo %NewProductVersion%) else (echo %%a)
				  )
				)
				if exist %SetupProjectFile_VdProj_Temp% (
					:: Change the following line if using different VS version or if VS installed in different location:
					%VS_Devenv% %ReleaseName%.sln /build Release /project %SetupProjectFile_VdProj_Temp%  /projectconfig Release
					move /Y .\%ReleaseName%_Setup\Release\%ReleaseName%_Setup.msi %PkgDir%\%PkgPrefix%%%a%PkgPostfix%_Setup.msi
					call set "FileList=%%FileList%%%PkgDir%\%PkgPrefix%%%a%PkgPostfix%_Setup.msi "
					if [%NoClean%] == [%IsTrue%] ( echo Skipping delete of %SetupProjectFile_VdProj_Temp%) else (
						del /Q %SetupProjectFile_VdProj_Temp%
					)
				)
			)
		) else (
			echo          %Line__Separator4%
			echo          Creating %%a TAR file
			"%Prg7Zip%" a -ttar %PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tar "./bin/Release/%DotNetVer%/%%a/*"
			if %ERRORLEVEL% NEQ 0 (
				echo %Line__Separator1%
				echo Error: Performming early exist due to error %ERRORLEVEL% from 7z for file "%PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tar".
				echo Check folder contents of "%~dp0bin\Release\%DotNetVer%\%%a"
				echo %Line__Separator1%
				EXIT /B 0
			)
			echo          %Line__Separator4%
			echo          Creating %%a TGZ file
			echo          "%Prg7Zip%" a %PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tgz %PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tar
			"%Prg7Zip%" a %PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tgz %PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tar
			if %ERRORLEVEL% NEQ 0 (
				echo %Line__Separator1%
				echo Error: Performming early exist due to error %ERRORLEVEL% from 7z for file "%PkgDir%/%PkgPrefix%%%a%PkgPostfix%.tgz".
				echo Check file "%~dp0%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.tar"
				echo %Line__Separator1%
				EXIT /B 0
			)
			echo          %Line__Separator4%
			if [%NoClean%] == [%IsTrue%] ( echo Skipping delete of %PkgDir%\%PkgPrefix%%%a%PkgPostfix%.tar) else (
				del /Q .\%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.tar
			)
			call set "FileList=%%FileList%%%PkgDir%\%PkgPrefix%%%a%PkgPostfix%.tgz "
		)
		echo       Package files compressed for %%a
		echo       %Line__Separator3%
	)
	echo    Process complete for %%a
	echo    %Line__Separator2%
))


echo All packages complete
echo Package build list = %FileList%
echo %Line__Separator1%
:SkipBuild

if [%NoRepoUpdate%] == [%IsTrue%] (
	echo Skipping repository update
	goto :SkipRepoUpdate
)
:: ################################################################################################
:: Step 4: Silently update github repository
:: Add all file changes
git add .
:: Setup a silent commit
git commit --allow-empty-message -q --no-edit
:: Push the changes to the repository
git push
echo Git repository update complete.
echo %Line__Separator1%
:SkipRepoUpdate


if [%NoGitRel%] == [%IsTrue%] (
	echo Skipping creating a Git release
	goto :SkipCreatingGitRelease
)
:: ################################################################################################
:: Step 5: Create a Github release and upload the packages
echo creating new release on Github
echo gh release create %ReleaseTag% %FileList% --latest --title %ReleaseTitle% --notes %ReleaseNotes%
gh release create %ReleaseTag% %FileList% --latest --title %ReleaseTitle% --notes %ReleaseNotes%
if %ERRORLEVEL% NEQ 0 (
	echo %Line__Separator1%
	echo Error: Creating a Github release failed!
	echo Error: Failed due to error %ERRORLEVEL% from gh release for files %FileList%.
	echo Check if these files exist in path "%~dp0%PkgDir%"
	echo %Line__Separator1%
	EXIT /B 0
)
echo Git release creation complete for ReleaseTag %ReleaseTag%
echo %Line__Separator1%
:SkipCreatingGitRelease

echo Done!

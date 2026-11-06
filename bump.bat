@echo off
rem Bumps mod.version, commits, tags v<version> and pushes both, which starts the release build.
rem Windows version of bump.sh: same arguments, same checks, same result.
rem
rem Run from anywhere inside a mod that has this framework as its framework\ submodule:
rem
rem   framework\bump.bat            # patch: 1.2.3 -> 1.2.4
rem   framework\bump.bat minor      # 1.2.3 -> 1.3.0
rem   framework\bump.bat major      # 1.2.3 -> 2.0.0
rem   framework\bump.bat 1.5.0      # an explicit version
rem
rem Options:
rem   --no-check   skip gradlew checkAll before tagging
rem   -y, --yes    do not ask for confirmation
setlocal EnableExtensions EnableDelayedExpansion

set "part=patch"
set "check=1"
set "yes=0"

:args
if "%~1"=="" goto args_done
set "arg=%~1"
if /i "!arg!"=="major" (set "part=major" & shift & goto args)
if /i "!arg!"=="minor" (set "part=minor" & shift & goto args)
if /i "!arg!"=="patch" (set "part=patch" & shift & goto args)
if "!arg!"=="--no-check" (set "check=0" & shift & goto args)
if "!arg!"=="-y" (set "yes=1" & shift & goto args)
if "!arg!"=="--yes" (set "yes=1" & shift & goto args)
if "!arg!"=="-h" goto help
if "!arg!"=="--help" goto help
rem Pipes run each side in a child cmd without delayed expansion, so %%var%% is used next to "|".
echo(%arg%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul && (set "part=%arg%" & shift & goto args)
set "msg=unknown argument '!arg!' (see --help)"
goto fail

:help
set /a "i=0"
for /f "usebackq tokens=* delims=" %%L in (`findstr /b /c:"rem" "%~f0"`) do (
    set /a "i+=1"
    if !i! leq 13 (
        set "line=%%L"
        echo(!line:~4!
    )
)
exit /b 0

:args_done
where git >nul 2>nul || (set "msg=git is not on PATH" & goto fail)

rem The mod is the repository this framework is checked out in.
set "mod_dir="
for /f "usebackq delims=" %%D in (`git -C "%~dp0." rev-parse --show-superproject-working-tree 2^>nul`) do set "mod_dir=%%D"
if not defined mod_dir (set "msg=run this as framework\bump.bat inside a mod, not in mod-framework itself" & goto fail)
cd /d "!mod_dir!" || (set "msg=cannot enter !mod_dir!" & goto fail)
if not exist gradle.properties (set "msg=no gradle.properties in !mod_dir!" & goto fail)

set "current="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"mod.version=" gradle.properties`) do set "current=%%B"
echo(%current%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul || (set "msg=mod.version '%current%' is not MAJOR.MINOR.PATCH" & goto fail)
for /f "tokens=1-3 delims=." %%A in ("!current!") do (
    rem 10000x %% 10000 drops leading zeros, which set /a would read as octal.
    set /a "major=10000%%A %% 10000, minor=10000%%B %% 10000, patch=10000%%C %% 10000"
)
if /i "!part!"=="major" (
    set /a "n=major+1"
    set "next=!n!.0.0"
) else if /i "!part!"=="minor" (
    set /a "n=minor+1"
    set "next=!major!.!n!.0"
) else if /i "!part!"=="patch" (
    set /a "n=patch+1"
    set "next=!major!.!minor!.!n!"
) else (
    set "next=!part!"
)
echo(%next%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul || (set "msg='%next%' is not MAJOR.MINOR.PATCH" & goto fail)
if "!next!"=="!current!" (set "msg=mod.version is already !current!" & goto fail)
set "tag=v!next!"

rem Refuse anything that would tag something other than what is on the remote branch.
set "branch="
for /f "usebackq delims=" %%B in (`git symbolic-ref --short HEAD 2^>nul`) do set "branch=%%B"
if not defined branch (set "msg=not on a branch" & goto fail)
set "dirty="
for /f "usebackq delims=" %%S in (`git status --porcelain`) do set "dirty=1"
if defined dirty (set "msg=the working tree has uncommitted changes" & goto fail)
git fetch -q origin "!branch!" --tags || (set "msg=git fetch failed" & goto fail)
set "behind="
for /f "usebackq delims=" %%C in (`git rev-list --count "HEAD..origin/!branch!"`) do set "behind=%%C"
if not "!behind!"=="0" (set "msg=origin/!branch! has commits you do not have; pull first" & goto fail)
git rev-parse -q --verify "refs/tags/!tag!" >nul 2>nul && (set "msg=tag !tag! already exists" & goto fail)
rem CI checks the framework out from GitHub, so the commit the mod points at must be pushed.
git -C framework fetch -q origin || (set "msg=git fetch in framework failed" & goto fail)
git -C framework merge-base --is-ancestor HEAD origin/main || (set "msg=framework\ points at a commit that is not on mod-framework's origin/main; push mod-framework first" & goto fail)

set "name="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"mod.name=" gradle.properties`) do set "name=%%B"
echo !name!: !current! -^> !next! (commit on !branch!, tag !tag!, push to origin)
if "!yes!"=="0" (
    set "answer="
    set /p "answer=Continue? [y/N] "
    if /i not "!answer!"=="y" (set "msg=aborted" & goto fail)
)

rem Rewrite only the mod.version line; keeps the file's encoding (UTF-8) and line endings.
rem The version goes in through the environment: a "!" on this line would make cmd eat the "^" of the regex.
set "BUMP_NEXT=!next!"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Join-Path (Get-Location) 'gradle.properties'; $t = [IO.File]::ReadAllText($p); $t = [regex]::Replace($t, '(?m)^mod\.version=[^\r\n]*', ('mod.version=' + $env:BUMP_NEXT)); [IO.File]::WriteAllText($p, $t)" ^
  || (set "msg=could not update gradle.properties" & goto fail)

if "!check!"=="1" (
    call gradlew.bat checkAll
    if errorlevel 1 (
        git checkout -- gradle.properties
        set "msg=checkAll failed; mod.version left at !current!"
        goto fail
    )
)

git commit -q -m "Release !tag!" gradle.properties || (set "msg=git commit failed" & goto fail)
git tag -a "!tag!" -m "!name! !next!" || (set "msg=git tag failed" & goto fail)
rem Atomic, so the tag never reaches GitHub without the commit it points at.
git push -q --atomic origin "!branch!" "!tag!" || (set "msg=git push failed; the commit and tag !tag! exist locally only" & goto fail)

set "url="
for /f "usebackq delims=" %%U in (`git remote get-url origin`) do set "url=%%U"
set "url=!url:git@github.com:=https://github.com/!"
if /i "!url:~-4!"==".git" set "url=!url:~0,-4!"
echo Pushed !tag!. The release build runs at: !url!/actions
exit /b 0

:fail
echo bump: !msg! 1>&2
exit /b 1

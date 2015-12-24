@ECHO OFF

REM TeamCity chokes on the COMPONENTS_VERSION processing here, it thinks
REM COMPONENTS_VERSION is required going into the build step when we would
REM define it in the build step.

SETLOCAL

REM ---------------------------------------------------------------------------
REM Check usage
REM ---------------------------------------------------------------------------

IF "%1" == "" GOTO Usage


SET BUILD_NUMBER=%1
ECHO BUILD_NUMBER=%BUILD_NUMBER%

REM ---------------------------------------------------------------------------
REM Build packages
REM ---------------------------------------------------------------------------

SET /P COMPONENTS_VERSION=<ver.txt
ECHO COMPONENTS_VERSION=%COMPONENTS_VERSION%

SET BUILD_VERSION=%COMPONENTS_VERSION%.%BUILD_NUMBER%
ECHO BUILD_VERSION=%BUILD_VERSION%

call build-packages.cmd %BUILD_VERSION%

GOTO :EOF

:Usage
ECHO USAGE: build_packages_teamcity.cmd (build-number)

EXIT 1

GOTO :EOF

ENDLOCAL

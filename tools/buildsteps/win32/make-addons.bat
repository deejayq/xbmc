@ECHO OFF

SETLOCAL

SET EXITCODE=0

SET install=false
SET clean=false
SET addon=
FOR %%b in (%1, %2, %3, %4) DO (
  IF %%b == install (
    SET install=true
  ) ELSE ( IF %%b == clean (
    SET clean=true
  ) ELSE (
    SET addon=%%b
  ))
)

rem set Visual C++ build environment
call "%VS120COMNTOOLS%..\..\VC\bin\vcvars32.bat"

SET WORKDIR=%WORKSPACE%

IF "%WORKDIR%" == "" (
  SET WORKDIR=%CD%\..\..\..
)

rem setup some paths that we need later
SET CUR_PATH=%CD%
SET BASE_PATH=%WORKDIR%\project\cmake
SET SCRIPTS_PATH=%BASE_PATH%\scripts\windows
SET ADDONS_PATH=%BASE_PATH%\addons
SET ADDON_DEPENDS_PATH=%ADDONS_PATH%\output
SET ADDONS_BUILD_PATH=%ADDONS_PATH%\build

SET ERRORFILE=%BASE_PATH%\make-addons.error

IF %clean% == true (
  rem remove the build directory if it exists
  IF EXIST "%ADDONS_BUILD_PATH%" (
    RMDIR "%ADDONS_BUILD_PATH%" /S /Q > NUL
  )

  rem remove the build directory if it exists
  IF EXIST "%ADDON_DEPENDS_PATH%" (
    RMDIR "%ADDON_DEPENDS_PATH%" /S /Q > NUL
  )

  GOTO END
)

rem create the depends directory
IF NOT EXIST "%ADDON_DEPENDS_PATH%" MKDIR "%ADDON_DEPENDS_PATH%"

rem create the build directory
IF NOT EXIST "%ADDONS_BUILD_PATH%" MKDIR "%ADDONS_BUILD_PATH%"

rem go into the build directory
CD "%ADDONS_BUILD_PATH%"

rem determine the proper install path for the built addons
IF %install% == true (
  SET ADDONS_INSTALL_PATH=%WORKDIR%\addons
) ELSE (
  SET ADDONS_INSTALL_PATH=%WORKDIR%\project\Win32BuildSetup\BUILD_WIN32\addons
)

ECHO --------------------------------------------------
ECHO Building addons
ECHO --------------------------------------------------

SET ADDONS_TO_BUILD="all"
IF "%addon%" NEQ "" (
  SET ADDONS_TO_BUILD="%addon%"
)

rem execute cmake to generate makefiles processable by nmake
cmake "%ADDONS_PATH%" -G "NMake Makefiles" ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DCMAKE_USER_MAKE_RULES_OVERRIDE="%SCRIPTS_PATH%/c-flag-overrides.cmake" ^
      -DCMAKE_USER_MAKE_RULES_OVERRIDE_CXX="%SCRIPTS_PATH%/cxx-flag-overrides.cmake" ^
      -DCMAKE_INSTALL_PREFIX=%ADDONS_INSTALL_PATH% ^
      -DAPP_ROOT=%WORKDIR% ^
      -DBUILD_DIR=%ADDONS_BUILD_PATH% ^
      -DDEPENDS_PATH=%ADDON_DEPENDS_PATH% ^
      -DPACKAGE_ZIP=1 ^
      -DARCH_DEFINES="-DTARGET_WINDOWS -DNOMINMAX -D_CRT_SECURE_NO_WARNINGS -D_USE_32BIT_TIME_T -D_WINSOCKAPI_" ^
      -DADDONS_TO_BUILD="%ADDONS_TO_BUILD%"
IF ERRORLEVEL 1 (
  ECHO cmake error level: %ERRORLEVEL% > %ERRORFILE%
  GOTO ERROR
)

rem execute nmake to build the addons
nmake %addon%
IF ERRORLEVEL 1 (
  ECHO nmake error level: %ERRORLEVEL% > %ERRORFILE%
  GOTO ERROR
)

rem everything was fine
GOTO END

:ERROR
rem something went wrong
ECHO Failed to build addons
ECHO See %ERRORFILE% for more details
SET EXITCODE=1

:END
rem go back to the original directory
cd %CUR_PATH%

rem exit the script with the defined exitcode
EXIT /B %EXITCODE%

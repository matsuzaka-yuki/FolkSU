@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Set JDK 21 path
set JAVA_HOME=C:\Program Files\Zulu\zulu-21
set PATH=%JAVA_HOME%\bin;%PATH%

:: Set Android NDK
set ANDROID_NDK_HOME=C:\Users\%USERNAME%\AppData\Local\Android\Sdk\ndk\29.0.14206865

:: Show help info
if "%~1"=="" goto :show_help
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help

:: Execute based on parameter
if "%~1"=="debug" goto :build_debug
if "%~1"=="release" goto :build_release
if "%~1"=="clean" goto :clean
if "%~1"=="clean-ksud" goto :clean_ksud
if "%~1"=="clean-all" goto :clean_all
if "%~1"=="ksud" goto :build_ksud
if "%~1"=="ksuinit" goto :build_ksuinit
if "%~1"=="all" goto :build_all
if "%~1"=="full" goto :build_full

:: Unknown parameter
echo [Error] Unknown parameter: %~1
goto :show_help

:show_help
echo.
echo ========================================
echo     KernelSU Manager Build Script
echo ========================================
echo.
echo Usage: build.bat [option]
echo.
echo Options:
echo   debug       - Build Debug version APK
echo   release     - Build Release version APK
echo   ksuinit     - Build ksuinit only
echo   ksud        - Build ksud only (includes ksuinit check)
echo   all         - Build ksud + Debug APK
echo   full        - Build ksuinit + ksud + Debug APK (complete build)
echo   clean       - Clean build artifacts
echo   clean-ksud  - Clean ksud build artifacts
echo   clean-all   - Clean all build artifacts (app + ksud)
echo   -h          - Show help info
echo.
echo Examples:
echo   build.bat debug
echo   build.bat release
echo   build.bat ksuinit
echo   build.bat ksud
echo   build.bat all
echo   build.bat full
echo   build.bat clean
echo   build.bat clean-ksud
echo   build.bat clean-all
echo.
goto :end

:build_ksuinit
echo.
echo ========================================
echo     Building ksuinit...
echo ========================================
echo.

:: Check if cargo is installed
cargo --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [Error] Rust/Cargo not found!
    echo [Info] Please install Rust first: https://rustup.rs/
    goto :end
)

:: Setup NDK environment
set NDK_BIN=%ANDROID_NDK_HOME%\toolchains\llvm\prebuilt\windows-x86_64\bin
set PATH=%NDK_BIN%;%PATH%
set CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=%NDK_BIN%\aarch64-linux-android26-clang.cmd
set RUSTFLAGS=-C link-arg=-no-pie

cd ..\userspace\ksuinit

echo [Info] Adding musl target...
rustup target add aarch64-unknown-linux-musl

echo [Info] Building ksuinit for arm64...
cargo build --target=aarch64-unknown-linux-musl --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [Error] ksuinit build failed!
    cd ..\..\manager
    goto :end
)

echo [Info] Copying ksuinit to bin/aarch64/...
if not exist "..\ksud\bin\aarch64" mkdir "..\ksud\bin\aarch64"
copy /Y "target\aarch64-unknown-linux-musl\release\ksuinit" "..\ksud\bin\aarch64\ksuinit"
if %ERRORLEVEL% neq 0 (
    echo [Error] Failed to copy ksuinit!
    cd ..\..\manager
    goto :end
)

cd ..\..\manager

echo.
echo ========================================
echo     ksuinit build successful!
echo ========================================
echo.
echo Output: ..\userspace\ksud\bin\aarch64\ksuinit
goto :end

:build_ksud
echo.
echo ========================================
echo     Building ksud...
echo ========================================
echo.

:: Check if ksuinit exists
if not exist "..\userspace\ksud\bin\aarch64\ksuinit" (
    echo [Warning] ksuinit not found, building ksuinit first...
    call :build_ksuinit
    if %ERRORLEVEL% neq 0 goto :end
)

:: Check if cargo is installed
cargo --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [Error] Rust/Cargo not found!
    echo [Info] Please install Rust first: https://rustup.rs/
    goto :end
)

:: Check if cargo-ndk is installed
cargo ndk --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [Warning] cargo-ndk not found, trying to install...
    cargo install cargo-ndk
    if %ERRORLEVEL% neq 0 (
        echo [Error] Failed to install cargo-ndk!
        goto :end
    )
)

:: Check if rust target is installed
rustup target list --installed | findstr "aarch64-linux-android" >nul
if %ERRORLEVEL% neq 0 (
    echo [Info] Adding Android target...
    rustup target add aarch64-linux-android
)

echo [Info] Building ksud for arm64-v8a...
cd ..\userspace\ksud

cargo ndk -t arm64-v8a -- build --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [Error] ksud build failed!
    cd ..\..\manager
    goto :end
)

cd ..\..\manager

echo [Info] Copying ksud to jniLibs...
if not exist "app\src\main\jniLibs\arm64-v8a" mkdir "app\src\main\jniLibs\arm64-v8a"
copy /Y "..\userspace\ksud\target\aarch64-linux-android\release\ksud" "app\src\main\jniLibs\arm64-v8a\libksud.so"
if %ERRORLEVEL% neq 0 (
    echo [Error] Failed to copy ksud!
    goto :end
)

echo.
echo ========================================
echo     ksud build successful!
echo ========================================
echo.
echo Output: app\src\main\jniLibs\arm64-v8a\libksud.so
goto :end

:build_full
echo.
echo ========================================
echo     Full Build (ksuinit + ksud + Debug APK)
echo ========================================
echo.
call :build_ksuinit
if %ERRORLEVEL% neq 0 goto :end
call :build_ksud
if %ERRORLEVEL% neq 0 goto :end
call :build_debug
goto :end

:build_all
echo.
echo ========================================
echo     Building ksud + Debug APK...
echo ========================================
echo.
call :build_ksud
if %ERRORLEVEL% neq 0 goto :end
call :build_debug
goto :end

:build_debug
echo.
echo ========================================
echo     Starting Debug build...
echo ========================================
echo.
echo [Info] Java version:
java -version
echo.
echo [Info] Checking libksud.so...
if not exist "app\src\main\jniLibs\arm64-v8a\libksud.so" (
    echo [Warning] libksud.so not found, building ksud first...
    call :build_ksud
    if %ERRORLEVEL% neq 0 goto :end
)
echo [Info] Starting build...
gradlew.bat clean assembleDebug
if %ERRORLEVEL% neq 0 (
    echo.
    echo [Error] Debug build failed!
    goto :end
)
echo.
echo ========================================
echo     Debug build successful!
echo ========================================
echo.
echo Output file: app\build\outputs\apk\debug\app-debug.apk
goto :end

:build_release
echo.
echo ========================================
echo     Starting Release build...
echo ========================================
echo.
echo [Info] Java version:
java -version
echo.
echo [Info] Checking libksud.so...
if not exist "app\src\main\jniLibs\arm64-v8a\libksud.so" (
    echo [Warning] libksud.so not found, building ksud first...
    call :build_ksud
    if %ERRORLEVEL% neq 0 goto :end
)
echo [Info] Starting build...
gradlew.bat clean assembleRelease
if %ERRORLEVEL% neq 0 (
    echo.
    echo [Error] Release build failed!
    goto :end
)
echo.
echo ========================================
echo     Release build successful!
echo ========================================
echo.
echo Output file: app\build\outputs\apk\release\app-release-unsigned.apk
echo.
echo [Note] Release version is unsigned, configure signing files if needed.
goto :end

:clean
echo.
echo ========================================
echo     Cleaning build artifacts...
echo ========================================
echo.
gradlew.bat clean
if %ERRORLEVEL% neq 0 (
    echo.
    echo [Error] Clean failed!
    goto :end
)
echo.
echo ========================================
echo     Clean completed!
echo ========================================
echo.
goto :end

:clean_ksud
echo.
echo ========================================
echo     Cleaning ksud build artifacts...
echo ========================================
echo.

:: Delete ksud target directory
if exist "..\userspace\ksud\target" (
    echo [Info] Deleting ..\userspace\ksud\target ...
    rmdir /s /q "..\userspace\ksud\target"
    if %ERRORLEVEL% neq 0 (
        echo [Warning] Failed to delete ..\userspace\ksud\target
    ) else (
        echo [OK] Deleted ..\userspace\ksud\target
    )
) else (
    echo [Info] ..\userspace\ksud\target does not exist, skipping
)

:: Delete ksuinit from bin/aarch64
if exist "..\userspace\ksud\bin\aarch64\ksuinit" (
    echo [Info] Deleting ksuinit ...
    del /f /q "..\userspace\ksud\bin\aarch64\ksuinit"
    if %ERRORLEVEL% neq 0 (
        echo [Warning] Failed to delete ksuinit
    ) else (
        echo [OK] Deleted ksuinit
    )
) else (
    echo [Info] ksuinit does not exist, skipping
)

:: Delete libksud.so from jniLibs
if exist "app\src\main\jniLibs\arm64-v8a\libksud.so" (
    echo [Info] Deleting libksud.so ...
    del /f /q "app\src\main\jniLibs\arm64-v8a\libksud.so"
    if %ERRORLEVEL% neq 0 (
        echo [Warning] Failed to delete libksud.so
    ) else (
        echo [OK] Deleted libksud.so
    )
) else (
    echo [Info] libksud.so does not exist, skipping
)

echo.
echo ========================================
echo     ksud clean completed!
echo ========================================
echo.
goto :end

:clean_all
echo.
echo ========================================
echo     Cleaning all build artifacts...
echo ========================================
echo.

:: Clean Manager build
call :clean
if %ERRORLEVEL% neq 0 (
    echo [Warning] Manager clean had issues, continuing...
)

:: Clean ksud
call :clean_ksud

echo.
echo ========================================
echo     All clean completed!
echo ========================================
echo.
goto :end

:end
endlocal

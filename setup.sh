#!/bin/bash

# Luckfox Nova SDK Automated Build Environment Setup Script
echo "=============================================="
echo "  Luckfox Nova SDK Docker Build Environment"
echo "=============================================="

# Function to display colored output
print_status() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

print_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

# Check Docker installation
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if SDK exists
SDK_TAR=$(find . -maxdepth 1 -name "Luckfox_Nova_SDK_*.tar.gz" | head -1)

if [ -z "$SDK_TAR" ] && [ ! -d "nova-sdk" ]; then
    print_error "Luckfox Nova SDK not found!"
    echo ""
    echo "Please download the SDK from the official wiki:"
    echo "https://wiki.luckfox.com/Luckfox-Nova/Download"
    echo ""
    echo "Place the downloaded 'Luckfox_Nova_SDK_*.tar.gz' file in this directory"
    echo "(No need to rename - any date format is supported)"
    exit 1
fi

# Create nova-sdk directory if it doesn't exist
mkdir -p nova-sdk

# Extract SDK if needed
if [ -n "$SDK_TAR" ] && [ ! -d "nova-sdk/.repo" ]; then
    print_status "Found SDK file: $(basename "$SDK_TAR")"
    print_status "Moving SDK tarball to nova-sdk directory..."
    
    # Move tarball to nova-sdk directory
    cp "$SDK_TAR" nova-sdk/
    
    print_status "Extracting Luckfox Nova SDK..."
    cd nova-sdk
    
    # Extract in the nova-sdk directory
    tar -xzf "$(basename "$SDK_TAR")"
    
    # Check if .repo directory was extracted directly or inside a subdirectory
    if [ -d ".repo" ]; then
        print_status "SDK .repo directory extracted directly"
        rm -f "$(basename "$SDK_TAR")"
        cd ..
    else
        # Find extracted directory and move contents up one level
        SDK_DIR=$(find . -maxdepth 1 -type d -name "Luckfox_Nova_SDK*" | head -1)
        if [ -n "$SDK_DIR" ]; then
            print_status "Moving SDK contents from $SDK_DIR to nova-sdk root..."
            # Move all contents from SDK_DIR to current directory (nova-sdk)
            mv "$SDK_DIR"/* ./ 2>/dev/null || true
            mv "$SDK_DIR"/.* ./ 2>/dev/null || true  # Move hidden files, ignore errors
            # Remove empty SDK directory and tarball
            rmdir "$SDK_DIR" 2>/dev/null || true
            rm -f "$(basename "$SDK_TAR")"
            cd ..
            print_status "SDK extracted and organized in nova-sdk directory"
        else
            cd ..
            print_error "Failed to find extracted SDK directory or .repo folder"
            exit 1
        fi
    fi
    
    # Verify .repo directory exists
    if [ ! -d "nova-sdk/.repo" ]; then
        print_error "Failed to extract .repo directory from SDK"
        exit 1
    fi
    
    print_status "✓ SDK .repo directory successfully extracted"
    
elif [ -d "nova-sdk/.repo" ]; then
    print_status "Using existing nova-sdk directory with .repo"
elif [ -d "nova-sdk" ]; then
    print_warning "nova-sdk directory exists but .repo directory is missing"
    if [ -n "$SDK_TAR" ]; then
        print_status "Re-extracting SDK..."
        rm -rf nova-sdk/*
        rm -rf nova-sdk/.*  2>/dev/null || true
        
        # Copy and extract
        cp "$SDK_TAR" nova-sdk/
        cd nova-sdk
        tar -xzf "$(basename "$SDK_TAR")"
        
        # Check for .repo or SDK directory
        if [ -d ".repo" ]; then
            print_status "SDK .repo directory extracted directly"
        else
            SDK_DIR=$(find . -maxdepth 1 -type d -name "Luckfox_Nova_SDK*" | head -1)
            if [ -n "$SDK_DIR" ]; then
                mv "$SDK_DIR"/* ./ 2>/dev/null || true
                mv "$SDK_DIR"/.* ./ 2>/dev/null || true
                rmdir "$SDK_DIR" 2>/dev/null || true
            fi
        fi
        
        rm -f "$(basename "$SDK_TAR")"
        cd ..
        
        if [ -d "nova-sdk/.repo" ]; then
            print_status "SDK re-extracted successfully"
        else
            print_error "Failed to extract .repo directory"
            exit 1
        fi
    fi
fi

# Check SDK structure
if [ ! -d "nova-sdk/.repo" ]; then
    print_error "Invalid SDK structure. .repo directory not found in nova-sdk/"
    exit 1
fi

print_status "✓ SDK directory structure verified"

# Create build setup script in container
cat > build_setup.sh << 'EOF'
#!/bin/bash

# Internal build setup script for container
echo "=============================================="
echo "    Luckfox Nova SDK Build Setup"
echo "=============================================="

# Function to display colored output
print_status() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

print_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

# Navigate to SDK directory
cd /home/nova/nova-sdk

# Check if SDK is properly mounted
if [ ! -d ".repo" ]; then
    print_error "SDK not properly mounted. .repo directory not found."
    exit 1
fi

# Fix potential which command issues
print_status "Fixing which command..."
if [ ! -x "/usr/bin/which" ]; then
    sudo apt-get update
    sudo apt-get install -y --reinstall which debianutils
fi

# Verify critical commands are available
print_status "Verifying dependencies..."
for cmd in rsync file hexdump; do
    if command -v "$cmd" &> /dev/null; then
        print_status "✓ $cmd is available"
    else
        print_error "$cmd not found"
        sudo apt-get update
        sudo apt-get install -y $cmd
    fi
done

# Test which command specifically
if /usr/bin/which rsync &> /dev/null; then
    print_status "✓ which command working correctly"
else
    print_warning "which command may have issues, but continuing..."
fi

print_status "Starting SDK repository synchronization..."
.repo/repo/repo sync -l

if [ $? -ne 0 ]; then
    print_error "Repository synchronization failed"
    exit 1
fi

print_status "✓ Repository synchronization completed"

# Run build lunch configuration
print_status "Configuring build environment..."
echo "2" | ./build.sh lunch 2>&1 | tee build_lunch_output.log

if [ $? -ne 0 ]; then
    print_error "Build configuration failed"
    
    # Show debug information
    print_status "Debug information:"
    echo "Current PATH: $PATH"
    echo "rsync locations:"
    find /usr /bin -name rsync 2>/dev/null || echo "rsync not found"
    echo "which command test:"
    /usr/bin/which rsync 2>/dev/null || echo "which rsync failed"
    
    exit 1
fi

print_status "✓ Build configuration completed"

# Apply hexdump fix for rkImageMaker
print_status "Applying rkImageMaker fix..."
sed -i '115c\\tTAG="RK330B"' device/rockchip/common/scripts/mk-updateimg.sh

if [ $? -eq 0 ]; then
    print_status "✓ rkImageMaker fix applied successfully"
else
    print_warning "Failed to apply rkImageMaker fix - continuing anyway"
fi

# Ask about kernel menuconfig
echo ""
echo "Do you want to run 'make menuconfig' to customize kernel configuration? (y/N): "
read -r menuconfig_choice

case $menuconfig_choice in
    [Yy]* )
        print_status "Running kernel menuconfig..."
        cd kernel
        make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- menuconfig
        cd ..
        print_status "✓ Kernel configuration completed"
        ;;
    * )
        print_status "Skipping kernel menuconfig"
        ;;
esac

# Build options menu
echo ""
echo "=============================================="
echo "           Build Options"
echo "=============================================="
echo "Select build option:"
echo "  a) Build all (complete firmware)"
echo "  k) Build kernel only"
echo "  f) Build firmware only"
echo "  u) Build u-boot only"
echo "  b) Build buildroot only"
echo "  d) Debug kernel build (verbose)"
echo "  s) Skip build (setup only)"
echo ""
echo -n "Enter your choice (a/k/f/u/b/d/s): "
read -r build_choice

case $build_choice in
    [Aa]* )
        print_status "Building complete firmware..."
        ./build.sh
        ;;
    [Kk]* )
        print_status "Building kernel only..."
        ./build.sh kernel
        ;;
    [Ff]* )
        print_status "Building firmware only..."
        ./build.sh firmware
        ;;
    [Uu]* )
        print_status "Building u-boot only..."
        ./build.sh uboot
        ;;
    [Bb]* )
        print_status "Building buildroot only..."
        ./build.sh buildroot
        ;;
    [Dd]* )
        print_status "Building kernel with verbose output..."
        cd kernel
        
        # Check available configs
        print_status "Available kernel configs:"
        ls arch/arm64/configs/*luckfox* arch/arm64/configs/*rk3308* 2>/dev/null || true
        
        # Check device tree files
        print_status "Available device tree files:"
        find arch/arm64/boot/dts/rockchip/ -name "*luckfox*" -o -name "*rk3308*" 2>/dev/null || true
        
        # Configure kernel
        make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- luckfox_linux_defconfig
        
        # Try building individual components
        print_status "Building kernel Image..."
        make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- V=1 -j1 Image
        
        print_status "Building device tree blobs..."
        make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- V=1 -j1 dtbs
        
        print_status "Trying problematic target with verbose output..."
        make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- V=1 -j1 luckfox-rk3308b-evb-v10.img || true
        
        # Check what files were created
        print_status "Generated files:"
        find . -name "*.img" -o -name "Image*" -o -name "*.dtb" | head -10
        
        cd ..
        ;;
    [Ss]* )
        print_status "Setup completed. Skipping build."
        ;;
    * )
        print_warning "Invalid choice. Let's try individual components first..."
        
        # Try building components individually for better error diagnosis
        print_status "Building U-Boot first..."
        ./build.sh uboot
        
        if [ $? -eq 0 ]; then
            print_status "✓ U-Boot build successful, trying kernel..."
            ./build.sh kernel
            
            if [ $? -eq 0 ]; then
                print_status "✓ Kernel build successful, trying buildroot..."
                ./build.sh buildroot
                
                if [ $? -eq 0 ]; then
                    print_status "✓ All components built, creating firmware..."
                    ./build.sh firmware
                fi
            else
                print_error "Kernel build failed. Let's try manual kernel build..."
                cd kernel
                print_status "Configuring kernel manually..."
                make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- luckfox_linux_defconfig
                
                print_status "Building kernel with single thread for better error visibility..."
                make ARCH=arm64 CROSS_COMPILE=../prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- V=1 -j1
                cd ..
            fi
        else
            print_error "U-Boot build failed. Please check the error messages."
        fi
        ;;
esac

# Check build result
if [ $? -eq 0 ]; then
    print_status "✓ Build completed successfully!"
    
    echo ""
    echo "=============================================="
    echo "           Build Summary"
    echo "=============================================="
    echo "Build output locations:"
    echo "  - Firmware images: nova-sdk/output/firmware/"
    echo "  - Individual images: nova-sdk/rockdev/"
    echo "  - Host access will be set up after container exit"
    echo ""
    
    if [ -f "rockdev/update.img" ]; then
        echo "Key files generated:"
        echo "  ✓ update.img (complete firmware package)"
        echo "  ✓ boot.img (kernel image)"
        echo "  ✓ rootfs.img (root filesystem)"
        echo "  ✓ uboot.img (U-Boot bootloader)"
    else
        echo "Individual images generated (update.img creation may have failed):"
        ls -la rockdev/*.img 2>/dev/null || echo "  No image files found"
    fi
    
else
    print_error "Build failed! Check the error messages above."
    echo ""
    echo "Common solutions:"
    echo "  - Check if all dependencies are installed"
    echo "  - Verify SDK integrity"
    echo "  - Try individual builds (kernel, uboot, firmware)"
fi

echo ""
echo "=============================================="
echo "You can now:"
echo "  - Exit container and access files in output/"
echo "  - Run additional builds with ./build.sh <target>"
echo "  - Modify sources and rebuild"
echo "=============================================="

# Keep container running
exec /bin/bash
EOF

chmod +x build_setup.sh

# Build Docker image
print_status "Building Docker image..."
docker build -t luckfox-nova-dev .

# Remove existing container if it exists
if [ "$(docker ps -aq -f name=luckfox-dev)" ]; then
    print_status "Removing existing container..."
    docker rm -f luckfox-dev
fi

# Create output directory
mkdir -p output

# Start Docker container
print_status "Starting Docker container..."
docker run -it \
    --name luckfox-dev \
    --privileged \
    -v $(pwd)/nova-sdk:/home/nova/nova-sdk \
    -v $(pwd)/build_setup.sh:/home/nova/build_setup.sh \
    luckfox-nova-dev /home/nova/build_setup.sh

# After container exits, set up host-side symbolic links
print_status "Setting up host-side output symbolic links..."

# Remove existing output directory if it exists
if [ -d "output" ]; then
    rm -rf output
fi

# Create symbolic link to firmware directory
if [ -d "nova-sdk/output/firmware" ]; then
    ln -sf nova-sdk/output/firmware output
    print_status "✓ Created symbolic link: output -> nova-sdk/output/firmware"
else
    print_warning "Firmware directory not found, creating placeholder"
    mkdir -p output
fi

# Additional symbolic links for convenience
if [ -d "nova-sdk/rockdev" ]; then
    ln -sf nova-sdk/rockdev rockdev 2>/dev/null || true
    print_status "✓ Created symbolic link: rockdev -> nova-sdk/rockdev"
fi

print_status "Build environment setup completed!"
echo ""
echo "=== Output Access ==="
echo "Firmware files: output/ (links to nova-sdk/output/firmware/)"
echo "Individual images: rockdev/ (links to nova-sdk/rockdev/)"
echo ""
echo "=== Container Management ==="
echo "Restart: docker start -i luckfox-dev"
echo "Stop: docker stop luckfox-dev"
echo "Remove: docker rm luckfox-dev"
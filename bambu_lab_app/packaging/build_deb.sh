#!/bin/bash
# Bambu Lab App - Debian 安装包打包脚本
# 用法: ./build_deb.sh [版本号]
# 默认版本号: 1.0.0

set -e

VERSION="${1:-1.0.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
OUTPUT_DIR="$PROJECT_DIR/packaging"
PACKAGE_DIR="$OUTPUT_DIR/bambu-lab-app_${VERSION}_amd64"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Bambu Lab App Debian 打包脚本 ===${NC}"
echo "版本: $VERSION"
echo ""

# 检查编译产物是否存在
if [ ! -f "$BUILD_DIR/bambu_lab_app" ]; then
    echo -e "${RED}错误: 未找到编译产物。请先运行 'flutter build linux'${NC}"
    echo "运行: cd $PROJECT_DIR && flutter build linux"
    exit 1
fi
echo -e "${GREEN}✓ 编译产物已找到${NC}"

# 清理旧的打包目录
rm -rf "$PACKAGE_DIR"
echo -e "${GREEN}✓ 清理旧打包目录${NC}"

# 创建目录结构
mkdir -p "$PACKAGE_DIR/DEBIAN"
mkdir -p "$PACKAGE_DIR/usr/local/bin"
mkdir -p "$PACKAGE_DIR/usr/share/applications"
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps"
echo -e "${GREEN}✓ 目录结构已创建${NC}"

# 拷贝编译产物（bundle 下所有文件）
cp -r "$BUILD_DIR/"* "$PACKAGE_DIR/usr/local/bin/"
echo -e "${GREEN}✓ 编译产物已拷贝${NC}"

# 拷贝图标（如果有）
ICON_SRC="$PROJECT_DIR/bamboo_app_logo.png"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps/bambu_lab_app.png"
    echo -e "${GREEN}✓ 图标已拷贝${NC}"
else
    echo -e "${YELLOW}⚠ 未找到图标文件 bamboo_app_logo.png，跳过${NC}"
fi

# 创建 desktop 文件
cat > "$PACKAGE_DIR/usr/share/applications/bambu_lab_app.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=Bambu Lab App
Comment=Bambu Lab 3D Printer Control App
Exec=/usr/local/bin/bambu_lab_app
Icon=bambu_lab_app
Terminal=false
Type=Application
Categories=Utility;HardwareSettings;
StartupNotify=true
EOF
echo -e "${GREEN}✓ desktop 文件已创建${NC}"

# 根据源文件列表计算实际安装大小（KB）
INSTALLED_SIZE=$(du -sk "$PACKAGE_DIR/usr" | cut -f1)

# 创建 DEBIAN/control 文件
cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: bambu-lab-app
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Bambu Lab Controller <developer@example.com>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0 (>= 3.24), libsqlite3-0 (>= 3.34), libc6 (>= 2.31)
Description: Bambu Lab 3D Printer Control App
 Flutter-based desktop application for controlling Bambu Lab 3D printers.
 Supports real-time monitoring, print control, FTP file management,
 and AMS filament management.
EOF
echo -e "${GREEN}✓ control 文件已创建${NC}"

# 创建后安装脚本（可选：注册图标缓存等）
cat > "$PACKAGE_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
# 更新图标缓存
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fi
# 更新桌面数据库
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications || true
fi
echo "Bambu Lab App 安装完成！"
EOF
chmod 755 "$PACKAGE_DIR/DEBIAN/postinst"

# 创建卸载前脚本
cat > "$PACKAGE_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e
echo "正在卸载 Bambu Lab App..."
EOF
chmod 755 "$PACKAGE_DIR/DEBIAN/prerm"

echo -e "${GREEN}✓ 维护脚本已创建${NC}"

# 设置目录权限
chmod 755 "$PACKAGE_DIR/DEBIAN"
chmod 755 "$PACKAGE_DIR/usr"
chmod 755 "$PACKAGE_DIR/usr/local"
chmod 755 "$PACKAGE_DIR/usr/local/bin"
chmod 755 "$PACKAGE_DIR/usr/share"
chmod 755 "$PACKAGE_DIR/usr/share/applications"
chmod 755 "$PACKAGE_DIR/usr/share/icons"
chmod 755 "$PACKAGE_DIR/usr/share/icons/hicolor"
chmod 755 "$PACKAGE_DIR/usr/share/icons/hicolor/256x256"
chmod 755 "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps"

# 二进制文件加上执行权限
chmod 755 "$PACKAGE_DIR/usr/local/bin/"*

# 打包
echo ""
echo -e "${YELLOW}正在打包 .deb ...${NC}"
cd "$OUTPUT_DIR"
dpkg-deb --build "bambu-lab-app_${VERSION}_amd64" > /dev/null

# 验证
if [ -f "bambu-lab-app_${VERSION}_amd64.deb" ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}打包成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "安装包: $OUTPUT_DIR/bambu-lab-app_${VERSION}_amd64.deb"
    echo "大小: $(du -h "bambu-lab-app_${VERSION}_amd64.deb" | cut -f1)"
    echo ""
    echo "安装方法:"
    echo "  sudo dpkg -i bambu-lab-app_${VERSION}_amd64.deb"
    echo ""
    echo "卸载方法:"
    echo "  sudo dpkg -r bambu-lab-app"
else
    echo -e "${RED}打包失败！${NC}"
    exit 1
fi

# 清理打包目录
rm -rf "$PACKAGE_DIR"

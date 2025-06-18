include $(TOPDIR)/rules.mk

PKG_NAME:=sing-box
PKG_VERSION:=dev-next
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/reF1nd/sing-box.git
PKG_SOURCE_VERSION:=dev-next
PKG_MIRROR_HASH:=skip

PKG_LICENSE:=GPL-3.0
PKG_MAINTAINER:=yourname <your@email.com>
PKG_BUILD_DEPENDS:=golang/host

include $(INCLUDE_DIR)/package.mk

define Package/sing-box
  SECTION:=net
  CATEGORY:=Network
  TITLE:=sing-box universal proxy
  DEPENDS:=+ca-bundle +kmod-inet-diag +kmod-tun +firewall4
  ARCH:=aarch64_cortex-a53
endef

define Package/sing-box/description
  sing-box is a universal proxy platform.
endef

define Build/Compile
	cd $(PKG_BUILD_DIR); \
	export GOOS=linux; \
	export GOARCH=arm64; \
	export CGO_ENABLED=0; \
	export TAGS="with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale"; \
	VERSION=$$(go run ./cmd/internal/read_tag); \
	go build -v -trimpath -ldflags "-X 'github.com/reF1nd/sing-box/constant.Version=$${VERSION}' -s -w -buildid=" -tags "$${TAGS}" -o sing-box ./cmd/sing-box
endef

define Package/sing-box/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sing-box $(1)/usr/bin/sing-box
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/sing-box.config $(1)/etc/config/sing-box
	$(INSTALL_DIR) $(1)/etc/sing-box
	$(INSTALL_CONF) ./files/config.json $(1)/etc/sing-box/config.json
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/sing-box.init $(1)/etc/init.d/sing-box
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_CONF) ./files/keep.sing-box $(1)/lib/upgrade/keep.d/sing-box
endef

$(eval $(call BuildPackage,sing-box))

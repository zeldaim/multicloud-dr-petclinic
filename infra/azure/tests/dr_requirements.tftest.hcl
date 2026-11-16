# Azure(DR 쪽) 요구사항 시험 — 클라우드 계정 없이(mock_provider) 코드 논리만 검증한다. 2026-11-17 개인 추가.
#   terraform init -backend=false && terraform test
# 증명하는 것: 이 코드로 만들어질 리소스 설정이 DMS/덤프 복제 대상·VPN·보안 요구를 만족하는가
# 증명하지 못하는 것: 실제 Azure 에서 만들어지는가, VPN 터널이 실제로 붙는가, 복제가 실제로 되는가
mock_provider "azurerm" {
  # azurerm 은 리소스 ID 형식을 검사하므로 형식에 맞는 가짜 ID 를 준다
  mock_resource "azurerm_resource_group" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test" } }
  mock_resource "azurerm_virtual_network" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet" } }
  mock_resource "azurerm_public_ip" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip" } }
  mock_resource "azurerm_network_security_group" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg" } }
  mock_resource "azurerm_network_interface" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic" } }
  mock_resource "azurerm_private_dns_zone" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/petclinic-dr.mysql.database.azure.com" } }
  mock_resource "azurerm_virtual_network_gateway" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworkGateways/vgw" } }
  mock_resource "azurerm_local_network_gateway" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/localNetworkGateways/lng" } }
  mock_resource "azurerm_private_dns_resolver" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver" } }
  mock_resource "azurerm_mysql_flexible_server" { defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforMySQL/flexibleServers/mysql", fqdn = "mysql.petclinic-dr.mysql.database.azure.com" } }
}

# 서브넷은 서로 다른 ID 를 줘야 "DB 가 DB 서브넷에 있다" 시험이 의미가 있다
override_resource {
  target = azurerm_subnet.subnet
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/default" }
}
override_resource {
  target = azurerm_subnet.db_subnet
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/db-subnet" }
}
override_resource {
  target = azurerm_subnet.dns_subnet
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/DNSSubnet" }
}
override_resource {
  target = azurerm_subnet.gateway_subnet
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/GatewaySubnet" }
}
mock_provider "random" {}

variables {
  resource_group_name = "rg-test"
  location            = "koreacentral"
  vm_name             = "dr-test"
  admin_username      = "azureuser"
  ssh_public_key_path = "tests/fixtures/test_key.pub" # 시험용 가짜 공개키
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  db_admin_username   = "petadmin"
  db_admin_password   = "Test-Only-Pass1!" # provider 복잡도 검사 통과용 시험 값
  aws_vpc_cidr        = "10.0.0.0/16"
  aws_vpn_public_ip   = "203.0.113.20"
  vpn_shared_key      = "test-only-psk"
}

run "mysql_is_replication_target" {
  command = apply
  assert {
    condition     = azurerm_mysql_flexible_server_configuration.gtid.name == "gtid_mode" && azurerm_mysql_flexible_server_configuration.gtid.value == "ON"
    error_message = "GTID 덤프·복제를 받으려면 gtid_mode=ON 이어야 한다 (AWS RDS 쪽과 같게)"
  }
  assert {
    condition     = azurerm_mysql_flexible_server_configuration.gtid_enforce.name == "enforce_gtid_consistency" && azurerm_mysql_flexible_server_configuration.gtid_enforce.value == "ON"
    error_message = "enforce_gtid_consistency=ON 이어야 한다"
  }
  assert {
    condition     = startswith(azurerm_mysql_flexible_server.mysql.version, "8.0")
    error_message = "AWS RDS(MySQL 8.0)와 주 버전이 같아야 한다"
  }
}

run "mysql_private_only" {
  command = apply
  assert {
    condition     = azurerm_mysql_flexible_server.mysql.delegated_subnet_id == azurerm_subnet.db_subnet.id
    error_message = "MySQL 은 위임 서브넷(VNet 통합)에만 있어야 한다 — 공개 접근 없음"
  }
  assert {
    condition     = alltrue([for r in azurerm_network_security_group.db_nsg.security_rule : !contains(["*", "0.0.0.0/0", "Internet"], r.source_address_prefix)])
    error_message = "DB NSG 에 인터넷 전체 허용 규칙이 있으면 안 된다"
  }
  assert {
    condition     = anytrue([for r in azurerm_network_security_group.db_nsg.security_rule : r.destination_port_range == "3306" && r.source_address_prefix == var.aws_vpc_cidr])
    error_message = "AWS VPC 대역에서 3306 이 열려 있어야 복제(DMS)가 들어온다"
  }
}

run "site_to_site_vpn_to_aws" {
  command = apply
  assert {
    condition     = azurerm_virtual_network_gateway.vpn_gateway.type == "Vpn" && azurerm_virtual_network_gateway.vpn_gateway.vpn_type == "RouteBased"
    error_message = "AWS 와 붙는 Route-based VPN 게이트웨이여야 한다"
  }
  assert {
    condition     = azurerm_virtual_network_gateway_connection.azure_to_aws.type == "IPsec"
    error_message = "AWS 와의 연결은 IPsec Site-to-Site 여야 한다"
  }
  assert {
    condition     = azurerm_local_network_gateway.aws_lng.gateway_address == var.aws_vpn_public_ip && contains(azurerm_local_network_gateway.aws_lng.address_space, var.aws_vpc_cidr)
    error_message = "로컬 네트워크 게이트웨이가 AWS VPN 공인 IP·VPC 대역을 가리켜야 한다"
  }
  assert {
    # CIDR 를 [시작, 시작+크기) 정수 범위로 바꿔 겹침을 계산한다
    condition     = alltrue([for v in [for c in tolist(azurerm_virtual_network.vnet.address_space) : { s = sum([for i, o in split(".", cidrhost(c, 0)) : tonumber(o) * pow(256, 3 - i)]), n = pow(2, 32 - tonumber(split("/", c)[1])) }] : alltrue([for a in [{ s = sum([for i, o in split(".", cidrhost(var.aws_vpc_cidr, 0)) : tonumber(o) * pow(256, 3 - i)]), n = pow(2, 32 - tonumber(split("/", var.aws_vpc_cidr)[1])) }] : v.s + v.n <= a.s || a.s + a.n <= v.s])])
    error_message = "Azure VNet 과 AWS VPC 대역이 겹치면 VPN 라우팅이 안 된다"
  }
}

run "current_state_records" {
  # 정책 시험이 아니라 현재 상태 기록이다 (AWS 쪽 ssh 시험과 같은 방식). 고치면 조건을 뒤집는다.
  command = plan
  assert {
    condition     = azurerm_mysql_flexible_server_configuration.no_ssl.name == "require_secure_transport" && azurerm_mysql_flexible_server_configuration.no_ssl.value == "OFF"
    error_message = "require_secure_transport 가 바뀌었다 — 앱 azure 프로필(useSSL=true)과 맞는지 확인하고 시험을 갱신할 것"
  }
  assert {
    condition     = anytrue([for r in azurerm_network_security_group.nsg.security_rule : r.destination_port_range == "22" && r.source_address_prefix == "*"])
    error_message = "VM SSH 허용 대역이 바뀌었다 — 시험을 갱신할 것 (Trivy 지적 항목)"
  }
  assert {
    condition     = azurerm_mysql_flexible_database.database.name == "petclinic-dr-db"
    error_message = "DB 이름이 바뀌었다 — 앱이 기대하는 이름(petclinic)과 맞는지 확인할 것"
  }
}

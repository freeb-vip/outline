#!/bin/bash

# OIDC 诊断脚本

ISSUER_URL="https://sso.freeb.vip"
WELL_KNOWN_URL="${ISSUER_URL}/.well-known/openid-configuration"

echo "=== OIDC 提供商诊断 ==="
echo ""
echo "尝试访问 OIDC 自动发现端点..."
echo "URL: $WELL_KNOWN_URL"
echo ""

# 尝试获取 OpenID Connect 配置
echo "正在获取 OIDC 配置..."
RESPONSE=$(curl -s -w "\n%{http_code}" "$WELL_KNOWN_URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP 状态码: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ 成功获取 OIDC 配置"
    echo ""
    echo "响应内容:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
    
    # 提取关键端点
    echo "=== 推荐的端点配置 ==="
    echo "Authorization URI: $(echo "$BODY" | jq -r '.authorization_endpoint' 2>/dev/null)"
    echo "Token URI: $(echo "$BODY" | jq -r '.token_endpoint' 2>/dev/null)"
    echo "UserInfo URI: $(echo "$BODY" | jq -r '.userinfo_endpoint' 2>/dev/null)"
    echo ""
else
    echo "✗ 无法获取 OIDC 配置 (HTTP $HTTP_CODE)"
    echo ""
    echo "响应内容:"
    echo "$BODY"
    echo ""
    echo "可能的原因:"
    echo "1. OIDC 提供商不支持自动发现"
    echo "2. Issuer URL 配置不正确"
    echo "3. OIDC 提供商未实现标准的 .well-known 端点"
    echo ""
    echo "请手动验证以下端点："
    echo ""
    echo "测试当前配置中的端点："
    echo ""
fi

echo "=== 逐个测试端点 ==="
echo ""

# 测试 authUri
echo "1. 测试 Authorization 端点"
AUTH_URI="https://sso.freeb.vip/login/oauth/authorize"
echo "   URL: $AUTH_URI"
AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AUTH_URI?client_id=test&response_type=code&redirect_uri=https://outline.freeb.vip&scope=openid")
echo "   HTTP 状态码: $AUTH_CODE"
echo ""

# 测试 tokenUri
echo "2. 测试 Token 端点"
TOKEN_URI="https://sso.freeb.vip/api/login/oauth/token"
echo "   URL: $TOKEN_URI"
TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TOKEN_URI")
echo "   HTTP 状态码: $TOKEN_CODE (POST 请求，无凭证时通常返回 400 或 401)"
echo ""

# 测试 userinfoUri
echo "3. 测试 UserInfo 端点"
USERINFO_URI="https://sso.freeb.vip/api/userinfo"
echo "   URL: $USERINFO_URI"
USERINFO_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer test_token" "$USERINFO_URI")
echo "   HTTP 状态码: $USERINFO_CODE (需要有效的 Bearer token)"
echo ""

echo "=== 诊断结果 ==="
if [ "$AUTH_CODE" = "200" ] || [ "$AUTH_CODE" = "302" ] || [ "$AUTH_CODE" = "400" ]; then
    echo "✓ Authorization 端点似乎正确"
else
    echo "✗ Authorization 端点可能有问题 (HTTP $AUTH_CODE)"
fi

if [ "$TOKEN_CODE" = "400" ] || [ "$TOKEN_CODE" = "401" ] || [ "$TOKEN_CODE" = "403" ]; then
    echo "✓ Token 端点似乎正确（返回 4xx 是正常的，表示缺少凭证）"
elif [ "$TOKEN_CODE" = "404" ]; then
    echo "✗ Token 端点返回 404 - URL 可能不正确"
    echo "  建议检查实际的 Token 端点 URL"
else
    echo "? Token 端点返回 $TOKEN_CODE"
fi

if [ "$USERINFO_CODE" = "401" ] || [ "$USERINFO_CODE" = "400" ]; then
    echo "✓ UserInfo 端点似乎正确（返回 401 是正常的，表示需要有效的 token）"
elif [ "$USERINFO_CODE" = "404" ]; then
    echo "✗ UserInfo 端点返回 404 - URL 可能不正确"
else
    echo "? UserInfo 端点返回 $USERINFO_CODE"
fi

echo ""
echo "=== 建议 ==="
echo ""
echo "如果测试失败，请："
echo "1. 查看 OIDC 提供商的官方文档"
echo "2. 确认正确的授权端点、Token 端点和 UserInfo 端点"
echo "3. 检查是否需要额外的步骤（如 PKCE 支持）"
echo "4. 验证客户端 ID 和密钥是否正确"
echo ""

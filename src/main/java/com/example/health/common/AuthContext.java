package com.example.health.common;

public final class AuthContext {
    private static final ThreadLocal<AuthUser> HOLDER = new ThreadLocal<>();

    private AuthContext() {
    }

    public static void set(AuthUser user) {
        HOLDER.set(user);
    }

    public static AuthUser get() {
        return HOLDER.get();
    }

    public static void clear() {
        HOLDER.remove();
    }

    public static void requireAdmin() {
        AuthUser user = get();
        if (user == null || !"ADMIN".equals(user.getRole())) {
            throw new BusinessException("无权操作，需要管理员权限");
        }
    }
}

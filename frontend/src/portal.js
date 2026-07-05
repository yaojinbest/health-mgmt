/** 根据 URL 路径区分患者 H5 与医生/管理员工作台 */
const WORKBENCH_PREFIXES = ['/manage', '/workbench', '/admin']

export function getPortal() {
  const path = window.location.pathname.replace(/\/+$/, '') || '/'
  if (WORKBENCH_PREFIXES.some(prefix => path === prefix || path.startsWith(`${prefix}/`))) {
    return 'workbench'
  }
  return 'patient'
}

export function portalLoginPath(portal = getPortal()) {
  return portal === 'workbench' ? '/manage' : '/'
}

export function portalTitle(portal = getPortal()) {
  return portal === 'workbench' ? '健康管理工作台' : '健康管理 · 患者端'
}

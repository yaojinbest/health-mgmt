<template>
  <main class="app" :class="shellClass">
    <div v-if="notice.text" class="toast" :class="notice.type">{{ notice.text }}</div>
    <div v-if="busy" class="loading">处理中...</div>
    <section v-if="!session.user" class="login-page" :class="{ 'login-h5': isPatientPortal, 'login-workbench': isWorkbenchPortal }">
      <!-- 患者端 H5 登录：/ -->
      <template v-if="isPatientPortal">
        <div class="login-visual">
          <div class="brand">
            <span>Patient Health</span>
            <strong>健康管理 · 患者端</strong>
          </div>
          <div class="login-copy">
            <h1>预约、监测、用药与在线咨询</h1>
            <p>移动端专属入口，随时管理您的健康档案。</p>
          </div>
        </div>
        <div class="panel login-card">
          <div class="login-title">
            <strong>患者登录</strong>
            <span>登录后进入移动 H5 首页</span>
          </div>
          <label>账号<input v-model="loginForm.username" autocomplete="username" /></label>
          <label>密码<input v-model="loginForm.password" type="password" autocomplete="current-password" /></label>
          <button class="primary" :disabled="busy" @click="login">{{ showRegister ? '注册并登录' : '登录' }}</button>
          <button class="ghost" type="button" @click="showRegister = !showRegister">{{ showRegister ? '已有账号，去登录' : '新用户注册' }}</button>
          <div v-if="showRegister" class="register-fields">
            <label>姓名<input v-model="registerForm.realName" /></label>
            <label>手机<input v-model="registerForm.phone" /></label>
            <label>性别<input v-model="registerForm.gender" /></label>
            <label>年龄<input v-model.number="registerForm.age" type="number" /></label>
          </div>
          <div class="demo-accounts">
            <span>演示账号 user_wang / root</span>
          </div>
        </div>
      </template>

      <!-- 医生/管理员工作台：/manage -->
      <template v-else>
        <div class="login-visual">
          <div class="brand">
            <span>Health Workbench</span>
            <strong>健康管理工作台</strong>
          </div>
          <div class="login-copy">
            <h1>医生诊疗与运营统计统一管理</h1>
            <p>PC 端工作台，支持排班、预约、咨询与数据维护。</p>
          </div>
          <div class="login-metrics">
            <div><strong>2</strong><span>工作台角色</span></div>
            <div><strong>15</strong><span>业务数据表</span></div>
            <div><strong>2026</strong><span>演示数据</span></div>
          </div>
        </div>
        <div class="panel login-card">
          <div class="login-title">
            <strong>工作台登录</strong>
            <span>请选择医生或管理员身份</span>
          </div>
          <div class="segmented workbench-segmented">
            <button :class="{ active: loginForm.role === 'DOCTOR' }" @click="selectRole('DOCTOR')">
              <span>医生端</span><small>诊疗工作台</small>
            </button>
            <button :class="{ active: loginForm.role === 'ADMIN' }" @click="selectRole('ADMIN')">
              <span>管理端</span><small>统计与维护</small>
            </button>
          </div>
          <label>账号<input v-model="loginForm.username" autocomplete="username" /></label>
          <label>密码<input v-model="loginForm.password" type="password" autocomplete="current-password" /></label>
          <button class="primary" :disabled="busy" @click="login">登录</button>
          <div class="demo-accounts">
            <span>医生 doctor_zhang / root</span>
            <span>管理员 admin / root</span>
          </div>
          <p class="login-portal-hint">患者请使用手机端访问：<a href="/">首页 /</a></p>
        </div>
      </template>
    </section>

    <template v-else>
      <!-- 患者 H5 顶栏 -->
      <header v-if="session.user.role === 'USER' && showMobileHeader" class="m-header">
        <div class="m-header-bg"></div>
        <div class="m-header-inner">
          <div class="m-user">
            <div class="m-avatar">{{ avatarText }}</div>
            <div>
              <p class="m-greet">{{ greetingText }}</p>
              <strong>{{ session.user.realName }}</strong>
            </div>
          </div>
          <button class="m-logout" @click="logout">退出</button>
        </div>
      </header>

      <!-- PC 侧边栏 + 顶栏 -->
      <nav v-if="session.user.role !== 'USER'" class="tabs wb-sidebar">
        <div class="wb-sidebar-brand">
          <span class="wb-sidebar-logo">{{ session.user.role === 'ADMIN' ? '管' : '医' }}</span>
          <div>
            <strong>{{ session.user.role === 'ADMIN' ? '健康管理后台' : '医生工作台' }}</strong>
            <small>Health Workbench</small>
          </div>
        </div>
        <div class="wb-nav-list">
          <button
            v-for="item in menus"
            :key="item.key"
            type="button"
            class="wb-nav-item"
            :class="{ active: tab === item.key }"
            @click="switchTab(item.key)"
          >
            <span class="wb-nav-icon">{{ item.icon }}</span>
            <span class="wb-nav-label">{{ item.label }}</span>
          </button>
        </div>
      </nav>

      <header v-if="session.user.role !== 'USER'" class="topbar wb-topbar">
        <div class="wb-topbar-main">
          <strong>{{ title }}</strong>
          <span>{{ session.user.realName }} · {{ roleText }}</span>
        </div>
        <button type="button" class="ghost wb-logout" @click="logout">退出登录</button>
      </header>

      <section v-if="tab === 'home'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <template v-if="session.user.role === 'USER'">
          <div class="m-hero">
            <div class="m-hero-text">
              <span>今日健康概览</span>
              <strong>用心守护每一天</strong>
            </div>
            <div class="m-hero-badge">{{ homeCards[2].value > 0 ? '有异常' : '状态良好' }}</div>
          </div>
          <div class="m-stats">
            <button
              v-for="card in homeCards"
              :key="card.label"
              type="button"
              class="m-stat"
              :class="cardTone(card.label)"
              @click="openHomeStat(card.key)"
            >
              <span>{{ card.icon }}</span>
              <strong>{{ card.value }}</strong>
              <small>{{ card.label }}</small>
            </button>
          </div>
          <div class="m-section-title">快捷服务</div>
          <div class="m-quick-grid">
            <button v-for="item in quickActions" :key="item.key" class="m-quick-item" @click="switchTab(item.key)">
              <span class="m-quick-icon" :style="{ background: item.bg }">{{ item.icon }}</span>
              <strong>{{ item.label }}</strong>
              <small>{{ item.desc }}</small>
            </button>
          </div>
          <div class="m-section-title">今日提醒</div>
          <div class="m-reminder-list">
            <div v-for="(item, idx) in reminders" :key="idx" class="m-reminder-item">
              <span class="m-reminder-dot"></span>
              <p>{{ item }}</p>
            </div>
          </div>
        </template>
        <template v-else-if="session.user.role === 'ADMIN'">
          <div class="wb-page-header">
            <div>
              <h1>平台概览</h1>
              <p>全平台关键指标与待办事项</p>
            </div>
            <button type="button" class="adm-btn" :disabled="adminLoading.overview" @click="refreshAdminOverview">刷新</button>
          </div>
          <div class="grid cards wb-metrics">
            <button
              v-for="card in adminHomeCards"
              :key="card.key"
              type="button"
              class="metric wb-metric-card wb-metric-link"
              @click="openAdminHomeCard(card.key)"
            >
              <span>{{ card.label }}</span>
              <strong>{{ card.value }}</strong>
              <small>{{ card.hint }}</small>
            </button>
          </div>
          <div class="adm-overview-grid">
            <div class="panel wb-section">
              <div class="wb-section-head">
                <h2>待办提醒</h2>
                <p>需要优先处理的平台事项</p>
              </div>
              <ul class="wb-reminder-list wb-reminder-action">
                <li v-for="item in adminReminders" :key="item.key">
                  <div>
                    <strong>{{ item.title }}</strong>
                    <p>{{ item.desc }}</p>
                  </div>
                  <button v-if="item.tab" type="button" class="adm-btn" @click="switchTab(item.tab)">去处理</button>
                </li>
              </ul>
            </div>
            <div class="panel wb-section">
              <div class="wb-section-head">
                <h2>快捷入口</h2>
                <p>常用后台维护功能</p>
              </div>
              <div class="adm-quick-links">
                <button type="button" class="adm-quick-link" @click="switchTab('medical')">🏥 医疗维护</button>
                <button type="button" class="adm-quick-link" @click="switchTab('appointment')">📅 预约管理</button>
                <button type="button" class="adm-quick-link" @click="switchTab('emergency')">🆘 救援记录</button>
                <button type="button" class="adm-quick-link" @click="switchTab('article')">📚 知识文章</button>
              </div>
            </div>
          </div>
        </template>
        <template v-else>
          <div class="wb-page-header">
            <div>
              <h1>数据概览</h1>
              <p>今日关键指标与提醒事项</p>
            </div>
            <button v-if="session.user.role === 'DOCTOR'" type="button" class="adm-btn" @click="refreshDoctorOverview">刷新</button>
          </div>
          <div class="grid cards wb-metrics">
            <button
              v-for="card in homeCards"
              :key="card.key"
              type="button"
              class="metric wb-metric-card wb-metric-link"
              @click="openHomeStat(card.key)"
            >
              <span>{{ card.label }}</span>
              <strong>{{ card.value }}</strong>
            </button>
          </div>
          <div class="panel wb-section">
            <div class="wb-section-head">
              <h2>今日提醒</h2>
            </div>
            <ul class="wb-reminder-list">
              <li v-for="item in reminders" :key="item">{{ item }}</li>
            </ul>
          </div>
        </template>
      </section>

      <!-- 患者「我的」页 -->
      <section v-if="tab === 'mine' && session.user.role === 'USER'" class="content m-page">
        <div class="m-profile-card">
          <div class="m-avatar lg">{{ avatarText }}</div>
          <div>
            <strong>{{ session.user.realName }}</strong>
            <p>{{ session.user.phone || '未绑定手机' }} · {{ session.user.gender }} · {{ session.user.age }}岁</p>
          </div>
        </div>
        <div class="m-menu-grid">
          <button v-for="item in mineMenus" :key="item.key" class="m-menu-item" @click="switchTab(item.key)">
            <span>{{ item.icon }}</span>
            <strong>{{ item.label }}</strong>
            <small>{{ item.desc }}</small>
          </button>
        </div>
      </section>

      <section v-if="tab === 'archive'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <div v-if="session.user.role === 'USER'" class="m-page-head">
          <button class="m-back" @click="switchTab('mine')">← 返回</button>
          <h1>健康档案</h1>
        </div>
        <div v-if="session.user.role === 'USER'" class="panel m-card">
          <h2>个人健康档案</h2>
          <div class="form-grid">
            <label>姓名<input v-model="archive.name" /></label>
            <label>年龄<input v-model.number="archive.age" type="number" /></label>
            <label>性别<input v-model="archive.gender" /></label>
            <label>身高(cm)<input v-model="archive.height" /></label>
            <label>体重(kg)<input v-model="archive.weight" /></label>
            <label>血型<input v-model="archive.bloodType" /></label>
          </div>
          <label>既往病史<textarea v-model="archive.diseaseHistory" /></label>
          <label>过敏史<textarea v-model="archive.allergyHistory" /></label>
          <label>常用药物<textarea v-model="archive.commonMedicine" /></label>
          <button class="primary" :disabled="busy" @click="saveArchive">保存档案</button>
        </div>
        <div v-if="session.user.role === 'USER'" class="panel m-card">
          <h2>档案附件</h2>
          <div class="upload-bar">
            <input type="file" accept=".pdf,.jpg,.jpeg,.png" @change="uploadArchiveFile" />
            <span class="hint">支持 PDF / 图片，需先保存档案</span>
          </div>
          <p v-if="!archiveFiles.length" class="empty">暂无附件</p>
          <p v-for="file in archiveFiles" :key="file.id">
            <a :href="file.fileUrl" target="_blank" rel="noopener">{{ file.fileName }}</a> · {{ formatDateTime(file.uploadTime) }}
          </p>
        </div>
        <ListPanel v-else title="授权用户档案" :items="archiveRows" :fields="['name','gender','age','bloodType','diseaseHistory','updateTime']" :labels="archiveLabels">
          <template #actions="{ item }">
            <button type="button" class="adm-action primary" @click="viewArchiveDetail(item.userId)">查看详情</button>
          </template>
        </ListPanel>
        <div v-if="archiveDetail" class="panel adm-form-card">
          <div class="adm-form-card-head">
            <strong>{{ archiveDetail.archive?.name || '档案详情' }}</strong>
            <button type="button" class="adm-btn" @click="closeArchiveDetail">关闭详情</button>
          </div>
          <p>性别：{{ archiveDetail.archive?.gender }} · 年龄：{{ archiveDetail.archive?.age }} · 血型：{{ archiveDetail.archive?.bloodType }}</p>
          <p>既往病史：{{ archiveDetail.archive?.diseaseHistory || '无' }}</p>
          <p>过敏史：{{ archiveDetail.archive?.allergyHistory || '无' }}</p>
          <p>常用药物：{{ archiveDetail.archive?.commonMedicine || '无' }}</p>
          <p v-if="!archiveDetail.files?.length" class="empty">暂无附件</p>
          <p v-for="file in archiveDetail.files || []" :key="file.id">
            <a :href="file.fileUrl" target="_blank" rel="noopener">{{ file.fileName }}</a>
          </p>
        </div>
      </section>

      <section v-if="tab === 'appointment'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <template v-if="session.user.role === 'USER' && appointmentView === 'list'">
          <div class="m-page-head m-consult-head">
            <button type="button" class="m-back" @click="switchTab('home')">← 返回</button>
            <h1>预约挂号</h1>
            <button type="button" class="m-consult-new" @click="openBookAppointment">+ 新建</button>
          </div>
          <div v-if="!appointments.length" class="m-empty-state">
            <span class="m-empty-icon">📅</span>
            <strong>暂无预约记录</strong>
            <p>点击右上角「新建」，选择医生与出诊时段</p>
            <button type="button" class="primary" @click="openBookAppointment">立即预约</button>
          </div>
          <ListPanel
            v-else
            title="我的预约记录"
            :items="appointments"
            :fields="appointmentFields"
            :labels="appointmentLabels"
            mobile
          >
            <template #actions="{ item }">
              <button v-if="item.status === 'CONFIRMED'" :disabled="busy" @click="cancelAppointment(item.id)">取消</button>
            </template>
          </ListPanel>
        </template>

        <template v-if="session.user.role === 'USER' && appointmentView === 'book'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="appointmentView = 'list'">← 返回</button>
            <h1>新建预约</h1>
          </div>
          <div class="panel m-card m-appointment-form">
            <div class="m-appt-steps">
              <span class="active">选医院</span>
              <span :class="{ active: appointment.hospitalId }">选科室</span>
              <span :class="{ active: appointment.doctorId }">选医生</span>
              <span :class="{ active: appointment.scheduleId }">选时段</span>
            </div>
            <div class="m-form-stack">
              <div class="m-field">
                <span class="m-field-label">选择医院</span>
                <div class="m-chip-picker">
                  <button
                    v-for="item in hospitals"
                    :key="item.id"
                    type="button"
                    class="m-chip-option"
                    :class="{ active: String(appointment.hospitalId) === String(item.id) }"
                    @click="selectAppointmentHospital(item.id)"
                  >
                    {{ item.name }}
                  </button>
                </div>
              </div>
              <div class="m-field">
                <span class="m-field-label">选择科室</span>
                <p v-if="!departments.length" class="hint">请先选择医院</p>
                <div v-else class="m-chip-picker">
                  <button
                    v-for="item in departments"
                    :key="item.id"
                    type="button"
                    class="m-chip-option"
                    :class="{ active: String(appointment.departmentId) === String(item.id) }"
                    @click="selectAppointmentDepartment(item.id)"
                  >
                    {{ item.name }}
                  </button>
                </div>
              </div>
              <div class="m-field">
                <span class="m-field-label">选择医生</span>
                <p v-if="!doctors.length" class="hint">当前科室暂无医生</p>
                <div v-else class="m-doctor-picker m-doctor-picker-compact">
                  <button
                    v-for="item in doctors"
                    :key="item.id"
                    type="button"
                    class="m-doctor-option"
                    :class="{ active: String(appointment.doctorId) === String(item.id) }"
                    @click="selectAppointmentDoctor(item.id)"
                  >
                    <span class="m-doctor-name">{{ item.doctorName || ('医生 #' + item.id) }} · {{ item.title }}</span>
                    <span class="m-doctor-spec">{{ item.specialty }}</span>
                  </button>
                </div>
              </div>
              <div v-if="appointment.doctorId" class="m-field">
                <span class="m-field-label">选择出诊日期</span>
                <p v-if="!appointmentScheduleDates.length" class="hint">当前医生暂无可预约号源</p>
                <div v-else class="m-schedule-date-row">
                  <button
                    v-for="dateKey in appointmentScheduleDates"
                    :key="dateKey"
                    type="button"
                    class="m-schedule-date-chip"
                    :class="{ active: appointmentScheduleDate === dateKey }"
                    @click="selectAppointmentScheduleDate(dateKey)"
                  >
                    {{ formatScheduleDateLabel(dateKey) }}
                  </button>
                </div>
              </div>
              <div v-if="appointmentScheduleDate" class="m-field">
                <span class="m-field-label">选择时段</span>
                <div class="m-schedule-slot-grid">
                  <button
                    v-for="item in filteredBookableSchedules"
                    :key="item.id"
                    type="button"
                    class="m-schedule-slot"
                    :class="{ active: String(appointment.scheduleId) === String(item.id) }"
                    @click="selectAppointmentSchedule(item.id)"
                  >
                    <strong>{{ item.timeSlot }}</strong>
                    <span>剩余 {{ item.remainQuota }} 号</span>
                  </button>
                </div>
              </div>
              <label class="m-field">
                <span class="m-field-label">症状描述</span>
                <textarea v-model="appointment.symptom" placeholder="简要描述您的症状或就诊需求" rows="3" />
              </label>
            </div>
          </div>
          <div class="m-appt-submit-bar">
            <p v-if="selectedScheduleSummary" class="m-appt-summary">{{ selectedScheduleSummary }}</p>
            <p v-else class="m-appt-summary muted">请完成医院、科室、医生与时段选择</p>
            <button type="button" class="primary" :disabled="busy || !appointment.scheduleId" @click="createAppointment">提交预约</button>
          </div>
        </template>
        <ListPanel v-if="session.user.role === 'DOCTOR'" title="预约记录" :items="appointments" :fields="appointmentFields" :labels="appointmentLabels">
          <template #actions="{ item }">
            <button v-if="item.status === 'CONFIRMED'" type="button" class="adm-action primary" :disabled="busy" @click="finishAppointment(item.id)">完成就诊</button>
          </template>
        </ListPanel>
        <AdminPageShell v-if="session.user.role === 'ADMIN'" icon="📅" title="预约管理" subtitle="查看并跟踪全平台预约订单">
          <template #actions>
            <button type="button" class="adm-btn" :disabled="busy" @click="loadAppointments">刷新列表</button>
          </template>
          <AdminListPanel
            title="预约列表"
            subtitle="支持按患者、医院、医生与状态筛选"
            :items="appointments"
            :fields="appointmentFields"
            :labels="appointmentLabels"
            status-field="status"
            :status-tabs="adminAppointmentStatusTabs"
            primary-field="userName"
            :loading="adminLoading.appointment"
            empty-text="暂无预约记录"
            empty-hint="当前还没有任何预约数据"
          >
            <template #actions="{ item }">
              <button
                v-if="item.status === 'CONFIRMED'"
                type="button"
                class="adm-action primary"
                :disabled="busy"
                @click="finishAppointment(item.id)"
              >
                完成就诊
              </button>
              <button
                v-if="item.status === 'CONFIRMED'"
                type="button"
                class="adm-action danger"
                :disabled="busy"
                @click="cancelAppointment(item.id)"
              >
                取消预约
              </button>
              <span v-if="item.status !== 'CONFIRMED'" class="adm-action muted">{{ item.statusText }}</span>
            </template>
          </AdminListPanel>
        </AdminPageShell>
      </section>

      <section v-if="tab === 'medicine'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <div v-if="session.user.role === 'DOCTOR'" class="wb-page-header">
          <div>
            <h1>患者用药</h1>
            <p>查看与您有关联的患者的用药记录</p>
          </div>
          <button type="button" class="adm-btn" :disabled="busy" @click="loadMedicines">刷新</button>
        </div>
        <template v-if="session.user.role === 'USER' && medicineView === 'list'">
          <div class="m-page-head m-consult-head">
            <button type="button" class="m-back" @click="switchTab('mine')">← 返回</button>
            <h1>用药管理</h1>
            <button type="button" class="m-consult-new" @click="medicineView = 'add'">+ 添加</button>
          </div>
          <div class="m-medicine-list">
            <div v-if="!medicines.length" class="m-empty-state">
              <span class="m-empty-icon">💊</span>
              <strong>暂无用药记录</strong>
              <p>点击右上角「添加」，记录您的用药信息</p>
              <button type="button" class="primary" @click="medicineView = 'add'">添加用药</button>
            </div>
            <div v-for="item in paginatedMedicines" :key="item.id" class="m-medicine-card">
              <div class="m-medicine-top">
                <strong>{{ item.medicineName }}</strong>
                <span class="m-consult-badge" :class="item.status === 'ACTIVE' ? 'open' : 'closed'">{{ item.statusText }}</span>
              </div>
              <p class="m-medicine-line">{{ item.usageMethod || '-' }} · {{ item.dosage || '-' }}</p>
              <p class="m-medicine-line">提醒 {{ item.reminderTimes || '-' }} · {{ item.startDate || '-' }} 至 {{ item.endDate || '-' }}</p>
              <p v-if="item.warning" class="m-medicine-warn">{{ item.warning }}</p>
              <div v-if="item.status === 'ACTIVE'" class="m-record-actions">
                <button type="button" :disabled="busy" @click="finishMedicine(item.id)">结束用药</button>
              </div>
            </div>
          </div>
          <PaginationBar
            v-if="medicines.length"
            :page="medicinePage"
            :page-size="medicinePageSize"
            :total="medicineTotal"
            :total-pages="medicineTotalPages"
            :range-start="medicineRangeStart"
            :range-end="medicineRangeEnd"
            mobile
            @update:page="goMedicinePage"
            @update:page-size="setMedicinePageSize"
          />
        </template>

        <template v-if="session.user.role === 'USER' && medicineView === 'add'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="medicineView = 'list'">← 返回</button>
            <h1>添加用药</h1>
          </div>
          <div class="panel m-card">
            <div class="m-form-stack">
              <label class="m-field"><span class="m-field-label">药品</span><input v-model="medicine.medicineName" placeholder="如：氨氯地平片" /></label>
              <label class="m-field"><span class="m-field-label">用法</span><input v-model="medicine.usageMethod" placeholder="如：口服" /></label>
              <label class="m-field"><span class="m-field-label">用量</span><input v-model="medicine.dosage" placeholder="如：每日1次，每次1片" /></label>
              <label class="m-field"><span class="m-field-label">提醒时间</span><input v-model="medicine.reminderTimes" placeholder="如：08:00" /></label>
              <label class="m-field"><span class="m-field-label">开始日期</span><input v-model="medicine.startDate" type="date" /></label>
              <label class="m-field"><span class="m-field-label">结束日期</span><input v-model="medicine.endDate" type="date" /></label>
            </div>
            <button type="button" class="primary" :disabled="busy" @click="saveMedicine">保存用药</button>
          </div>
        </template>

        <ListPanel v-if="session.user.role !== 'USER'" title="患者用药记录" :items="scopedMedicines" :fields="medicineListFields" :labels="medicineLabels" />
      </section>

      <section v-if="tab === 'health' && session.user.role === 'USER'" class="content m-page">
        <template v-if="healthView === 'list'">
          <div class="m-page-head m-consult-head">
            <button type="button" class="m-back" @click="switchTab('home')">← 返回</button>
            <h1>健康监测</h1>
            <button type="button" class="m-consult-new" @click="openAddHealth">+ 录入</button>
          </div>

          <div class="panel m-card m-health-chart-panel">
            <div class="m-health-chart-head">
              <strong>指标趋势</strong>
              <span v-if="healthWarnCount" class="m-health-warn-tag">{{ healthWarnCount }} 条异常</span>
            </div>
            <div id="healthChart" class="m-health-chart"></div>
          </div>

          <div v-if="!healthList.length" class="m-empty-state">
            <span class="m-empty-icon">💓</span>
            <strong>暂无监测记录</strong>
            <p>录入血压、血糖等指标，系统将自动分析并生成趋势图</p>
            <button type="button" class="primary" @click="openAddHealth">录入第一条数据</button>
          </div>

          <template v-else>
            <div class="m-section-title">监测记录 · 共 {{ healthTotal }} 条</div>
            <div class="m-health-list">
              <article
                v-for="item in paginatedHealthRecords"
                :key="item.id"
                class="m-health-card"
                :class="{ warn: item.warningLevel === 'WARN' }"
              >
                <div class="m-health-card-top">
                  <span>{{ item.recordTimeDisplay }}</span>
                  <span class="m-health-badge" :class="item.warningLevel === 'WARN' ? 'warn' : 'ok'">
                    {{ item.warningLevel === 'WARN' ? '异常' : '正常' }}
                  </span>
                </div>
                <div class="m-health-metrics">
                  <div class="m-health-metric">
                    <small>血压</small>
                    <strong>{{ item.systolic ?? '-' }}/{{ item.diastolic ?? '-' }}</strong>
                  </div>
                  <div class="m-health-metric">
                    <small>血糖</small>
                    <strong>{{ item.bloodSugar ?? '-' }}</strong>
                  </div>
                  <div class="m-health-metric">
                    <small>心率</small>
                    <strong>{{ item.heartRate ?? '-' }}</strong>
                  </div>
                  <div class="m-health-metric">
                    <small>步数</small>
                    <strong>{{ item.steps ?? '-' }}</strong>
                  </div>
                </div>
                <p v-if="item.warningMessage && item.warningLevel === 'WARN'" class="m-health-card-warn">{{ item.warningMessage }}</p>
              </article>
            </div>
            <PaginationBar
              :page="healthPage"
              :page-size="healthPageSize"
              :total="healthTotal"
              :total-pages="healthTotalPages"
              :range-start="healthRangeStart"
              :range-end="healthRangeEnd"
              mobile
              @update:page="goHealthPage"
              @update:page-size="setHealthPageSize"
            />
          </template>
        </template>

        <template v-if="healthView === 'add'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="closeAddHealth">← 返回</button>
            <h1>录入健康数据</h1>
          </div>
          <div class="panel m-card m-health-form">
            <div class="m-form-stack">
              <div class="m-health-form-grid">
                <label class="m-field"><span class="m-field-label">收缩压 (mmHg)</span><input v-model.number="health.systolic" type="number" placeholder="如 120" /></label>
                <label class="m-field"><span class="m-field-label">舒张压 (mmHg)</span><input v-model.number="health.diastolic" type="number" placeholder="如 80" /></label>
                <label class="m-field"><span class="m-field-label">血糖 (mmol/L)</span><input v-model="health.bloodSugar" placeholder="如 5.6" /></label>
                <label class="m-field"><span class="m-field-label">心率 (次/分)</span><input v-model.number="health.heartRate" type="number" placeholder="如 76" /></label>
                <label class="m-field"><span class="m-field-label">步数</span><input v-model.number="health.steps" type="number" placeholder="如 8000" /></label>
                <label class="m-field"><span class="m-field-label">睡眠 (小时)</span><input v-model="health.sleepHours" placeholder="如 7.5" /></label>
                <label class="m-field m-health-form-wide"><span class="m-field-label">体重 (kg)</span><input v-model="health.weight" placeholder="如 60" /></label>
              </div>
            </div>
          </div>
          <div class="m-appt-submit-bar">
            <p class="m-appt-summary muted">至少填写一项指标，保存后自动分析是否异常</p>
            <button type="button" class="primary" :disabled="busy" @click="saveHealthData">保存数据</button>
          </div>
        </template>
      </section>

      <section v-if="tab === 'emergency'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <template v-if="session.user.role === 'USER' && emergencyView === 'list'">
          <div class="m-page-head m-consult-head">
            <button type="button" class="m-back" @click="switchTab('mine')">← 返回</button>
            <h1>紧急求救</h1>
            <button type="button" class="m-consult-new" @click="openAddContact">+ 联系人</button>
          </div>

          <button type="button" class="m-emergency-sos-banner panel m-card" @click="openEmergencySos">
            <span class="m-emergency-sos-banner-icon">🆘</span>
            <div class="m-emergency-sos-banner-body">
              <strong>一键求救</strong>
              <p v-if="contacts.length">已设置 {{ contacts.length }} 位紧急联系人，点击发送求救</p>
              <p v-else>请先添加紧急联系人后再发送求救</p>
            </div>
            <span class="m-emergency-sos-arrow">›</span>
          </button>

          <div class="m-section-title">紧急联系人 · 共 {{ contacts.length }} 人</div>
          <div v-if="!contacts.length" class="m-empty-state m-empty-compact">
            <strong>暂无紧急联系人</strong>
            <p>添加家人或朋友，求救时将自动通知对方</p>
            <button type="button" class="primary" @click="openAddContact">添加联系人</button>
          </div>
          <div v-else class="m-emergency-contact-list">
            <article v-for="item in contacts" :key="item.id" class="m-emergency-contact-card">
              <div class="m-emergency-contact-main">
                <strong>{{ item.name }}</strong>
                <span>{{ item.relation || '联系人' }}</span>
              </div>
              <div class="m-emergency-contact-phone">{{ item.phone }}</div>
              <button type="button" class="m-emergency-contact-del" :disabled="busy" @click="deleteContact(item.id)">删除</button>
            </article>
          </div>

          <div class="m-section-title">求救记录 · 共 {{ emergencyTotal }} 条</div>
          <div v-if="!emergencyRecords.length" class="m-empty-state m-empty-compact">
            <strong>暂无求救记录</strong>
            <p>发生紧急情况时，可通过上方入口一键发送求救</p>
          </div>
          <div v-else class="m-emergency-record-list">
            <article
              v-for="item in paginatedEmergencyRecords"
              :key="item.id"
              class="m-emergency-record-card"
              :class="{ processing: item.status === 'PROCESSING' }"
            >
              <div class="m-emergency-record-top">
                <span>{{ item.helpTime }}</span>
                <span class="m-emergency-badge" :class="item.status === 'PROCESSING' ? 'processing' : 'finished'">
                  {{ item.statusText }}
                </span>
              </div>
              <p class="m-emergency-record-line">📍 {{ item.locationText || '-' }}</p>
              <p v-if="item.result && item.result !== '-'" class="m-emergency-record-result">处理结果：{{ item.result }}</p>
              <p v-if="item.contactSnapshot && item.contactSnapshot !== '-'" class="m-emergency-record-contacts">
                已通知：{{ formatContactSnapshot(item.contactSnapshot) }}
              </p>
            </article>
          </div>
          <PaginationBar
            v-if="emergencyRecords.length"
            :page="emergencyPage"
            :page-size="emergencyPageSize"
            :total="emergencyTotal"
            :total-pages="emergencyTotalPages"
            :range-start="emergencyRangeStart"
            :range-end="emergencyRangeEnd"
            mobile
            @update:page="goEmergencyPage"
            @update:page-size="setEmergencyPageSize"
          />
        </template>

        <template v-if="session.user.role === 'USER' && emergencyView === 'sos'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="emergencyView = 'list'">← 返回</button>
            <h1>一键求救</h1>
          </div>
          <div class="panel m-card m-emergency-sos-panel">
            <div class="m-sos-icon">🆘</div>
            <p class="m-emergency-sos-tip">系统将通知您设置的紧急联系人，请确认位置信息准确</p>
            <label class="m-field">
              <span class="m-field-label">当前位置</span>
              <input v-model="emergency.locationText" placeholder="请输入您当前所在位置" />
            </label>
            <div v-if="contacts.length" class="m-emergency-sos-contacts">
              <small>将通知以下联系人</small>
              <p>{{ contacts.map(item => `${item.name}(${item.relation || '联系人'})`).join('、') }}</p>
            </div>
            <p v-else class="hint">请先返回添加至少一位紧急联系人</p>
          </div>
          <div class="m-appt-submit-bar">
            <p class="m-appt-summary muted">发送后可在列表中查看处理进度</p>
            <button type="button" class="danger m-sos-btn" :disabled="busy || !contacts.length" @click="sendHelp">立即发送求救</button>
          </div>
        </template>

        <template v-if="session.user.role === 'USER' && emergencyView === 'contact-add'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="emergencyView = 'list'">← 返回</button>
            <h1>添加联系人</h1>
          </div>
          <div class="panel m-card">
            <div class="m-form-stack">
              <label class="m-field"><span class="m-field-label">姓名</span><input v-model="contact.name" placeholder="如：王建国" /></label>
              <label class="m-field"><span class="m-field-label">关系</span><input v-model="contact.relation" placeholder="如：父亲" /></label>
              <label class="m-field"><span class="m-field-label">电话</span><input v-model="contact.phone" placeholder="如：13800000000" /></label>
            </div>
          </div>
          <div class="m-appt-submit-bar">
            <p class="m-appt-summary muted">建议至少添加 1 位可及时联系的家人或朋友</p>
            <button type="button" class="primary" :disabled="busy" @click="saveContact">保存联系人</button>
          </div>
        </template>
        <AdminPageShell v-if="session.user.role === 'ADMIN'" icon="🆘" title="救援记录" subtitle="紧急求救事件处理与跟踪">
          <template #actions>
            <button type="button" class="adm-btn" :disabled="busy" @click="loadEmergencyRecords">刷新列表</button>
          </template>
          <AdminListPanel
            title="求救事件"
            subtitle="按用户、位置与处理状态快速检索"
            :items="emergencyRecords"
            :fields="emergencyFields"
            :labels="emergencyLabels"
            status-field="status"
            :status-tabs="adminEmergencyStatusTabs"
            primary-field="userName"
            :loading="adminLoading.emergency"
            empty-text="暂无救援记录"
            empty-hint="系统尚未收到紧急求救事件"
          >
            <template #actions="{ item }">
              <button v-if="item.status !== 'FINISHED'" type="button" class="adm-action primary" :disabled="busy" @click="finishEmergency(item)">标记完成</button>
              <span v-else class="adm-action muted">已处理</span>
            </template>
          </AdminListPanel>
        </AdminPageShell>
        <ListPanel v-else-if="session.user.role === 'DOCTOR'" title="求救记录" :items="emergencyRecords" :fields="emergencyFields" :labels="emergencyLabels">
          <template #actions="{ item }">
            <button v-if="item.status !== 'FINISHED'" :disabled="busy" @click="finishEmergency(item.id)">标记完成</button>
          </template>
        </ListPanel>
      </section>

      <section v-if="tab === 'article'" class="content" :class="{ 'm-page': session.user.role === 'USER' }">
        <template v-if="session.user.role === 'USER' && articleView === 'list'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="switchTab('mine')">← 返回</button>
            <h1>健康知识</h1>
          </div>
          <div class="m-article-search">
            <input v-model="articleKeyword" placeholder="搜索疾病、饮食、运动..." @keyup.enter="searchArticles" />
            <button type="button" class="m-article-search-btn" :disabled="busy" @click="searchArticles">搜索</button>
          </div>
          <div v-if="!articles.length" class="m-empty-state">
            <span class="m-empty-icon">📚</span>
            <strong>暂无相关文章</strong>
            <p>换个关键词试试，或浏览全部科普内容</p>
            <button type="button" class="primary" @click="articleKeyword = ''; searchArticles()">查看全部</button>
          </div>
          <div v-else class="m-article-list">
            <article
              v-for="item in paginatedPatientArticles"
              :key="item.id"
              class="m-article-item"
              @click="openArticle(item.id)"
            >
              <div class="m-article-tags">
                <span class="m-tag">{{ item.category }}</span>
                <span v-if="item.diseaseTag" class="m-tag soft">{{ item.diseaseTag }}</span>
              </div>
              <strong>{{ item.title }}</strong>
              <p>{{ item.summary }}</p>
              <span class="m-article-meta">👁 {{ item.viewCount }} 次阅读</span>
            </article>
          </div>
          <PaginationBar
            v-if="articles.length"
            :page="patientArticlePage"
            :page-size="patientArticlePageSize"
            :total="patientArticleTotal"
            :total-pages="patientArticleTotalPages"
            :range-start="patientArticleRangeStart"
            :range-end="patientArticleRangeEnd"
            mobile
            @update:page="goPatientArticlePage"
            @update:page-size="setPatientArticlePageSize"
          />
        </template>

        <template v-if="session.user.role === 'USER' && articleView === 'detail' && selectedArticle">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="closeArticle">← 返回</button>
            <h1>文章详情</h1>
          </div>
          <article class="m-article-detail">
            <div class="m-article-tags">
              <span class="m-tag">{{ selectedArticle.category }}</span>
              <span v-if="selectedArticle.diseaseTag" class="m-tag soft">{{ selectedArticle.diseaseTag }}</span>
            </div>
            <h2>{{ selectedArticle.title }}</h2>
            <p class="m-article-meta">👁 {{ selectedArticle.viewCount }} 次阅读</p>
            <div class="m-article-body">{{ selectedArticle.content }}</div>
          </article>
        </template>

        <AdminPageShell v-if="session.user.role === 'ADMIN'" icon="📚" title="知识文章" subtitle="发布科普内容并管理阅读数据">
          <div class="adm-split adm-split-wide">
            <aside class="adm-form-side">
              <div class="adm-form-card">
                <div class="adm-form-card-head">
                  <strong>{{ articleForm.id ? '编辑文章' : '发布文章' }}</strong>
                  <span>填写标题、分类与正文后发布</span>
                </div>
                <div class="form-grid adm-form-grid">
                  <label>标题<input v-model="articleForm.title" placeholder="文章标题" /></label>
                  <label>分类<input v-model="articleForm.category" placeholder="如：饮食健康" /></label>
                  <label>疾病标签<input v-model="articleForm.diseaseTag" placeholder="如：高血压" /></label>
                </div>
                <label>摘要<textarea v-model="articleForm.summary" rows="2" placeholder="列表页展示的简短摘要" /></label>
                <label>正文<textarea v-model="articleForm.content" rows="8" placeholder="文章正文内容" /></label>
                <div class="adm-form-actions">
                  <button type="button" class="primary" :disabled="busy" @click="saveArticle">{{ articleForm.id ? '保存修改' : '立即发布' }}</button>
                  <button v-if="articleForm.id" type="button" class="adm-btn" @click="resetArticleForm">取消编辑</button>
                </div>
              </div>
              <article v-if="selectedArticle" class="adm-preview-card">
                <span class="adm-preview-label">预览</span>
                <strong>{{ selectedArticle.title }}</strong>
                <p>{{ selectedArticle.summary }}</p>
                <div class="adm-preview-body">{{ selectedArticle.content }}</div>
              </article>
            </aside>
            <div class="adm-list-side">
              <AdminListPanel
                title="文章列表"
                subtitle="服务端搜索后浏览，编辑不会增加阅读量"
                :items="articles"
                :fields="adminArticleFields"
                :labels="adminArticleLabels"
                primary-field="title"
                :loading="adminLoading.article"
                :searchable="false"
                empty-text="暂无文章"
                empty-hint="尝试调整搜索关键词，或发布第一篇科普文章"
              >
                <template #toolbar>
                  <div class="adm-search">
                    <input v-model="articleKeyword" placeholder="搜索标题、分类、标签..." @keyup.enter="searchArticles" />
                    <button type="button" class="adm-btn primary" :disabled="busy || adminLoading.article" @click="searchArticles">搜索</button>
                    <button v-if="articleKeyword" type="button" class="adm-btn" :disabled="busy || adminLoading.article" @click="clearArticleSearch">重置</button>
                  </div>
                </template>
                <template #actions="{ item }">
                  <button type="button" class="adm-action" @click="previewArticle(item.id)">查看</button>
                  <button type="button" class="adm-action primary" @click="editArticle(item)">编辑</button>
                  <button type="button" class="adm-action danger" :disabled="busy" @click="deleteArticle(item)">删除</button>
                </template>
              </AdminListPanel>
            </div>
          </div>
        </AdminPageShell>
        <template v-else-if="session.user.role === 'DOCTOR'">
          <div class="wb-page-header">
            <div>
              <h1>健康知识</h1>
              <p>浏览平台发布的健康科普文章</p>
            </div>
          </div>
          <div class="panel m-card">
            <div class="filters">
              <input v-model="articleKeyword" placeholder="搜索疾病、饮食、运动" @keyup.enter="searchArticles" />
              <button type="button" class="adm-btn primary" :disabled="busy" @click="searchArticles">搜索</button>
            </div>
          </div>
          <p v-if="!articles.length && !selectedArticle" class="panel empty">暂无文章，请调整搜索关键词</p>
          <article v-if="selectedArticle" class="panel article selected">
            <strong>{{ selectedArticle.title }}</strong>
            <span>{{ selectedArticle.category }} · {{ selectedArticle.diseaseTag }} · 阅读 {{ selectedArticle.viewCount }}</span>
            <p>{{ selectedArticle.content }}</p>
          </article>
          <article v-for="item in paginatedDoctorArticles" :key="item.id" class="panel article" @click="openArticle(item.id)">
            <strong>{{ item.title }}</strong>
            <span>{{ item.category }} · {{ item.diseaseTag }} · 阅读 {{ item.viewCount }}</span>
            <p>{{ item.summary }}</p>
          </article>
          <PaginationBar
            v-if="articles.length"
            :page="doctorArticlePage"
            :page-size="doctorArticlePageSize"
            :total="doctorArticleTotal"
            :total-pages="doctorArticleTotalPages"
            :range-start="doctorArticleRangeStart"
            :range-end="doctorArticleRangeEnd"
            @update:page="goDoctorArticlePage"
            @update:page-size="setDoctorArticlePageSize"
          />
        </template>
      </section>

      <section v-if="tab === 'consult'" class="content" :class="{ 'm-page': session.user.role === 'USER', 'm-consult-shell': session.user.role === 'USER' && consultView === 'chat' }">
        <!-- 患者：会话列表 -->
        <template v-if="session.user.role === 'USER' && consultView === 'list'">
          <div class="m-page-head m-consult-head">
            <h1>在线咨询</h1>
            <button type="button" class="m-consult-new" @click="consultView = 'create'">+ 新建</button>
          </div>
          <div class="m-consult-list">
            <div v-if="!consultations.length" class="m-empty-state">
              <span class="m-empty-icon">💬</span>
              <strong>暂无咨询会话</strong>
              <p>点击右上角「新建」，选择医生发起咨询</p>
              <button type="button" class="primary" @click="consultView = 'create'">发起咨询</button>
            </div>
            <button
              v-for="item in paginatedConsultations"
              :key="item.id"
              type="button"
              class="m-consult-item"
              @click="openConsultation(item)"
            >
              <div class="m-consult-item-icon">💬</div>
              <div class="m-consult-item-body">
                <div class="m-consult-item-top">
                  <strong>{{ item.title }}</strong>
                  <span class="m-consult-badge" :class="item.status === 'OPEN' ? 'open' : 'closed'">{{ item.statusText }}</span>
                </div>
                <p>{{ item.doctorName }}</p>
                <span>{{ formatDateTime(item.createTime) }}</span>
              </div>
              <span class="m-consult-arrow">›</span>
            </button>
          </div>
          <PaginationBar
            v-if="consultations.length"
            :page="consultPage"
            :page-size="consultPageSize"
            :total="consultTotal"
            :total-pages="consultTotalPages"
            :range-start="consultRangeStart"
            :range-end="consultRangeEnd"
            mobile
            @update:page="goConsultPage"
            @update:page-size="setConsultPageSize"
          />
        </template>

        <!-- 患者：新建咨询 -->
        <template v-if="session.user.role === 'USER' && consultView === 'create'">
          <div class="m-page-head">
            <button type="button" class="m-back" @click="consultView = 'list'">← 返回</button>
            <h1>发起咨询</h1>
          </div>
          <div class="panel m-card m-consult-form">
            <div class="m-form-stack">
              <div class="m-field">
                <span class="m-field-label">选择医生</span>
                <p v-if="!consultDoctors.length" class="hint">暂无可用医生</p>
                <div v-else class="m-doctor-picker">
                  <button
                    v-for="item in consultDoctors"
                    :key="item.id"
                    type="button"
                    class="m-doctor-option"
                    :class="{ active: String(consultForm.doctorId) === String(item.id) }"
                    @click="consultForm.doctorId = item.id"
                  >
                    <span class="m-doctor-name">{{ item.doctorName || ('医生 #' + item.id) }} · {{ item.title }}</span>
                    <span class="m-doctor-spec">{{ item.specialty }}</span>
                    <span class="m-doctor-meta">{{ item.hospitalName }} · {{ item.departmentName }}</span>
                  </button>
                </div>
              </div>
              <label class="m-field">
                <span class="m-field-label">咨询标题</span>
                <input v-model="consultForm.title" placeholder="简要描述您的问题，如：餐后血糖偏高" />
              </label>
            </div>
            <button type="button" class="primary" :disabled="busy || !consultForm.doctorId" @click="createConsultation">创建并进入会话</button>
          </div>
        </template>

        <!-- 患者：全屏聊天 -->
        <div v-if="session.user.role === 'USER' && consultView === 'chat' && activeConsultation" class="m-chat-room">
          <header class="m-chat-header">
            <button type="button" class="m-chat-back" @click="closeConsultChat">←</button>
            <div class="m-chat-header-info">
              <strong>{{ activeConsultation.title }}</strong>
              <span>{{ activeConsultation.doctorName }} · {{ activeConsultation.statusText }}</span>
            </div>
          </header>
          <div ref="chatBodyRef" class="m-chat-body">
            <div v-if="!messages.length" class="m-chat-empty">暂无消息，发送第一条咨询吧</div>
            <div
              v-for="item in messages"
              :key="item.id"
              class="m-msg-row"
              :class="item.senderRole === 'USER' ? 'me' : 'doctor'"
            >
              <div class="m-msg-wrap">
                <span class="m-msg-name">{{ item.senderRole === 'USER' ? '我' : '医生' }}</span>
                <div class="m-msg-bubble">{{ item.content }}</div>
              </div>
            </div>
          </div>
          <footer class="m-chat-footer">
            <p v-if="activeConsultation.status === 'CLOSED'" class="m-chat-closed">会话已关闭，无法继续发送消息</p>
            <div v-else-if="activeConsultation.status === 'OPEN'" class="m-chat-actions">
              <button type="button" class="adm-btn" :disabled="busy" @click="closeConsultation(activeConsultation.id)">结束咨询</button>
            </div>
            <div v-if="activeConsultation.status !== 'CLOSED'" class="m-chat-inputbar">
              <input v-model="messageText" placeholder="描述您的症状或疑问..." @keyup.enter="sendMessage" />
              <button type="button" class="m-chat-send" :disabled="busy || !messageText.trim()" @click="sendMessage">发送</button>
            </div>
          </footer>
        </div>

        <!-- 医生端 -->
        <template v-if="session.user.role === 'DOCTOR'">
          <div class="wb-page-header">
            <div>
              <h1>在线咨询</h1>
              <p>查看患者咨询、回复消息并设置复诊时间</p>
            </div>
            <div class="wb-consult-toolbar">
              <div class="wb-subtabs">
                <button
                  v-for="item in consultStatusTabs"
                  :key="item.key"
                  type="button"
                  :class="{ active: consultStatusFilter === item.key }"
                  @click="consultStatusFilter = item.key"
                >
                  {{ item.label }}
                </button>
              </div>
              <button type="button" class="adm-btn" :disabled="busy" @click="loadConsultations">刷新</button>
            </div>
          </div>

          <div class="wb-consult-layout">
            <aside class="panel wb-consult-list">
              <div class="wb-list-head">
                <h2>咨询会话</h2>
                <span v-if="filteredDoctorConsultations.length" class="wb-list-count">共 {{ filteredDoctorConsultations.length }} 条</span>
              </div>
              <div v-if="!filteredDoctorConsultations.length" class="wb-empty">暂无咨询会话</div>
              <div v-else class="wb-consult-items">
                <button
                  v-for="item in paginatedDoctorConsultations"
                  :key="item.id"
                  type="button"
                  class="wb-consult-item"
                  :class="{ active: activeConsultation?.id === item.id, closed: item.status === 'CLOSED' }"
                  @click="openConsultation(item)"
                >
                  <div class="wb-consult-item-top">
                    <strong>{{ item.title }}</strong>
                    <span class="wb-consult-badge" :class="item.status === 'OPEN' ? 'open' : 'closed'">{{ item.statusText }}</span>
                  </div>
                  <p>{{ item.userName }}</p>
                  <div class="wb-consult-item-meta">
                    <span>{{ item.createTimeDisplay }}</span>
                    <span v-if="item.messageCount">💬 {{ item.messageCount }}</span>
                  </div>
                </button>
              </div>
              <PaginationBar
                v-if="filteredDoctorConsultations.length"
                :page="doctorConsultPage"
                :page-size="doctorConsultPageSize"
                :total="doctorConsultTotal"
                :total-pages="doctorConsultTotalPages"
                :range-start="doctorConsultRangeStart"
                :range-end="doctorConsultRangeEnd"
                @update:page="goDoctorConsultPage"
                @update:page-size="setDoctorConsultPageSize"
              />
            </aside>

            <section class="panel wb-consult-chat">
              <div v-if="!activeConsultation" class="wb-consult-empty">
                <span>💬</span>
                <strong>选择左侧会话开始回复</strong>
                <p>点击咨询记录查看详情并发送消息</p>
              </div>
              <template v-else>
                <header class="wb-consult-chat-head">
                  <div>
                    <strong>{{ activeConsultation.title }}</strong>
                    <p>
                      {{ activeConsultation.userName }}
                      · {{ activeConsultation.statusText }}
                      · {{ activeConsultation.createTimeDisplay }}
                    </p>
                  </div>
                  <div class="wb-consult-chat-actions">
                    <button
                      v-if="activeConsultation.status === 'OPEN'"
                      type="button"
                      class="adm-action"
                      :disabled="busy"
                      @click="closeConsultation(activeConsultation.id)"
                    >
                      关闭
                    </button>
                    <button
                      v-if="activeConsultation.status === 'CLOSED'"
                      type="button"
                      class="adm-action danger"
                      :disabled="busy"
                      @click="deleteConsultation(activeConsultation)"
                    >
                      删除
                    </button>
                  </div>
                </header>

                <div ref="chatBodyRef" class="wb-consult-messages">
                  <div v-if="!messages.length" class="m-chat-empty">暂无消息，向患者发送第一条回复吧</div>
                  <div
                    v-for="item in messages"
                    :key="item.id"
                    class="m-msg-row"
                    :class="item.senderRole === 'DOCTOR' ? 'me' : 'doctor'"
                  >
                    <div class="m-msg-wrap">
                      <span class="m-msg-name">{{ item.senderRole === 'DOCTOR' ? '我' : activeConsultation.userName }}</span>
                      <div class="m-msg-bubble">{{ item.content }}</div>
                    </div>
                  </div>
                </div>

                <footer class="wb-consult-compose">
                  <p v-if="activeConsultation.status === 'CLOSED'" class="m-chat-closed">会话已关闭，无法继续发送消息</p>
                  <div v-else class="m-chat-inputbar">
                    <input v-model="messageText" placeholder="输入回复内容..." @keyup.enter="sendMessage" />
                    <button type="button" class="m-chat-send" :disabled="busy || !messageText.trim()" @click="sendMessage">发送</button>
                  </div>
                  <div class="wb-consult-followup">
                    <label>
                      <span>复诊时间</span>
                      <input v-model="followUpText" type="datetime-local" />
                    </label>
                    <button type="button" class="adm-btn" :disabled="busy" @click="setFollowUp">保存复诊</button>
                    <span v-if="activeConsultation.followUpTimeDisplay && activeConsultation.followUpTimeDisplay !== '-'" class="hint">
                      已设置：{{ activeConsultation.followUpTimeDisplay }}
                    </span>
                  </div>
                </footer>
              </template>
            </section>
          </div>
        </template>
      </section>

      <section v-if="tab === 'schedule' && session.user.role === 'DOCTOR'" class="content">
        <div class="wb-page-header">
          <div>
            <h1>我的排班</h1>
            <p>查看本人出诊日历与号源情况（只读）</p>
          </div>
          <div class="view-toggle wb-view-toggle">
            <button type="button" :class="{ active: doctorScheduleView === 'calendar' }" @click="doctorScheduleView = 'calendar'">日历视图</button>
            <button type="button" :class="{ active: doctorScheduleView === 'list' }" @click="doctorScheduleView = 'list'">列表视图</button>
          </div>
        </div>
        <div class="panel wb-toolbar-panel">
          <div class="form-grid compact">
            <button type="button" class="ghost" :disabled="busy" @click="loadDoctorSchedules">刷新排班</button>
            <button v-if="doctorSelectedDate" type="button" class="ghost" @click="doctorSelectedDate = ''">清除日期筛选</button>
          </div>
        </div>

        <div v-if="doctorScheduleView === 'calendar'" class="panel calendar-panel">
          <div class="calendar-header">
            <button class="ghost" @click="shiftDoctorCalendarMonth(-1)">上月</button>
            <strong>{{ doctorCalendarTitle }}</strong>
            <button class="ghost" @click="shiftDoctorCalendarMonth(1)">下月</button>
          </div>
          <div class="calendar-grid">
            <div v-for="head in calendarWeekHeads" :key="'d-' + head" class="calendar-head">{{ head }}</div>
            <div
              v-for="(cell, idx) in doctorCalendarCells"
              :key="'d-cell-' + idx"
              class="calendar-cell"
              :class="{ empty: cell.empty, selected: cell.dateStr === doctorSelectedDate, 'has-data': cell.count > 0, full: cell.full > 0 }"
              @click="selectDoctorCalendarDay(cell)"
            >
              <span v-if="!cell.empty" class="day-num">{{ cell.day }}</span>
              <span v-if="cell.count" class="day-badge">{{ cell.count }}班</span>
              <span v-if="cell.remainTotal > 0" class="day-quota">余{{ cell.remainTotal }}</span>
            </div>
          </div>
          <p v-if="doctorSelectedDate" class="hint">已选 {{ doctorSelectedDate }}，列表视图将只显示该日排班</p>
        </div>

        <ListPanel title="排班明细" :items="filteredDoctorSchedules" :fields="['scheduleDate','timeSlot','totalQuota','remainQuota','bookedQuota']" :labels="scheduleLabels" />
      </section>

      <section v-if="tab === 'medical' && session.user.role === 'ADMIN'" class="content admin-medical">
        <div class="med-shell">
          <header class="med-hero">
            <div class="med-hero-main">
              <span class="med-hero-badge">资源维护中心</span>
              <h1>医疗维护</h1>
              <p>按业务流程依次配置：先建医院与科室，再绑定医生，最后设置出诊排班</p>
            </div>
            <div class="med-hero-stats">
              <div v-for="item in medResourceStats" :key="item.label" class="med-stat-chip">
                <strong>{{ item.value }}</strong>
                <span>{{ item.label }}</span>
              </div>
            </div>
          </header>

          <nav class="med-steps" aria-label="医疗维护步骤">
            <button
              v-for="item in adminMedTabs"
              :key="item.key"
              type="button"
              class="med-step"
              :class="medStepState(item.key)"
              @click="switchAdminMedTab(item.key)"
            >
              <span class="med-step-index">{{ item.step }}</span>
              <span class="med-step-icon">{{ item.icon }}</span>
              <span class="med-step-text">
                <strong>{{ item.label }}</strong>
                <small>{{ item.desc }}</small>
              </span>
            </button>
          </nav>

          <div class="med-body">
            <div class="med-panel-head">
              <div>
                <h2>{{ activeMedTab.label }}</h2>
                <p>{{ activeMedTab.desc }} · 当前步骤 {{ activeMedTab.step }}/04</p>
              </div>
            </div>

        <div v-if="adminMedTab === 'hospital'" class="adm-split">
          <aside class="adm-form-side">
            <div class="adm-form-card">
              <div class="adm-form-card-head">
                <strong>{{ hospitalForm.id ? '编辑医院' : '新增医院' }}</strong>
                <span>维护合作医院基础资料</span>
              </div>
              <div class="form-grid adm-form-grid">
                <label>名称<input v-model="hospitalForm.name" placeholder="医院全称" /></label>
                <label>等级<input v-model="hospitalForm.level" placeholder="三级甲等" /></label>
                <label>地址<input v-model="hospitalForm.address" placeholder="详细地址" /></label>
                <label>电话<input v-model="hospitalForm.phone" placeholder="联系电话" /></label>
              </div>
              <div class="adm-form-actions">
                <button type="button" class="primary" :disabled="busy" @click="saveHospital">{{ hospitalForm.id ? '保存修改' : '新增医院' }}</button>
                <button v-if="hospitalForm.id" type="button" class="adm-btn" @click="resetHospitalForm">取消编辑</button>
              </div>
            </div>
          </aside>
          <div class="adm-list-side">
            <AdminListPanel
              title="医院列表"
              subtitle="全部合作医院一览"
              :items="hospitals"
              :fields="['name','level','address','phone']"
              :labels="hospitalLabels"
              primary-field="name"
              empty-text="暂无医院"
              empty-hint="在左侧表单添加第一家合作医院"
            >
              <template #actions="{ item }">
                <button type="button" class="adm-action primary" @click="editHospital(item)">编辑</button>
                <button type="button" class="adm-action danger" :disabled="busy" @click="deleteHospital(item)">删除</button>
              </template>
            </AdminListPanel>
          </div>
        </div>

        <div v-if="adminMedTab === 'department'" class="adm-split">
          <aside class="adm-form-side">
            <div class="adm-form-card">
              <div class="adm-form-card-head">
                <strong>{{ departmentForm.id ? '编辑科室' : '新增科室' }}</strong>
                <span>按医院维护科室信息</span>
              </div>
              <div class="form-grid adm-form-grid">
                <label>所属医院<select v-model="adminDeptHospitalId" @change="loadAdminDepartments">
                  <option v-for="item in hospitals" :key="item.id" :value="item.id">{{ item.name }}</option>
                </select></label>
                <label>科室名称<input v-model="departmentForm.name" placeholder="如：心内科" /></label>
                <label>简介<input v-model="departmentForm.description" placeholder="科室简介" /></label>
              </div>
              <div class="adm-form-actions">
                <button type="button" class="primary" :disabled="busy" @click="saveDepartment">{{ departmentForm.id ? '保存修改' : '新增科室' }}</button>
                <button v-if="departmentForm.id" type="button" class="adm-btn" @click="resetDepartmentForm">取消编辑</button>
              </div>
            </div>
          </aside>
          <div class="adm-list-side">
            <AdminListPanel
              title="科室列表"
              subtitle="当前医院下的全部科室"
              :items="adminDepartments"
              :fields="['name','description']"
              :labels="departmentLabels"
              primary-field="name"
              empty-text="暂无科室"
              empty-hint="选择医院后在左侧添加科室"
            >
              <template #actions="{ item }">
                <button type="button" class="adm-action primary" @click="editDepartment(item)">编辑</button>
                <button type="button" class="adm-action danger" :disabled="busy" @click="deleteDepartment(item)">删除</button>
              </template>
            </AdminListPanel>
          </div>
        </div>

        <div v-if="adminMedTab === 'doctor'" class="adm-split">
          <aside class="adm-form-side">
            <div class="adm-form-card">
              <div class="adm-form-card-head">
                <strong>{{ doctorForm.id ? '编辑医生' : '新增医生' }}</strong>
                <span>关联账号、科室与职称</span>
              </div>
              <div class="form-grid adm-form-grid">
                <label>医院<select v-model="adminDoctorHospitalId" @change="loadAdminDepartmentsForDoctor">
                  <option v-for="item in hospitals" :key="item.id" :value="item.id">{{ item.name }}</option>
                </select></label>
                <label>科室<select v-model="doctorForm.departmentId">
                  <option v-for="item in adminDoctorDepartments" :key="item.id" :value="item.id">{{ item.name }}</option>
                </select></label>
                <label>医生账号<select v-model="doctorForm.userId">
                  <option v-for="item in doctorUsers" :key="item.id" :value="item.id">{{ item.realName }} ({{ item.username }})</option>
                </select></label>
                <label>职称<input v-model="doctorForm.title" placeholder="主任医师" /></label>
                <label>专长<input v-model="doctorForm.specialty" placeholder="擅长领域" /></label>
                <label>状态<select v-model="doctorForm.status"><option value="ACTIVE">在职</option><option value="INACTIVE">停诊</option></select></label>
              </div>
              <label>简介<textarea v-model="doctorForm.profile" rows="3" placeholder="医生简介" /></label>
              <div class="adm-form-actions">
                <button type="button" class="primary" :disabled="busy" @click="saveDoctor">{{ doctorForm.id ? '保存修改' : '新增医生' }}</button>
                <button v-if="doctorForm.id" type="button" class="adm-btn" @click="resetDoctorForm">取消编辑</button>
              </div>
            </div>
          </aside>
          <div class="adm-list-side">
            <AdminListPanel
              title="医生列表"
              subtitle="平台全部注册医生"
              :items="adminDoctors"
              :fields="['doctorName','hospitalName','departmentName','title','specialty','statusText']"
              :labels="adminDoctorLabels"
              primary-field="doctorName"
              status-field="status"
              :status-tabs="adminDoctorStatusTabs"
              empty-text="暂无医生"
              empty-hint="在左侧表单添加第一位医生"
            >
              <template #actions="{ item }">
                <button type="button" class="adm-action primary" @click="editDoctor(item)">编辑</button>
                <button type="button" class="adm-action danger" :disabled="busy" @click="deleteDoctor(item)">删除</button>
              </template>
            </AdminListPanel>
          </div>
        </div>

        <template v-if="adminMedTab === 'schedule'">
          <div class="med-schedule-toolbar">
            <label class="med-inline-field">
              <span>出诊医生</span>
              <select v-model="adminScheduleDoctorId" @change="loadAdminSchedules">
                <option v-for="item in adminDoctors" :key="item.id" :value="item.id">{{ item.doctorName }} · {{ item.specialty }}</option>
              </select>
            </label>
            <div class="med-schedule-toolbar-right">
              <div class="view-toggle wb-view-toggle med-view-toggle">
                <button type="button" :class="{ active: scheduleView === 'calendar' }" @click="scheduleView = 'calendar'">日历视图</button>
                <button type="button" :class="{ active: scheduleView === 'list' }" @click="scheduleView = 'list'">列表视图</button>
              </div>
              <button type="button" class="adm-btn" :disabled="busy" @click="loadAdminSchedules">刷新</button>
              <button v-if="selectedCalendarDate" type="button" class="adm-btn" @click="selectedCalendarDate = ''">清除日期</button>
            </div>
          </div>

          <div class="med-schedule-layout" :class="{ 'is-list': scheduleView === 'list' }">
            <aside class="med-schedule-side">
              <div class="med-schedule-card">
                <div class="med-schedule-card-head">
                  <span class="med-schedule-tag">推荐</span>
                  <strong>批量排班</strong>
                  <p>按日期范围与工作日规则，一键生成多个出诊时段</p>
                </div>
                <div class="form-grid med-schedule-form">
                  <label>开始日期<input v-model="batchForm.startDate" type="date" /></label>
                  <label>结束日期<input v-model="batchForm.endDate" type="date" /></label>
                  <label>每时段号源<input v-model.number="batchForm.totalQuota" type="number" min="1" /></label>
                </div>
                <div class="med-option-group">
                  <strong>工作日</strong>
                  <div class="med-chip-row">
                    <label v-for="item in weekdayOptions" :key="item.value" class="med-chip" :class="{ active: batchForm.weekdays.includes(item.value) }">
                      <input type="checkbox" :value="item.value" v-model="batchForm.weekdays" hidden /> {{ item.label }}
                    </label>
                  </div>
                </div>
                <div class="med-option-group">
                  <strong>出诊时段</strong>
                  <div class="med-chip-row">
                    <label v-for="slot in timeSlotOptions" :key="slot" class="med-chip" :class="{ active: batchForm.timeSlots.includes(slot) }">
                      <input type="checkbox" :value="slot" v-model="batchForm.timeSlots" hidden /> {{ slot }}
                    </label>
                  </div>
                </div>
                <button type="button" class="primary med-schedule-submit" :disabled="busy || !adminScheduleDoctorId" @click="saveBatchSchedule">批量生成排班</button>
              </div>

              <div v-if="scheduleView === 'list'" class="med-schedule-card">
                <div class="med-schedule-card-head">
                  <strong>单条排班</strong>
                  <p>补充或修改某一天的单个出诊时段</p>
                </div>
                <div class="form-grid med-schedule-form">
                  <label>日期<input v-model="scheduleForm.scheduleDate" type="date" /></label>
                  <label>时段<select v-model="scheduleForm.timeSlot"><option v-for="slot in timeSlotOptions" :key="slot" :value="slot">{{ slot }}</option></select></label>
                  <label>总号源<input v-model.number="scheduleForm.totalQuota" type="number" min="1" /></label>
                </div>
                <button type="button" class="primary med-schedule-submit" :disabled="busy" @click="saveSingleSchedule">{{ scheduleForm.id ? '保存修改' : '新增排班' }}</button>
              </div>
            </aside>

            <div class="med-schedule-main">
              <div v-if="scheduleView === 'calendar'" class="panel calendar-panel adm-calendar">
                <div class="calendar-header">
                  <div>
                    <strong>{{ calendarTitle }}</strong>
                    <p class="hint">{{ scheduleDoctorName }}</p>
                  </div>
                  <div class="calendar-header-actions">
                    <button type="button" class="adm-btn" @click="shiftCalendarMonth(-1)">上月</button>
                    <button type="button" class="adm-btn" @click="shiftCalendarMonth(1)">下月</button>
                  </div>
                </div>
                <div class="calendar-grid">
                  <div v-for="head in calendarWeekHeads" :key="head" class="calendar-head">{{ head }}</div>
                  <div v-for="(cell, idx) in calendarCells" :key="idx" class="calendar-cell" :class="{ empty: cell.empty, selected: cell.dateStr === selectedCalendarDate, 'has-data': cell.count > 0 }" @click="selectCalendarDay(cell)">
                    <span v-if="!cell.empty" class="day-num">{{ cell.day }}</span>
                    <span v-if="cell.count" class="day-badge">{{ cell.count }}班</span>
                  </div>
                </div>
                <p v-if="selectedCalendarDate" class="hint">已选 {{ selectedCalendarDate }}，下方列表仅显示该日排班</p>
              </div>

              <AdminListPanel
                :title="scheduleView === 'calendar' ? (selectedCalendarDate ? '当日排班' : '全部排班') : '排班列表'"
                :subtitle="scheduleView === 'calendar' ? '点击日历日期可筛选当日记录' : '支持搜索与分页浏览'"
                :items="filteredAdminSchedules"
                :fields="['scheduleDate','timeSlot','totalQuota','remainQuota','bookedQuota']"
                :labels="scheduleLabels"
                primary-field="scheduleDate"
                empty-text="暂无排班"
                empty-hint="先在左侧批量生成，或在列表视图下单条新增"
              >
                <template #actions="{ item }">
                  <button type="button" class="adm-action" @click="editSchedule(item)">编辑</button>
                  <button type="button" class="adm-action danger" :disabled="busy" @click="deleteSchedule(item)">删除</button>
                </template>
              </AdminListPanel>
            </div>
          </div>
        </template>
          </div>
        </div>
      </section>

      <section v-if="tab === 'dashboard'" class="content screen">
        <div class="wb-page-header">
          <div>
            <h1>统计大屏</h1>
            <p>关键业务指标与趋势分析</p>
          </div>
          <button type="button" class="ghost wb-refresh" :disabled="busy" @click="refreshDashboard">刷新统计</button>
        </div>
        <div class="grid cards wb-dashboard-metrics">
          <div v-for="card in dashboardCards" :key="card.label" class="metric wb-metric-card wb-screen-metric">
            <span>{{ card.label }}</span>
            <strong>{{ card.value }}</strong>
          </div>
        </div>
        <div class="dashboard-grid wb-chart-grid">
          <div class="panel chart-panel wb-chart-card"><div class="wb-chart-title">预约趋势</div><div id="chartA"></div></div>
          <div class="panel chart-panel wb-chart-card"><div class="wb-chart-title">{{ session.user.role === 'ADMIN' ? '预约状态' : '状态分布' }}</div><div id="chartB"></div></div>
          <div class="panel chart-panel wb-chart-card"><div class="wb-chart-title">{{ session.user.role === 'ADMIN' ? '健康异常趋势' : '患者异常趋势' }}</div><div id="chartC"></div></div>
          <div class="panel chart-panel wb-chart-card"><div class="wb-chart-title">{{ session.user.role === 'ADMIN' ? '文章分类' : '分类统计' }}</div><div id="chartD"></div></div>
        </div>
      </section>

      <nav v-if="session.user?.role === 'USER' && showMobileNav" class="mobile-nav">
        <button v-for="item in mobileNavItems" :key="item.key" :class="{ active: mobileNavActive === item.key }" @click="switchMobileTab(item.key)">
          <span class="nav-icon">{{ item.icon }}</span>
          <span class="nav-label">{{ item.label }}</span>
        </button>
      </nav>
    </template>
  </main>
</template>

<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import axios from 'axios'
import * as echarts from 'echarts'
import { getPortal, portalTitle } from './portal'
import AdminPageShell from './components/AdminPageShell.vue'
import AdminListPanel from './components/AdminListPanel.vue'
import ListPanel from './components/ListPanel.vue'
import PaginationBar from './components/PaginationBar.vue'
import { usePagination } from './composables/usePagination'

const api = axios.create({ baseURL: '' })
api.interceptors.request.use(config => {
  const raw = localStorage.getItem('health_session')
  if (raw) {
    const parsed = JSON.parse(raw)
    if (parsed.token) config.headers.Authorization = `Bearer ${parsed.token}`
  }
  return config
})

const tab = ref('home')
const session = reactive(JSON.parse(localStorage.getItem('health_session') || '{"user":null,"doctor":null,"token":null}'))
const busy = ref(false)
const adminLoading = reactive({ overview: false, appointment: false, emergency: false, article: false })
const notice = reactive({ type: 'success', text: '' })
const portal = ref(getPortal())
const isPatientPortal = computed(() => portal.value === 'patient')
const isWorkbenchPortal = computed(() => portal.value === 'workbench')
const loginForm = reactive({ username: 'user_wang', password: 'root', role: 'USER' })
const showRegister = ref(false)
const registerForm = reactive({ username: '', password: '', realName: '', phone: '', gender: '男', age: 30, role: 'USER' })
const roleAccounts = {
  USER: 'user_wang',
  DOCTOR: 'doctor_zhang',
  ADMIN: 'admin'
}
const archive = reactive({})
const archiveFiles = ref([])
const archiveRows = ref([])
const archiveDetail = ref(null)
const hospitals = ref([])
const departments = ref([])
const doctors = ref([])
const consultDoctors = ref([])
const schedules = ref([])
const appointments = ref([])
const medicines = ref([])
const healthList = ref([])
const contacts = ref([])
const emergencyRecords = ref([])
const articles = ref([])
const consultations = ref([])

const medicinePager = usePagination(medicines, { pageSize: 8 })
const patientArticlePager = usePagination(articles, { pageSize: 8 })
const consultPager = usePagination(consultations, { pageSize: 8 })
const healthPager = usePagination(healthList, { pageSize: 6 })
const emergencyPager = usePagination(emergencyRecords, { pageSize: 5 })
const doctorArticlePager = usePagination(articles, { pageSize: 10 })

const consultStatusFilter = ref('ALL')
const consultStatusTabs = [
  { key: 'ALL', label: '全部' },
  { key: 'OPEN', label: '进行中' },
  { key: 'CLOSED', label: '已关闭' }
]

const filteredDoctorConsultations = computed(() => {
  if (consultStatusFilter.value === 'ALL') return consultations.value
  return consultations.value.filter(item => item.status === consultStatusFilter.value)
})

const doctorConsultPager = usePagination(filteredDoctorConsultations, { pageSize: 8 })

const {
  paginatedItems: paginatedMedicines,
  page: medicinePage,
  pageSize: medicinePageSize,
  total: medicineTotal,
  totalPages: medicineTotalPages,
  rangeStart: medicineRangeStart,
  rangeEnd: medicineRangeEnd,
  goPage: goMedicinePage,
  resetPage: resetMedicinePage
} = medicinePager

const {
  paginatedItems: paginatedPatientArticles,
  page: patientArticlePage,
  pageSize: patientArticlePageSize,
  total: patientArticleTotal,
  totalPages: patientArticleTotalPages,
  rangeStart: patientArticleRangeStart,
  rangeEnd: patientArticleRangeEnd,
  goPage: goPatientArticlePage,
  resetPage: resetPatientArticlePage
} = patientArticlePager

const {
  paginatedItems: paginatedConsultations,
  page: consultPage,
  pageSize: consultPageSize,
  total: consultTotal,
  totalPages: consultTotalPages,
  rangeStart: consultRangeStart,
  rangeEnd: consultRangeEnd,
  goPage: goConsultPage,
  resetPage: resetConsultPage
} = consultPager

const {
  paginatedItems: paginatedHealthRecords,
  page: healthPage,
  pageSize: healthPageSize,
  total: healthTotal,
  totalPages: healthTotalPages,
  rangeStart: healthRangeStart,
  rangeEnd: healthRangeEnd,
  goPage: goHealthPage
} = healthPager

function setHealthPageSize(value) {
  healthPager.pageSize.value = value
}

const {
  paginatedItems: paginatedEmergencyRecords,
  page: emergencyPage,
  pageSize: emergencyPageSize,
  total: emergencyTotal,
  totalPages: emergencyTotalPages,
  rangeStart: emergencyRangeStart,
  rangeEnd: emergencyRangeEnd,
  goPage: goEmergencyPage
} = emergencyPager

function setEmergencyPageSize(value) {
  emergencyPager.pageSize.value = value
}

const {
  paginatedItems: paginatedDoctorConsultations,
  page: doctorConsultPage,
  pageSize: doctorConsultPageSize,
  total: doctorConsultTotal,
  totalPages: doctorConsultTotalPages,
  rangeStart: doctorConsultRangeStart,
  rangeEnd: doctorConsultRangeEnd,
  goPage: goDoctorConsultPage
} = doctorConsultPager

function setDoctorConsultPageSize(value) {
  doctorConsultPager.pageSize.value = value
}

const {
  paginatedItems: paginatedDoctorArticles,
  page: doctorArticlePage,
  pageSize: doctorArticlePageSize,
  total: doctorArticleTotal,
  totalPages: doctorArticleTotalPages,
  rangeStart: doctorArticleRangeStart,
  rangeEnd: doctorArticleRangeEnd,
  goPage: goDoctorArticlePage,
  resetPage: resetDoctorArticlePage
} = doctorArticlePager
const messages = ref([])
const dashboard = ref({})
const activeConsultation = ref(null)
const consultView = ref('list')
const medicineView = ref('list')
const appointmentView = ref('list')
const appointmentScheduleDate = ref('')
const healthView = ref('list')
const emergencyView = ref('list')
const articleView = ref('list')
const chatBodyRef = ref(null)
const messageText = ref('')
const CONSULT_POLL_MS = 3000
let consultPollTimer = null
const articleKeyword = ref('')
const selectedArticle = ref(null)
const followUpText = ref('2026-06-25T10:00')

const appointment = reactive({ hospitalId: '', departmentId: '', doctorId: '', scheduleId: '', symptom: '' })
const medicine = reactive({ medicineName: '', usageMethod: '口服', dosage: '', reminderTimes: '08:00', startDate: '2026-06-20', endDate: '2026-06-25' })
const health = reactive({ systolic: 120, diastolic: 80, bloodSugar: 5.6, heartRate: 76, steps: 8000, sleepHours: 7, weight: 60 })
const contact = reactive({ name: '', relation: '', phone: '' })
const emergency = reactive({ locationText: '当前位置' })
const consultForm = reactive({ doctorId: '', title: '' })
const articleForm = reactive({ id: null, title: '', category: '养生', diseaseTag: '', summary: '', content: '' })
const chartInstances = {}

const adminMedTab = ref('hospital')
const adminMedTabs = [
  { key: 'hospital', label: '医院管理', icon: '🏥', desc: '维护合作医院', step: '01' },
  { key: 'department', label: '科室管理', icon: '🏢', desc: '配置医院科室', step: '02' },
  { key: 'doctor', label: '医生管理', icon: '👨‍⚕️', desc: '绑定医生账号', step: '03' },
  { key: 'schedule', label: '排班管理', icon: '📅', desc: '设置出诊号源', step: '04' }
]
const activeMedTab = computed(() => adminMedTabs.find(item => item.key === adminMedTab.value) || adminMedTabs[0])
const medResourceStats = computed(() => [
  { label: '合作医院', value: hospitals.value.length },
  { label: '注册医生', value: adminDoctors.value.length },
  { label: '排班记录', value: adminSchedules.value.length }
])
const medStepOrder = ['hospital', 'department', 'doctor', 'schedule']

function medStepState(key) {
  const current = medStepOrder.indexOf(adminMedTab.value)
  const index = medStepOrder.indexOf(key)
  return {
    active: adminMedTab.value === key,
    done: index >= 0 && index < current
  }
}

const scheduleView = ref('calendar')
const scheduleDoctorName = computed(() => {
  const doctor = adminDoctors.value.find(item => String(item.id) === String(adminScheduleDoctorId.value))
  return doctor ? `${doctor.doctorName} · ${doctor.specialty || '全科'}` : '未选择医生'
})
const adminScheduleDoctorId = ref('')
const adminSchedules = ref([])
const doctorSchedules = ref([])
const doctorScheduleView = ref('calendar')
const doctorSelectedDate = ref('')
const doctorCalendarMonth = reactive({ year: new Date().getFullYear(), month: new Date().getMonth() + 1 })
const adminDepartments = ref([])
const adminDoctorDepartments = ref([])
const adminDoctors = ref([])
const doctorUsers = ref([])
const adminDeptHospitalId = ref('')
const adminDoctorHospitalId = ref('')
const selectedCalendarDate = ref('')
const calendarMonth = reactive({ year: new Date().getFullYear(), month: new Date().getMonth() + 1 })
const hospitalForm = reactive({ id: null, name: '', level: '', address: '', phone: '' })
const departmentForm = reactive({ id: null, hospitalId: '', name: '', description: '' })
const doctorForm = reactive({ id: null, userId: '', hospitalId: '', departmentId: '', title: '', specialty: '', profile: '', status: 'ACTIVE' })
const scheduleForm = reactive({ id: null, scheduleDate: '', timeSlot: '上午', totalQuota: 10 })
const batchForm = reactive({
  startDate: '',
  endDate: '',
  weekdays: [1, 2, 3, 4, 5],
  timeSlots: ['上午', '下午'],
  totalQuota: 10
})
const weekdayOptions = [
  { value: 1, label: '周一' }, { value: 2, label: '周二' }, { value: 3, label: '周三' },
  { value: 4, label: '周四' }, { value: 5, label: '周五' }, { value: 6, label: '周六' }, { value: 7, label: '周日' }
]
const timeSlotOptions = ['上午', '下午', '晚上']
const calendarWeekHeads = ['一', '二', '三', '四', '五', '六', '日']
const hospitalLabels = { name: '名称', level: '等级', address: '地址', phone: '电话' }
const departmentLabels = { name: '科室', description: '简介' }
const adminDoctorLabels = {
  doctorName: '医生',
  hospitalName: '医院',
  departmentName: '科室',
  title: '职称',
  specialty: '专长',
  status: '状态',
  statusText: '状态'
}
const scheduleLabels = {
  scheduleDate: '日期',
  timeSlot: '时段',
  totalQuota: '总号源',
  remainQuota: '剩余',
  bookedQuota: '已预约'
}
const adminArticleFields = ['title', 'category', 'diseaseTag', 'viewCount']
const adminArticleLabels = { title: '标题', category: '分类', diseaseTag: '标签', viewCount: '阅读量' }
const adminAppointmentStatusTabs = [
  { key: 'ALL', label: '全部' },
  { key: 'CONFIRMED', label: '已确认' },
  { key: 'FINISHED', label: '已完成' },
  { key: 'CANCELLED', label: '已取消' }
]
const adminEmergencyStatusTabs = [
  { key: 'ALL', label: '全部' },
  { key: 'PROCESSING', label: '处理中' },
  { key: 'FINISHED', label: '已完成' }
]
const adminDoctorStatusTabs = [
  { key: 'ALL', label: '全部' },
  { key: 'ACTIVE', label: '在职' },
  { key: 'INACTIVE', label: '停诊' }
]

const statusTextMap = {
  CONFIRMED: '已确认',
  CANCELLED: '已取消',
  FINISHED: '已完成',
  ACTIVE: '进行中',
  OPEN: '进行中',
  CLOSED: '已关闭',
  PROCESSING: '处理中'
}

const appointmentLabels = {
  userName: '用户',
  hospitalName: '医院',
  departmentName: '科室',
  doctorName: '医生',
  appointmentDate: '日期',
  timeSlot: '时段',
  statusText: '状态',
  symptom: '症状'
}
const medicineLabels = {
  medicineName: '药品',
  usageMethod: '用法',
  dosage: '用量',
  reminderTimes: '提醒',
  startDate: '开始',
  endDate: '结束',
  statusText: '状态',
  warning: '风险提示'
}
const medicineListFields = ['medicineName', 'usageMethod', 'dosage', 'reminderTimes', 'startDate', 'endDate', 'statusText', 'warning']
const healthLabels = {
  recordTime: '时间',
  systolic: '收缩压',
  diastolic: '舒张压',
  bloodSugar: '血糖',
  heartRate: '心率',
  warningMessage: '预警'
}
const contactLabels = { name: '姓名', relation: '关系', phone: '电话' }
const emergencyLabels = {
  userName: '用户',
  helpTime: '时间',
  locationText: '位置',
  statusText: '状态',
  result: '处理结果',
  contactSnapshot: '联系人快照'
}
const consultLabels = {
  title: '标题',
  userName: '用户',
  doctorName: '医生',
  statusText: '状态',
  createTime: '创建时间',
  followUpTime: '复诊时间'
}
const archiveLabels = {
  name: '姓名',
  gender: '性别',
  age: '年龄',
  bloodType: '血型',
  diseaseHistory: '病史',
  updateTime: '更新时间'
}

const dashboardCardLabels = {
  users: '用户数',
  doctors: '医生数',
  appointments: '预约数',
  warnings: '异常数据',
  patients: '患者数',
  openConsultations: '开放咨询',
  medicineRecords: '用药记录',
  USER: '用户',
  DOCTOR: '医生',
  ADMIN: '管理员'
}

const title = computed(() => session.user?.role === 'ADMIN' ? '管理员大屏' : session.user?.role === 'DOCTOR' ? '医生工作台' : '移动端健康管理')
const roleText = computed(() => ({ USER: '用户', DOCTOR: '医生', ADMIN: '管理员' }[session.user?.role] || ''))
const doctorPatientIds = computed(() => {
  const ids = new Set()
  appointments.value.forEach(item => item.userId && ids.add(item.userId))
  consultations.value.forEach(item => item.userId && ids.add(item.userId))
  return ids
})
const appointmentFields = computed(() => session.user?.role === 'USER'
  ? ['hospitalName', 'departmentName', 'doctorName', 'appointmentDate', 'timeSlot', 'statusText', 'symptom']
  : ['userName', 'hospitalName', 'departmentName', 'doctorName', 'appointmentDate', 'timeSlot', 'statusText', 'symptom'])
const emergencyFields = computed(() => session.user?.role === 'USER'
  ? ['helpTime', 'locationText', 'statusText', 'result', 'contactSnapshot']
  : ['userName', 'helpTime', 'locationText', 'statusText', 'result', 'contactSnapshot'])
const consultFields = computed(() => session.user?.role === 'USER'
  ? ['title', 'doctorName', 'statusText', 'createTime', 'followUpTime']
  : ['title', 'userName', 'statusText', 'createTime', 'followUpTime'])
const shellClass = computed(() => {
  if (!session.user) return ''
  return session.user.role === 'USER' ? 'mobile-mode' : `desktop-mode ${session.user.role.toLowerCase()}-mode`
})
const menus = computed(() => {
  if (session.user?.role === 'ADMIN') return [
    { key: 'dashboard', label: '统计大屏', icon: '📊' },
    { key: 'medical', label: '医疗维护', icon: '🏥' },
    { key: 'appointment', label: '预约管理', icon: '📅' },
    { key: 'emergency', label: '救援记录', icon: '🆘' },
    { key: 'article', label: '知识文章', icon: '📚' },
    { key: 'home', label: '数据概览', icon: '📋' }
  ]
  if (session.user?.role === 'DOCTOR') return [
    { key: 'dashboard', label: '统计图表', icon: '📊' },
    { key: 'schedule', label: '我的排班', icon: '🗓️' },
    { key: 'appointment', label: '预约管理', icon: '📅' },
    { key: 'consult', label: '在线咨询', icon: '💬' },
    { key: 'archive', label: '健康档案', icon: '📋' },
    { key: 'medicine', label: '患者用药', icon: '💊' },
    { key: 'emergency', label: '救援记录', icon: '🆘' },
    { key: 'article', label: '健康知识', icon: '📚' },
    { key: 'home', label: '数据概览', icon: '🏠' }
  ]
  return [{ key: 'home', label: '首页' }, { key: 'archive', label: '档案' }, { key: 'appointment', label: '预约' }, { key: 'medicine', label: '用药' }, { key: 'health', label: '监测' }, { key: 'emergency', label: '求救' }, { key: 'article', label: '知识' }, { key: 'consult', label: '咨询' }]
})
const mobileNavItems = [
  { key: 'home', label: '首页', icon: '🏠' },
  { key: 'appointment', label: '预约', icon: '📅' },
  { key: 'health', label: '监测', icon: '💓' },
  { key: 'consult', label: '咨询', icon: '💬' },
  { key: 'mine', label: '我的', icon: '👤' }
]
const quickActions = [
  { key: 'appointment', label: '预约挂号', desc: '在线选医生', icon: '📅', bg: 'linear-gradient(135deg,#dbeafe,#bfdbfe)' },
  { key: 'health', label: '健康监测', desc: '记录指标', icon: '💓', bg: 'linear-gradient(135deg,#fce7f3,#fbcfe8)' },
  { key: 'consult', label: '在线咨询', desc: '问医生', icon: '💬', bg: 'linear-gradient(135deg,#d1fae5,#a7f3d0)' },
  { key: 'emergency', label: '一键求救', desc: '紧急情况', icon: '🆘', bg: 'linear-gradient(135deg,#fee2e2,#fecaca)' }
]
const mineMenus = [
  { key: 'archive', label: '健康档案', desc: '个人信息与附件', icon: '📋' },
  { key: 'medicine', label: '用药管理', desc: '查看与添加用药', icon: '💊' },
  { key: 'article', label: '健康知识', desc: '科普文章阅读', icon: '📚' },
  { key: 'emergency', label: '紧急求救', desc: '联系人与求救', icon: '🆘' }
]
const mobileNavActive = computed(() => {
  if (['archive', 'medicine', 'emergency', 'article'].includes(tab.value)) return 'mine'
  return mobileNavItems.some(item => item.key === tab.value) ? tab.value : 'home'
})
const avatarText = computed(() => (session.user?.realName || '用').slice(0, 1))
const greetingText = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return '早上好'
  if (hour < 18) return '下午好'
  return '晚上好'
})
const showMobileHeader = computed(() => {
  if (tab.value === 'consult' && ['create', 'chat'].includes(consultView.value)) return false
  return ['home', 'mine', 'appointment', 'health', 'consult'].includes(tab.value)
})
const showMobileNav = computed(() => {
  if (tab.value === 'consult' && ['create', 'chat'].includes(consultView.value)) return false
  return true
})
const scopedMedicines = computed(() => {
  if (session.user?.role === 'DOCTOR') return medicines.value.filter(item => doctorPatientIds.value.has(item.userId))
  if (session.user?.role === 'USER') return medicines.value
  return medicines.value
})
const scopedHealthList = computed(() => {
  if (session.user?.role === 'DOCTOR') return healthList.value.filter(item => doctorPatientIds.value.has(item.userId))
  if (session.user?.role === 'USER') return healthList.value
  return healthList.value
})
const homeCards = computed(() => [
  { key: 'appointment', label: '预约记录', value: appointments.value.length, icon: '📅' },
  { key: 'medicine', label: session.user?.role === 'DOCTOR' ? '患者用药' : '用药记录', value: scopedMedicines.value.length, icon: '💊' },
  { key: 'health', label: '异常数据', value: scopedHealthList.value.filter(item => item.warningLevel === 'WARN').length, icon: '⚠️' },
  { key: 'consult', label: '咨询会话', value: consultations.value.length, icon: '💬' }
])

const adminHomeCards = computed(() => {
  const cards = dashboard.value.cards || {}
  const pendingAppointments = appointments.value.filter(item => item.status === 'CONFIRMED').length
  const pendingEmergencies = emergencyRecords.value.filter(item => item.status === 'PROCESSING').length
  return [
    { key: 'users', label: '注册用户', value: cards.users ?? '-', hint: '平台患者账号' },
    { key: 'doctors', label: '注册医生', value: cards.doctors ?? '-', hint: '合作医生数量' },
    { key: 'appointment', label: '待处理预约', value: pendingAppointments, hint: '已确认待就诊' },
    { key: 'emergency', label: '待处理救援', value: pendingEmergencies, hint: '进行中的求救' }
  ]
})

const adminReminders = computed(() => {
  const items = []
  const pendingEmergency = emergencyRecords.value.find(item => item.status === 'PROCESSING')
  const pendingAppointment = appointments.value.find(item => item.status === 'CONFIRMED')
  const warnCount = dashboard.value.cards?.warnings ?? 0
  items.push(pendingEmergency
    ? { key: 'emergency', title: '紧急求救待处理', desc: `${pendingEmergency.userName} · ${pendingEmergency.locationText}`, tab: 'emergency' }
    : { key: 'emergency', title: '暂无待处理求救', desc: '当前没有进行中的救援事件', tab: null })
  items.push(pendingAppointment
    ? { key: 'appointment', title: '预约待跟进', desc: `${pendingAppointment.userName} · ${pendingAppointment.appointmentDate} ${pendingAppointment.timeSlot || ''}`, tab: 'appointment' }
    : { key: 'appointment', title: '暂无待处理预约', desc: '当前没有已确认预约', tab: null })
  items.push(Number(warnCount) > 0
    ? { key: 'warning', title: '健康异常预警', desc: `平台共有 ${warnCount} 条异常监测数据`, tab: 'dashboard' }
    : { key: 'warning', title: '健康数据平稳', desc: '暂无需要关注的异常监测', tab: null })
  return items
})

function formatDateTime(value) {
  if (!value) return ''
  return String(value).replace('T', ' ').slice(0, 16)
}

function formatScheduleDateLabel(dateKey) {
  if (!dateKey) return ''
  const date = new Date(`${dateKey}T12:00:00`)
  const week = ['日', '一', '二', '三', '四', '五', '六'][date.getDay()]
  return `${dateKey.slice(5).replace('-', '/')} 周${week}`
}

function syncAppointmentScheduleDate() {
  const dates = appointmentScheduleDates.value
  if (!dates.length) {
    appointmentScheduleDate.value = ''
    appointment.scheduleId = ''
    return
  }
  if (!dates.includes(appointmentScheduleDate.value)) {
    appointmentScheduleDate.value = dates[0]
  }
  const slots = filteredBookableSchedules.value
  const current = slots.find(item => String(item.id) === String(appointment.scheduleId))
  appointment.scheduleId = current?.id || slots[0]?.id || ''
}

function selectAppointmentScheduleDate(dateKey) {
  appointmentScheduleDate.value = dateKey
  const slots = filteredBookableSchedules.value
  appointment.scheduleId = slots[0]?.id || ''
}

async function openBookAppointment() {
  appointmentView.value = 'book'
  if (!hospitals.value.length) await loadHospitals()
  if (!appointment.hospitalId && hospitals.value[0]) {
    await selectAppointmentHospital(hospitals.value[0].id)
  }
}

function openAddHealth() {
  healthView.value = 'add'
  Object.assign(health, {
    systolic: null,
    diastolic: null,
    bloodSugar: null,
    heartRate: null,
    steps: null,
    sleepHours: null,
    weight: null
  })
}

async function closeAddHealth() {
  healthView.value = 'list'
  await nextTick()
  renderHealthChart()
}

function formatContactSnapshot(text) {
  if (!text || text === '-') return '-'
  const parts = String(text).split(';').map(item => item.trim()).filter(Boolean)
  if (parts.length <= 1) return parts[0] || '-'
  return `${parts[0]} 等 ${parts.length} 人`
}

function openAddContact() {
  emergencyView.value = 'contact-add'
  Object.assign(contact, { name: '', relation: '', phone: '' })
}

function openEmergencySos() {
  emergencyView.value = 'sos'
  if (!emergency.locationText?.trim()) emergency.locationText = '当前位置'
}

function scrollChatToBottom() {
  const el = chatBodyRef.value
  if (el) el.scrollTop = el.scrollHeight
}

function shouldPollConsultMessages() {
  if (!session.user || !activeConsultation.value) return false
  if (tab.value !== 'consult') return false
  if (session.user.role === 'USER') return consultView.value === 'chat'
  if (session.user.role === 'DOCTOR') return true
  return false
}

function stopConsultMessagePolling() {
  if (consultPollTimer) {
    clearInterval(consultPollTimer)
    consultPollTimer = null
  }
}

function startConsultMessagePolling() {
  stopConsultMessagePolling()
  if (!shouldPollConsultMessages()) return
  pollConsultMessages().catch(() => {})
  consultPollTimer = setInterval(() => {
    pollConsultMessages().catch(() => {})
  }, CONSULT_POLL_MS)
}

function messagesChanged(prev, next) {
  if (prev.length !== next.length) return true
  const prevLast = prev[prev.length - 1]
  const nextLast = next[next.length - 1]
  if (!prevLast && !nextLast) return false
  if (!prevLast || !nextLast) return true
  return prevLast.id !== nextLast.id || prevLast.content !== nextLast.content
}

async function pollConsultMessages() {
  if (!shouldPollConsultMessages() || busy.value) return
  const consultationId = activeConsultation.value.id
  const rows = await request(api.get(`/api/consultations/${consultationId}/messages`))
  if (!shouldPollConsultMessages() || activeConsultation.value?.id !== consultationId) return
  if (!messagesChanged(messages.value, rows)) return
  const el = chatBodyRef.value
  const wasNearBottom = el ? el.scrollHeight - el.scrollTop - el.clientHeight < 80 : true
  messages.value = rows
  await nextTick()
  if (wasNearBottom) scrollChatToBottom()
  if (session.user.role === 'DOCTOR') {
    await loadConsultations()
  }
}

function closeConsultChat() {
  stopConsultMessagePolling()
  consultView.value = 'list'
  activeConsultation.value = null
  messages.value = []
  messageText.value = ''
}

function cardTone(label) {
  if (label === '异常数据') return 'tone-warn'
  if (label === '预约记录') return 'tone-blue'
  if (label === '用药记录') return 'tone-green'
  return 'tone-purple'
}

function switchMobileTab(key) {
  if (key === 'mine' && mobileNavActive.value === 'mine' && tab.value !== 'mine') {
    tab.value = 'mine'
    return
  }
  switchTab(key)
}

function openHomeStat(key) {
  if (key === 'medicine') medicineView.value = 'list'
  if (key === 'consult') consultView.value = 'list'
  if (key === 'article') articleView.value = 'list'
  if (key === 'appointment') appointmentView.value = 'list'
  if (key === 'health') healthView.value = 'list'
  if (key === 'emergency') emergencyView.value = 'list'
  switchTab(key)
}

function openAdminHomeCard(key) {
  if (key === 'users' || key === 'doctors') switchTab('dashboard')
  else switchTab(key)
}

async function refreshDoctorOverview() {
  await Promise.all([loadAppointments(), loadConsultations(), loadMedicines(), loadHealthData()])
  notify('success', '概览已刷新')
}

function closeArchiveDetail() {
  archiveDetail.value = null
}

async function deleteContact(id) {
  if (!window.confirm('确定删除该紧急联系人吗？')) return
  await run('删除联系人', async () => {
    await request(api.post(`/api/emergency/contact/delete/${id}`))
    await loadContacts()
  })
}

async function refreshAdminOverview() {
  adminLoading.overview = true
  try {
    await Promise.all([loadDashboard(), loadAppointments(), loadEmergencyRecords()])
    notify('success', '概览已刷新')
  } catch (error) {
    notify('error', error.message || '刷新失败')
  } finally {
    adminLoading.overview = false
  }
}

async function withAdminLoading(key, task) {
  adminLoading[key] = true
  try {
    return await task()
  } finally {
    adminLoading[key] = false
  }
}
const reminders = computed(() => [
  appointments.value.find(item => item.status === 'CONFIRMED') ? `预约提醒：${appointments.value.find(item => item.status === 'CONFIRMED').appointmentDate} ${appointments.value.find(item => item.status === 'CONFIRMED').timeSlot || ''}` : '暂无待就诊预约',
  scopedMedicines.value.find(item => item.status === 'ACTIVE') ? `用药提醒：${scopedMedicines.value.find(item => item.status === 'ACTIVE').medicineName}` : '暂无进行中用药',
  scopedHealthList.value.find(item => item.warningLevel === 'WARN') ? '存在异常健康数据，请关注趋势' : '健康数据平稳',
  consultations.value.find(item => item.status === 'OPEN') ? `咨询提醒：${consultations.value.find(item => item.status === 'OPEN').title}` : '暂无进行中的咨询'
])
const dashboardCards = computed(() => {
  const cards = dashboard.value.cards || {}
  return Object.entries(cards).map(([label, value]) => ({ label: dashboardCardLabels[label] || label, value }))
})

function pad2(n) {
  return String(n).padStart(2, '0')
}

const calendarTitle = computed(() => `${calendarMonth.year}年${calendarMonth.month}月`)

const calendarCells = computed(() => {
  const year = calendarMonth.year
  const monthIndex = calendarMonth.month - 1
  const firstDay = new Date(year, monthIndex, 1)
  const offset = (firstDay.getDay() + 6) % 7
  const daysInMonth = new Date(year, monthIndex + 1, 0).getDate()
  const cells = []
  for (let i = 0; i < offset; i++) cells.push({ empty: true })
  for (let day = 1; day <= daysInMonth; day++) {
    const dateStr = `${year}-${pad2(calendarMonth.month)}-${pad2(day)}`
    const daySchedules = adminSchedules.value.filter(item => String(item.scheduleDate).slice(0, 10) === dateStr)
    cells.push({ empty: false, day, dateStr, count: daySchedules.length, schedules: daySchedules })
  }
  while (cells.length % 7 !== 0) cells.push({ empty: true })
  return cells
})

const filteredAdminSchedules = computed(() => {
  if (!selectedCalendarDate.value) return adminSchedules.value
  return adminSchedules.value.filter(item => String(item.scheduleDate).slice(0, 10) === selectedCalendarDate.value)
})

const bookableSchedules = computed(() =>
  schedules.value
    .filter(item => item.remainQuota > 0)
    .map(item => ({
      ...item,
      dateKey: String(item.scheduleDate).slice(0, 10)
    }))
)

const appointmentScheduleDates = computed(() => {
  const dates = [...new Set(bookableSchedules.value.map(item => item.dateKey))]
  return dates.sort()
})

const filteredBookableSchedules = computed(() => {
  if (!appointmentScheduleDate.value) return []
  return bookableSchedules.value.filter(item => item.dateKey === appointmentScheduleDate.value)
})

const selectedScheduleSummary = computed(() => {
  const item = schedules.value.find(row => String(row.id) === String(appointment.scheduleId))
  if (!item) return ''
  const hospital = hospitals.value.find(row => String(row.id) === String(appointment.hospitalId))
  const doctor = doctors.value.find(row => String(row.id) === String(appointment.doctorId))
  return `${hospital?.name || ''} · ${doctor?.doctorName || '医生'} · ${String(item.scheduleDate).slice(0, 10)} ${item.timeSlot}`
})

const healthWarnCount = computed(() => healthList.value.filter(item => item.warningLevel === 'WARN').length)

const doctorCalendarTitle = computed(() => `${doctorCalendarMonth.year}年${doctorCalendarMonth.month}月`)

const doctorCalendarCells = computed(() => {
  const year = doctorCalendarMonth.year
  const monthIndex = doctorCalendarMonth.month - 1
  const firstDay = new Date(year, monthIndex, 1)
  const offset = (firstDay.getDay() + 6) % 7
  const daysInMonth = new Date(year, monthIndex + 1, 0).getDate()
  const cells = []
  for (let i = 0; i < offset; i++) cells.push({ empty: true })
  for (let day = 1; day <= daysInMonth; day++) {
    const dateStr = `${year}-${pad2(doctorCalendarMonth.month)}-${pad2(day)}`
    const daySchedules = doctorSchedules.value.filter(item => String(item.scheduleDate).slice(0, 10) === dateStr)
    cells.push({
      empty: false,
      day,
      dateStr,
      count: daySchedules.length,
      remainTotal: daySchedules.reduce((sum, item) => sum + (item.remainQuota || 0), 0),
      full: daySchedules.filter(item => (item.remainQuota || 0) <= 0).length,
      schedules: daySchedules
    })
  }
  while (cells.length % 7 !== 0) cells.push({ empty: true })
  return cells
})

const filteredDoctorSchedules = computed(() => {
  if (!doctorSelectedDate.value) return doctorSchedules.value
  return doctorSchedules.value.filter(item => String(item.scheduleDate).slice(0, 10) === doctorSelectedDate.value)
})

function decorateRows(list, statusField = 'status') {
  return (list || []).map(item => ({
    ...item,
    statusText: statusTextMap[item[statusField]] || item[statusField] || '-'
  }))
}

function enrichAppointmentRow(item) {
  const row = decorateRows([item])[0]
  if (item.appointmentDate) row.appointmentDate = String(item.appointmentDate).slice(0, 10)
  return row
}

function enrichEmergencyRow(item) {
  const row = decorateRows([item])[0]
  if (item.helpTime) row.helpTime = formatDateTime(item.helpTime)
  return row
}

function enrichDoctorRow(item) {
  const row = decorateRows([item])[0]
  row.statusText = statusTextMap[item.status] || item.status || '-'
  return row
}

function enrichConsultRow(item) {
  const row = decorateRows([item])[0]
  return {
    ...row,
    createTimeDisplay: formatDateTime(item.createTime) || '-',
    followUpTimeDisplay: item.followUpTime ? formatDateTime(item.followUpTime) : '-',
    followUpTimeRaw: item.followUpTime || '',
    messageCount: item.messageCount ?? 0
  }
}

async function request(promise) {
  let data
  try {
    const response = await promise
    data = response.data
  } catch (error) {
    if (error.response?.status === 401 || error.response?.data?.code === 401) {
      logout(true)
      throw new Error(error.response?.data?.message || '登录已过期，请重新登录')
    }
    throw new Error(error.response?.data?.message || error.message || '网络请求失败')
  }
  if (data.code !== 200) throw new Error(data.message)
  return data.data
}

function notify(type, text) {
  notice.type = type
  notice.text = text
  window.clearTimeout(notify.timer)
  notify.timer = window.setTimeout(() => {
    notice.text = ''
  }, 2600)
}

async function run(label, task, successText = `${label}成功`) {
  if (busy.value) return null
  busy.value = true
  try {
    const data = await task()
    if (successText) notify('success', successText)
    return data
  } catch (error) {
    notify('error', error.message || `${label}失败`)
    return null
  } finally {
    busy.value = false
  }
}

async function login() {
  if (isPatientPortal.value) {
    loginForm.role = 'USER'
  }
  if (showRegister.value && !isPatientPortal.value) {
    notify('error', '注册功能仅限患者端')
    return
  }
  if (showRegister.value) {
    if (!loginForm.username || !loginForm.password || !registerForm.realName) {
      notify('error', '请填写账号、密码和姓名')
      return
    }
    await run('注册', async () => {
      await request(api.post('/api/auth/register', {
        username: loginForm.username,
        password: loginForm.password,
        realName: registerForm.realName,
        phone: registerForm.phone,
        gender: registerForm.gender,
        age: registerForm.age,
        role: 'USER'
      }))
      showRegister.value = false
    }, '注册成功，正在登录')
  }
  await run('登录', async () => {
    const data = await request(api.post('/api/auth/login', loginForm))
    if (isPatientPortal.value && data.user.role !== 'USER') {
      throw new Error('此地址仅限患者登录，工作人员请访问 /manage')
    }
    if (isWorkbenchPortal.value && data.user.role === 'USER') {
      throw new Error('患者请使用手机端首页 / 登录')
    }
    session.user = data.user
    session.doctor = data.doctor
    session.token = data.token
    localStorage.setItem('health_session', JSON.stringify(session))
    tab.value = session.user.role === 'USER' ? 'home' : 'dashboard'
    await loadAll()
  })
}

function initPortalLogin() {
  document.title = portalTitle(portal.value)
  if (isPatientPortal.value) {
    selectRole('USER')
    showRegister.value = false
  } else {
    selectRole('DOCTOR')
    showRegister.value = false
  }
}

function ensurePortalSession() {
  if (!session.user) return
  if (isPatientPortal.value && session.user.role !== 'USER') {
    logout(true)
    notify('error', '此入口仅限患者，请访问 /manage 登录工作台')
    return
  }
  if (isWorkbenchPortal.value && session.user.role === 'USER') {
    logout(true)
    notify('error', '患者请访问首页 / 登录')
  }
}

function selectRole(role) {
  loginForm.role = role
  loginForm.username = roleAccounts[role]
  loginForm.password = 'root'
  if (role !== 'USER') showRegister.value = false
}

function logout(silent = false) {
  stopConsultMessagePolling()
  localStorage.removeItem('health_session')
  session.user = null
  session.doctor = null
  session.token = null
  tab.value = 'home'
  consultView.value = 'list'
  medicineView.value = 'list'
  appointmentView.value = 'list'
  healthView.value = 'list'
  emergencyView.value = 'list'
  articleView.value = 'list'
  archiveDetail.value = null
  activeConsultation.value = null
  selectedArticle.value = null
  if (!silent) notify('success', '已退出登录')
}

async function switchTab(key) {
  if (tab.value === 'consult' && key !== 'consult') {
    stopConsultMessagePolling()
    consultView.value = 'list'
    activeConsultation.value = null
    messages.value = []
  }
  tab.value = key
  if (key === 'archive') {
    if (session.user.role === 'USER') await loadArchive()
    else await loadArchiveList()
  }
  if (key === 'consult') {
    if (session.user.role === 'USER') consultView.value = 'list'
    await loadConsultDoctors()
    await loadConsultations()
    if (session.user.role === 'USER' && !consultForm.doctorId && consultDoctors.value[0]) {
      consultForm.doctorId = consultDoctors.value[0].id
    }
  }
  if (key === 'medical' && session.user.role === 'ADMIN') await loadAdminMedicalData()
  if (key === 'schedule' && session.user.role === 'DOCTOR') await loadDoctorSchedules()
  if (key === 'medicine') {
    if (session.user.role === 'USER') medicineView.value = 'list'
    await loadMedicines()
  }
  if (key === 'health') {
    if (session.user.role === 'USER') healthView.value = 'list'
    await loadHealthData()
  }
  if (key === 'appointment') {
    if (session.user.role === 'USER') appointmentView.value = 'list'
    await loadAppointments()
  }
  if (key === 'emergency') {
    if (session.user.role === 'USER') emergencyView.value = 'list'
    await loadEmergencyRecords()
    if (session.user.role === 'USER') await loadContacts()
  }
  if (key === 'article') {
    if (session.user.role === 'USER') {
      articleView.value = 'list'
      selectedArticle.value = null
    }
    await loadArticles()
  }
  if (key === 'home' && session.user.role === 'ADMIN') {
    adminLoading.overview = true
    try {
      await Promise.all([loadDashboard(), loadAppointments(), loadEmergencyRecords()])
    } finally {
      adminLoading.overview = false
    }
  } else if (key === 'home' && session.user.role === 'DOCTOR') {
    await Promise.all([loadAppointments(), loadConsultations(), loadMedicines(), loadHealthData()])
  }
  await nextTick()
  if (key === 'dashboard') renderDashboard()
  if (key === 'health' && session.user.role === 'USER' && healthView.value === 'list') {
    await nextTick()
    renderHealthChart()
  }
}

async function loadAll() {
  const role = session.user.role
  if (role === 'ADMIN') {
    await Promise.all([
      loadAppointments(),
      loadEmergencyRecords(),
      loadArticles(),
      loadHospitals(),
      loadDashboard()
    ])
    return
  }
  if (role === 'DOCTOR') {
    await Promise.all([
      loadAppointments(),
      loadConsultations(),
      loadMedicines(),
      loadHealthData(),
      loadEmergencyRecords(),
      loadArticles(),
      loadDashboard()
    ])
    await loadArchiveList()
    return
  }
  await Promise.all([
    loadHospitals(),
    loadConsultDoctors(),
    loadAppointments(),
    loadMedicines(),
    loadHealthData(),
    loadContacts(),
    loadEmergencyRecords(),
    loadArticles(),
    loadConsultations()
  ])
  await loadArchive()
}

async function loadArchive() {
  const data = await request(api.get(`/api/archive/${session.user.id}`))
  Object.assign(archive, data.archive || { userId: session.user.id, name: session.user.realName, age: session.user.age, gender: session.user.gender, privacyLevel: 'AUTHORIZED_DOCTOR' })
  archiveFiles.value = data.files || []
}

async function saveArchive() {
  await run('保存档案', async () => {
    archive.userId = session.user.id
    const data = await request(api.post('/api/archive/save', archive))
    if (data?.id) archive.id = data.id
    await loadArchive()
  })
}

async function uploadArchiveFile(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  if (!archive.id) {
    notify('error', '请先保存档案后再上传附件')
    return
  }
  const formData = new FormData()
  formData.append('file', file)
  await run('上传附件', async () => {
    await request(api.post(`/api/archive/${archive.id}/upload`, formData, { headers: { 'Content-Type': 'multipart/form-data' } }))
    await loadArchive()
  })
}

async function loadArchiveList() {
  const rows = await request(api.get('/api/archive/list'))
  archiveRows.value = rows.map(item => ({
    ...item,
    updateTime: formatDateTime(item.updateTime) || '-'
  }))
}

async function viewArchiveDetail(userId) {
  await run('加载档案', async () => {
    archiveDetail.value = await request(api.get(`/api/archive/${userId}`))
  }, '')
}

async function loadConsultDoctors() {
  consultDoctors.value = await request(api.get('/api/medical/doctors'))
  if (consultDoctors.value[0] && !consultForm.doctorId) consultForm.doctorId = consultDoctors.value[0].id
}

function resetHospitalForm() {
  Object.assign(hospitalForm, { id: null, name: '', level: '', address: '', phone: '' })
}

function resetDepartmentForm() {
  Object.assign(departmentForm, { id: null, hospitalId: adminDeptHospitalId.value || '', name: '', description: '' })
}

function resetDoctorForm() {
  Object.assign(doctorForm, {
    id: null,
    userId: doctorUsers.value[0]?.id || '',
    hospitalId: adminDoctorHospitalId.value || '',
    departmentId: adminDoctorDepartments.value[0]?.id || '',
    title: '',
    specialty: '',
    profile: '',
    status: 'ACTIVE'
  })
}

function resetScheduleForm() {
  Object.assign(scheduleForm, { id: null, scheduleDate: selectedCalendarDate.value || '', timeSlot: '上午', totalQuota: 10 })
}

function editHospital(item) {
  Object.assign(hospitalForm, { ...item })
}

function editDepartment(item) {
  Object.assign(departmentForm, { ...item })
  adminDeptHospitalId.value = item.hospitalId
}

function editDoctor(item) {
  Object.assign(doctorForm, { ...item })
  adminDoctorHospitalId.value = item.hospitalId
  loadAdminDepartmentsForDoctor()
}

function editSchedule(item) {
  Object.assign(scheduleForm, {
    id: item.id,
    scheduleDate: String(item.scheduleDate).slice(0, 10),
    timeSlot: item.timeSlot,
    totalQuota: item.totalQuota
  })
  scheduleView.value = 'list'
}

async function confirmAdminDelete({ checkUrl, deleteUrl, label, onSuccess }) {
  try {
    const check = await request(api.get(checkUrl))
    if (!check.canDelete) {
      notify('error', check.message)
      return
    }
  } catch (error) {
    notify('error', error.message || '删除检查失败')
    return
  }
  if (!window.confirm(`确定删除「${label}」吗？此操作不可恢复。`)) return
  await run('删除', async () => {
    await request(api.post(deleteUrl))
    if (onSuccess) await onSuccess()
  })
}

async function deleteHospital(item) {
  await confirmAdminDelete({
    checkUrl: `/api/medical/hospital/delete-check/${item.id}`,
    deleteUrl: `/api/medical/hospital/delete/${item.id}`,
    label: item.name,
    onSuccess: async () => {
      if (hospitalForm.id === item.id) resetHospitalForm()
      await loadHospitals()
      if (adminDeptHospitalId.value === item.id) {
        adminDeptHospitalId.value = hospitals.value[0]?.id || ''
        await loadAdminDepartments()
      }
      if (adminDoctorHospitalId.value === item.id) {
        adminDoctorHospitalId.value = hospitals.value[0]?.id || ''
        await loadAdminDepartmentsForDoctor()
      }
    }
  })
}

async function deleteDepartment(item) {
  await confirmAdminDelete({
    checkUrl: `/api/medical/department/delete-check/${item.id}`,
    deleteUrl: `/api/medical/department/delete/${item.id}`,
    label: item.name,
    onSuccess: async () => {
      if (departmentForm.id === item.id) resetDepartmentForm()
      await loadAdminDepartments()
    }
  })
}

async function deleteDoctor(item) {
  await confirmAdminDelete({
    checkUrl: `/api/medical/doctor/delete-check/${item.id}`,
    deleteUrl: `/api/medical/doctor/delete/${item.id}`,
    label: item.doctorName,
    onSuccess: async () => {
      if (doctorForm.id === item.id) resetDoctorForm()
      await Promise.all([loadAdminDoctors(), loadConsultDoctors()])
      if (adminScheduleDoctorId.value === item.id) {
        adminScheduleDoctorId.value = adminDoctors.value[0]?.id || ''
        await loadAdminSchedules()
      }
    }
  })
}

async function switchAdminMedTab(key) {
  adminMedTab.value = key
  if (key === 'schedule') await loadAdminSchedules()
}

async function loadAdminMedicalData() {
  if (session.user.role !== 'ADMIN') return
  await Promise.all([loadHospitals(), loadDoctorUsers(), loadAdminDoctors()])
  if (!adminDeptHospitalId.value && hospitals.value[0]) adminDeptHospitalId.value = hospitals.value[0].id
  if (!adminDoctorHospitalId.value && hospitals.value[0]) adminDoctorHospitalId.value = hospitals.value[0].id
  await Promise.all([loadAdminDepartments(), loadAdminDepartmentsForDoctor()])
  if (!adminScheduleDoctorId.value && adminDoctors.value[0]) adminScheduleDoctorId.value = adminDoctors.value[0].id
  initBatchDates()
  if (adminMedTab.value === 'schedule') await loadAdminSchedules()
}

function initBatchDates() {
  const now = new Date()
  const year = now.getFullYear()
  const month = now.getMonth()
  batchForm.startDate = `${year}-${pad2(month + 1)}-01`
  batchForm.endDate = `${year}-${pad2(month + 1)}-${pad2(new Date(year, month + 1, 0).getDate())}`
}

async function loadDoctorUsers() {
  doctorUsers.value = await request(api.get('/api/users', { params: { role: 'DOCTOR' } }))
}

async function loadAdminDepartments() {
  if (!adminDeptHospitalId.value) return
  adminDepartments.value = await request(api.get('/api/medical/departments', { params: { hospitalId: adminDeptHospitalId.value } }))
}

async function loadAdminDepartmentsForDoctor() {
  if (!adminDoctorHospitalId.value) return
  adminDoctorDepartments.value = await request(api.get('/api/medical/departments', { params: { hospitalId: adminDoctorHospitalId.value } }))
  if (adminDoctorDepartments.value[0] && !doctorForm.departmentId) doctorForm.departmentId = adminDoctorDepartments.value[0].id
}

async function loadAdminDoctors() {
  const rows = await request(api.get('/api/medical/doctors', { params: { all: true } }))
  adminDoctors.value = rows.map(enrichDoctorRow)
}

async function saveHospital() {
  if (!hospitalForm.name?.trim()) {
    notify('error', '请填写医院名称')
    return
  }
  await run('保存医院', async () => {
    await request(api.post('/api/medical/hospital/save', { ...hospitalForm }))
    resetHospitalForm()
    await loadHospitals()
  })
}

async function saveDepartment() {
  if (!departmentForm.name?.trim()) {
    notify('error', '请填写科室名称')
    return
  }
  await run('保存科室', async () => {
    await request(api.post('/api/medical/department/save', { ...departmentForm, hospitalId: adminDeptHospitalId.value }))
    resetDepartmentForm()
    await loadAdminDepartments()
  })
}

async function saveDoctor() {
  if (!doctorForm.userId || !doctorForm.departmentId) {
    notify('error', '请选择医生账号和科室')
    return
  }
  await run('保存医生', async () => {
    await request(api.post('/api/medical/doctor/save', { ...doctorForm, hospitalId: adminDoctorHospitalId.value }))
    resetDoctorForm()
    await Promise.all([loadAdminDoctors(), loadConsultDoctors()])
  })
}

function adminScheduleRange() {
  const start = `${calendarMonth.year}-${pad2(calendarMonth.month)}-01`
  const endDay = new Date(calendarMonth.year, calendarMonth.month, 0).getDate()
  const end = `${calendarMonth.year}-${pad2(calendarMonth.month)}-${pad2(endDay)}`
  return { start, end }
}

async function loadAdminSchedules() {
  if (!adminScheduleDoctorId.value) return
  const range = adminScheduleRange()
  adminSchedules.value = await request(api.get('/api/medical/schedules/manage', {
    params: { doctorId: adminScheduleDoctorId.value, startDate: range.start, endDate: range.end }
  }))
}

async function saveBatchSchedule() {
  if (!adminScheduleDoctorId.value || !batchForm.startDate || !batchForm.endDate) {
    notify('error', '请选择医生和日期范围')
    return
  }
  if (!batchForm.weekdays.length || !batchForm.timeSlots.length) {
    notify('error', '请选择工作日和时段')
    return
  }
  await run('批量排班', async () => {
    const result = await request(api.post('/api/medical/schedule/batch', {
      doctorId: adminScheduleDoctorId.value,
      startDate: batchForm.startDate,
      endDate: batchForm.endDate,
      weekdays: batchForm.weekdays,
      timeSlots: batchForm.timeSlots,
      totalQuota: batchForm.totalQuota
    }))
    await loadAdminSchedules()
    notify('success', `批量排班完成：新增 ${result.created} 条，跳过 ${result.skipped} 条`)
  }, '')
}

async function saveSingleSchedule() {
  if (!adminScheduleDoctorId.value || !scheduleForm.scheduleDate || !scheduleForm.timeSlot) {
    notify('error', '请完善排班信息')
    return
  }
  await run('保存排班', async () => {
    await request(api.post('/api/medical/schedule/save', {
      ...scheduleForm,
      doctorId: adminScheduleDoctorId.value
    }))
    resetScheduleForm()
    await loadAdminSchedules()
  })
}

async function deleteSchedule(item) {
  const id = typeof item === 'object' ? item.id : item
  const label = typeof item === 'object'
    ? `${String(item.scheduleDate).slice(0, 10)} ${item.timeSlot}`
    : '该排班'
  await confirmAdminDelete({
    checkUrl: `/api/medical/schedule/delete-check/${id}`,
    deleteUrl: `/api/medical/schedule/delete/${id}`,
    label,
    onSuccess: async () => {
      if (scheduleForm.id === id) resetScheduleForm()
      await loadAdminSchedules()
    }
  })
}

function shiftCalendarMonth(step) {
  calendarMonth.month += step
  if (calendarMonth.month > 12) {
    calendarMonth.month = 1
    calendarMonth.year += 1
  } else if (calendarMonth.month < 1) {
    calendarMonth.month = 12
    calendarMonth.year -= 1
  }
  selectedCalendarDate.value = ''
  loadAdminSchedules()
}

function selectCalendarDay(cell) {
  if (cell.empty) return
  selectedCalendarDate.value = cell.dateStr
  scheduleView.value = 'list'
  resetScheduleForm()
}

function doctorScheduleRange() {
  const start = `${doctorCalendarMonth.year}-${pad2(doctorCalendarMonth.month)}-01`
  const endDay = new Date(doctorCalendarMonth.year, doctorCalendarMonth.month, 0).getDate()
  const end = `${doctorCalendarMonth.year}-${pad2(doctorCalendarMonth.month)}-${pad2(endDay)}`
  return { start, end }
}

async function loadDoctorSchedules() {
  if (session.user.role !== 'DOCTOR') return
  if (!session.doctor?.id) {
    notify('error', '未找到医生档案，请联系管理员')
    return
  }
  const range = doctorScheduleRange()
  doctorSchedules.value = await request(api.get('/api/medical/schedules/mine', {
    params: { startDate: range.start, endDate: range.end }
  }))
}

function shiftDoctorCalendarMonth(step) {
  doctorCalendarMonth.month += step
  if (doctorCalendarMonth.month > 12) {
    doctorCalendarMonth.month = 1
    doctorCalendarMonth.year += 1
  } else if (doctorCalendarMonth.month < 1) {
    doctorCalendarMonth.month = 12
    doctorCalendarMonth.year -= 1
  }
  doctorSelectedDate.value = ''
  loadDoctorSchedules()
}

function selectDoctorCalendarDay(cell) {
  if (cell.empty) return
  doctorSelectedDate.value = cell.dateStr
  doctorScheduleView.value = 'list'
}

async function loadHospitals() {
  hospitals.value = await request(api.get('/api/medical/hospitals'))
  if (!appointment.hospitalId && hospitals.value[0]) appointment.hospitalId = hospitals.value[0].id
  await loadDepartments()
}

async function loadDepartments() {
  if (!appointment.hospitalId) return
  departments.value = await request(api.get('/api/medical/departments', { params: { hospitalId: appointment.hospitalId } }))
  if (departments.value[0]) appointment.departmentId = departments.value[0].id
  else appointment.departmentId = ''
  await loadDoctors()
}

async function selectAppointmentHospital(hospitalId) {
  if (String(appointment.hospitalId) === String(hospitalId)) return
  appointment.hospitalId = hospitalId
  await loadDepartments()
}

async function selectAppointmentDepartment(departmentId) {
  if (String(appointment.departmentId) === String(departmentId)) return
  appointment.departmentId = departmentId
  await loadDoctors()
}

async function loadDoctors() {
  if (!appointment.hospitalId || !appointment.departmentId) {
    doctors.value = []
    appointment.doctorId = ''
    schedules.value = []
    appointment.scheduleId = ''
    return
  }
  doctors.value = await request(api.get('/api/medical/doctors', { params: { hospitalId: appointment.hospitalId, departmentId: appointment.departmentId } }))
  if (!doctors.value.length) doctors.value = await request(api.get('/api/medical/doctors'))
  if (doctors.value[0]) appointment.doctorId = doctors.value[0].id
  else appointment.doctorId = ''
  await loadSchedules()
}

async function selectAppointmentDoctor(doctorId) {
  if (String(appointment.doctorId) === String(doctorId)) return
  appointment.doctorId = doctorId
  await loadSchedules()
}

async function loadSchedules() {
  if (!appointment.doctorId) {
    schedules.value = []
    appointment.scheduleId = ''
    appointmentScheduleDate.value = ''
    return
  }
  schedules.value = await request(api.get('/api/medical/schedules', { params: { doctorId: appointment.doctorId } }))
  syncAppointmentScheduleDate()
}

function selectAppointmentSchedule(scheduleId) {
  appointment.scheduleId = scheduleId
}

async function loadAppointments() {
  const params = {}
  if (session.user.role === 'USER') params.userId = session.user.id
  if (session.user.role === 'DOCTOR') params.doctorId = session.doctor?.id
  const loader = async () => {
    const rows = await request(api.get('/api/medical/appointments', { params }))
    appointments.value = rows.map(enrichAppointmentRow)
  }
  if (session.user.role === 'ADMIN') await withAdminLoading('appointment', loader)
  else await loader()
}

async function createAppointment() {
  if (!appointment.scheduleId) {
    notify('error', '请选择可预约排班')
    return
  }
  await run('提交预约', async () => {
    await request(api.post('/api/medical/appointment/create', { ...appointment, userId: session.user.id }))
    appointment.scheduleId = ''
    appointment.symptom = ''
    appointmentView.value = 'list'
    await Promise.all([loadAppointments(), loadSchedules()])
  })
}

async function cancelAppointment(id) {
  if (!window.confirm('确定取消该预约吗？取消后号源将返还。')) return
  await run('取消预约', async () => {
    await request(api.post(`/api/medical/appointment/cancel/${id}`))
    await loadAppointments()
  })
}

async function finishAppointment(id) {
  if (!window.confirm('确定将该预约标记为已完成就诊吗？')) return
  await run('完成就诊', async () => {
    await request(api.post(`/api/medical/appointment/finish/${id}`))
    await loadAppointments()
  })
}

async function loadMedicines() {
  const params = session.user.role === 'USER' ? { userId: session.user.id } : {}
  medicines.value = decorateRows(await request(api.get('/api/medicine/list', { params })))
}

async function saveMedicine() {
  if (!medicine.medicineName?.trim()) {
    notify('error', '请填写药品名称')
    return
  }
  await run('保存用药', async () => {
    await request(api.post('/api/medicine/save', { ...medicine, userId: session.user.id, status: 'ACTIVE' }))
    Object.assign(medicine, { medicineName: '', usageMethod: '口服', dosage: '', reminderTimes: '08:00', startDate: '', endDate: '' })
    await loadMedicines()
    medicineView.value = 'list'
  })
}

async function finishMedicine(id) {
  if (!window.confirm('确定结束该用药记录吗？')) return
  await run('结束用药', async () => {
    await request(api.post(`/api/medicine/finish/${id}`))
    await loadMedicines()
  })
}

async function loadHealthData() {
  const params = session.user.role === 'USER' ? { userId: session.user.id } : {}
  const rows = await request(api.get('/api/health-data/list', { params }))
  healthList.value = rows.map(item => ({
    ...item,
    recordTimeRaw: item.recordTime,
    recordTimeDisplay: formatDateTime(item.recordTime) || '-'
  }))
  if (session.user.role === 'USER' && tab.value === 'health' && healthView.value === 'list') {
    await nextTick()
    renderHealthChart()
  }
}

async function saveHealthData() {
  const hasValue = health.systolic != null || health.diastolic != null || health.bloodSugar != null
    || health.heartRate != null || health.steps != null || health.sleepHours != null || health.weight != null
  if (!hasValue) {
    notify('error', '请至少填写一项健康数据')
    return
  }
  await run('保存健康数据', async () => {
    await request(api.post('/api/health-data/save', { ...health, userId: session.user.id }))
    Object.assign(health, { systolic: null, diastolic: null, bloodSugar: null, heartRate: null, steps: null, sleepHours: null, weight: null })
    healthView.value = 'list'
    await loadHealthData()
  })
}

async function loadContacts() {
  if (session.user.role !== 'USER') return
  contacts.value = await request(api.get('/api/emergency/contacts', { params: { userId: session.user.id } }))
}

async function saveContact() {
  if (!contact.name?.trim() || !contact.phone?.trim()) {
    notify('error', '请填写联系人姓名和电话')
    return
  }
  await run('保存联系人', async () => {
    await request(api.post('/api/emergency/contact/save', { ...contact, userId: session.user.id, sortNo: contacts.value.length + 1 }))
    Object.assign(contact, { name: '', relation: '', phone: '' })
    emergencyView.value = 'list'
    await loadContacts()
  })
}

async function sendHelp() {
  if (!emergency.locationText?.trim()) {
    notify('error', '请填写当前位置')
    return
  }
  if (!window.confirm('确定发送求救信息吗？系统将通知紧急联系人。')) return
  await run('发送求救', async () => {
    await request(api.post('/api/emergency/help', { ...emergency, userId: session.user.id, latitude: '30.26', longitude: '120.17' }))
    emergencyView.value = 'list'
    await loadEmergencyRecords()
  }, '求救信息已发送')
}

async function loadEmergencyRecords() {
  const params = session.user.role === 'USER' ? { userId: session.user.id } : {}
  const loader = async () => {
    const rows = await request(api.get('/api/emergency/records', { params }))
    emergencyRecords.value = rows.map(enrichEmergencyRow)
  }
  if (session.user.role === 'ADMIN') await withAdminLoading('emergency', loader)
  else await loader()
}

async function finishEmergency(item) {
  const id = typeof item === 'object' ? item.id : item
  const label = typeof item === 'object' ? `${item.userName} · ${item.locationText}` : '该求救记录'
  const result = window.prompt(`请输入处理结果（${label}）`, '已联系紧急联系人并确认安全')
  if (result === null) return
  if (!result.trim()) {
    notify('error', '请填写处理结果')
    return
  }
  if (!window.confirm('确定将该求救标记为已完成吗？')) return
  await run('处理求救', async () => {
    await request(api.post(`/api/emergency/record/finish/${id}`, null, { params: { result: result.trim() } }))
    await loadEmergencyRecords()
  })
}

async function loadArticles() {
  const loader = async () => {
    articles.value = await request(api.get('/api/articles', { params: { keyword: articleKeyword.value } }))
  }
  if (session.user.role === 'ADMIN') await withAdminLoading('article', loader)
  else await loader()
}

async function searchArticles() {
  await run('搜索文章', async () => {
    await loadArticles()
    resetPatientArticlePage()
    resetDoctorArticlePage()
  }, '')
}

async function clearArticleSearch() {
  articleKeyword.value = ''
  await searchArticles()
}

function setMedicinePageSize(value) {
  medicinePageSize.value = value
}

function setPatientArticlePageSize(value) {
  patientArticlePageSize.value = value
}

function setConsultPageSize(value) {
  consultPageSize.value = value
}

function setDoctorArticlePageSize(value) {
  doctorArticlePageSize.value = value
}

function closeArticle() {
  articleView.value = 'list'
  selectedArticle.value = null
}

async function openArticle(id) {
  await run('打开文章', async () => {
    selectedArticle.value = await request(api.get(`/api/articles/${id}`))
    if (session.user.role === 'USER') articleView.value = 'detail'
    await loadArticles()
  }, '')
}

async function saveArticle() {
  if (!articleForm.title?.trim() || !articleForm.content?.trim()) {
    notify('error', '请填写文章标题和正文')
    return
  }
  await run('保存文章', async () => {
    await request(api.post('/api/articles/save', { ...articleForm, authorId: session.user.id }))
    resetArticleForm()
    selectedArticle.value = null
    await loadArticles()
  })
}

async function previewArticle(id) {
  await run('预览文章', async () => {
    selectedArticle.value = await request(api.get(`/api/articles/${id}/edit`))
  }, '')
}

async function editArticle(item) {
  await run('载入文章', async () => {
    const detail = await request(api.get(`/api/articles/${item.id}/edit`))
    selectedArticle.value = detail
    Object.assign(articleForm, {
      id: detail.id,
      title: detail.title || '',
      category: detail.category || '养生',
      diseaseTag: detail.diseaseTag || '',
      summary: detail.summary || '',
      content: detail.content || ''
    })
  }, '')
}

async function deleteArticle(item) {
  if (!window.confirm(`确定删除文章「${item.title}」吗？此操作不可恢复。`)) return
  await run('删除文章', async () => {
    await request(api.post(`/api/articles/delete/${item.id}`))
    if (selectedArticle.value?.id === item.id) selectedArticle.value = null
    if (articleForm.id === item.id) resetArticleForm()
    await loadArticles()
  })
}

function resetArticleForm() {
  Object.assign(articleForm, { id: null, title: '', category: '养生', diseaseTag: '', summary: '', content: '' })
}

async function loadConsultations() {
  const params = {}
  if (session.user.role === 'USER') params.userId = session.user.id
  if (session.user.role === 'DOCTOR') params.doctorId = session.doctor?.id
  const rows = await request(api.get('/api/consultations', { params }))
  consultations.value = rows.map(enrichConsultRow)
  if (session.user.role === 'DOCTOR' && activeConsultation.value) {
    const latest = consultations.value.find(item => item.id === activeConsultation.value.id)
    if (latest) activeConsultation.value = latest
    else activeConsultation.value = null
  }
}

async function createConsultation() {
  if (!consultForm.doctorId) {
    notify('error', '请选择咨询医生')
    return
  }
  await run('创建咨询', async () => {
    const data = await request(api.post('/api/consultations/create', { userId: session.user.id, doctorId: consultForm.doctorId, title: consultForm.title || '健康咨询' }))
    const row = enrichConsultRow(data)
    consultations.value.unshift(row)
    consultForm.title = ''
    await openConsultation(row)
  })
}

async function openConsultation(item) {
  activeConsultation.value = item
  followUpText.value = item.followUpTimeRaw
    ? String(item.followUpTimeRaw).replace(' ', 'T').slice(0, 16)
    : ''
  messages.value = await request(api.get(`/api/consultations/${item.id}/messages`))
  if (session.user.role === 'USER') {
    consultView.value = 'chat'
  }
  await nextTick()
  scrollChatToBottom()
}

async function sendMessage() {
  if (!messageText.value?.trim()) {
    notify('error', '请输入咨询内容')
    return
  }
  if (!activeConsultation.value) return
  await run('发送消息', async () => {
    await request(api.post('/api/consultations/message/send', {
      consultationId: activeConsultation.value.id,
      senderId: session.user.id,
      senderRole: session.user.role,
      content: messageText.value
    }))
    messageText.value = ''
    await openConsultation(activeConsultation.value)
    await nextTick()
    scrollChatToBottom()
  }, '')
}

async function closeConsultation(id) {
  if (!window.confirm('确定关闭该咨询会话吗？关闭后双方将无法继续发送消息。')) return
  await run('关闭咨询', async () => {
    await request(api.post(`/api/consultations/close/${id}`))
    await loadConsultations()
    if (activeConsultation.value?.id === id) {
      activeConsultation.value.status = 'CLOSED'
      activeConsultation.value.statusText = statusTextMap.CLOSED
    }
  })
}

async function deleteConsultation(item) {
  try {
    const check = await request(api.get(`/api/consultations/delete-check/${item.id}`))
    if (!check.canDelete) {
      notify('error', check.message)
      return
    }
    const extra = check.messageCount > 0 ? `，${check.message}` : ''
    if (!window.confirm(`确定删除「${item.title}」吗？此操作不可恢复${extra}。`)) return
  } catch (error) {
    notify('error', error.message || '删除检查失败')
    return
  }
  await run('删除咨询', async () => {
    await request(api.post(`/api/consultations/delete/${item.id}`))
    if (activeConsultation.value?.id === item.id) {
      stopConsultMessagePolling()
      activeConsultation.value = null
      messages.value = []
      messageText.value = ''
      followUpText.value = ''
    }
    await loadConsultations()
  })
}

async function setFollowUp() {
  if (!activeConsultation.value) return
  if (!followUpText.value) {
    notify('error', '请选择复诊时间')
    return
  }
  await run('设置复诊', async () => {
    const data = await request(api.post(`/api/consultations/follow-up/${activeConsultation.value.id}`, null, { params: { followUpTime: followUpText.value } }))
    activeConsultation.value = enrichConsultRow({ ...activeConsultation.value, ...data })
    await loadConsultations()
  })
}

async function loadDashboard() {
  if (session.user.role === 'ADMIN') dashboard.value = await request(api.get('/api/dashboard/admin'))
  if (session.user.role === 'DOCTOR') {
    if (!session.doctor?.id) {
      notify('error', '未找到医生档案，请联系管理员')
      return
    }
    dashboard.value = await request(api.get(`/api/dashboard/doctor/${session.doctor.id}`))
  }
  await nextTick()
  renderDashboard()
}

async function refreshDashboard() {
  await run('刷新统计', loadDashboard, '统计已刷新')
}

function renderHealthChart() {
  const el = document.getElementById('healthChart')
  if (!el) return
  const list = [...healthList.value].reverse()
  chartInstances.health?.dispose()
  chartInstances.health = echarts.init(el)
  chartInstances.health.setOption({
    title: list.length ? undefined : { text: '暂无监测数据', left: 'center', top: 'center', textStyle: { color: '#9ca3af', fontSize: 14 } },
    tooltip: { trigger: 'axis' },
    legend: { data: ['收缩压', '舒张压', '血糖'], bottom: 0 },
    grid: { left: 36, right: 12, top: 16, bottom: 48 },
    xAxis: { type: 'category', data: list.map(item => String(item.recordTimeRaw || item.recordTimeDisplay || '').slice(5, 16)) },
    yAxis: { type: 'value', scale: true },
    series: [
      { name: '收缩压', type: 'line', smooth: true, data: list.map(item => item.systolic) },
      { name: '舒张压', type: 'line', smooth: true, data: list.map(item => item.diastolic) },
      { name: '血糖', type: 'line', smooth: true, data: list.map(item => item.bloodSugar) }
    ]
  })
}

function mapKeys(obj = {}) {
  return Object.keys(obj)
}

function mapValues(obj = {}) {
  return Object.values(obj)
}

function translateChartLabel(name) {
  return statusTextMap[name] || dashboardCardLabels[name] || name
}

function toChartPieData(obj = {}) {
  return Object.entries(obj).map(([name, value]) => ({ name: translateChartLabel(name), value }))
}

function renderDashboard() {
  if (!document.getElementById('chartA')) return
  const trend = dashboard.value.appointmentTrend || {}
  const status = dashboard.value.appointmentStatus || dashboard.value.consultationStatus || {}
  const third = dashboard.value.warningTrend || dashboard.value.patientWarnings || {}
  const fourth = session.user?.role === 'ADMIN'
    ? (dashboard.value.articleCategory || dashboard.value.emergencyStatus || {})
    : (dashboard.value.consultationStatus || dashboard.value.articleCategory || dashboard.value.rolePie || {})
  ;['chartA', 'chartB', 'chartC', 'chartD'].forEach(id => chartInstances[id]?.dispose())
  chartInstances.chartA = echarts.init(document.getElementById('chartA'))
  chartInstances.chartB = echarts.init(document.getElementById('chartB'))
  chartInstances.chartC = echarts.init(document.getElementById('chartC'))
  chartInstances.chartD = echarts.init(document.getElementById('chartD'))
  chartInstances.chartA.setOption({ tooltip: {}, xAxis: { type: 'category', data: mapKeys(trend) }, yAxis: { type: 'value' }, series: [{ type: 'bar', data: mapValues(trend), itemStyle: { color: '#2f80ed' } }] })
  chartInstances.chartB.setOption({ tooltip: {}, series: [{ type: 'pie', radius: '62%', data: toChartPieData(status) }] })
  chartInstances.chartC.setOption({ tooltip: {}, xAxis: { type: 'category', data: mapKeys(third) }, yAxis: { type: 'value' }, series: [{ type: 'line', data: mapValues(third), smooth: true, itemStyle: { color: '#eb5757' } }] })
  chartInstances.chartD.setOption({ tooltip: {}, series: [{ type: 'pie', radius: ['42%', '70%'], data: toChartPieData(fourth) }] })
}

onMounted(async () => {
  initPortalLogin()
  if (session.user) {
    if (!session.token) {
      logout(true)
      notify('error', '登录状态已失效，请重新登录')
      return
    }
    ensurePortalSession()
    if (!session.user) return
    tab.value = session.user.role === 'USER' ? 'home' : 'dashboard'
    try {
      await loadAll()
    } catch (error) {
      notify('error', error.message || '初始化数据失败')
    }
  }
})

watch([tab, consultView, () => activeConsultation.value?.id], () => {
  if (shouldPollConsultMessages()) startConsultMessagePolling()
  else stopConsultMessagePolling()
})

onUnmounted(() => {
  stopConsultMessagePolling()
})
</script>

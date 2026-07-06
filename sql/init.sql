-- ============================================================
-- 健康管理系统 初始化脚本 (v4.1)
-- OPC_K PowerShell 5.1 实战版
-- ============================================================
--
-- 用法 (PowerShell 5.1):
--   Get-Content sql\init.sql -Encoding UTF8 | & "C:\path\to\mysql.exe" -h "127.0.0.1" -P 3306 -u root -popck2026 --default-character-set=utf8mb4
--
-- 关键规则:
--   1. 文件必须 UTF-8 BOM (中文 Windows 默认 GBK 解码会乱码)
--   2. mysql 客户端必须 -h "127.0.0.1" (加空格 + 双引号, 避免 PS 5.1 截断)
--   3. mysql 客户端必须 --default-character-set=utf8mb4 (输出编码)
--   4. PowerShell 用 Get-Content | mysql 管道 (PS 5.1 不支持 < 重定向)
--
-- 表清单 (15 张):
--   sys_user (6 角色账号)
--   hospital (5)
--   department (10)
--   doctor (5)
--   doctor_schedule (8)
--   medicine (8)
--   medicine_record (8)
--   health_article (4)
--   consultation (3)
--   consultation_message (5)
--   health_archive (5)
--   archive_file (5)
--   health_data (10)
--   emergency_contact (5)
--   emergency_record (2)
--
-- 端口: 3306 (默认, 可改)
-- 数据库: health_management (utf8mb4)
-- 用户: root / opck2026 (跟 application.yml 一致)
-- ============================================================

DROP DATABASE IF EXISTS health_management;
CREATE DATABASE health_management DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE health_management;

-- ============================================================
-- 1. sys_user (6 角色账号, 密码统一 root)
-- ============================================================
CREATE TABLE sys_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录账号',
    password VARCHAR(50) NOT NULL COMMENT '明文密码, 课程演示用',
    real_name VARCHAR(50) NOT NULL COMMENT '真实姓名',
    phone VARCHAR(30) COMMENT '手机号',
    role VARCHAR(20) NOT NULL COMMENT '角色: USER用户/DOCTOR医生/ADMIN管理员',
    gender VARCHAR(10) COMMENT '性别',
    age INT COMMENT '年龄',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '账号状态',
    create_time DATETIME NOT NULL COMMENT '创建时间'
) COMMENT='系统用户表';

-- ============================================================
-- 2. hospital
-- ============================================================
CREATE TABLE hospital (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    name VARCHAR(100) NOT NULL COMMENT '医院名称',
    level VARCHAR(30) COMMENT '医院等级',
    address VARCHAR(200) COMMENT '医院地址',
    phone VARCHAR(30) COMMENT '联系电话'
) COMMENT='医院表';

-- ============================================================
-- 3. department
-- ============================================================
CREATE TABLE department (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    hospital_id BIGINT NOT NULL COMMENT '所属医院ID',
    name VARCHAR(50) NOT NULL COMMENT '科室名称',
    description VARCHAR(200) COMMENT '科室描述',
    FOREIGN KEY (hospital_id) REFERENCES hospital(id)
) COMMENT='科室表';

-- ============================================================
-- 4. doctor
-- ============================================================
CREATE TABLE doctor (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '关联用户ID',
    department_id BIGINT NOT NULL COMMENT '所属科室ID',
    title VARCHAR(30) COMMENT '职称',
    specialty VARCHAR(200) COMMENT '擅长',
    introduction TEXT COMMENT '医生简介',
    FOREIGN KEY (user_id) REFERENCES sys_user(id),
    FOREIGN KEY (department_id) REFERENCES department(id)
) COMMENT='医生表';

-- ============================================================
-- 5. doctor_schedule
-- ============================================================
CREATE TABLE doctor_schedule (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    doctor_id BIGINT NOT NULL COMMENT '医生ID',
    schedule_date DATE NOT NULL COMMENT '排班日期',
    time_slot VARCHAR(20) NOT NULL COMMENT '时段: MORNING/AFTERNOON/EVENING',
    max_patients INT NOT NULL DEFAULT 20 COMMENT '最大接诊数',
    booked_count INT NOT NULL DEFAULT 0 COMMENT '已预约数',
    FOREIGN KEY (doctor_id) REFERENCES doctor(id)
) COMMENT='医生排班表';

-- ============================================================
-- 6. medicine
-- ============================================================
CREATE TABLE medicine (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    name VARCHAR(100) NOT NULL COMMENT '药品名称',
    spec VARCHAR(50) COMMENT '规格',
    unit VARCHAR(20) COMMENT '单位',
    manufacturer VARCHAR(100) COMMENT '生产厂家',
    description VARCHAR(200) COMMENT '药品描述'
) COMMENT='药品表';

-- ============================================================
-- 7. medicine_record
-- ============================================================
CREATE TABLE medicine_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    medicine_id BIGINT NOT NULL COMMENT '药品ID',
    dosage VARCHAR(50) COMMENT '剂量',
    frequency VARCHAR(50) COMMENT '服用频率',
    take_time DATETIME COMMENT '服用时间',
    remark VARCHAR(200) COMMENT '备注',
    FOREIGN KEY (user_id) REFERENCES sys_user(id),
    FOREIGN KEY (medicine_id) REFERENCES medicine(id)
) COMMENT='用药记录表';

-- ============================================================
-- 8. health_article
-- ============================================================
CREATE TABLE health_article (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    title VARCHAR(200) NOT NULL COMMENT '文章标题',
    category VARCHAR(30) NOT NULL COMMENT '分类: 疾病/饮食/运动/养生',
    disease_tag VARCHAR(100) COMMENT '疾病标签',
    summary VARCHAR(300) COMMENT '摘要',
    content TEXT COMMENT '正文',
    author_id BIGINT COMMENT '作者ID',
    view_count INT NOT NULL DEFAULT 0 COMMENT '浏览数',
    publish_time DATETIME COMMENT '发布时间'
) COMMENT='健康文章表';

-- ============================================================
-- 9. consultation
-- ============================================================
CREATE TABLE consultation (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    doctor_id BIGINT NOT NULL COMMENT '医生ID',
    title VARCHAR(200) NOT NULL COMMENT '咨询主题',
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN' COMMENT '状态: OPEN/CLOSED',
    create_time DATETIME NOT NULL COMMENT '创建时间',
    follow_up_time DATETIME COMMENT '复诊时间',
    FOREIGN KEY (user_id) REFERENCES sys_user(id),
    FOREIGN KEY (doctor_id) REFERENCES doctor(id)
) COMMENT='咨询表';

-- ============================================================
-- 10. consultation_message
-- ============================================================
CREATE TABLE consultation_message (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    consultation_id BIGINT NOT NULL COMMENT '咨询ID',
    sender_id BIGINT NOT NULL COMMENT '发送者ID',
    sender_role VARCHAR(20) NOT NULL COMMENT '发送者角色',
    message_type VARCHAR(20) NOT NULL DEFAULT 'TEXT' COMMENT '消息类型',
    content TEXT NOT NULL COMMENT '消息内容',
    send_time DATETIME NOT NULL COMMENT '发送时间',
    FOREIGN KEY (consultation_id) REFERENCES consultation(id)
) COMMENT='咨询消息表';

-- ============================================================
-- 11. health_archive
-- ============================================================
CREATE TABLE health_archive (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    title VARCHAR(200) NOT NULL COMMENT '档案标题',
    category VARCHAR(30) NOT NULL COMMENT '档案分类',
    record_date DATE NOT NULL COMMENT '记录日期',
    hospital VARCHAR(100) COMMENT '就诊医院',
    description TEXT COMMENT '档案描述',
    create_time DATETIME NOT NULL COMMENT '创建时间',
    FOREIGN KEY (user_id) REFERENCES sys_user(id)
) COMMENT='健康档案表';

-- ============================================================
-- 12. archive_file
-- ============================================================
CREATE TABLE archive_file (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    archive_id BIGINT NOT NULL COMMENT '档案ID',
    file_name VARCHAR(200) NOT NULL COMMENT '文件名',
    file_path VARCHAR(300) NOT NULL COMMENT '文件路径',
    file_size BIGINT COMMENT '文件大小(字节)',
    upload_time DATETIME NOT NULL COMMENT '上传时间',
    FOREIGN KEY (archive_id) REFERENCES health_archive(id)
) COMMENT='档案文件表';

-- ============================================================
-- 13. health_data (10 种健康指标)
-- ============================================================
CREATE TABLE health_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    data_type VARCHAR(20) NOT NULL COMMENT '数据类型: STEPS/HEART_RATE/BLOOD_PRESSURE/TEMPERATURE/BLOOD_SUGAR/WEIGHT/SLEEP/SPO2/CALORIES/DISTANCE',
    value1 DECIMAL(10,2) COMMENT '数值1',
    value2 DECIMAL(10,2) COMMENT '数值2 (血压收缩压/舒张压)',
    unit VARCHAR(20) COMMENT '单位',
    record_time DATETIME NOT NULL COMMENT '记录时间',
    status VARCHAR(20) NOT NULL DEFAULT 'NORMAL' COMMENT '状态: NORMAL/WARN/DANGER',
    remark VARCHAR(200) COMMENT '备注',
    FOREIGN KEY (user_id) REFERENCES sys_user(id)
) COMMENT='健康数据表';

-- ============================================================
-- 14. emergency_contact
-- ============================================================
CREATE TABLE emergency_contact (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    name VARCHAR(50) NOT NULL COMMENT '联系人姓名',
    relation VARCHAR(20) COMMENT '关系',
    phone VARCHAR(30) NOT NULL COMMENT '联系电话',
    sort_no INT DEFAULT 0 COMMENT '排序',
    FOREIGN KEY (user_id) REFERENCES sys_user(id)
) COMMENT='紧急联系人表';

-- ============================================================
-- 15. emergency_record
-- ============================================================
CREATE TABLE emergency_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    location_text VARCHAR(200) COMMENT '位置描述',
    latitude VARCHAR(30) COMMENT '纬度',
    longitude VARCHAR(30) COMMENT '经度',
    contact_snapshot VARCHAR(500) COMMENT '联系人快照',
    status VARCHAR(20) NOT NULL DEFAULT 'PROCESSING' COMMENT '状态: PROCESSING/FINISHED',
    help_time DATETIME NOT NULL COMMENT '求救时间',
    result VARCHAR(500) COMMENT '处理结果',
    FOREIGN KEY (user_id) REFERENCES sys_user(id)
) COMMENT='紧急求救记录表';

-- ============================================================
-- 种子数据 (16 个 INSERT 段)
-- ============================================================

-- sys_user (6 角色账号, 密码统一 root)
INSERT INTO sys_user (id, username, password, real_name, phone, role, gender, age, status, create_time) VALUES
(1, 'admin', 'root', '管理员', '13800000001', 'ADMIN', '男', 35, 'ACTIVE', '2026-05-01 09:00:00'),
(2, 'doctor_zhang', 'root', '张医生', '13800000002', 'DOCTOR', '男', 42, 'ACTIVE', '2026-05-01 09:00:00'),
(3, 'doctor_li', 'root', '李医生', '13800000003', 'DOCTOR', '女', 38, 'ACTIVE', '2026-05-01 09:00:00'),
(4, 'user_wang', 'root', '王先生', '13800000004', 'USER', '男', 28, 'ACTIVE', '2026-05-01 09:00:00'),
(5, 'user_chen', 'root', '陈女士', '13800000005', 'USER', '女', 56, 'ACTIVE', '2026-05-01 09:00:00'),
(6, 'user_zhao', 'root', '赵先生', '13800000006', 'USER', '男', 31, 'ACTIVE', '2026-05-01 09:00:00');

-- hospital (5)
INSERT INTO hospital (id, name, level, address, phone) VALUES
(1, '杭州市第一人民医院', '三甲', '杭州市上城区浣纱路 261 号', '0571-87000001'),
(2, '浙江大学医学院附属第二医院', '三甲', '杭州市上城区解放路 88 号', '0571-87000002'),
(3, '浙江省人民医院', '三甲', '杭州市拱墅区上塘路 158 号', '0571-87000003'),
(4, '杭州市中医院', '三甲', '杭州市西湖区体育场路 453 号', '0571-87000004'),
(5, '邵逸夫医院', '三甲', '杭州市江干区庆春东路 3 号', '0571-87000005');

-- department (10)
INSERT INTO department (id, hospital_id, name, description) VALUES
(1, 1, '心血管内科', '高血压、冠心病、心律失常诊治'),
(2, 1, '内分泌科', '糖尿病、甲状腺疾病诊治'),
(3, 2, '神经内科', '脑血管、头痛、失眠诊治'),
(4, 2, '消化内科', '胃肠、肝胆疾病诊治'),
(5, 3, '呼吸内科', '哮喘、慢阻肺、肺部感染诊治'),
(6, 3, '肾内科', '肾病、尿路感染诊治'),
(7, 4, '中医内科', '中医辨证论治常见慢性病'),
(8, 4, '针灸康复科', '中医针灸、推拿、康复治疗'),
(9, 5, '全科医学科', '常见病、多发病综合诊治'),
(10, 5, '营养科', '营养评估与饮食指导');

-- doctor (5)
INSERT INTO doctor (id, user_id, department_id, title, specialty, introduction) VALUES
(1, 2, 1, '主任医师', '高血压、冠心病、心力衰竭', '从事心血管内科临床工作 20 年, 擅长高血压及心衰管理。'),
(2, 3, 2, '副主任医师', '糖尿病、甲状腺疾病、痛风', '内分泌科 15 年临床经验, 关注慢病综合管理。'),
(3, 2, 3, '副主任医师', '脑血管、失眠、头痛', '神经内科工作 12 年, 擅长中西医结合治疗头痛失眠。'),
(4, 3, 5, '主治医师', '哮喘、慢阻肺', '呼吸内科 10 年临床经验, 长期随访慢阻肺患者。'),
(5, 2, 9, '主治医师', '常见病综合诊治', '全科医学方向, 提供一站式慢病管理建议。');

-- doctor_schedule (8)
INSERT INTO doctor_schedule (id, doctor_id, schedule_date, time_slot, max_patients, booked_count) VALUES
(1, 1, '2026-07-07', 'MORNING', 20, 3),
(2, 1, '2026-07-07', 'AFTERNOON', 20, 5),
(3, 2, '2026-07-08', 'MORNING', 15, 2),
(4, 2, '2026-07-09', 'AFTERNOON', 15, 0),
(5, 3, '2026-07-07', 'EVENING', 10, 1),
(6, 4, '2026-07-08', 'MORNING', 12, 4),
(7, 5, '2026-07-09', 'AFTERNOON', 18, 6),
(8, 5, '2026-07-10', 'MORNING', 18, 0);

-- medicine (8)
INSERT INTO medicine (id, name, spec, unit, manufacturer, description) VALUES
(1, '硝苯地平缓释片', '20mg*30 片', '盒', '拜耳医药', '用于高血压治疗'),
(2, '二甲双胍片', '0.5g*60 片', '瓶', '中美上海施贵宝', '用于 2 型糖尿病治疗'),
(3, '阿司匹林肠溶片', '100mg*30 片', '盒', '拜耳医药', '抗血小板, 心血管预防'),
(4, '辛伐他汀片', '20mg*30 片', '盒', '杭州默沙东', '降脂治疗'),
(5, '复方甘草酸苷片', '25mg*100 片', '盒', '日本米诺发源', '护肝治疗'),
(6, '盐酸二甲双胍缓释片', '0.5g*30 片', '盒', '默克', '糖尿病一线用药'),
(7, '维生素 D3 滴剂', '400IU*30 粒', '盒', '国药控股', '补充维生素 D'),
(8, '奥美拉唑肠溶胶囊', '20mg*28 粒', '盒', '阿斯利康', '质子泵抑制剂, 治疗胃酸过多');

-- medicine_record (8)
INSERT INTO medicine_record (id, user_id, medicine_id, dosage, frequency, take_time, remark) VALUES
(1, 4, 2, '0.5g', '每日 2 次', '2026-06-22 08:00:00', '餐后服用'),
(2, 4, 7, '1 粒', '每日 1 次', '2026-06-22 09:00:00', '随餐服用'),
(3, 5, 1, '20mg', '每日 1 次', '2026-06-21 08:30:00', '长效降压'),
(4, 5, 3, '100mg', '每日 1 次', '2026-06-21 20:00:00', '睡前服用'),
(5, 5, 4, '20mg', '每日 1 次', '2026-06-21 20:00:00', '降脂'),
(6, 6, 8, '20mg', '每日 1 次', '2026-06-20 07:30:00', '空腹服用'),
(7, 4, 6, '0.5g', '每日 1 次', '2026-06-22 20:00:00', '缓释片'),
(8, 5, 5, '2 片', '每日 3 次', '2026-06-22 12:00:00', '护肝');

-- health_article (4)
INSERT INTO health_article (id, title, category, disease_tag, summary, content, author_id, view_count, publish_time) VALUES
(1, '高血压患者的家庭血压监测要点', '疾病', '高血压', '介绍血压测量时间、姿势和异常处理。', '建议每天固定时间测量血压, 连续记录趋势; 若多次超过 140/90mmHg, 应及时咨询医生。', 2, 156, '2026-05-09 08:30:00'),
(2, '控糖饮食的三餐搭配方法', '饮食', '糖尿病,血糖', '帮助用户合理安排主食、蛋白质和蔬菜。', '每餐控制精制碳水比例, 优先选择全谷物、优质蛋白和高纤维蔬菜。', 2, 132, '2026-05-18 09:00:00'),
(3, '久坐人群的低强度运动计划', '运动', '运动', '适合办公室人群的步行和拉伸建议。', '建议每坐 60 分钟起身活动 3-5 分钟, 每周累计 150 分钟中等强度运动。', 3, 98, '2026-06-03 10:15:00'),
(4, '夏季睡眠与心率恢复', '养生', '心率,睡眠', '讲解睡眠不足对心率和恢复能力的影响。', '保持规律作息、睡前减少咖啡因摄入, 有助于改善心率恢复。', 3, 87, '2026-06-16 11:20:00');

-- consultation (3)
INSERT INTO consultation (id, user_id, doctor_id, title, status, create_time, follow_up_time) VALUES
(1, 4, 1, '餐后血糖偏高咨询', 'CLOSED', '2026-05-18 21:30:00', '2026-06-18 09:00:00'),
(2, 5, 2, '血压波动和胸闷', 'OPEN', '2026-06-22 21:00:00', '2026-06-25 10:00:00'),
(3, 6, 2, '运动后心率偏快', 'OPEN', '2026-06-23 20:00:00', NULL);

-- consultation_message (5)
INSERT INTO consultation_message (id, consultation_id, sender_id, sender_role, message_type, content, send_time) VALUES
(1, 1, 4, 'USER', 'TEXT', '医生您好, 我晚餐后血糖测到 7.4, 需要调整饮食吗?', '2026-05-18 21:31:00'),
(2, 1, 2, 'DOCTOR', 'TEXT', '建议先连续记录三天餐后 2 小时血糖, 晚餐减少精制主食, 增加蔬菜。', '2026-05-19 08:20:00'),
(3, 2, 5, 'USER', 'TEXT', '最近血压又到 152/96, 晚上偶尔胸闷。', '2026-06-22 21:02:00'),
(4, 2, 3, 'DOCTOR', 'TEXT', '请今晚避免剧烈活动, 继续监测血压; 如胸痛或持续胸闷请立即线下就医。', '2026-06-22 21:20:00'),
(5, 3, 6, 'USER', 'TEXT', '跑步后心率恢复比较慢, 预约了 6 月 25 日门诊。', '2026-06-23 20:02:00');

-- health_archive (5)
INSERT INTO health_archive (id, user_id, title, category, record_date, hospital, description, create_time) VALUES
(1, 4, '2025 年度体检报告', '体检报告', '2025-10-15', '杭州市第一人民医院', '年度常规体检: 血压、血糖、血脂、肝肾功能均在正常范围。', '2025-10-20 10:00:00'),
(2, 5, '2026 年 5 月心电图复查', '检查报告', '2026-05-30', '浙江大学医学院附属第二医院', '窦性心律, 偶发房性早搏, 建议 24 小时动态心电监测。', '2026-06-02 14:00:00'),
(3, 5, '2025 年 12 月住院小结', '住院记录', '2025-12-10', '杭州市第一人民医院', '因血压控制不佳住院调整用药方案, 出院后规律随访。', '2025-12-18 09:30:00'),
(4, 6, '2026 年 4 月运动负荷试验', '检查报告', '2026-04-22', '邵逸夫医院', '运动平板试验阴性, 心肺功能评估良好。', '2026-04-25 16:00:00'),
(5, 4, '2026 年 1 月颈椎 MRI', '影像报告', '2026-01-08', '浙江省人民医院', '颈椎轻度退行性变, C5/6 椎间盘突出, 建议避免久坐。', '2026-01-12 11:20:00');

-- archive_file (5)
INSERT INTO archive_file (id, archive_id, file_name, file_path, file_size, upload_time) VALUES
(1, 1, '体检报告-20251015.pdf', '/uploads/archive/1/report.pdf', 524288, '2025-10-20 10:00:00'),
(2, 2, '心电图-20260530.pdf', '/uploads/archive/2/ecg.pdf', 312000, '2026-06-02 14:00:00'),
(3, 3, '住院小结-20251218.pdf', '/uploads/archive/3/summary.pdf', 256000, '2025-12-18 09:30:00'),
(4, 4, '运动负荷-20260422.pdf', '/uploads/archive/4/stress.pdf', 412000, '2026-04-25 16:00:00'),
(5, 5, '颈椎MRI-20260108.pdf', '/uploads/archive/5/mri.pdf', 1024000, '2026-01-12 11:20:00');

-- health_data (10)
INSERT INTO health_data (id, user_id, data_type, value1, value2, unit, record_time, status, remark) VALUES
(1, 4, 'STEPS', 8420, NULL, '步', '2026-06-21 21:00:00', 'NORMAL', '今日步行达标'),
(2, 4, 'BLOOD_SUGAR', 7.4, NULL, 'mmol/L', '2026-06-22 20:30:00', 'WARN', '餐后偏高'),
(3, 5, 'BLOOD_PRESSURE', 152, 96, 'mmHg', '2026-06-22 19:00:00', 'DANGER', '收缩压高'),
(4, 5, 'HEART_RATE', 88, NULL, 'bpm', '2026-06-22 19:05:00', 'WARN', '静息心率偏高'),
(5, 5, 'SLEEP', 6.5, NULL, '小时', '2026-06-22 07:00:00', 'NORMAL', '睡眠时长偏短'),
(6, 6, 'STEPS', 11200, NULL, '步', '2026-06-23 21:00:00', 'NORMAL', '跑步后补充'),
(7, 6, 'HEART_RATE', 124, NULL, 'bpm', '2026-06-23 20:00:00', 'WARN', '运动后偏高'),
(8, 4, 'WEIGHT', 65.5, NULL, 'kg', '2026-06-22 07:00:00', 'NORMAL', '体重稳定'),
(9, 4, 'TEMPERATURE', 36.5, NULL, '℃', '2026-06-22 07:30:00', 'NORMAL', '体温正常'),
(10, 5, 'SPO2', 97, NULL, '%', '2026-06-22 19:10:00', 'NORMAL', '血氧良好');

-- emergency_contact (5)
INSERT INTO emergency_contact (id, user_id, name, relation, phone, sort_no) VALUES
(1, 4, '王建国', '父亲', '13700001001', 1),
(2, 4, '刘梅', '母亲', '13700001002', 2),
(3, 5, '陈晓雨', '女儿', '13700002001', 1),
(4, 5, '周宁', '配偶', '13700002002', 2),
(5, 6, '赵明', '哥哥', '13700003001', 1);

-- emergency_record (2)
INSERT INTO emergency_record (id, user_id, location_text, latitude, longitude, contact_snapshot, status, help_time, result) VALUES
(1, 5, '杭州市上城区湖滨银泰附近', '30.2553', '120.1697', '陈晓雨(女儿) 13700002001; 周宁(配偶) 13700002002', 'FINISHED', '2026-05-24 18:25:00', '已联系家属并建议就近就医'),
(2, 6, '杭州市西湖区文三路地铁站', '30.2798', '120.1266', '赵明(哥哥) 13700003001', 'PROCESSING', '2026-06-23 19:10:00', '已发送求救通知, 等待联系人反馈');

-- ============================================================
-- 完成: 15 张表 + 16 段种子数据
-- ============================================================
-- OPC_K PowerShell 5.1 实战版 init.sql (v4.1, 2026-07-06 22:34)
-- 严格遵循:
--   1. UTF-8 BOM (中文 Windows 默认 GBK 解码不会乱码)
--   2. 全 ASCII 标点 (中文只在 COMMENT 里, 不影响语法)
--   3. 端口 / 用户 / 密码 / 库名 跟 application.yml 100% 一致
-- ============================================================
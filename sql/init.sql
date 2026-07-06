-- 健康管理系统初始化脚本
-- MySQL 端口按用户环境使用 3305，执行示例：
-- mysql -h127.0.0.1 -P3305 -uroot -proot < sql/init.sql

DROP DATABASE IF EXISTS health_management;
CREATE DATABASE health_management DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE health_management;

CREATE TABLE sys_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录账号',
    password VARCHAR(50) NOT NULL COMMENT '明文密码，课程演示用',
    real_name VARCHAR(50) NOT NULL COMMENT '真实姓名',
    phone VARCHAR(30) COMMENT '手机号',
    role VARCHAR(20) NOT NULL COMMENT '角色：USER用户、DOCTOR医生、ADMIN管理员',
    gender VARCHAR(10) COMMENT '性别',
    age INT COMMENT '年龄',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '账号状态',
    create_time DATETIME NOT NULL COMMENT '创建时间'
) COMMENT='系统用户表';

CREATE TABLE hospital (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    name VARCHAR(100) NOT NULL COMMENT '医院名称',
    level VARCHAR(30) COMMENT '医院等级',
    address VARCHAR(200) COMMENT '医院地址',
    phone VARCHAR(30) COMMENT '联系电话'
) COMMENT='医院表';

CREATE TABLE department (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    hospital_id BIGINT NOT NULL COMMENT '所属医院ID',
    name VARCHAR(50) NOT NULL COMMENT '科室名称',
    description VARCHAR(255) COMMENT '科室说明'
) COMMENT='科室表';

CREATE TABLE doctor (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '医生对应用户ID',
    hospital_id BIGINT NOT NULL COMMENT '所属医院ID',
    department_id BIGINT NOT NULL COMMENT '所属科室ID',
    title VARCHAR(50) COMMENT '医生职称',
    specialty VARCHAR(255) COMMENT '擅长方向',
    profile VARCHAR(500) COMMENT '医生简介',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '医生状态'
) COMMENT='医生信息表';

CREATE TABLE doctor_schedule (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    doctor_id BIGINT NOT NULL COMMENT '医生ID',
    schedule_date DATE NOT NULL COMMENT '出诊日期',
    time_slot VARCHAR(30) NOT NULL COMMENT '出诊时段',
    total_quota INT NOT NULL COMMENT '总号源',
    remain_quota INT NOT NULL COMMENT '剩余号源'
) COMMENT='医生排班表';

CREATE TABLE health_archive (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    age INT COMMENT '年龄',
    gender VARCHAR(10) COMMENT '性别',
    height DECIMAL(5,2) COMMENT '身高cm',
    weight DECIMAL(5,2) COMMENT '体重kg',
    blood_type VARCHAR(10) COMMENT '血型',
    disease_history VARCHAR(500) COMMENT '既往病史',
    allergy_history VARCHAR(500) COMMENT '过敏史',
    common_medicine VARCHAR(500) COMMENT '常用药物',
    privacy_level VARCHAR(20) NOT NULL DEFAULT 'AUTHORIZED_DOCTOR' COMMENT '隐私级别',
    update_time DATETIME NOT NULL COMMENT '更新时间'
) COMMENT='个人健康档案表';

CREATE TABLE archive_file (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    archive_id BIGINT NOT NULL COMMENT '健康档案ID',
    file_name VARCHAR(120) NOT NULL COMMENT '原始文件名',
    file_url VARCHAR(255) NOT NULL COMMENT '文件访问地址',
    upload_time DATETIME NOT NULL COMMENT '上传时间'
) COMMENT='档案附件表';

CREATE TABLE appointment (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '预约用户ID',
    hospital_id BIGINT NOT NULL COMMENT '医院ID',
    department_id BIGINT NOT NULL COMMENT '科室ID',
    doctor_id BIGINT NOT NULL COMMENT '医生ID',
    schedule_id BIGINT NOT NULL COMMENT '排班ID',
    appointment_date DATE NOT NULL COMMENT '预约日期',
    time_slot VARCHAR(30) NOT NULL COMMENT '预约时段',
    status VARCHAR(20) NOT NULL COMMENT '状态：CONFIRMED、CANCELLED、FINISHED',
    symptom VARCHAR(500) COMMENT '症状描述',
    create_time DATETIME NOT NULL COMMENT '创建时间',
    remind_time DATETIME COMMENT '提醒时间'
) COMMENT='医疗预约表';

CREATE TABLE medicine_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    medicine_name VARCHAR(100) NOT NULL COMMENT '药品名称',
    usage_method VARCHAR(100) COMMENT '用法',
    dosage VARCHAR(100) COMMENT '用量',
    reminder_times VARCHAR(100) COMMENT '每日提醒时间',
    start_date DATE COMMENT '开始日期',
    end_date DATE COMMENT '结束日期',
    status VARCHAR(20) NOT NULL COMMENT '状态：ACTIVE进行中、FINISHED已结束',
    warning VARCHAR(255) COMMENT '用药风险提示',
    create_time DATETIME NOT NULL COMMENT '创建时间'
) COMMENT='用药记录表';

CREATE TABLE health_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    systolic INT COMMENT '收缩压',
    diastolic INT COMMENT '舒张压',
    blood_sugar DECIMAL(4,1) COMMENT '血糖mmol/L',
    heart_rate INT COMMENT '心率',
    steps INT COMMENT '步数',
    sleep_hours DECIMAL(3,1) COMMENT '睡眠时长',
    weight DECIMAL(5,2) COMMENT '体重kg',
    warning_level VARCHAR(20) NOT NULL COMMENT '预警级别：NORMAL、WARN',
    warning_message VARCHAR(255) COMMENT '预警说明',
    record_time DATETIME NOT NULL COMMENT '记录时间'
) COMMENT='健康数据监控表';

CREATE TABLE emergency_contact (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    name VARCHAR(50) NOT NULL COMMENT '联系人姓名',
    relation VARCHAR(30) COMMENT '关系',
    phone VARCHAR(30) NOT NULL COMMENT '联系电话',
    sort_no INT NOT NULL COMMENT '排序'
) COMMENT='紧急联系人表';

CREATE TABLE emergency_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    location_text VARCHAR(255) COMMENT '求救位置文本',
    latitude VARCHAR(30) COMMENT '纬度',
    longitude VARCHAR(30) COMMENT '经度',
    contact_snapshot VARCHAR(500) COMMENT '求救时联系人快照',
    status VARCHAR(20) NOT NULL COMMENT '状态：PROCESSING、FINISHED',
    help_time DATETIME NOT NULL COMMENT '求救时间',
    result VARCHAR(255) COMMENT '处理结果'
) COMMENT='紧急求救记录表';

CREATE TABLE health_article (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    title VARCHAR(120) NOT NULL COMMENT '标题',
    category VARCHAR(30) NOT NULL COMMENT '分类：疾病、养生、饮食、运动',
    disease_tag VARCHAR(100) COMMENT '疾病标签',
    summary VARCHAR(255) COMMENT '摘要',
    content TEXT COMMENT '正文',
    author_id BIGINT COMMENT '作者用户ID',
    view_count INT NOT NULL DEFAULT 0 COMMENT '浏览次数',
    publish_time DATETIME NOT NULL COMMENT '发布时间'
) COMMENT='健康知识文章表';

CREATE TABLE consultation (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    doctor_id BIGINT NOT NULL COMMENT '医生ID',
    title VARCHAR(120) NOT NULL COMMENT '咨询标题',
    status VARCHAR(20) NOT NULL COMMENT '状态：OPEN、CLOSED',
    create_time DATETIME NOT NULL COMMENT '创建时间',
    follow_up_time DATETIME COMMENT '复诊提醒时间'
) COMMENT='在线咨询会话表';

CREATE TABLE consultation_message (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    consultation_id BIGINT NOT NULL COMMENT '咨询会话ID',
    sender_id BIGINT NOT NULL COMMENT '发送人用户ID',
    sender_role VARCHAR(20) NOT NULL COMMENT '发送人角色',
    message_type VARCHAR(20) NOT NULL COMMENT '消息类型：TEXT、IMAGE',
    content VARCHAR(1000) NOT NULL COMMENT '消息内容或图片地址',
    send_time DATETIME NOT NULL COMMENT '发送时间'
) COMMENT='在线咨询消息表';

INSERT INTO sys_user (id, username, password, real_name, phone, role, gender, age, status, create_time) VALUES
(1, 'admin', 'root', '系统管理员', '13800000000', 'ADMIN', '男', 36, 'ACTIVE', '2026-05-01 09:00:00'),
(2, 'doctor_zhang', 'root', '张医生', '13800000001', 'DOCTOR', '女', 42, 'ACTIVE', '2026-05-02 09:30:00'),
(3, 'doctor_li', 'root', '李医生', '13800000002', 'DOCTOR', '男', 39, 'ACTIVE', '2026-05-02 10:00:00'),
(4, 'user_wang', 'root', '王晓敏', '13900000001', 'USER', '女', 34, 'ACTIVE', '2026-05-03 08:30:00'),
(5, 'user_chen', 'root', '陈志远', '13900000002', 'USER', '男', 51, 'ACTIVE', '2026-05-04 11:20:00'),
(6, 'user_zhao', 'root', '赵一诺', '13900000003', 'USER', '女', 28, 'ACTIVE', '2026-05-05 15:10:00');

INSERT INTO hospital (id, name, level, address, phone) VALUES
(1, '杭州市第一人民医院', '三甲', '杭州市上城区浣纱路261号', '0571-56000001'),
(2, '浙江省中医院湖滨院区', '三甲', '杭州市上城区邮电路54号', '0571-56000002');

INSERT INTO department (id, hospital_id, name, description) VALUES
(1, 1, '内科', '慢病、血压、血糖及常见内科疾病诊疗'),
(2, 1, '外科', '普通外科、创伤和术后随访'),
(3, 2, '中医养生科', '中医体质辨识、饮食运动调养'),
(4, 2, '心血管科', '心血管疾病管理和复诊随访');

INSERT INTO doctor (id, user_id, hospital_id, department_id, title, specialty, profile, status) VALUES
(1, 2, 1, 1, '主任医师', '高血压、糖尿病、慢病管理', '从事内科慢病管理18年，擅长个体化健康方案。', 'ACTIVE'),
(2, 3, 2, 4, '副主任医师', '心律失常、冠心病、用药指导', '长期从事心血管疾病诊治和远程复诊。', 'ACTIVE');

INSERT INTO doctor_schedule (id, doctor_id, schedule_date, time_slot, total_quota, remain_quota) VALUES
(1, 1, '2026-05-10', '上午', 20, 18),
(2, 1, '2026-05-28', '下午', 15, 14),
(3, 1, '2026-06-15', '上午', 20, 19),
(4, 2, '2026-05-20', '上午', 18, 16),
(5, 2, '2026-06-10', '下午', 12, 11),
(6, 2, '2026-06-25', '上午', 18, 17);

INSERT INTO health_archive (id, user_id, name, age, gender, height, weight, blood_type, disease_history, allergy_history, common_medicine, privacy_level, update_time) VALUES
(1, 4, '王晓敏', 34, '女', 163.00, 58.50, 'A', '妊娠期血糖偏高史', '青霉素过敏', '维生素D', 'AUTHORIZED_DOCTOR', '2026-05-08 10:20:00'),
(2, 5, '陈志远', 51, '男', 172.00, 78.20, 'O', '高血压5年，血脂偏高', '无', '氨氯地平、阿托伐他汀', 'AUTHORIZED_DOCTOR', '2026-06-01 09:40:00'),
(3, 6, '赵一诺', 28, '女', 168.00, 55.00, 'B', '无重大病史', '海鲜轻度过敏', '无', 'AUTHORIZED_DOCTOR', '2026-06-12 14:10:00');

INSERT INTO archive_file (id, archive_id, file_name, file_url, upload_time) VALUES
(1, 1, '2026-05-08-体检报告.pdf', '/uploads/demo-check-wang.pdf', '2026-05-08 10:30:00'),
(2, 2, '2026-06-01-血脂复查.pdf', '/uploads/demo-lipid-chen.pdf', '2026-06-01 09:50:00'),
(3, 3, '2026-06-12-入职体检.pdf', '/uploads/demo-check-zhao.pdf', '2026-06-12 14:20:00');

INSERT INTO appointment (id, user_id, hospital_id, department_id, doctor_id, schedule_id, appointment_date, time_slot, status, symptom, create_time, remind_time) VALUES
(1, 4, 1, 1, 1, 1, '2026-05-10', '上午', 'FINISHED', '近期餐后血糖偏高，想咨询饮食控制', '2026-05-06 09:10:00', '2026-05-09 09:00:00'),
(2, 5, 2, 4, 2, 4, '2026-05-20', '上午', 'FINISHED', '血压波动，偶有胸闷', '2026-05-15 16:30:00', '2026-05-19 09:00:00'),
(3, 5, 1, 1, 1, 3, '2026-06-15', '上午', 'CONFIRMED', '复查血压和用药方案', '2026-06-10 11:05:00', '2026-06-14 09:00:00'),
(4, 6, 2, 4, 2, 6, '2026-06-25', '上午', 'CONFIRMED', '运动后心率恢复较慢', '2026-06-20 13:40:00', '2026-06-24 09:00:00'),
(5, 4, 1, 1, 1, 2, '2026-05-28', '下午', 'CANCELLED', '复诊时间冲突取消', '2026-05-21 10:00:00', '2026-05-27 09:00:00');

INSERT INTO medicine_record (id, user_id, medicine_name, usage_method, dosage, reminder_times, start_date, end_date, status, warning, create_time) VALUES
(1, 5, '氨氯地平片', '口服', '每日1次，每次1片', '08:00', '2026-05-01', '2026-06-25', 'ACTIVE', '暂无冲突风险', '2026-05-01 08:00:00'),
(2, 5, '阿司匹林肠溶片', '口服', '每日1次，每次100mg', '20:00', '2026-05-12', '2026-06-20', 'ACTIVE', '抗凝/抗血小板药物请遵医嘱，避免自行叠加服用', '2026-05-12 19:30:00'),
(3, 4, '维生素D滴剂', '口服', '每日1次，每次1粒', '09:00', '2026-05-08', '2026-06-08', 'FINISHED', '暂无冲突风险', '2026-05-08 09:00:00'),
(4, 6, '布洛芬缓释胶囊', '口服', '疼痛时服用，每次1粒', '按需', '2026-06-18', '2026-06-22', 'FINISHED', '请勿长期自行服用，如伴随心血管症状需咨询医生', '2026-06-18 12:20:00');

INSERT INTO health_data (id, user_id, systolic, diastolic, blood_sugar, heart_rate, steps, sleep_hours, weight, warning_level, warning_message, record_time) VALUES
(1, 4, 118, 76, 5.6, 74, 8600, 7.2, 58.50, 'NORMAL', '指标正常', '2026-05-05 21:00:00'),
(2, 4, 122, 78, 7.4, 78, 7200, 6.8, 58.70, 'WARN', '血糖偏高；', '2026-05-18 21:00:00'),
(3, 4, 116, 72, 5.8, 72, 9800, 7.5, 58.20, 'NORMAL', '指标正常', '2026-06-10 21:00:00'),
(4, 5, 146, 92, 6.2, 84, 5200, 6.1, 78.20, 'WARN', '血压超过140/90mmHg；', '2026-05-16 20:30:00'),
(5, 5, 138, 86, 6.0, 80, 6800, 6.5, 77.80, 'NORMAL', '指标正常', '2026-06-05 20:30:00'),
(6, 5, 152, 96, 6.8, 88, 4300, 5.9, 78.60, 'WARN', '血压超过140/90mmHg；', '2026-06-22 20:30:00'),
(7, 6, 110, 70, 5.1, 76, 10300, 7.8, 55.00, 'NORMAL', '指标正常', '2026-05-22 22:10:00'),
(8, 6, 124, 80, 5.4, 108, 11800, 6.4, 55.20, 'WARN', '心率异常；', '2026-06-21 22:10:00');

INSERT INTO emergency_contact (id, user_id, name, relation, phone, sort_no) VALUES
(1, 4, '王建国', '父亲', '13700001001', 1),
(2, 4, '刘梅', '母亲', '13700001002', 2),
(3, 5, '陈晓雨', '女儿', '13700002001', 1),
(4, 5, '周宁', '配偶', '13700002002', 2),
(5, 6, '赵明', '哥哥', '13700003001', 1);

INSERT INTO emergency_record (id, user_id, location_text, latitude, longitude, contact_snapshot, status, help_time, result) VALUES
(1, 5, '杭州市上城区湖滨银泰附近', '30.2553', '120.1697', '陈晓雨(女儿) 13700002001；周宁(配偶) 13700002002', 'FINISHED', '2026-05-24 18:25:00', '已联系家属并建议就近就医'),
(2, 6, '杭州市西湖区文三路地铁站', '30.2798', '120.1266', '赵明(哥哥) 13700003001', 'PROCESSING', '2026-06-23 19:10:00', '已发送求救通知，等待联系人反馈');

INSERT INTO health_article (id, title, category, disease_tag, summary, content, author_id, view_count, publish_time) VALUES
(1, '高血压患者的家庭血压监测要点', '疾病', '高血压', '介绍血压测量时间、姿势和异常处理。', '建议每天固定时间测量血压，连续记录趋势；若多次超过140/90mmHg，应及时咨询医生。', 2, 156, '2026-05-09 08:30:00'),
(2, '控糖饮食的三餐搭配方法', '饮食', '糖尿病,血糖', '帮助用户合理安排主食、蛋白质和蔬菜。', '每餐控制精制碳水比例，优先选择全谷物、优质蛋白和高纤维蔬菜。', 2, 132, '2026-05-18 09:00:00'),
(3, '久坐人群的低强度运动计划', '运动', '运动', '适合办公室人群的步行和拉伸建议。', '建议每坐60分钟起身活动3-5分钟，每周累计150分钟中等强度运动。', 3, 98, '2026-06-03 10:15:00'),
(4, '夏季睡眠与心率恢复', '养生', '心率,睡眠', '讲解睡眠不足对心率和恢复能力的影响。', '保持规律作息、睡前减少咖啡因摄入，有助于改善心率恢复。', 3, 87, '2026-06-16 11:20:00');

INSERT INTO consultation (id, user_id, doctor_id, title, status, create_time, follow_up_time) VALUES
(1, 4, 1, '餐后血糖偏高咨询', 'CLOSED', '2026-05-18 21:30:00', '2026-06-18 09:00:00'),
(2, 5, 2, '血压波动和胸闷', 'OPEN', '2026-06-22 21:00:00', '2026-06-25 10:00:00'),
(3, 6, 2, '运动后心率偏快', 'OPEN', '2026-06-23 20:00:00', NULL);

INSERT INTO consultation_message (id, consultation_id, sender_id, sender_role, message_type, content, send_time) VALUES
(1, 1, 4, 'USER', 'TEXT', '医生您好，我晚餐后血糖测到7.4，需要调整饮食吗？', '2026-05-18 21:31:00'),
(2, 1, 2, 'DOCTOR', 'TEXT', '建议先连续记录三天餐后2小时血糖，晚餐减少精制主食，增加蔬菜。', '2026-05-19 08:20:00'),
(3, 2, 5, 'USER', 'TEXT', '最近血压又到152/96，晚上偶尔胸闷。', '2026-06-22 21:02:00'),
(4, 2, 3, 'DOCTOR', 'TEXT', '请今晚避免剧烈活动，继续监测血压；如胸痛或持续胸闷请立即线下就医。', '2026-06-22 21:20:00'),
(5, 3, 6, 'USER', 'TEXT', '跑步后心率恢复比较慢，预约了6月25日门诊。', '2026-06-23 20:02:00');

// 相伴课表 Mock API — 仅用于本地开发与 UI 联调演示
// 不是生产后端：无数据库、无短信、无 OCR、无权限校验。
// express / cors / helmet / rate-limit 骨架参考了私有后端的安全基础配置。
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const PORT = parseInt(process.env.PORT || '3000', 10);
const MOCK_TOKEN = process.env.MOCK_TOKEN || 'mock-token-heybuddy-2026';
const MOCK_SMS_CODE = '123456';

// ---- 配置校验 ----
function validateRuntimeConfig() {
  const issues = [];
  if (!MOCK_TOKEN || MOCK_TOKEN.includes('change_me')) {
    issues.push('MOCK_TOKEN 缺失或仍使用占位值');
  }
  if (issues.length > 0) {
    console.warn('[mock-api] 配置提醒:', issues.join('；'));
  }
}

// ---- 工具函数（从私有后端安全抽取）----
function clampInt(v, min, max) {
  const n = parseInt(v || min);
  if (isNaN(n) || n < min) return min;
  if (n > max) return max;
  return n;
}

function toInt(value, fallback) {
  const parsed = parseInt(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, toInt(value, min)));
}

function normalizeCoursePayload(raw) {
  const startPeriod = parseInt(raw.startPeriod ?? raw.startSection ?? 1);
  const endPeriod = parseInt(raw.endPeriod ?? raw.endSection ?? startPeriod);
  return {
    name: String(raw.name || '').trim(),
    teacher: String(raw.teacher || '').trim(),
    location: String(raw.location ?? raw.position ?? '').trim(),
    dayOfWeek: parseInt(raw.dayOfWeek ?? raw.day ?? 1),
    startPeriod,
    endPeriod,
    weeks: (Array.isArray(raw.weeks) ? raw.weeks.join(',') : String(raw.weeks || '1-16')).trim() || '1-16',
    color: String(raw.color || '#5B6AF0').trim() || '#5B6AF0',
    semester: String(raw.semester || '2025-2026-2').trim() || '2025-2026-2',
  };
}

// ---- 中间件 ----
const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '8mb' }));
app.use('/api/', rateLimit({ windowMs: 60000, max: 60, message: { code: 1, msg: '请求太频繁' } }));

// ---- Mock 鉴权（不校验真实 JWT，只检查 token 头） ----
function mockAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ code: 401, msg: '请先登录' });
  }
  const token = header.split(' ')[1];
  if (token !== MOCK_TOKEN) {
    return res.status(401).json({ code: 401, msg: '登录已过期，请重新登录' });
  }
  req.userId = 'mock-user-1';
  req.phone = '138****0000';
  next();
}

// ---- 健康检查 ----
app.get('/api/ping', (_req, res) =>
  res.json({ code: 0, msg: 'pong', time: new Date().toISOString() }),
);

// ---- 登录 / 注册 ----
app.post('/api/auth/register', (_req, res) =>
  res.json({ code: 0, msg: '注册成功 [mock]', data: { token: MOCK_TOKEN, userId: 'mock-user-1' } }),
);

app.post('/api/auth/login', (_req, res) =>
  res.json({ code: 0, msg: '登录成功 [mock]', data: { token: MOCK_TOKEN, userId: 'mock-user-1' } }),
);

app.post('/api/auth/register-sms', (_req, res) =>
  res.json({ code: 0, msg: '注册成功 [mock]', data: { token: MOCK_TOKEN, userId: 'mock-user-1' } }),
);

// ---- 短信（mock：固定验证码）----
app.post('/api/sms/send', (_req, res) =>
  res.json({ code: 0, msg: '[mock] 验证码已发送，测试验证码: ' + MOCK_SMS_CODE }),
);

// ---- 忘记密码 ----
app.post('/api/auth/forgot-password/send-code', (_req, res) =>
  res.json({ code: 0, msg: '[mock] 验证码已发送' }),
);
app.post('/api/auth/forgot-password/reset', (_req, res) =>
  res.json({ code: 0, msg: '密码重置成功 [mock]，请重新登录' }),
);

// ---- 用户资料 ----
app.get('/api/user/profile', mockAuth, (_req, res) =>
  res.json({
    code: 0,
    data: {
      id: 'mock-user-1',
      phone: '138****0000',
      nickname: '测试用户',
      avatarUrl: null,
      schoolName: '示例大学',
      schoolId: 'DEMO',
      createdAt: '2026-01-01T00:00:00.000Z',
    },
  }),
);

app.put('/api/user/profile', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '更新成功 [mock]' }),
);

app.put('/api/user/phone', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '手机号修改成功 [mock]', data: { token: MOCK_TOKEN, userId: 'mock-user-1' } }),
);

app.put('/api/user/password', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '密码修改成功 [mock]' }),
);

// ---- 课程 mock ----
const MOCK_COURSES = [
  { id: 'c-1', name: '高等数学', teacher: '张老师', location: '教学楼A201', day_of_week: 1, start_period: 1, end_period: 3, weeks: '1-16', color: '#4CAF50', semester: '2025-2026-2', user_id: 'mock-user-1' },
  { id: 'c-2', name: '大学英语', teacher: '李老师', location: '教学楼B305', day_of_week: 2, start_period: 3, end_period: 4, weeks: '1-16', color: '#2196F3', semester: '2025-2026-2', user_id: 'mock-user-1' },
  { id: 'c-3', name: '数据结构', teacher: '王老师', location: '实验楼C102', day_of_week: 3, start_period: 1, end_period: 2, weeks: '1-12', color: '#FF9800', semester: '2025-2026-2', user_id: 'mock-user-1' },
  { id: 'c-4', name: '体育', teacher: '赵老师', location: '操场', day_of_week: 4, start_period: 5, end_period: 6, weeks: '1-16', color: '#E91E63', semester: '2025-2026-2', user_id: 'mock-user-1' },
  { id: 'c-5', name: '形势与政策', teacher: '刘老师', location: '报告厅', day_of_week: 5, start_period: 7, end_period: 8, weeks: '3-10', color: '#9C27B0', semester: '2025-2026-2', user_id: 'mock-user-1' },
];

const MOCK_FRIEND_COURSES = [
  { id: 'fc-1', name: '线性代数', teacher: '陈老师', location: '教学楼A303', day_of_week: 1, start_period: 1, end_period: 2, weeks: '1-16', color: '#00BCD4', semester: '2025-2026-2' },
  { id: 'fc-2', name: '大学物理', teacher: '周老师', location: '教学楼C201', day_of_week: 2, start_period: 5, end_period: 6, weeks: '1-14', color: '#FF5722', semester: '2025-2026-2' },
  { id: 'fc-3', name: '程序设计', teacher: '吴老师', location: '机房D101', day_of_week: 4, start_period: 3, end_period: 4, weeks: '1-16', color: '#607D8B', semester: '2025-2026-2' },
];

app.get('/api/courses', mockAuth, (req, res) => {
  const semester = req.query.semester || '2025-2026-2';
  const filtered = MOCK_COURSES.filter((c) => c.semester === semester);
  res.json({ code: 0, data: filtered });
});

app.post('/api/courses', mockAuth, (req, res) => {
  const course = normalizeCoursePayload(req.body);
  course.id = 'mock-c-' + Date.now();
  res.json({ code: 0, msg: '添加成功 [mock]', data: course });
});

app.post('/api/courses/batch', mockAuth, (req, res) => {
  const courses = req.body.courses || [];
  if (!Array.isArray(courses) || courses.length === 0) {
    return res.json({ code: 1, msg: '课程数据为空' });
  }
  res.json({ code: 0, msg: '成功导入 ' + courses.length + ' 门课程 [mock]' });
});

app.delete('/api/courses/:id', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '删除成功 [mock]' }),
);

// ---- 好友课表 ----
app.get('/api/friends/:friendId/courses', mockAuth, (_req, res) =>
  res.json({ code: 0, data: MOCK_FRIEND_COURSES }),
);

// ---- 好友管理 ----
const MOCK_FRIENDS = [
  { id: 'f-1', status: 'accepted', friend_id: 'mock-user-2', nickname: '小明', original_nickname: '小明', avatar_url: null, school_name: '示例大学', is_outgoing: false, created_at: '2026-03-01T00:00:00.000Z' },
  { id: 'f-2', status: 'pending', friend_id: 'mock-user-3', nickname: '小红', original_nickname: '小红', avatar_url: null, school_name: '示例大学', is_outgoing: true, created_at: '2026-04-15T00:00:00.000Z' },
];

app.get('/api/friends', mockAuth, (_req, res) =>
  res.json({ code: 0, data: MOCK_FRIENDS }),
);

app.post('/api/friends/request', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '好友请求已发送 [mock]' }),
);

app.put('/api/friends/:id/accept', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '已接受好友请求 [mock]' }),
);

app.put('/api/friends/:id/reject', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '已拒绝好友请求 [mock]' }),
);

app.put('/api/friends/:id/remark', mockAuth, (req, res) => {
  const remark = String(req.body.remark || '').trim();
  return res.json({ code: 0, msg: remark ? '备注已更新 [mock]' : '已清除备注 [mock]' });
});

app.delete('/api/friends/:id', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '已删除好友 [mock]' }),
);

// ---- 好友纪念日 ----
app.get('/api/friends/:friendId/anniversaries', mockAuth, (_req, res) =>
  res.json({
    code: 0,
    data: [{ id: 'a-1', name: '成为好友', target_date: '2026-03-01', created_at: '2026-03-01T00:00:00.000Z', owner_id: 'mock-user-1', can_edit: true }],
  }),
);

app.post('/api/friends/:friendId/anniversaries', mockAuth, (req, res) =>
  res.json({ code: 0, msg: '纪念日已添加 [mock]', data: { id: 'a-' + Date.now(), name: req.body.name, target_date: req.body.targetDate, created_at: new Date().toISOString() } }),
);

app.put('/api/friends/:friendId/anniversaries/:id', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '纪念日已更新 [mock]' }),
);

app.delete('/api/friends/:friendId/anniversaries/:id', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '纪念日已删除 [mock]' }),
);

// ---- 聊天 ----
app.get('/api/messages/:friendId', mockAuth, (_req, res) =>
  res.json({
    code: 0,
    data: [
      { id: 'm-1', sender_id: 'mock-user-2', receiver_id: 'mock-user-1', content: '下午有课吗？', content_type: 'text', created_at: new Date(Date.now() - 3600000).toISOString(), is_read: true },
      { id: 'm-2', sender_id: 'mock-user-1', receiver_id: 'mock-user-2', content: '有两节', content_type: 'text', created_at: new Date(Date.now() - 1800000).toISOString(), is_read: false },
    ],
  }),
);

app.post('/api/messages', mockAuth, (req, res) =>
  res.json({
    code: 0,
    data: { id: 'm-' + Date.now(), sender_id: 'mock-user-1', receiver_id: req.body.receiverId || 'mock-user-2', content: req.body.content || '', content_type: req.body.contentType || 'text', created_at: new Date().toISOString(), is_read: false },
  }),
);

// ---- OCR mock（固定返回示例课程，不调用第三方模型）----
app.post('/api/ocr/recognize', mockAuth, (_req, res) =>
  res.json({
    code: 0,
    msg: '识别成功，共 3 门课 [mock]',
    warning: null,
    data: [
      { name: '高等数学', teacher: '张老师', location: '教学楼A201', dayOfWeek: 1, startPeriod: 1, endPeriod: 3, weeks: '1-16', mock: true },
      { name: '大学英语', teacher: '李老师', location: '教学楼B305', dayOfWeek: 2, startPeriod: 3, endPeriod: 4, weeks: '1-16', mock: true },
      { name: '体育', teacher: '赵老师', location: '操场', dayOfWeek: 4, startPeriod: 5, endPeriod: 6, weeks: '1-16', mock: true },
    ],
  }),
);

// ---- 显示偏好 ----
app.get('/api/prefs', mockAuth, (_req, res) =>
  res.json({ code: 0, data: { dayViewFriends: ['mock-user-2'], weekViewFriend: 'mock-user-2' } }),
);

app.put('/api/prefs', mockAuth, (_req, res) =>
  res.json({ code: 0, msg: '更新成功 [mock]' }),
);

// ---- 404 / 500 ----
app.use((_req, res) => res.status(404).json({ code: 404, msg: '接口不存在' }));
app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ code: 500, msg: '服务器内部错误' });
});

// ---- 启动 ----
Promise.resolve()
  .then(() => validateRuntimeConfig())
  .then(() => {
    app.listen(PORT, () => console.log('[mock-api] http://localhost:' + PORT));
  })
  .catch((err) => {
    console.error('[mock-api] init failed:', err);
    process.exit(1);
  });
